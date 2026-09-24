import AdServices
import Foundation

enum AppleSearchAdsAttributionResult: Sendable {
    case attributed([String: Any])
    case organic
    case unavailable
}

struct AppleSearchAdsAttributionFetch: Sendable {
    let token: String?
    let result: AppleSearchAdsAttributionResult
}

final class AppleSearchAdsAttributionService {
    static let shared = AppleSearchAdsAttributionService()

    private static let attributionURL = URL(string: "https://api-adservices.apple.com/api/v1/")!

    private init() {}

    @available(iOS 14.3, *)
    func fetchAttribution() async -> AppleSearchAdsAttributionFetch {
        guard let token = try? AAAttribution.attributionToken() else {
            return AppleSearchAdsAttributionFetch(token: nil, result: .unavailable)
        }
        let result = await resolveAttribution(token: token)
        return AppleSearchAdsAttributionFetch(token: token, result: result)
    }

    @available(iOS 14.3, *)
    func resolveAttribution(token: String) async -> AppleSearchAdsAttributionResult {
        var request = URLRequest(url: Self.attributionURL)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(token.utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let attribution = json["attribution"] as? Bool
            else {
                return .unavailable
            }
            return attribution ? .attributed(json) : .organic
        } catch {
            #if DEBUG
            print("[AppleSearchAdsAttribution] API error: \(error.localizedDescription)")
            #endif
            return .unavailable
        }
    }
}
