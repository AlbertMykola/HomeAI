import UIKit

struct PaywallPriceDisplay: Equatable {
    let billedPrice: String
    let billingPeriod: String
    let emphasizedPrice: String
    let emphasizedPeriod: String

    var billingSubtitle: String {
        String(format: "%@ billed %@".localized, billedPrice, billingPeriod)
    }

    func makeEmphasizedAttributedString(
        amountFont: UIFont,
        periodFont: UIFont,
        textColor: UIColor
    ) -> NSAttributedString {
        let result = NSMutableAttributedString(
            string: emphasizedPrice,
            attributes: [
                .font: amountFont,
                .foregroundColor: textColor
            ]
        )
        result.append(NSAttributedString(
            string: emphasizedPeriod,
            attributes: [
                .font: periodFont,
                .foregroundColor: textColor.withAlphaComponent(0.5)
            ]
        ))
        return result
    }

    var debugPlainText: String {
        "\(billedPrice) billed \(billingPeriod); \(emphasizedPrice)\(emphasizedPeriod)"
    }
}
