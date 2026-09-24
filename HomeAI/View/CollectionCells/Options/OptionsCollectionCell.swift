import UIKit

private struct Defaults {
    struct Gradient {
        static let start = UIColor.white.withAlphaComponent(0)
        static let mid = UIColor(red: 235 / 255, green: 255 / 255, blue: 203 / 255, alpha: 0.99)
        static let end = UIColor(red: 236 / 255, green: 255 / 255, blue: 229 / 255, alpha: 1)
    }
    struct Shadow {
        static let color = UIColor.black
        static let opacity: Float = 0.35
        static let radius: CGFloat = 14
        static let offset = CGSize(width: 0, height: 6)
        /// Відступ карти від країв клітинки (5pt з XIB)
        static let cardInset: CGFloat = 5
        static let cardCornerRadius: CGFloat = 17
    }
}

final class OptionsCollectionCell: UICollectionViewCell {

    static let reuseIdentifier = "OptionsCollectionCell"

    @IBOutlet weak private var arrowRightImageView: UIImageView!
    @IBOutlet weak private var rightImageView: UIImageView!
    @IBOutlet weak private var iconImageView: UIImageView!
    @IBOutlet weak private var descriptionLabel: UILabel!
    @IBOutlet weak private var headlineLabel: UILabel!
    
    @IBOutlet weak private var bottomArrowContainerView: LiquidGlassView!
    @IBOutlet weak private var arrowContainerView: LiquidGlassView!
    @IBOutlet weak private var gradientContainerView: UIView!

    @IBOutlet private var leftIconContstaints: [NSLayoutConstraint]!
    @IBOutlet weak private var rightImageLeftConstraint: NSLayoutConstraint!

    @IBOutlet var yConstraintsCollection: [NSLayoutConstraint]!
    @IBOutlet var xConstraintsCollection: [NSLayoutConstraint]!
    
    /// Оригінальні значення констрейнтів із XIB — зберігаємо один раз.
    private var originalLeftIconConstants: [CGFloat] = []
    private var originalRightImageLeftConstant: CGFloat = 0

    override func awakeFromNib() {
        super.awakeFromNib()
        
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        clipsToBounds = false
        layer.shadowColor = Defaults.Shadow.color.cgColor
        layer.shadowOpacity = Defaults.Shadow.opacity
        layer.shadowRadius = Defaults.Shadow.radius
        layer.shadowOffset = Defaults.Shadow.offset
        
        yConstraintsCollection.forEach { $0.scaleConstant() }
        xConstraintsCollection.forEach { $0.scaleConstantByWidth() }

        originalLeftIconConstants = leftIconContstaints.map { $0.constant }
        originalRightImageLeftConstant = rightImageLeftConstraint.constant
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        rightImageView.image = nil
        iconImageView.image = nil
        resetConstraints()
    }

    // MARK: - Private helpers
    private func resetConstraints() {
        zip(leftIconContstaints, originalLeftIconConstants).forEach { $0.constant = $1 }
        rightImageLeftConstraint.constant = originalRightImageLeftConstant
        iconImageView.isHidden = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let cardRect = bounds.insetBy(dx: Defaults.Shadow.cardInset, dy: Defaults.Shadow.cardInset)
        layer.shadowPath = UIBezierPath(roundedRect: cardRect, cornerRadius: Defaults.Shadow.cardCornerRadius).cgPath

        gradientContainerView.layoutIfNeeded()
        arrowContainerView.cornerRadius = arrowContainerView.frame.height / 2
        arrowContainerView.cornerRadiusValue = arrowContainerView.frame.height / 2
        bottomArrowContainerView.cornerRadiusValue = bottomArrowContainerView.frame.height / 2
        let b = gradientContainerView.bounds
        guard b.width > 1, b.height > 1 else { return }

        gradientContainerView.backgroundColor = .clear
        gradientContainerView.setGradient(
            stops: [
                .init(percent: 0,   color: Defaults.Gradient.end),
                .init(percent: 73,  color: Defaults.Gradient.mid),
                .init(percent: 100, color: Defaults.Gradient.start)
            ],
            direction: .horizontal
        )
        gradientContainerView.updateGradientFrame()
    }

    func config(model: OptionsCollectionModel) {
        resetConstraints()
        headlineLabel.text = model.title
        descriptionLabel.text = model.description
        iconImageView.image = model.icon
        rightImageView.image = model.heroImage
    }

    func configHideIcon(model: OptionsCollectionModel) {
        headlineLabel.text = model.title
        descriptionLabel.text = model.description
        iconImageView.isHidden = true
        leftIconContstaints.forEach { $0.constant = 0 }
        rightImageLeftConstraint.constant = originalRightImageLeftConstant + 50
        rightImageView.image = model.heroImage
        arrowContainerView.isHidden = true
        arrowRightImageView.isHidden = true
        bottomArrowContainerView.isHidden = false
    }
}
