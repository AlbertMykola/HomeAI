import Adapty
import UIKit
import XCTest
@testable import HomeAI

final class PaywallPricingTests: XCTestCase {
    @MainActor
    func testSingleWeeklyOfferCollapsesTrialChoiceWithoutMovingContentOutsideViewport() throws {
        #if DEBUG
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        let previousLanguage = AppQA.language
        let previousPremium = AppQA.premium
        let previousSnapshot = AppQA.snapshot
        let previousEmptyProjects = AppQA.emptyProjects
        AppQA.language = "en"
        AppQA.snapshot = true
        defer {
            AppQA.language = previousLanguage
            AppQA.premium = previousPremium
            AppQA.snapshot = previousSnapshot
            AppQA.emptyProjects = previousEmptyProjects
        }

        let paywall = try XCTUnwrap(AppQA.makeScreen("paywall-single-weekly") as? ProPaywallViewController)
        let view = try XCTUnwrap(paywall.view)
        let toggle = try XCTUnwrap(paywall.value(forKey: "trialToggle") as? UIView)
        let card = try XCTUnwrap(paywall.value(forKey: "cardView") as? UIView)
        let timeline = try XCTUnwrap(paywall.value(forKey: "timelineView") as? UIView)
        let cta = try XCTUnwrap(paywall.value(forKey: "ctaButton") as? UIView)
        XCTAssertTrue(toggle.isHidden)

        for size in [CGSize(width: 375, height: 667), CGSize(width: 466, height: 678),
                     CGSize(width: 1032, height: 1376)] {
            view.frame = CGRect(origin: .zero, size: size)
            for _ in 0..<6 { view.setNeedsLayout(); view.layoutIfNeeded() }

            XCTAssertLessThanOrEqual(toggle.bounds.height, 1, "Hidden trial choice must collapse at \(size)")
            let cardFrame = card.convert(card.bounds, to: view)
            let timelineFrame = timeline.convert(timeline.bounds, to: view)
            let ctaFrame = cta.convert(cta.bounds, to: view)
            XCTAssertGreaterThan(cardFrame.height, 0)
            XCTAssertGreaterThan(timelineFrame.height, 0)
            XCTAssertGreaterThanOrEqual(timelineFrame.minY, cardFrame.maxY - 1,
                                        "Timeline must follow the subscription card at \(size)")
            XCTAssertGreaterThan(ctaFrame.width, 0)
            XCTAssertGreaterThan(ctaFrame.height, 0)
            XCTAssertGreaterThanOrEqual(ctaFrame.minX, -1)
            XCTAssertGreaterThanOrEqual(ctaFrame.minY, -1)
            XCTAssertLessThanOrEqual(ctaFrame.maxX, view.bounds.width + 1)
            XCTAssertLessThanOrEqual(ctaFrame.maxY, view.bounds.height + 1,
                                     "Purchase button must remain in the viewport at \(size)")
        }
        #else
        throw XCTSkip("Use a Debug HomeAIFullQA build")
        #endif
    }

    @MainActor
    func testProPaywallFixtureKeepsWeeklyPriceWhenTrialIsDisabled() throws {
        #if DEBUG
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        let previousLanguage = AppQA.language
        AppQA.language = "en"
        defer { AppQA.language = previousLanguage }

        let paywall = AppStoryboard.instantiate(ProPaywallViewController.self)
        paywall.loadViewIfNeeded()
        let price = try XCTUnwrap(paywall.value(forKey: "cardPriceLabel") as? UILabel)
        let cardTitle = try XCTUnwrap(paywall.value(forKey: "cardTitleLabel") as? UILabel)
        let trial = try XCTUnwrap(paywall.value(forKey: "trialLabel") as? UILabel)
        let note = try XCTUnwrap(paywall.value(forKey: "noteLabel") as? UILabel)
        let cta = try XCTUnwrap(paywall.value(forKey: "ctaLabel") as? UILabel)
        let toggle = try XCTUnwrap(paywall.value(forKey: "trialToggle") as? DSPressableControl)

        XCTAssertEqual(cardTitle.text, "Rehomely PRO")
        XCTAssertTrue(try XCTUnwrap(price.text).contains("/week"))
        XCTAssertFalse(try XCTUnwrap(price.text).contains("/year"))
        XCTAssertEqual(trial.text, "Free Trial Enabled")
        XCTAssertEqual(note.text, "No payment now")
        XCTAssertEqual(cta.text, "Start Free Trial")
        XCTAssertFalse(toggle.isHidden)

        toggle.sendActions(for: .touchUpInside)

        XCTAssertEqual(cardTitle.text, "Rehomely PRO")
        XCTAssertTrue(try XCTUnwrap(price.text).contains("/week, billed today"))
        XCTAssertFalse(try XCTUnwrap(price.text).contains("/year"))
        XCTAssertEqual(trial.text, "Enable Free Trial")
        XCTAssertEqual(note.text, "Billed weekly · Cancel anytime")
        XCTAssertEqual(cta.text, "Continue")
        #else
        throw XCTSkip("Use a Debug HomeAIFullQA build")
        #endif
    }

