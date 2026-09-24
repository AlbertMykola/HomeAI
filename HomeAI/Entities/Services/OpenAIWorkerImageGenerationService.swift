import CoreImage
import UIKit

enum OpenAIWorkerImageError: ImageGenerationFailure {
    case invalidURL
    case requestEncoding
    case requestFailed(Error)
    case server(statusCode: Int, code: String, message: String, retryable: Bool)
    case invalidResponse
    case invalidImage
    case invalidMask

    var category: String {
        switch self {
        case .invalidURL, .requestEncoding:
            return "configuration"
        case .requestFailed(let error):
            return (error as? URLError)?.code == .timedOut ? "timeout" : "network"
        case .server(_, let code, _, _):
            return code
        case .invalidResponse, .invalidImage:
            return "decoding"
        case .invalidMask:
            return "mask"
        }
    }

    var statusCode: Int? {
        if case .server(let statusCode, _, _, _) = self { return statusCode }
        return nil
    }

    var errorDescription: String? {
        switch self {
        case .invalidURL, .requestEncoding:
            return "The generation request could not be prepared. Please try again.".localized
        case .requestFailed(let error):
            if (error as? URLError)?.code == .timedOut {
                return "Generation is taking longer than expected. Please try again.".localized
            }
            return "Please check your internet connection and try again.".localized
        case .server(_, let code, let message, _):
            if code == "content_policy" {
                return "The image request could not be processed. Please adjust it and try again.".localized
            }
            #if DEBUG
            return message
            #else
            return "The generation service is temporarily unavailable. Please try again.".localized
            #endif
        case .invalidResponse, .invalidImage:
            return "The generated image could not be opened. Please try again.".localized
        case .invalidMask:
            return "The selected area no longer matches the photo. Please select the area again.".localized
        }
    }
}

final class OpenAIWorkerImageGenerationService: ImageGenerationService {
    private let endpoint: URL
    private let session: URLSession
    private let mobileGateKey: String?

    var provider: ImageGenerationProvider { .openAI }

