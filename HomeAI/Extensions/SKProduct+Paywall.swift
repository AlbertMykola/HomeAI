import StoreKit

extension SKProduct {

    /// Безкоштовний trial (intro offer).
    var paywallHasFreeTrial: Bool {
        introductoryPrice?.paymentMode == .freeTrial
    }

    /// Тижнева підписка (1 week або 7 days).
    var paywallIsWeeklySubscription: Bool {
        guard let period = subscriptionPeriod else { return false }
        if period.unit == .week, period.numberOfUnits == 1 { return true }
        if period.unit == .day, period.numberOfUnits == 7 { return true }
        return false
    }

    /// Річна підписка (1 year).
    var paywallIsYearlySubscription: Bool {
        guard let period = subscriptionPeriod else { return false }
        return period.unit == .year && period.numberOfUnits == 1
    }

    /// Місячна підписка (1 month).
    var paywallIsMonthlySubscription: Bool {
        guard let period = subscriptionPeriod else { return false }
        return period.unit == .month && period.numberOfUnits == 1
    }

    /// Кількість днів trial для бейджа (напр. 3).
    var paywallTrialDays: Int? {
        guard paywallHasFreeTrial, let intro = introductoryPrice else { return nil }
        return intro.subscriptionPeriod.paywallApproximateDays
    }

    func paywallFormattedCurrencyAmount(_ value: NSDecimalNumber) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = priceLocale
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value) ?? "\(priceLocale.currencyCode ?? "USD") 0.00"
    }

    func paywallPriceDisplay() -> PaywallPriceDisplay {
        let billedPrice = paywallFormattedCurrencyAmount(price)

        if paywallIsWeeklySubscription {
            return PaywallPriceDisplay(
                billedPrice: billedPrice,
                billingPeriod: PaywallProductCopy.weeklyBillingPeriod,
                emphasizedPrice: billedPrice,
                emphasizedPeriod: PaywallProductCopy.perWeek
            )
        }

        if paywallIsYearlySubscription {
            let perMonth = price.dividing(by: NSDecimalNumber(value: 12))
            return PaywallPriceDisplay(
                billedPrice: billedPrice,
                billingPeriod: PaywallProductCopy.annualBillingPeriod,
                emphasizedPrice: paywallFormattedCurrencyAmount(perMonth),
                emphasizedPeriod: PaywallProductCopy.perMonth
            )
        }

        if paywallIsMonthlySubscription {
            // 12 місяців / 52 тижні ≈ еквівалентна тижнева ціна.
            let perWeek = price.multiplying(by: NSDecimalNumber(value: 12))
                .dividing(by: NSDecimalNumber(value: 52))
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
            emphasizedPeriod: PaywallProductCopy.perWeek
        )
    }

    /// Заголовок тарифу за періодом підписки (без імені з кабінету).
    var paywallPeriodTitle: String {
        if paywallIsYearlySubscription { return PaywallProductCopy.yearlyAccessTitle }
        if paywallIsMonthlySubscription { return PaywallProductCopy.monthlyAccessTitle }
        if paywallIsWeeklySubscription { return PaywallProductCopy.weeklyAccessTitle }
        return PaywallProductCopy.yearlyAccessTitle
    }

}

extension SKProductSubscriptionPeriod {

    var paywallApproximateDays: Int {
        switch unit {
        case .day: return numberOfUnits
        case .week: return numberOfUnits * 7
        case .month: return numberOfUnits * 30
        case .year: return numberOfUnits * 365
        @unknown default: return numberOfUnits
        }
    }
}

enum PaywallProductCopy {
    static var yearlyAccessTitle: String { "Yearly Access".localized }
    static var monthlyAccessTitle: String { "Monthly Access".localized }
    static var weeklyAccessTitle: String { "Weekly Access".localized }
    static var perYear: String { "/year".localized }
    static var perMonth: String { "/month".localized }
    static var perWeek: String { "/week".localized }
    static var annualBillingPeriod: String { "annually".localized }
    static var monthlyBillingPeriod: String { "monthly".localized }
    static var weeklyBillingPeriod: String { "weekly".localized }
    static var bestValue: String { "Best Value".localized }
    static var threeDaysTrial: String { "3 days trial".localized }
    static var tryFreeTrial: String { "Try Free trial".localized }
    static var `continue`: String { "Continue".localized }

    static func trialBadgeTitle(days: Int) -> String {
        days == 3 ? threeDaysTrial : String(format: "%d days trial".localized, days)
    }

    static func savingsBadgeTitle(percent: Int) -> String {
        String(format: "%d%% OFF".localized, percent)
    }
}
