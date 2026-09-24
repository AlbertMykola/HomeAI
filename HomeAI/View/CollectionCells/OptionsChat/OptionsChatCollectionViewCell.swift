import UIKit

private struct Defaults {
    struct Colors {
        static let startColor = UIColor(red: 77 / 255, green: 163 / 255, blue: 255 / 255, alpha: 1)
        static let middleColor = UIColor(red: 79 / 255, green: 109 / 255, blue: 255 / 255, alpha: 1)
        static let endColor = UIColor(red: 139 / 255, green: 92 / 255, blue: 255 / 255, alpha: 1)
    }

    struct Shadow {
        static let color = UIColor.black
        static let opacity: Float = 0.35
        static let radius: CGFloat = 14
        static let offset = CGSize(width: 0, height: 6)
        static let cardInsetH: CGFloat = 5
        static let cardInsetTop: CGFloat = 5
        static let cardInsetBottom: CGFloat = 10
        static let cardCornerRadius: CGFloat = 10
    }

    struct Text {
        static let headline = "Chat with AI-Assistant".localized
        static let description = "Get personalized renovation advice and inspiration".localized
    }
}

final class OptionsChatCollectionViewCell: UICollectionViewCell {

    static let reuseIdentifier = "OptionsChatCollectionViewCell"

    @IBOutlet weak private var descriptionLabel: UILabel!
    @IBOutlet weak private var headlineLabel: UILabel!
    
    @IBOutlet private var xConstraintsCollection: [NSLayoutConstraint]!
    
    @IBOutlet private var yConstraintsCollection: [NSLayoutConstraint]!
    @IBOutlet weak private var gradientContainerView: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        clipsToBounds = false
        layer.shadowColor = Defaults.Shadow.color.cgColor
        layer.shadowOpacity = Defaults.Shadow.opacity
        layer.shadowRadius = Defaults.Shadow.radius
        layer.shadowOffset = Defaults.Shadow.offset
        headlineLabel.text = Defaults.Text.headline
        descriptionLabel.text = Defaults.Text.description
        xConstraintsCollection.forEach { $0.scaleConstantByWidth() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let cardRect = CGRect(
            x: Defaults.Shadow.cardInsetH,
            y: Defaults.Shadow.cardInsetTop,
            width: bounds.width - Defaults.Shadow.cardInsetH * 2,
            height: bounds.height - Defaults.Shadow.cardInsetTop - Defaults.Shadow.cardInsetBottom
        )
        layer.shadowPath = UIBezierPath(roundedRect: cardRect, cornerRadius: Defaults.Shadow.cardCornerRadius).cgPath

        gradientContainerView.layoutIfNeeded()
        
        let b = gradientContainerView.bounds
        guard b.width > 1, b.height > 1 else { return }

        gradientContainerView.backgroundColor = .clear
        gradientContainerView.setGradient(
            stops: [
                .init(percent: 0,   color: Defaults.Colors.startColor),
                .init(percent: 54,  color: Defaults.Colors.middleColor),
                .init(percent: 100, color: Defaults.Colors.endColor)
            ],
            direction: .horizontal
        )
        gradientContainerView.updateGradientFrame()
    }
}
