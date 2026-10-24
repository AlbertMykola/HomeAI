import GoogleGenerativeAI
import XCTest
@testable import HomeAI

final class GeminiRESTServiceTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testSuccessDecodesImageAndUsesPrecisePreset() async throws {
        let imageData = makeImageData()
        URLProtocolStub.requestHandler = { request in
            let body = try XCTUnwrap(request.bodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let config = try XCTUnwrap(json["generationConfig"] as? [String: Any])
            XCTAssertEqual(config["temperature"] as? Double, 0.2)
            XCTAssertEqual(config["topP"] as? Double, 0.8)
            return (Self.response(status: 200, request: request), Self.successBody(imageData: imageData))
        }

        let result = try await makeService().generateImage(
            from: makeParts(),
            designOption: .replace
        )

        XCTAssertEqual(result.promptText, "test prompt")
        XCTAssertNotNil(result.image.cgImage)
    }

    func testRedesignAndCreativePresetsUseDifferentSampling() async throws {
        var observedTemperatures: [Double] = []
        URLProtocolStub.requestHandler = { request in
            let body = try XCTUnwrap(request.bodyData)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let config = try XCTUnwrap(json["generationConfig"] as? [String: Any])
            observedTemperatures.append(try XCTUnwrap(config["temperature"] as? Double))
            return (Self.response(status: 200, request: request), Self.successBody(imageData: self.makeImageData()))
        }
        let service = makeService()

        _ = try await service.generateImage(from: makeParts(), designOption: .interior)
        _ = try await service.generateImage(from: makeParts(), designOption: .rearrange)

        XCTAssertEqual(observedTemperatures, [0.45, 0.6])
    }

    func testRateLimitRetriesAndSucceeds() async throws {
        var requestCount = 0
        URLProtocolStub.requestHandler = { request in
            requestCount += 1
            if requestCount == 1 {
                return (
                    Self.response(status: 429, request: request),
                    Data(#"{"error":{"code":429,"message":"busy","status":"RESOURCE_EXHAUSTED"}}"#.utf8)
                )
            }
            return (Self.response(status: 200, request: request), Self.successBody(imageData: self.makeImageData()))
        }

        _ = try await makeService().generateImage(from: makeParts(), designOption: .interior)

        XCTAssertEqual(requestCount, 2)
    }

    func testServerFailureStopsAfterConfiguredRetries() async {
        var requestCount = 0
        URLProtocolStub.requestHandler = { request in
            requestCount += 1
            return (
                Self.response(status: 503, request: request),
                Data(#"{"error":{"code":503,"message":"unavailable","status":"UNAVAILABLE"}}"#.utf8)
            )
        }

        do {
            _ = try await makeService().generateImage(from: makeParts(), designOption: .interior)
            XCTFail("Expected server failure")
        } catch let error as GeminiServiceError {
            XCTAssertEqual(error.category, "server")
            XCTAssertEqual(requestCount, Constants.Generation.maximumRetryCount + 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTimeoutIsNotRetriedBecauseTheImageMayAlreadyBeBilled() async {
        var requestCount = 0
        URLProtocolStub.requestHandler = { _ in
            requestCount += 1
            throw URLError(.timedOut)
        }

        do {
            _ = try await makeService().generateImage(from: makeParts(), designOption: .interior)
            XCTFail("Expected timeout")
        } catch let error as GeminiServiceError {
            XCTAssertEqual(error.category, "timeout")
            XCTAssertEqual(requestCount, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSafetyRefusalReturnsContentBlockedError() async {
        URLProtocolStub.requestHandler = { request in
            (
                Self.response(status: 200, request: request),
                Data(#"{"candidates":[{"content":{"parts":[{"text":"blocked"}]},"finishReason":"SAFETY"}]}"#.utf8)
            )
        }

        do {
            _ = try await makeService().generateImage(from: makeParts(), designOption: .garden)
            XCTFail("Expected moderation refusal")
        } catch let error as GeminiServiceError {
            XCTAssertEqual(error.category, "content_blocked")
            XCTAssertNotNil(error.errorDescription)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTextOnlyResponseWithoutSafetyReasonReturnsNoImageError() async {
        URLProtocolStub.requestHandler = { request in
            (Self.response(status: 200, request: request),
             Data(#"{"candidates":[{"content":{"parts":[{"text":"No image"}]},"finishReason":"STOP"}]}"#.utf8))
        }
        do {
            _ = try await makeService().generateImage(from: makeParts(), designOption: .interior)
            XCTFail("Expected no-image failure")
        } catch let error as GeminiServiceError {
            XCTAssertEqual(error.category, "no_image")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMalformedImageReturnsDecodingError() async {
        URLProtocolStub.requestHandler = { request in
            (
                Self.response(status: 200, request: request),
                Data(#"{"candidates":[{"content":{"parts":[{"inlineData":{"mimeType":"image/png","data":"not-base64"}}]},"finishReason":"STOP"}]}"#.utf8)
            )
        }

        do {
            _ = try await makeService().generateImage(from: makeParts(), designOption: .garden)
            XCTFail("Expected decoding failure")
        } catch let error as GeminiServiceError {
            XCTAssertEqual(error.category, "decoding")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMalformedResponseReturnsStableDecodingError() async {
        URLProtocolStub.requestHandler = { request in
            (Self.response(status: 200, request: request), Data("not-json".utf8))
        }

        do {
            _ = try await makeService().generateImage(from: makeParts(), designOption: .garden)
            XCTFail("Expected response decoding failure")
        } catch let error as GeminiServiceError {
            XCTAssertEqual(error.category, "decoding")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testOversizedBodyFailsBeforeNetwork() async {
        var requestCount = 0
        URLProtocolStub.requestHandler = { request in
            requestCount += 1
            return (Self.response(status: 200, request: request), Data())
        }
        let oversizedParts: [ModelContent.Part] = [
            .data(mimetype: "image/png", Data(repeating: 1, count: Constants.Generation.maxRequestBodyBytes)),
            .text("test")
        ]

        do {
            _ = try await makeService().generateImage(from: oversizedParts, designOption: .reference)
            XCTFail("Expected payload-too-large failure")
        } catch let error as GeminiServiceError {
            XCTAssertEqual(error.category, "payload_too_large")
            XCTAssertEqual(requestCount, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeService() -> GeminiRESTService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return GeminiRESTService(
            session: URLSession(configuration: configuration),
            proxyURL: "https://example.com/generate",
            retryDelay: { _ in }
        )
    }

    private func makeParts() -> [ModelContent.Part] {
        [
            .data(mimetype: "image/png", makeImageData()),
            .text("test prompt")
        ]
    }

    private func makeImageData() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.green.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }.pngData()!
    }

    private static func successBody(imageData: Data) -> Data {
        Data(
            """
            {"candidates":[{"content":{"parts":[{"inlineData":{"mimeType":"image/png","data":"\(imageData.base64EncodedString())"}}]},"finishReason":"STOP"}]}
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

private final class URLProtocolStub: URLProtocol {
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
        let bufferSize = 4_096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: bufferSize)
            guard count >= 0 else { return nil }
            if count == 0 { break }
            result.append(buffer, count: count)
        }
        return result
    }
}
