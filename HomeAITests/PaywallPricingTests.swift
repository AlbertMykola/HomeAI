import XCTest
@testable import HomeAI

final class PaywallPricingTests: XCTestCase {
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
            billedPrice: "$49.99",
            billingPeriod: "annually",
            emphasizedPrice: "$4.17",
            emphasizedPeriod: "/month"
        )

        let value = display.makeEmphasizedAttributedString(
            amountFont: .systemFont(ofSize: 18, weight: .bold),
            periodFont: .systemFont(ofSize: 12),
            textColor: .white
        )

        XCTAssertEqual(value.string, "$4.17/month")
        XCTAssertEqual(display.debugPlainText, "$49.99 billed annually; $4.17/month")
    }
}
