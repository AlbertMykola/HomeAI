import Foundation

/// Завантажує та кешує remote config з Supabase (`App_Config`).
final class SupabaseAppConfigService {

    static let shared = SupabaseAppConfigService()

    private let cacheKey = Constants.Keys.cachedSupabaseAppConfig
    private let session: URLSession
    private let queue = DispatchQueue(label: "HomeAI.SupabaseAppConfigService", qos: .utility)
    private var config: SupabaseAppConfig

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

    var current: SupabaseAppConfig {
        queue.sync { config }
    }

    /// Системний Store review на згенерованій детальці (`ob_sw_rate_alert`). Частоту лімітить Apple.
    var obSwRateAlert: Bool {
        current.obSwRateAlert
    }

    var imageGenerationProvider: ImageGenerationProvider {
        current.imageGenerationProvider
    }

    @discardableResult
    func refreshIfNeeded() async -> SupabaseAppConfig {
        guard let url = URL(string: Constants.API.supabaseAppConfigURL) else {
            log("refresh skipped: invalid URL")
            return current
        }

        log("refresh started: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 12
        applySupabaseAuthHeaders(to: &request)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                log("refresh failed: invalid HTTP response, using \(Self.describe(current))")
                return current
            }

            let rawBody = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
            guard (200 ..< 300).contains(http.statusCode) else {
                log("refresh failed: HTTP \(http.statusCode), body: \(rawBody), using \(Self.describe(current))")
                return current
            }

            log("refresh response HTTP \(http.statusCode), raw: \(rawBody)")

            let decoder = Self.makeJSONDecoder()
            let rows = try decoder.decode([SupabaseAppConfig].self, from: data)
            guard let row = rows.first else {
                log("refresh failed: empty rows (no data or RLS blocks SELECT), using \(Self.describe(current))")
                return current
            }

            apply(row, persist: true)
            log("refresh success: \(Self.describe(row))")
            return row
        } catch {
            log("refresh failed: \(error.localizedDescription), using \(Self.describe(current))")
            return current
        }
    }

    private func apply(_ newConfig: SupabaseAppConfig, persist: Bool) {
        queue.sync {
            config = newConfig
            if persist {
                Self.saveCachedConfig(newConfig, forKey: cacheKey)
            }
        }
    }

    private func applySupabaseAuthHeaders(to request: inout URLRequest) {
        let key = Constants.API.supabaseAnonKey
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
    }

    private static func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            let formatters: [ISO8601DateFormatter] = [
                fractionalSecondsFormatter,
                standardFormatter
            ]

            for formatter in formatters {
                if let date = formatter.date(from: value) {
                    return date
                }
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date: \(value)"
            )
        }
        return decoder
    }

    private static let fractionalSecondsFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let standardFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static func loadCachedConfig(forKey key: String) -> SupabaseAppConfig? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let cached = try? JSONDecoder().decode(CachedPayload.self, from: data) else { return nil }
        return SupabaseAppConfig(
            id: cached.id,
            createdAt: Date(),
            updatedAt: nil,
            obSwRateAlert: cached.obSwRateAlert,
            imageGenerationProvider: cached.imageGenerationProvider ?? .defaultProvider
        )
    }

    private static func saveCachedConfig(_ config: SupabaseAppConfig, forKey key: String) {
        let payload = CachedPayload(
            id: config.id,
            obSwRateAlert: config.obSwRateAlert,
            imageGenerationProvider: config.imageGenerationProvider
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func describe(_ config: SupabaseAppConfig) -> String {
        "id=\(config.id), ob_sw_rate_alert=\(config.obSwRateAlert), image_provider=\(config.imageGenerationProvider.rawValue)"
    }

    private func log(_ message: String) {
        print("[SupabaseAppConfig] \(message)")
    }
}

private struct CachedPayload: Codable {
    let id: Int64
    let obSwRateAlert: Bool
    let imageGenerationProvider: ImageGenerationProvider?

    enum CodingKeys: String, CodingKey {
        case id
        case obSwRateAlert = "ob_sw_rate_alert"
        case imageGenerationProvider = "image_generation_provider"
    }
}
