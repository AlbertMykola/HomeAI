import FirebaseCrashlytics
import Foundation
import Sentry

/// One place for every user-visible or silent failure:
/// Sentry (tags + extras, the main place to read "what happened"), a Crashlytics non-fatal and an `app_error`
/// analytics event (Amplitude + Firebase) so error rates can be charted.
///
/// Privacy: never pass photos, prompts, user text, keys or tokens — only codes, statuses and service messages.
enum ErrorReporter {

    struct Details {
        var provider: String?
        var model: String?
        var httpStatus: Int?
        /// Our worker's `error.code` (e.g. `provider_error`, `content_policy`).
        var workerError: String?
        /// What the upstream AI (OpenAI / Gemini) said, when the worker passes it through.
        var upstreamStatus: Int?
        var upstreamCode: String?
        var upstreamMessage: String?
        var requestID: String?
        var durationMS: Int?
        var retryCount: Int?
        /// Short, non-personal context (design option, placement, …).
        var extra: [String: String] = [:]

        init(provider: String? = nil, model: String? = nil, httpStatus: Int? = nil, workerError: String? = nil,
             upstreamStatus: Int? = nil, upstreamCode: String? = nil, upstreamMessage: String? = nil,
             requestID: String? = nil, durationMS: Int? = nil, retryCount: Int? = nil, extra: [String: String] = [:]) {
            self.provider = provider
            self.model = model
            self.httpStatus = httpStatus
            self.workerError = workerError
            self.upstreamStatus = upstreamStatus
            self.upstreamCode = upstreamCode
            self.upstreamMessage = upstreamMessage
            self.requestID = requestID
            self.durationMS = durationMS
            self.retryCount = retryCount
            self.extra = extra
        }

        /// Fills the fields that are still empty from `other` (call site wins).
        func merged(with other: Details) -> Details {
            var d = self
            d.provider = d.provider ?? other.provider
            d.model = d.model ?? other.model
            d.httpStatus = d.httpStatus ?? other.httpStatus
            d.workerError = d.workerError ?? other.workerError
            d.upstreamStatus = d.upstreamStatus ?? other.upstreamStatus
            d.upstreamCode = d.upstreamCode ?? other.upstreamCode
            d.upstreamMessage = d.upstreamMessage ?? other.upstreamMessage
            d.requestID = d.requestID ?? other.requestID
            d.durationMS = d.durationMS ?? other.durationMS
            d.retryCount = d.retryCount ?? other.retryCount
            d.extra = other.extra.merging(d.extra) { _, mine in mine }
            return d
        }
    }

    /// Errors that know their own report details (worker / provider fields).
    protocol Reportable: Error {
        var reportDetails: Details { get }
    }

    static func report(_ error: Error, operation: String, details: Details = .init()) {
        let full = (error as? Reportable).map { details.merged(with: $0.reportDetails) } ?? details
        let ns = error as NSError
        let code = errorCode(full, fallback: "\(ns.domain):\(ns.code)")
        if logAndTrack(operation: operation, code: code, details: full, description: String(describing: error)) {
            // No answer at all (blocked or dead network, e.g. AI hosts in sanctioned regions) is not an app bug:
            // a warning tagged network:unreachable, so `!network:unreachable` filters it out in Sentry.
            let unreachable = ServiceReachability.isUnreachableError(error)
            SentrySDK.capture(error: error) { scope in
                configure(scope, operation: operation, code: code, details: full)
                if unreachable {
                    scope.setLevel(.warning)
                    scope.setTag(value: "unreachable", key: "network")
                }
            }
        }
        Crashlytics.crashlytics().record(error: error, userInfo: crashlyticsInfo(operation: operation, code: code,
                                                                                 details: full))
    }

    /// Failures without an `Error` value (bad HTTP status, empty response, …).
    static func report(message: String, operation: String, details: Details = .init()) {
        let code = errorCode(details, fallback: "message")
        if logAndTrack(operation: operation, code: code, details: details, description: message) {
            SentrySDK.capture(message: "\(operation): \(message)") {
                configure($0, operation: operation, code: code, details: details)
            }
        }
        let error = NSError(domain: "Rehomely.\(operation)", code: details.httpStatus ?? 0,
                            userInfo: [NSLocalizedDescriptionKey: message])
        Crashlytics.crashlytics().record(error: error, userInfo: crashlyticsInfo(operation: operation, code: code,
                                                                                 details: details))
    }

