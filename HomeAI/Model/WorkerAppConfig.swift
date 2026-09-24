import Foundation

/// Remote config з Cloudflare worker (`GET /app/config`).
struct WorkerAppConfig: Codable, Equatable {

    let freeGenerationsLifetime: Int
    let premiumGenerationsPerDay: Int
    let paywallShowTopCloseButton: Bool
    let configVersion: Int

    enum CodingKeys: String, CodingKey {
        case freeGenerationsLifetime
        case premiumGenerationsPerDay
        case paywallShowTopCloseButton
        case configVersion
        case lifetimeFreeScanLimit
    }

    init(
        freeGenerationsLifetime: Int,
        premiumGenerationsPerDay: Int,
        paywallShowTopCloseButton: Bool,
        configVersion: Int = 1
    ) {
        self.freeGenerationsLifetime = freeGenerationsLifetime
        self.premiumGenerationsPerDay = premiumGenerationsPerDay
        self.paywallShowTopCloseButton = paywallShowTopCloseButton
        self.configVersion = configVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyFree = try container.decodeIfPresent(Int.self, forKey: .lifetimeFreeScanLimit)
        freeGenerationsLifetime = try container.decodeIfPresent(Int.self, forKey: .freeGenerationsLifetime)
            ?? legacyFree
            ?? Constants.GenerationLimits.freeGenerationsLifetime
        premiumGenerationsPerDay = try container.decodeIfPresent(Int.self, forKey: .premiumGenerationsPerDay)
            ?? Constants.GenerationLimits.premiumGenerationsPerDay
        paywallShowTopCloseButton = try container.decodeIfPresent(Bool.self, forKey: .paywallShowTopCloseButton)
            ?? Constants.PaywallRemote.showTopCloseButtonFallback
        configVersion = try container.decodeIfPresent(Int.self, forKey: .configVersion) ?? 1
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(freeGenerationsLifetime, forKey: .freeGenerationsLifetime)
        try container.encode(premiumGenerationsPerDay, forKey: .premiumGenerationsPerDay)
        try container.encode(paywallShowTopCloseButton, forKey: .paywallShowTopCloseButton)
        try container.encode(configVersion, forKey: .configVersion)
    }

    static let fallback = WorkerAppConfig(
        freeGenerationsLifetime: Constants.GenerationLimits.freeGenerationsLifetime,
        premiumGenerationsPerDay: Constants.GenerationLimits.premiumGenerationsPerDay,
        paywallShowTopCloseButton: Constants.PaywallRemote.showTopCloseButtonFallback
    )
}
