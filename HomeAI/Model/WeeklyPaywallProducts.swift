/// Shared product policy for every paywall and the purchase boundary.
protocol PaywallSubscriptionProduct {
    var paywallIsWeeklySubscription: Bool { get }
    var paywallHasFreeTrial: Bool { get }
}

enum WeeklyPaywallProducts {
    struct Selection: Equatable {
        let trialIndex: Int?
        let plainIndex: Int?

        var preferredIndex: Int? { trialIndex ?? plainIndex }
        var canToggleTrial: Bool { trialIndex != nil && plainIndex != nil }

        func selectedIndex(trialEnabled: Bool) -> Int? {
            trialEnabled ? (trialIndex ?? plainIndex) : (plainIndex ?? trialIndex)
        }
    }

    static func onlyWeekly<Product: PaywallSubscriptionProduct>(from products: [Product]) -> [Product] {
        products.filter(\.paywallIsWeeklySubscription)
    }

    static func selection<Product: PaywallSubscriptionProduct>(from products: [Product]) -> Selection {
        let indices = products.indices.filter { products[$0].paywallIsWeeklySubscription }
        return Selection(
            trialIndex: indices.first { products[$0].paywallHasFreeTrial },
            plainIndex: indices.first { !products[$0].paywallHasFreeTrial }
        )
    }
}
