import Foundation

/// Remote config з таблиці Supabase `App_Config`.
struct SupabaseAppConfig: Codable, Equatable {

    let id: Int64
    let createdAt: Date
    let updatedAt: Date?
    let obSwRateAlert: Bool
    let imageGenerationProvider: ImageGenerationProvider

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case obSwRateAlert = "ob_sw_rate_alert"
        case imageGenerationProvider = "image_generation_provider"
    }

    init(
        id: Int64,
        createdAt: Date,
        updatedAt: Date?,
        obSwRateAlert: Bool,
        imageGenerationProvider: ImageGenerationProvider = .gemini
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.obSwRateAlert = obSwRateAlert
        self.imageGenerationProvider = imageGenerationProvider
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        // Timestamps are informational: a format the decoder doesn't know (e.g. Postgres `timestamp` without a
        // time zone, "2026-07-16T16:01:47.379775") must not drop the whole config and its provider switch.
        createdAt = (try? container.decodeIfPresent(Date.self, forKey: .createdAt)) ?? Date()
        updatedAt = try? container.decodeIfPresent(Date.self, forKey: .updatedAt)
        obSwRateAlert = try container.decodeIfPresent(Bool.self, forKey: .obSwRateAlert) ?? false
        imageGenerationProvider = try container.decodeIfPresent(
            ImageGenerationProvider.self,
            forKey: .imageGenerationProvider
        ) ?? .defaultProvider
    }

    static let fallback = SupabaseAppConfig(
        id: 0,
        createdAt: Date(),
        updatedAt: nil,
        obSwRateAlert: false,
        imageGenerationProvider: .defaultProvider
    )
}

extension ImageGenerationProvider {
    /// Used when Supabase `App_Config.image_generation_provider` is missing (or no config yet): the OpenAI worker.
    /// Rollback without a build: set the column to "gemini" (Gemini worker).
    static let defaultProvider: ImageGenerationProvider = .openAI
}
