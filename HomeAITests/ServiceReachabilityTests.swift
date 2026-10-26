import XCTest
@testable import HomeAI

final class ServiceReachabilityTests: XCTestCase {
    func testConnectionLevelFailuresCountAsUnreachable() {
        for code in [URLError.Code.timedOut, .cannotConnectToHost, .networkConnectionLost, .secureConnectionFailed,
                     .cannotFindHost, .dnsLookupFailed] {
            XCTAssertTrue(ServiceReachability.isUnreachableError(URLError(code)), "\(code)")
            XCTAssertTrue(ServiceReachability.isUnreachableError(GeminiServiceError.requestFailed(URLError(code))), "\(code)")
        }
    }

    func testOfflineAndServerAnswersAreNotUnreachable() {
        // No internet at all keeps the offline screen; an HTTP status means the server answered.
        XCTAssertFalse(ServiceReachability.isUnreachableError(URLError(.notConnectedToInternet)))
        XCTAssertFalse(ServiceReachability.isUnreachableError(GeminiServiceError.httpError(statusCode: 502, message: "")))
        XCTAssertFalse(ServiceReachability.isUnreachableError(GeminiServiceError.noImageInResponse))
    }

    func testUnderlyingErrorIsFollowed() {
        let wrapped = NSError(domain: "Wrapper", code: 1, userInfo: [NSUnderlyingErrorKey: URLError(.timedOut)])
        XCTAssertTrue(ServiceReachability.isUnreachableError(wrapped))
    }
}
