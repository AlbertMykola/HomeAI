import Foundation

/// Завантажує та кешує remote config з worker (`/app/config`).
final class WorkerConfigService {

    static let shared = WorkerConfigService()

    private let cacheKey = Constants.Keys.cachedWorkerAppConfig
    private let session: URLSession
    private let queue = DispatchQueue(label: "HomeAI.WorkerConfigService", qos: .utility)
    private var config: WorkerAppConfig

    private init(session: URLSession = .shared) {
        self.session = session
        if let cached = Self.loadCachedConfig(forKey: cacheKey) {
            config = cached
            log("init from cache: \(Self.describe(cached))")
        } else {
            config = .fallback
            log("init from fallback: \(Self.describe(config))")
        }
    }

    var current: WorkerAppConfig {
        queue.sync { config }
    }

    var freeGenerationsLifetime: Int {
        max(0, current.freeGenerationsLifetime)
    }

    var premiumGenerationsPerDay: Int {
        max(1, current.premiumGenerationsPerDay)
    }

    var paywallShowTopCloseButton: Bool {
        current.paywallShowTopCloseButton
    }

    /// Оновити config з worker (fire-and-forget при старті; повертає актуальний snapshot).
    @discardableResult
    func refreshIfNeeded() async -> WorkerAppConfig {
        guard let url = URL(string: Constants.API.workerAppConfigURL) else {
            log("refresh skipped: invalid URL")
            return current
        }

        log("refresh started: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 12

        do {
            let (data, response) = try await session.data(for: request)
            if response is HTTPURLResponse { ServiceReachability.markReachable() }
            guard let http = response as? HTTPURLResponse else {
                log("refresh failed: invalid HTTP response, using \(Self.describe(current))")
                ErrorReporter.report(message: "invalid HTTP response", operation: "config_worker")
                return current
            }

            let rawBody = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
            guard (200 ..< 300).contains(http.statusCode) else {
                log("refresh failed: HTTP \(http.statusCode), body: \(rawBody), using \(Self.describe(current))")
                ErrorReporter.report(message: "HTTP \(http.statusCode)", operation: "config_worker",
                                     details: .init(httpStatus: http.statusCode, upstreamMessage: rawBody))
                return current
            }

            log("refresh response HTTP \(http.statusCode), raw: \(rawBody)")

            let decoded = try JSONDecoder().decode(WorkerAppConfig.self, from: data)
            apply(decoded, persist: true)
            log("refresh success: \(Self.describe(decoded))")
            return decoded
        } catch {
            log("refresh failed: \(error.localizedDescription), using \(Self.describe(current))")
            // Offline at launch is normal; parse errors and other failures are worth knowing about.
            if (error as? URLError)?.code != .notConnectedToInternet {
                ErrorReporter.report(error, operation: "config_worker")
            }
            return current
        }
    }

    private func apply(_ newConfig: WorkerAppConfig, persist: Bool) {
        queue.sync {
            config = newConfig
            if persist {
                Self.saveCachedConfig(newConfig, forKey: cacheKey)
            }
        }
    }

    private static func loadCachedConfig(forKey key: String) -> WorkerAppConfig? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WorkerAppConfig.self, from: data)
    }

    private static func saveCachedConfig(_ config: WorkerAppConfig, forKey key: String) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func describe(_ config: WorkerAppConfig) -> String {
        "freeGenerationsLifetime=\(config.freeGenerationsLifetime), premiumGenerationsPerDay=\(config.premiumGenerationsPerDay), paywallShowTopCloseButton=\(config.paywallShowTopCloseButton), configVersion=\(config.configVersion)"
    }

    private func log(_ message: String) {
        print("[WorkerAppConfig] \(message)")
    }
}
