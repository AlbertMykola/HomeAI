import StoreKit

public extension SKProduct {

    var formattedPrice: String? {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.locale = priceLocale
        return nf.string(from: price)
    }

    var currencySymbol: String? {
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.locale = priceLocale
        return nf.currencySymbol
    }

    struct WeeklyPrice {
        public let value: Decimal
        public let formatted: String
    }

    var weeklyPrice: WeeklyPrice? {
        guard let period = subscriptionPeriod else { return nil }

        let calendar = Calendar(identifier: .gregorian)
        let start = Date()
        var comps = DateComponents()

        switch period.unit {
        case .day:   comps.day = period.numberOfUnits
        case .week:  comps.weekOfYear = period.numberOfUnits
        case .month: comps.month = period.numberOfUnits
        case .year:  comps.year = period.numberOfUnits
        @unknown default: return nil
        }

        guard let end = calendar.date(byAdding: comps, to: start) else { return nil }
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        let weeks = max(1.0, Double(days) / 7.0)

        let perWeek = (price as Decimal) / Decimal(weeks)

        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.locale = priceLocale
        let formatted = nf.string(from: perWeek as NSDecimalNumber) ?? ""

        return WeeklyPrice(value: perWeek, formatted: formatted)
    }

    var isTrial: Bool {
        introductoryPrice?.subscriptionPeriod != nil
    }
}
