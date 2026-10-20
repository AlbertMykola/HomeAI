#if DEBUG
import UIKit

/// Feeds the production runner, persistence, credit accounting and analytics pipeline in simulator QA.
final class QAGenerationService: ImageGenerationService {
    let provider: ImageGenerationProvider = .gemini
    let delay: UInt64
    let failure: String?
    let image: UIImage?
    let failFirst: Bool
    private let lock = NSLock()
    private var attempts = 0

    init(delay: UInt64 = 700_000_000, failure: String? = nil, image: UIImage? = nil, failFirst: Bool = false) {
        self.delay = delay; self.failure = failure; self.image = image; self.failFirst = failFirst
    }

    func model(for option: DesignOption) -> String { "qa-local-\(option.rawValue)" }
    func generateImage(from input: ImageGenerationInput) async throws -> ImageGenerationResult {
        let attempt = nextAttempt()
        AppQA.record("qa_local_generation", properties: ["option": input.designOption.rawValue, "attempt": attempt])
        try await Task.sleep(nanoseconds: delay)
        let failure = failure ?? (ProcessInfo.processInfo.arguments.contains("--qa-generation-fail") ? "server" : nil)
        if let failure, !failFirst || attempt == 1 { throw Failure(category: failure) }
        return ImageGenerationResult(image: image ?? Self.resultImage(for: input.designOption), prompt: input.prompt,
                                     provider: provider, model: model(for: input.designOption))
    }

    private func nextAttempt() -> Int {
        lock.lock(); defer { lock.unlock() }
        attempts += 1
        return attempts
    }

    /// Bundled photos only. These exercise rendering, not the quality of an AI model.
    static func resultImage(for option: DesignOption) -> UIImage {
        let asset: String
        switch option {
        case .interior: asset = "ob_room_after"
        case .exterior: asset = "home_card_exterior"
        case .garden: asset = "home_card_garden"
        case .newWalls: asset = "ob_tool_walls_after"
        case .newFlooring: asset = "ob_tool_floor_after"
        case .replace: asset = "ob_tool_replace_after"
        case .delete: asset = "ob_tool_remove_after"
        case .reference: asset = "ob_tool_style_after"
        case .furnish: asset = "ob_room_after"
        case .rearrange: asset = "ob_words_after"
        case .floolPlan: asset = "ob_room_after"
        }
        return UIImage(named: asset)!
    }

    struct Failure: ImageGenerationFailure {
        let category: String
        var statusCode: Int? { category == "server" ? 502 : nil }
        var errorDescription: String? { "Local QA failure" }
    }
}

/// Fail closed if HTTP escapes the local QA adapters. Shared sessions register globally;
/// app-created sessions also install the protocol explicitly on their configuration.
final class QANetworkBlocker: URLProtocol {
    static func install() { URLProtocol.registerClass(Self.self) }
    static func protect(_ configuration: URLSessionConfiguration) {
        guard AppQA.enabled else { return }
        configuration.protocolClasses = [Self.self] + (configuration.protocolClasses ?? [])
    }
    override class func canInit(with request: URLRequest) -> Bool {
        AppQA.enabled && ["http", "https"].contains(request.url?.scheme?.lowercased() ?? "")
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        AppQA.record("qa_network_blocked", properties: ["host": request.url?.host ?? "", "method": request.httpMethod ?? "GET"])
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }
    override func stopLoading() {}
}
#endif
