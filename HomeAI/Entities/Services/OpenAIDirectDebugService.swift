#if DEBUG
import Security
import UIKit

/// DEBUG ONLY (never compiled into Release): calls OpenAI directly from the device, bypassing the Cloudflare
/// worker, to check whether OpenAI accepts our image requests outside Cloudflare.
/// The key is typed by the tester on the device (Profile → long-press the app version) and kept in the
/// Keychain (this device only). It is never logged, reported or stored in source.
enum OpenAIDirectDebugKey {
    private static let service = "rehomely.debug.openai"
    private static let account = "direct-key"

    static var value: String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data, let key = String(data: data, encoding: .utf8), !key.isEmpty else { return nil }
        return key
    }

    static var isSet: Bool { value != nil }

    static func save(_ key: String) {
        clear()
        var query = baseQuery
        query[kSecValueData as String] = Data(key.trimmingCharacters(in: .whitespacesAndNewlines).utf8)
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    static func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private static var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
}

/// Same request as the worker builds (multipart to /v1/images/edits, same models and options).
final class OpenAIDirectDebugService: ImageGenerationService {
    private static let endpoint = URL(string: "https://api.openai.com/v1/images/edits")!
    private let apiKey: String
    private let session: URLSession

    var provider: ImageGenerationProvider { .openAI }

    init(apiKey: String) {
        self.apiKey = apiKey
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = Constants.Generation.requestTimeout
        configuration.timeoutIntervalForResource = Constants.Generation.resourceTimeout
        session = URLSession(configuration: configuration)
    }

    func model(for option: DesignOption) -> String {
        switch option {
        case .reference, .replace, .delete: return Constants.Generation.OpenAI.sunburstModel
        default: return Constants.Generation.OpenAI.flareModel
        }
    }

    func generateImage(from input: ImageGenerationInput) async throws -> ImageGenerationResult {
        let model = model(for: input.designOption)
        let boundary = "rehomely-\(UUID().uuidString)"
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        func file(_ name: String, _ filename: String, _ mime: String, _ data: Data) {
            body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n"
                        + "Content-Type: \(mime)\r\n\r\n")
            body.append(data)
            body.append("\r\n")
        }
        field("model", model)
        field("prompt", input.prompt(for: .openAI))
        field("quality", Constants.Generation.OpenAI.quality)
        field("size", "auto")
        field("background", "opaque")
        field("output_format", "jpeg")
        field("output_compression", "90")
        field("n", "1")
        guard let base = input.baseImage.jpegData(compressionQuality: Constants.Generation.jpegCompressionQuality) else {
            throw OpenAIWorkerImageError.requestEncoding
        }
        file("image[]", "base-0.jpg", "image/jpeg", base)
        if let reference = input.referenceImage?.jpegData(compressionQuality: Constants.Generation.jpegCompressionQuality) {
            file("image[]", "reference-1.jpg", "image/jpeg", reference)
        }
        if let mask = input.maskImage {
            file("mask", "mask.png", "image/png",
                 try OpenAIWorkerImageGenerationService.makeAlphaMaskPNG(from: mask, matching: input.baseImage))
        }
        body.append("--\(boundary)--\r\n")

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled || Task.isCancelled {
            throw CancellationError()
        } catch {
            throw OpenAIWorkerImageError.requestFailed(error)
        }
        guard let http = response as? HTTPURLResponse else { throw OpenAIWorkerImageError.invalidResponse }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        guard (200...299).contains(http.statusCode) else {
            let error = json?["error"] as? [String: Any]
            let upstream = OpenAIWorkerUpstreamError(
                status: http.statusCode,
                code: error?["code"] as? String,
                type: error?["type"] as? String,
                message: error?["message"] as? String,
                requestId: http.value(forHTTPHeaderField: "x-request-id"),
                organization: http.value(forHTTPHeaderField: "openai-organization"),
                project: http.value(forHTTPHeaderField: "openai-project"))
            print("[OpenAIDirect] HTTP \(http.statusCode) code=\(upstream.code ?? "-") "
                  + "request=\(upstream.requestId ?? "-") msg=\(upstream.message ?? "-")")
            throw OpenAIWorkerImageError.server(
                statusCode: http.statusCode, code: "direct_\(upstream.code ?? "http")",
                message: upstream.message ?? "HTTP \(http.statusCode)", retryable: false,
                requestID: upstream.requestId, upstream: upstream)
        }
        guard let first = (json?["data"] as? [[String: Any]])?.first,
              let b64 = first["b64_json"] as? String,
              let imageData = Data(base64Encoded: b64),
              let image = UIImage(data: imageData) else {
            throw OpenAIWorkerImageError.invalidImage
        }
        print("[OpenAIDirect] OK model=\(model) request=\(http.value(forHTTPHeaderField: "x-request-id") ?? "-")")
        return ImageGenerationResult(image: image, prompt: input.prompt(for: .openAI), provider: .openAI, model: model)
    }
}

private extension Data {
    mutating func append(_ string: String) { append(Data(string.utf8)) }
}
#endif
