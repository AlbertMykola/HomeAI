import Adapty
import Foundation

extension AdaptyPaywallProduct {

    var paywallHasFreeTrial: Bool {
        subscriptionOffer?.paymentMode == .freeTrial
    }

    var paywallIsWeeklySubscription: Bool {
        guard let period = subscriptionPeriod else { return false }
        if period.unit == .week, period.numberOfUnits == 1 { return true }
        if period.unit == .day, period.numberOfUnits == 7 { return true }
        return false
    }

    var paywallIsYearlySubscription: Bool {
        guard let period = subscriptionPeriod else { return false }
        return period.unit == .year && period.numberOfUnits == 1
    }

    var paywallIsMonthlySubscription: Bool {
        guard let period = subscriptionPeriod else { return false }
        return period.unit == .month && period.numberOfUnits == 1
    }

    var paywallTrialDays: Int? {
        guard paywallHasFreeTrial, let offerPeriod = subscriptionOffer?.subscriptionPeriod else { return nil }
        return offerPeriod.paywallApproximateDays
    }

    var paywallPriceDecimal: Decimal {
        price
    }

    func paywallFormattedCurrencyAmount(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        if let currencyCode {
            formatter.currencyCode = currencyCode
        }
        if let currencySymbol {
            formatter.currencySymbol = currencySymbol
        }
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber)
            ?? localizedPrice
            ?? "USD 0.00"
    }

    func paywallPriceDisplay() -> PaywallPriceDisplay {
        let billedPrice = localizedPrice ?? paywallFormattedCurrencyAmount(paywallPriceDecimal)

        if paywallIsWeeklySubscription {
            return PaywallPriceDisplay(
                billedPrice: billedPrice,
                billingPeriod: PaywallProductCopy.weeklyBillingPeriod,
                emphasizedPrice: billedPrice,
                emphasizedPeriod: PaywallProductCopy.perWeek
            )
        }

        if paywallIsYearlySubscription {
            let perMonth = paywallPriceDecimal / 12
            return PaywallPriceDisplay(
                billedPrice: billedPrice,
                billingPeriod: PaywallProductCopy.annualBillingPeriod,
                emphasizedPrice: paywallFormattedCurrencyAmount(perMonth),
                emphasizedPeriod: PaywallProductCopy.perMonth
            )
        }

        if paywallIsMonthlySubscription {
            let perWeek = paywallPriceDecimal * 12 / 52
            return PaywallPriceDisplay(
                billedPrice: billedPrice,
                billingPeriod: PaywallProductCopy.monthlyBillingPeriod,
                emphasizedPrice: paywallFormattedCurrencyAmount(perWeek),
                emphasizedPeriod: PaywallProductCopy.perWeek
            )
        }

        return PaywallPriceDisplay(
            billedPrice: billedPrice,
            billingPeriod: PaywallProductCopy.weeklyBillingPeriod,
            emphasizedPrice: billedPrice,
            emphasizedPeriod: PaywallProductCopy.perYear
        )
    }

    var paywallPeriodTitle: String {
        if paywallIsYearlySubscription { return PaywallProductCopy.yearlyAccessTitle }
        if paywallIsMonthlySubscription { return PaywallProductCopy.monthlyAccessTitle }
        if paywallIsWeeklySubscription { return PaywallProductCopy.weeklyAccessTitle }
        return PaywallProductCopy.yearlyAccessTitle
    }
}

extension AdaptySubscriptionPeriod {

    var paywallApproximateDays: Int {
        switch unit {
        case .day: return numberOfUnits
        case .week: return numberOfUnits * 7
        case .month: return numberOfUnits * 30
        case .year: return numberOfUnits * 365
        case .unknown: return numberOfUnits
        }
    }
}