    // MARK: Private

    /// Console (Debug) + `app_error` event. Returns whether Sentry still needs an explicit capture.
    private static func logAndTrack(operation: String, code: String, details: Details, description: String) -> Bool {
        #if DEBUG
        print("[ErrorReporter] op=\(operation) code=\(code) http=\(details.httpStatus.map(String.init) ?? "-") "
              + "provider=\(details.provider ?? "-") upstream=\(details.upstreamStatus.map(String.init) ?? "-")/"
              + "\(details.upstreamCode ?? "-") msg=\(truncated(details.upstreamMessage ?? description, 160))")
        #endif
        // Sentry's own HTTP-client capture already records 5xx responses of our requests; 4xx (e.g. a 403 from the
        // AI provider) and non-HTTP failures only reach Sentry through here.
        let autoCaptured = (500...599).contains(details.httpStatus ?? 0) && details.upstreamCode == nil

        var props: [String: Any] = ["operation": operation, "error_code": code]
        if let provider = details.provider { props["provider"] = provider }
        if let model = details.model { props["model"] = model }
        if let status = details.httpStatus { props["http_status"] = status }
        if let worker = details.workerError { props["worker_error"] = worker }
        if let upstream = details.upstreamCode { props["upstream_code"] = upstream }
        if let upstreamStatus = details.upstreamStatus { props["upstream_status"] = upstreamStatus }
        if let duration = details.durationMS { props["duration_ms"] = duration }
        if let retries = details.retryCount { props["retry_count"] = retries }
        details.extra.forEach { props[$0.key] = $0.value }
        AmplitudeService.shared.logRedesignEvent("app_error", properties: props)
        return !autoCaptured
    }

    private static func configure(_ scope: Scope, operation: String, code: String, details: Details) {
        scope.setTag(value: operation, key: "operation")
        scope.setTag(value: code, key: "error_code")
        if let provider = details.provider { scope.setTag(value: provider, key: "provider") }
        if let model = details.model { scope.setTag(value: model, key: "model") }
        if let status = details.httpStatus { scope.setTag(value: String(status), key: "http_status") }
        if let worker = details.workerError { scope.setTag(value: worker, key: "worker_error") }
        if let upstream = details.upstreamCode { scope.setTag(value: upstream, key: "upstream_code") }
        if let upstreamStatus = details.upstreamStatus {
            scope.setTag(value: String(upstreamStatus), key: "upstream_status")
        }
        if let message = details.upstreamMessage { scope.setExtra(value: truncated(message, 300), key: "upstream_message") }
        if let requestID = details.requestID { scope.setExtra(value: requestID, key: "request_id") }
        if let duration = details.durationMS { scope.setExtra(value: duration, key: "duration_ms") }
        if let retries = details.retryCount { scope.setExtra(value: retries, key: "retry_count") }
        details.extra.forEach { scope.setExtra(value: $0.value, key: $0.key) }
        scope.setFingerprint(["app_error", operation, code])
        if details.workerError == "service_unreachable" {
            scope.setLevel(.warning)
            scope.setTag(value: "unreachable", key: "network")
        }
    }

    private static func crashlyticsInfo(operation: String, code: String, details: Details) -> [String: Any] {
        var info: [String: Any] = ["operation": operation, "error_code": code]
        if let provider = details.provider { info["provider"] = provider }
        if let status = details.httpStatus { info["http_status"] = status }
        if let upstream = details.upstreamCode { info["upstream_code"] = upstream }
        if let message = details.upstreamMessage { info["upstream_message"] = truncated(message, 300) }
        if let requestID = details.requestID { info["request_id"] = requestID }
        return info
    }

    private static func errorCode(_ d: Details, fallback: String) -> String {
        d.upstreamCode ?? d.workerError ?? d.httpStatus.map { "http_\($0)" } ?? fallback
    }

    private static func truncated(_ text: String, _ limit: Int) -> String {
        text.count > limit ? String(text.prefix(limit)) + "…" : text
    }
}
