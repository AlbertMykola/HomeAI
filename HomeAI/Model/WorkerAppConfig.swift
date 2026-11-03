import Foundation

/// Remote config з Cloudflare worker (`GET /app/config`).
struct WorkerAppConfig: Codable, Equatable {

    let freeGenerationsLifetime: Int
    let premiumGenerationsPerDay: Int
    let paywallShowTopCloseButton: Bool
    let configVersion: Int
    var premiumGenerationsPerWindow = Constants.GenerationLimits.premiumGenerationsPerWindow
    var generationWindowHours = Constants.GenerationLimits.generationWindowHours
    /// A/12 Force update: versions below this one must update ("2.0", "2.1.3"). Absent → no forced update.
    var minSupportedVersion: String? = nil

    enum CodingKeys: String, CodingKey {
        case freeGenerationsLifetime
        case premiumGenerationsPerDay
        case paywallShowTopCloseButton
        case configVersion
        case lifetimeFreeScanLimit
        case minSupportedVersion
        case premiumGenerationsPerWindow
        case generationWindowHours
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
        minSupportedVersion = try container.decodeIfPresent(String.self, forKey: .minSupportedVersion)
        premiumGenerationsPerWindow = try container.decodeIfPresent(Int.self, forKey: .premiumGenerationsPerWindow)
            ?? Constants.GenerationLimits.premiumGenerationsPerWindow
        generationWindowHours = try container.decodeIfPresent(Int.self, forKey: .generationWindowHours)
            ?? Constants.GenerationLimits.generationWindowHours
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(freeGenerationsLifetime, forKey: .freeGenerationsLifetime)
        try container.encode(premiumGenerationsPerDay, forKey: .premiumGenerationsPerDay)
        try container.encode(paywallShowTopCloseButton, forKey: .paywallShowTopCloseButton)
        try container.encode(configVersion, forKey: .configVersion)
        try container.encodeIfPresent(minSupportedVersion, forKey: .minSupportedVersion)
        try container.encode(premiumGenerationsPerWindow, forKey: .premiumGenerationsPerWindow)
        try container.encode(generationWindowHours, forKey: .generationWindowHours)
    }

    static let fallback = WorkerAppConfig(
        freeGenerationsLifetime: Constants.GenerationLimits.freeGenerationsLifetime,
        premiumGenerationsPerDay: Constants.GenerationLimits.premiumGenerationsPerDay,
        paywallShowTopCloseButton: Constants.PaywallRemote.showTopCloseButtonFallback
    )
}
