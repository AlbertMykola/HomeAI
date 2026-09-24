import Adapty
import Foundation

/// UI-стан двох тарифів paywall після завантаження продуктів Adapty.
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
    let bottom: ProductRow

    /// Індекс продукту StoreKit для покупки за обраним рядом UI.
    func storeIndex(for uiRow: PaywallUIRow) -> Int {
        uiRow == .top ? top.storeIndex : bottom.storeIndex
    }

    func productRow(for uiRow: PaywallUIRow) -> ProductRow {
        uiRow == .top ? top : bottom
    }

    /// Стартовий вибір: trial-тижневий, інакше верхній (best value).
    var preferredUIRow: PaywallUIRow {
        if top.hasFreeTrial, top.badge?.kind == .trial { return .top }
        if bottom.hasFreeTrial, bottom.badge?.kind == .trial { return .bottom }
        return .top
    }

    static func make(from products: [AdaptyPaywallProduct]) -> PaywallProductsPresentation? {
        guard products.count >= 2 else { return nil }

        let indexed = products.enumerated().map { index, product in
            (
                index: index,
                product: product,
                isWeekly: product.paywallIsWeeklySubscription,
                isYearly: product.paywallIsYearlySubscription,
                hasTrial: product.paywallHasFreeTrial,
                trialDays: product.paywallTrialDays
            )
        }

        let weeklyTrialIndex = indexed.first(where: { $0.isWeekly && $0.hasTrial })?.index
        let yearlyIndex = indexed.first(where: { $0.isYearly })?.index
        let weeklyIndex = indexed.first(where: { $0.isWeekly })?.index

        var badgesByIndex: [Int: Badge] = [:]

        if let trialIndex = weeklyTrialIndex {
            let days = indexed[trialIndex].trialDays ?? 3
            badgesByIndex[trialIndex] = Badge(kind: .trial, title: PaywallProductCopy.trialBadgeTitle(days: days))
        }

        if let yearlyIndex,
           let weeklyIndex {
            let yearlyPrice = NSDecimalNumber(decimal: products[yearlyIndex].paywallPriceDecimal)
            let weeklyPrice = NSDecimalNumber(decimal: products[weeklyIndex].paywallPriceDecimal)
            if let savings = savingsPercent(yearlyPrice: yearlyPrice, weeklyPrice: weeklyPrice) {
                badgesByIndex[yearlyIndex] = Badge(
                    kind: .savings,
                    title: PaywallProductCopy.savingsBadgeTitle(percent: savings)
                )
            } else {
                let bestValueIndex = yearlyIndex
                if badgesByIndex[bestValueIndex] == nil {
                    badgesByIndex[bestValueIndex] = Badge(kind: .bestValue, title: PaywallProductCopy.bestValue)
                }
            }
        } else {
            let bestValueIndex = yearlyIndex ?? 0
            if badgesByIndex[bestValueIndex] == nil {
                badgesByIndex[bestValueIndex] = Badge(kind: .bestValue, title: PaywallProductCopy.bestValue)
            }
        }

        func row(at index: Int) -> ProductRow {
            let product = products[index]
            return ProductRow(
                storeIndex: index,
                title: product.paywallPeriodTitle,
                priceDisplay: product.paywallPriceDisplay(),
                badge: badgesByIndex[index],
                hasFreeTrial: product.paywallHasFreeTrial
            )
        }

        let topIndex = yearlyIndex ?? 0
        let bottomIndex = weeklyIndex.flatMap { $0 == topIndex ? nil : $0 } ?? (topIndex == 0 ? 1 : 0)
        return PaywallProductsPresentation(
            top: row(at: topIndex),
            bottom: row(at: bottomIndex)
        )
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
