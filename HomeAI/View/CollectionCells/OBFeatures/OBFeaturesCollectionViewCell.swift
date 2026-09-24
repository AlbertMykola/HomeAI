import UIKit

class OBFeaturesCollectionViewCell: UICollectionViewCell {

    static let reuseIdentifier = "OBFeaturesCollectionViewCell"

    @IBOutlet weak private var containerView: LiquidGlassView!
    @IBOutlet weak private var featureNameLabel: UILabel!
    @IBOutlet weak private var featureImageView: UIImageView!

    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        clipsToBounds = false
        contentView.clipsToBounds = false
        containerView.clipsToBounds = true
        featureImageView.tintColor = .label
        featureNameLabel.textColor = .label
        applyNeutralAppearance()
        transform = .identity
        alpha = 1
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius: CGFloat = 12
        layer.cornerRadius = radius
        contentView.layer.cornerRadius = radius
        containerView.layer.cornerRadius = radius
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        layer.zPosition = 0
        featureNameLabel.text = nil
        featureImageView.image = nil
        applyNeutralAppearance()
        transform = .identity
        alpha = 1
    }

    func configureStatic(title: String, icon: UIImage) {
        featureNameLabel.text = title
        featureImageView.image = icon.withRenderingMode(.alwaysTemplate)
        applyNeutralAppearance()
    }

    private func applyNeutralAppearance() {
        containerView.backgroundColor = .clear
        containerView.glassStyle = 0
        containerView.glassTintColor = .clear
        containerView.fallbackGradient = true
        containerView.fallbackShadow = true
        containerView.fallbackTintOpacity = 0.14
        containerView.fallbackBlurAlpha = 0.52
    }
}
