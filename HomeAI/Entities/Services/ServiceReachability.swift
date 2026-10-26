import UIKit

/// Online, but our servers (Cloudflare workers) can't be reached from this network — e.g. where Cloudflare is
/// blocked. Detected by reachability, never by locale or region. A recent successful answer from the worker costs
/// normal users nothing; otherwise one short probe runs before a generation / edit.
enum ServiceReachability {
    /// Answers from the worker within this window count as "reachable" without a new probe.
    private static let freshness: TimeInterval = 10 * 60
    private static let probeTimeout: TimeInterval = 12
    private static var lastSuccess: Date?

    static var isRecentlyReachable: Bool {
        lastSuccess.map { Date().timeIntervalSince($0) < freshness } ?? false
    }

    /// Any HTTP answer from the worker (even an error status) proves the network path works.
    static func markReachable() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-unreachableWorker") { return }
        #endif
        lastSuccess = Date()
    }

    /// Connection-level failures: no HTTP answer at all (timeout before a response, host unreachable, TLS refused).
    /// Plain "no internet" stays with the offline screen.
    static func isUnreachableError(_ error: Error) -> Bool {
        let codes: Set<Int> = [NSURLErrorTimedOut, NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost,
                               NSURLErrorSecureConnectionFailed, NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed]
        var current: Error? = error
        while let e = current {
            let ns = e as NSError
            if ns.domain == NSURLErrorDomain, codes.contains(ns.code) { return true }
            if let service = e as? GeminiServiceError, case .requestFailed(let inner) = service {
                current = inner
            } else {
                current = ns.userInfo[NSUnderlyingErrorKey] as? Error
            }
        }
        return false
    }

    /// Before a generation / edit: runs `action` when the worker is reachable, otherwise explains why not.
    @MainActor
    static func run(from presenter: UIViewController, operation: String, _ action: @escaping () -> Void) {
        guard !isRecentlyReachable else { return action() }
        presenter.view.isUserInteractionEnabled = false
        Task { @MainActor [weak presenter] in
            let reachable = await probe()
            guard let presenter else { return }
            presenter.view.isUserInteractionEnabled = true
            if reachable {
                action()
            } else {
                showUnavailable(from: presenter, operation: operation, error: nil) {
                    run(from: presenter, operation: operation, action)
                }
            }
        }
    }

    /// One grouped report (not one Sentry issue per NSURLError code) and the honest message.
    @MainActor
    static func showUnavailable(from presenter: UIViewController, operation: String, error: Error?,
                                reported: Bool = false, retry: @escaping () -> Void) {
        if !reported { report(operation: operation, error: error) }
        DS.Haptic.warning()
        DSAlertViewController.show(
            from: presenter,
            title: "Service unavailable".localized,
            message: "The service is unavailable on your network. Check your internet connection or try again later.".localized,
            actions: [
                .init(title: "OK".localized, style: .cancel) {},
                .init(title: "Try again".localized, style: .primary) { retry() }
            ])
    }

    static func report(operation: String, error: Error?) {
        var details = ErrorReporter.Details(provider: "cloudflare_worker", workerError: "service_unreachable",
                                            extra: ["host": URL(string: Constants.API.workerProxyBase)?.host ?? "-"])
        if let error {
            var inner: Error = error
            if let service = error as? GeminiServiceError, case .requestFailed(let e) = service { inner = e }
            let ns = inner as NSError
            details.extra["url_error"] = "\(ns.domain):\(ns.code)"
        }
        ErrorReporter.report(message: "service_unreachable", operation: operation, details: details)
    }

    private static func probe() async -> Bool {
        guard let url = probeURL else { return false }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = probeTimeout
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = probeTimeout
        config.timeoutIntervalForResource = probeTimeout
        do {
            let (_, response) = try await URLSession(configuration: config).data(for: request)
            guard response is HTTPURLResponse else { return false }
            markReachable()
            return true
        } catch {
            return false
        }
    }

    private static var probeURL: URL? {
        #if DEBUG
        // QA: `-unreachableWorker` probes a blackhole address so the "service unavailable" path can be tested.
        if ProcessInfo.processInfo.arguments.contains("-unreachableWorker") { return URL(string: "https://10.255.255.1/") }
        #endif
        return URL(string: Constants.API.workerAppConfigURL)
    }
}
