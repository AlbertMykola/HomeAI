import Adapty
import Foundation

/// UI-стан єдиної тижневої підписки після завантаження продуктів Adapty.
struct PaywallProductsPresentation: Equatable {

    struct Badge: Equatable {
        enum Kind: Equatable {
            case trial
            case savings
            case bestValue
        }

        let kind: Kind
        let title: String
    }

    struct ProductRow: Equatable {
        let storeIndex: Int
        let title: String
        let priceDisplay: PaywallPriceDisplay
        let badge: Badge?
        let hasFreeTrial: Bool
    }

    let top: ProductRow

    /// Індекс продукту StoreKit для покупки за обраним рядом UI.
    func storeIndex(for uiRow: PaywallUIRow) -> Int? {
        productRow(for: uiRow)?.storeIndex
    }

    func productRow(for uiRow: PaywallUIRow) -> ProductRow? {
        uiRow == .top ? top : nil
    }

    var preferredUIRow: PaywallUIRow { .top }

    static func make(from products: [AdaptyPaywallProduct]) -> PaywallProductsPresentation? {
        guard let selectedIndex = WeeklyPaywallProducts.selection(from: products).preferredIndex else { return nil }
        let product = products[selectedIndex]
        let badge: Badge? = product.paywallHasFreeTrial
            ? Badge(kind: .trial, title: PaywallProductCopy.trialBadgeTitle(days: product.paywallTrialDays ?? 3))
            : nil
        return PaywallProductsPresentation(top: ProductRow(
            storeIndex: selectedIndex,
            title: product.paywallPeriodTitle,
            priceDisplay: product.paywallPriceDisplay(),
            badge: badge,
            hasFreeTrial: product.paywallHasFreeTrial
        ))
    }

    static func savingsPercent(
        yearlyPrice: NSDecimalNumber,
        weeklyPrice: NSDecimalNumber
    ) -> Int? {
        guard yearlyPrice.compare(NSDecimalNumber.zero) == .orderedDescending,
              weeklyPrice.compare(NSDecimalNumber.zero) == .orderedDescending else { return nil }
        let annualizedWeekly = weeklyPrice.multiplying(by: NSDecimalNumber(value: 52))
        guard annualizedWeekly.compare(yearlyPrice) == .orderedDescending else { return nil }
        let ratio = yearlyPrice.dividing(by: annualizedWeekly).doubleValue
        return Int(((1 - ratio) * 100).rounded())
    }
}

enum PaywallUIRow {
    case top
    case bottom
}