    func testActualSDKPeriodsAcceptExactlyOneWeek() throws {
        let cases: [(unit: String, count: Int, weekly: Bool)] = [
            ("week", 1, true), ("day", 7, true),
            ("day", 1, false), ("day", 6, false), ("day", 8, false),
            ("day", 14, false), ("week", 2, false),
            ("month", 1, false), ("month", 12, false),
            ("year", 1, false), ("unknown", 1, false)
        ]
        for test in cases {
            let data = try JSONSerialization.data(withJSONObject: [
                "unit": test.unit, "number_of_units": test.count
            ])
            let period = try JSONDecoder().decode(AdaptySubscriptionPeriod.self, from: data)
            XCTAssertEqual(period.paywallIsWeeklySubscription, test.weekly,
                           "Incorrect weekly classification for \(test.count) \(test.unit)")
        }
    }

    func testMixedOfferingsSelectOnlyWeeklyProductsInEveryServerOrder() throws {
        let yearly = Product(id: "yearly", weekly: false, trial: true)
        let monthly = Product(id: "monthly", weekly: false)
        let weekly = Product(id: "weekly", weekly: true)
        let weeklyTrial = Product(id: "weekly-trial", weekly: true, trial: true)

        for products in permutations([yearly, monthly, weekly, weeklyTrial]) {
            let weeklyProducts = WeeklyPaywallProducts.onlyWeekly(from: products)
            XCTAssertEqual(weeklyProducts, products.filter(\.paywallIsWeeklySubscription))

            let selection = WeeklyPaywallProducts.selection(from: products)
            let trialIndex = try XCTUnwrap(selection.trialIndex)
            let plainIndex = try XCTUnwrap(selection.plainIndex)
            XCTAssertEqual(products[trialIndex], weeklyTrial)
            XCTAssertEqual(products[plainIndex], weekly)
            XCTAssertEqual(selection.preferredIndex, trialIndex)
            XCTAssertEqual(selection.selectedIndex(trialEnabled: true), trialIndex)
            XCTAssertEqual(selection.selectedIndex(trialEnabled: false), plainIndex)
            XCTAssertTrue(selection.canToggleTrial)
        }
    }

    func testSingleWeeklyProductCanBeSelectedWithoutASecondPlan() {
        let weekly = Product(id: "weekly", weekly: true)
        let selection = WeeklyPaywallProducts.selection(from: [weekly])

        XCTAssertEqual(WeeklyPaywallProducts.onlyWeekly(from: [weekly]), [weekly])
        XCTAssertNil(selection.trialIndex)
        XCTAssertEqual(selection.plainIndex, 0)
        XCTAssertEqual(selection.preferredIndex, 0)
        XCTAssertEqual(selection.selectedIndex(trialEnabled: true), 0)
        XCTAssertEqual(selection.selectedIndex(trialEnabled: false), 0)
        XCTAssertFalse(selection.canToggleTrial)
    }

    func testSingleWeeklyTrialRemainsWeeklyWhenTrialCannotBeToggled() {
        let weeklyTrial = Product(id: "weekly-trial", weekly: true, trial: true)
        let selection = WeeklyPaywallProducts.selection(from: [weeklyTrial])

        XCTAssertEqual(selection.trialIndex, 0)
        XCTAssertEqual(selection.preferredIndex, 0)
        XCTAssertEqual(selection.selectedIndex(trialEnabled: true), 0)
        XCTAssertEqual(selection.selectedIndex(trialEnabled: false), 0)
        XCTAssertFalse(selection.canToggleTrial)
    }

