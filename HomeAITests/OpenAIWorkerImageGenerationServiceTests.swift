import UIKit
import XCTest
@testable import HomeAI

final class OpenAIWorkerImageGenerationServiceTests: XCTestCase {
    override func tearDown() {
        OpenAIWorkerURLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testRequestUsesProviderNeutralContractAndDecodesResult() async throws {
        let outputData = makeImage(color: .green).jpegData(compressionQuality: 0.8)!
        OpenAIWorkerURLProtocolStub.requestHandler = { request in
            let data = try XCTUnwrap(request.bodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            XCTAssertEqual(json["version"] as? Int, 1)
            XCTAssertEqual(json["operation"] as? String, DesignOption.interior.rawValue)
            let images = try XCTUnwrap(json["images"] as? [[String: Any]])
            XCTAssertEqual(images.first?["role"] as? String, "base")

            return (
                Self.response(status: 200, request: request),
                Self.successBody(imageData: outputData)
            )
        }

        let result = try await makeService().generateImage(
            from: makeInput(option: .interior)
        )

        XCTAssertEqual(result.provider, .openAI)
        XCTAssertEqual(result.model, Constants.Generation.OpenAI.flareModel)
        XCTAssertNotNil(result.image.cgImage)
    }

    func testStableWorkerErrorIsExposedAsTypedFailure() async {
        OpenAIWorkerURLProtocolStub.requestHandler = { request in
            (
                Self.response(status: 429, request: request),
                Data(
                    #"{"version":1,"requestId":"test","error":{"code":"rate_limited","message":"busy","retryable":true}}"#.utf8
                )
            )
        }

        do {
            _ = try await makeService().generateImage(from: makeInput(option: .interior))
            XCTFail("Expected failure")
        } catch let error as OpenAIWorkerImageError {
            XCTAssertEqual(error.category, "rate_limited")
            XCTAssertEqual(error.statusCode, 429)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAlphaMaskKeepsBlackOpaqueAndMakesWhiteTransparent() throws {
        let size = CGSize(width: 2, height: 1)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let mask = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
            UIColor.white.setFill()
            context.fill(CGRect(x: 1, y: 0, width: 1, height: 1))
        }
        let base = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }

        let data = try OpenAIWorkerImageGenerationService.makeAlphaMaskPNG(
            from: mask,
            matching: base
        )
        let decoded = try XCTUnwrap(UIImage(data: data)?.cgImage)
        let alpha = try alphaValues(from: decoded)

        XCTAssertGreaterThan(alpha[0], 250)
        XCTAssertLessThan(alpha[1], 5)
    }

    func testFactoryFollowsTheConfiguredProvider() {
        XCTAssertEqual(ImageGenerationProvider.defaultProvider, .gemini)
        XCTAssertEqual(SupabaseAppConfig.fallback.imageGenerationProvider, .gemini)
        // OpenAI comes wrapped: a region_unavailable answer retries on Gemini.
        let openAI = ImageGenerationServiceFactory.make(environment: [:], provider: .openAI, directDebugKey: nil)
        let wrapped = try? XCTUnwrap(openAI as? RegionFallbackImageService)
        XCTAssertTrue(wrapped?.primary is OpenAIWorkerImageGenerationService)
        XCTAssertTrue(wrapped?.fallback is GeminiRESTService)
        XCTAssertTrue(
            ImageGenerationServiceFactory.make(environment: [:], provider: .gemini, directDebugKey: nil)
                is GeminiRESTService
        )
    }

    func testRemoteConfigWithoutProviderUsesTheDefaultAndExplicitValuesAreHonoured() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let missing = try decoder.decode(SupabaseAppConfig.self, from: Data(#"{"id":1}"#.utf8))
        XCTAssertEqual(missing.imageGenerationProvider, .defaultProvider)
        let openAI = try decoder.decode(
            SupabaseAppConfig.self, from: Data(#"{"id":1,"image_generation_provider":"openai"}"#.utf8))
        XCTAssertEqual(openAI.imageGenerationProvider, .openAI)
    }

    func testDirectOpenAIModeIsDebugOnlyAndNeedsASavedKey() {
        #if DEBUG
        XCTAssertTrue(
            ImageGenerationServiceFactory.make(environment: [:], provider: .gemini, directDebugKey: "test-key")
                is OpenAIDirectDebugService
        )
        XCTAssertTrue(
            ImageGenerationServiceFactory.make(environment: [:], provider: .gemini, directDebugKey: "")
                is GeminiRESTService
        )
        #else
        XCTAssertTrue(
            ImageGenerationServiceFactory.make(environment: [:], provider: .gemini, directDebugKey: "test-key")
                is GeminiRESTService
        )
        #endif
    }

    private func makeService() -> OpenAIWorkerImageGenerationService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OpenAIWorkerURLProtocolStub.self]
        return OpenAIWorkerImageGenerationService(
            endpoint: URL(string: "https://worker.test/v1/images/generate")!,
            session: URLSession(configuration: configuration),
            attestClient: nil
        )
    }

    private func makeInput(option: DesignOption) -> ImageGenerationInput {
        ImageGenerationInput(
            prompt: "Redesign this room",
            baseImage: makeImage(color: .gray),
            referenceImage: nil,
            maskImage: nil,
            designOption: option
        )
    }

    private func makeImage(color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }

    private func alphaValues(from image: CGImage) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = try XCTUnwrap(CGContext(
            data: &pixels,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return stride(from: 3, to: pixels.count, by: 4).map { pixels[$0] }
    }

    private static func successBody(imageData: Data) -> Data {
        Data(
            """
            {"version":1,"requestId":"test","provider":"openai","model":"gpt-image-2.5-flare","image":{"mimeType":"image/jpeg","data":"\(imageData.base64EncodedString())"},"usage":null}
            """.utf8
        )
    }

    private static func response(status: Int, request: URLRequest) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
    }
}

private final class OpenAIWorkerURLProtocolStub: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension URLRequest {
    var bodyData: Data? {
        if let httpBody { return httpBody }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count >= 0 else { return nil }
            if count == 0 { break }
            result.append(buffer, count: count)
        }
        return result
    }
}
