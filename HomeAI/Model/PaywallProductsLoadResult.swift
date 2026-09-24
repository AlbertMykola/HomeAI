import Adapty
import Foundation

struct PaywallProductsLoadResult {
    let products: [AdaptyPaywallProduct]
    let presentation: PaywallProductsPresentation
}

/// Purchase success grants access; it does not necessarily mean money was charged.
/// A first paid transaction must be measured from App Store/Adapty billing events.
public struct PaywallPurchaseOutcome {
    let startedFreeTrial: Bool?
    let transactionVerified: Bool
}

enum AdaptyServiceError: LocalizedError, Equatable {
    case placementNotFound
    case insufficientProducts
    case invalidProductIndex
    case purchaseCancelled
    case purchasePending
    case purchaseFailed

    var errorDescription: String? {
        switch self {
        case .placementNotFound: return "Paywall placement not found".localized
        case .insufficientProducts: return "Paywall requires at least two products".localized
        case .invalidProductIndex: return "Invalid product index"
        case .purchaseCancelled: return nil
        case .purchasePending: return "Purchase pending"
        case .purchaseFailed: return "Purchase failed"
        }
    }
}