    func testYearlyTrialCannotEnableTrialForAWeeklyProduct() {
        let products = [Product(id: "yearly-trial", weekly: false, trial: true),
                        Product(id: "weekly", weekly: true)]
        let selection = WeeklyPaywallProducts.selection(from: products)

        XCTAssertNil(selection.trialIndex)
        XCTAssertEqual(selection.plainIndex, 1)
        XCTAssertEqual(selection.preferredIndex, 1)
        XCTAssertEqual(selection.selectedIndex(trialEnabled: true), 1)
        XCTAssertEqual(selection.selectedIndex(trialEnabled: false), 1)
        XCTAssertFalse(selection.canToggleTrial)
    }

    func testMissingWeeklyProductNeverFallsBackToAnotherPeriod() {
        let offerings: [[Product]] = [
            [],
            [Product(id: "yearly", weekly: false)],
            [Product(id: "weekly-name-but-yearly-period", weekly: false, trial: true),
             Product(id: "monthly", weekly: false)]
        ]

        for products in offerings {
            XCTAssertTrue(WeeklyPaywallProducts.onlyWeekly(from: products).isEmpty)
            let selection = WeeklyPaywallProducts.selection(from: products)
            XCTAssertNil(selection.trialIndex)
            XCTAssertNil(selection.plainIndex)
            XCTAssertNil(selection.preferredIndex)
            XCTAssertNil(selection.selectedIndex(trialEnabled: true))
            XCTAssertNil(selection.selectedIndex(trialEnabled: false))
            XCTAssertFalse(selection.canToggleTrial)
        }
        XCTAssertNil(PaywallProductsPresentation.make(from: []))
    }

    func testSinglePlanPresentationHasNoPurchasableSecondRow() {
        let row = PaywallProductsPresentation.ProductRow(
            storeIndex: 3,
            title: "Weekly Access",
            priceDisplay: PaywallPriceDisplay(billedPrice: "$7.99", billingPeriod: "weekly",
                                             emphasizedPrice: "$7.99", emphasizedPeriod: "/week"),
            badge: nil,
            hasFreeTrial: false
        )
        let presentation = PaywallProductsPresentation(top: row)

        XCTAssertEqual(presentation.productRow(for: .top), row)
        XCTAssertEqual(presentation.storeIndex(for: presentation.preferredUIRow), 3)
        XCTAssertNil(presentation.productRow(for: .bottom))
        XCTAssertNil(presentation.storeIndex(for: .bottom))
    }

    func testSavingsPercentMatchesYearlyVersusWeeklyEquivalent() {
        let savings = PaywallProductsPresentation.savingsPercent(
            yearlyPrice: NSDecimalNumber(string: "49.99"),
            weeklyPrice: NSDecimalNumber(string: "7.99")
        )

        XCTAssertEqual(savings, 88)
    }

    func testSavingsPercentRejectsNonDiscountedYearlyPrice() {
        let savings = PaywallProductsPresentation.savingsPercent(
            yearlyPrice: NSDecimalNumber(string: "500"),
            weeklyPrice: NSDecimalNumber(string: "7.99")
        )

        XCTAssertNil(savings)
    }

    func testEmphasizedPriceKeepsAmountAndPeriodSeparate() {
        let display = PaywallPriceDisplay(
            billedPrice: "$7.99",
            billingPeriod: "weekly",
            emphasizedPrice: "$7.99",
            emphasizedPeriod: "/week"
        )

        let value = display.makeEmphasizedAttributedString(
            amountFont: .systemFont(ofSize: 18, weight: .bold),
            periodFont: .systemFont(ofSize: 12),
            textColor: .white
        )

        XCTAssertEqual(value.string, "$7.99/week")
        XCTAssertEqual(display.debugPlainText, "$7.99 billed weekly; $7.99/week")
    }

    private struct Product: PaywallSubscriptionProduct, Equatable {
        let id: String
        let paywallIsWeeklySubscription: Bool
        let paywallHasFreeTrial: Bool

        init(id: String, weekly: Bool, trial: Bool = false) {
            self.id = id
            paywallIsWeeklySubscription = weekly
            paywallHasFreeTrial = trial
        }
    }

    private func permutations<T>(_ values: [T]) -> [[T]] {
        guard !values.isEmpty else { return [[]] }
        return values.indices.flatMap { index in
            var remaining = values
            let first = remaining.remove(at: index)
            return permutations(remaining).map { [first] + $0 }
        }
    }
}