    init(
        endpoint: URL,
        session: URLSession? = nil,
        mobileGateKey: String? = nil
    ) {
        self.endpoint = endpoint
        self.mobileGateKey = mobileGateKey
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = Constants.Generation.requestTimeout
            configuration.timeoutIntervalForResource = Constants.Generation.resourceTimeout
            self.session = URLSession(configuration: configuration)
        }
    }

    func model(for option: DesignOption) -> String {
        switch option {
        case .reference, .replace, .delete:
            return Constants.Generation.OpenAI.sunburstModel
        default:
            return Constants.Generation.OpenAI.flareModel
        }
    }

    func generateImage(from input: ImageGenerationInput) async throws -> ImageGenerationResult {
        let request = try makeURLRequest(from: input)
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled || Task.isCancelled {
            throw CancellationError()
        } catch {
            throw OpenAIWorkerImageError.requestFailed(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw OpenAIWorkerImageError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let payload = try? JSONDecoder().decode(OpenAIWorkerErrorResponse.self, from: data)
            throw OpenAIWorkerImageError.server(
                statusCode: http.statusCode,
                code: payload?.error.code ?? "http",
                message: payload?.error.message ?? "HTTP \(http.statusCode)",
                retryable: payload?.error.retryable ?? false
            )
        }

        let payload: OpenAIWorkerResponse
        do {
            payload = try JSONDecoder().decode(OpenAIWorkerResponse.self, from: data)
        } catch {
            throw OpenAIWorkerImageError.invalidResponse
        }
        guard payload.version == 1,
              payload.provider == ImageGenerationProvider.openAI.rawValue,
              let imageData = Data(base64Encoded: payload.image.data),
              let image = UIImage(data: imageData) else {
            throw OpenAIWorkerImageError.invalidImage
        }

        if let usage = payload.usage {
            print(
                "[OpenAIWorker] request=\(payload.requestId) model=\(payload.model) totalTokens=\(usage.totalTokens ?? 0)"
            )
        }

        return ImageGenerationResult(
            image: image,
            prompt: input.prompt(for: .openAI),
            provider: .openAI,
            model: payload.model
        )
    }

    private func makeURLRequest(from input: ImageGenerationInput) throws -> URLRequest {
        guard endpoint.scheme != nil else { throw OpenAIWorkerImageError.invalidURL }

        var images: [OpenAIWorkerRequest.InputImage] = [
            try makeJPEGInput(role: "base", image: input.baseImage)
        ]
        if let referenceImage = input.referenceImage {
            images.append(try makeJPEGInput(role: "reference", image: referenceImage))
        }
        if let maskImage = input.maskImage {
            let maskData = try Self.makeAlphaMaskPNG(
                from: maskImage,
                matching: input.baseImage
            )
            images.append(
                .init(
                    role: "mask",
                    mimeType: "image/png",
                    data: maskData.base64EncodedString()
                )
            )
        }

        let payload = OpenAIWorkerRequest(
            version: 1,
            operation: input.designOption.rawValue,
            prompt: input.prompt(for: .openAI),
            images: images
        )
        let data: Data
        do {
            data = try JSONEncoder().encode(payload)
        } catch {
            throw OpenAIWorkerImageError.requestEncoding
        }
        guard data.count <= Constants.Generation.maxRequestBodyBytes else {
            throw OpenAIWorkerImageError.requestEncoding
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = data
        request.timeoutInterval = Constants.Generation.requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let mobileGateKey, !mobileGateKey.isEmpty {
            request.setValue(mobileGateKey, forHTTPHeaderField: "X-HomeAI-Mobile-Key")
        }
        return request
    }

    private func makeJPEGInput(
        role: String,
        image: UIImage
    ) throws -> OpenAIWorkerRequest.InputImage {
        guard let data = image.jpegData(
            compressionQuality: Constants.Generation.jpegCompressionQuality
        ) else {
            throw OpenAIWorkerImageError.requestEncoding
        }
        return .init(
            role: role,
            mimeType: "image/jpeg",
            data: data.base64EncodedString()
        )
    }

    static func makeAlphaMaskPNG(from mask: UIImage, matching baseImage: UIImage) throws -> Data {
        guard mask.generationPixelSize == baseImage.generationPixelSize,
              let inputImage = CIImage(image: mask) else {
            throw OpenAIWorkerImageError.invalidMask
        }

        // HomeAI uses white=edit. OpenAI requires fully transparent=edit.
        let filter = CIFilter(name: "CIColorMatrix")
        filter?.setValue(inputImage, forKey: kCIInputImageKey)
        filter?.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputRVector")
        filter?.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputGVector")
        filter?.setValue(CIVector(x: 0, y: 0, z: 0, w: 0), forKey: "inputBVector")
        filter?.setValue(
            CIVector(x: -0.2126, y: -0.7152, z: -0.0722, w: 0),
            forKey: "inputAVector"
        )
        filter?.setValue(CIVector(x: 1, y: 1, z: 1, w: 1), forKey: "inputBiasVector")

        guard let output = filter?.outputImage,
              let cgImage = CIContext(options: nil).createCGImage(output, from: inputImage.extent),
              let data = UIImage(cgImage: cgImage).pngData() else {
            throw OpenAIWorkerImageError.invalidMask
        }
        return data
    }
}

private struct OpenAIWorkerRequest: Encodable {
    struct InputImage: Encodable {
        let role: String
        let mimeType: String
        let data: String
    }

    let version: Int
    let operation: String
    let prompt: String
    let images: [InputImage]
}

private struct OpenAIWorkerResponse: Decodable {
    struct OutputImage: Decodable {
        let mimeType: String
        let data: String
    }

    struct Usage: Decodable {
        let totalTokens: Int?
        let inputTokens: Int?
        let outputTokens: Int?
    }

    let version: Int
    let requestId: String
    let provider: String
    let model: String
    let image: OutputImage
    let usage: Usage?
}

private struct OpenAIWorkerErrorResponse: Decodable {
    struct Payload: Decodable {
        let code: String
        let message: String
        let retryable: Bool
    }

    let error: Payload
}
