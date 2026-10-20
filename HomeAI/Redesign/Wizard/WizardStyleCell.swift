import UIKit

/// Style tile 109×136 r22 + title. Layout: Wizard.storyboard prototype.
final class WizardStyleCell: DSAdaptiveCollectionViewCell {

    static let reuseID = "WizardStyleCell"

    @IBOutlet private weak var tileView: UIView!
    @IBOutlet private weak var previewImageView: UIImageView!
    @IBOutlet private weak var popularBadge: UIView!
    @IBOutlet private weak var customStack: UIStackView!
    @IBOutlet private weak var customIconBox: UIView!
    @IBOutlet private weak var describeLabel: UILabel!
    @IBOutlet private weak var checkView: UIView!
    @IBOutlet private weak var titleLabel: UILabel!

    private var imagePath: String?
    var previewImage: UIImage? { previewImageView.image }

    override func awakeFromNib() {
        super.awakeFromNib()
        describeLabel.text = "Describe".localized
        (popularBadge.subviews.first as? UILabel)?.text = "Popular".localized
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        previewImageView.image = nil
        imagePath = nil
        transform = .identity
        alpha = 1
    }

    func configure(title: String, imagePath: String?, popular: Bool, chosen: Bool) {
        titleLabel.text = title
        accessibilityLabel = title
        customStack.isHidden = true
        tileView.backgroundColor = DS.Color.surface
        popularBadge.isHidden = !popular
        self.imagePath = imagePath
        if let imagePath {
            CatalogImage.load(imagePath) { [weak self] image in
                guard let self, self.imagePath == imagePath else { return }
                self.previewImageView.image = image
            }
        }
        setChosen(chosen, animated: false)
    }

    func configureCustom(title: String, chosen: Bool) {
        titleLabel.text = title
        accessibilityLabel = "Custom style — describe in your own words".localized
        customStack.isHidden = false
        popularBadge.isHidden = true
        previewImageView.image = nil
        tileView.backgroundColor = UIColor(named: "dsInk")
        setChosen(chosen, animated: false)
    }

    func setChosen(_ chosen: Bool, animated: Bool) {
        let changes = {
            self.tileView.layer.borderWidth = chosen ? 3 : 0
            self.tileView.layer.borderColor = DS.Color.lime.cgColor
            self.titleLabel.font = DS.Font.geologica(chosen ? .semiBold : .medium, self.titleLabel.font.pointSize)
            self.checkView.alpha = chosen ? 1 : 0
            self.checkView.transform = chosen ? .identity : CGAffineTransform(scaleX: 0.4, y: 0.4)
        }
        accessibilityTraits = chosen ? [.button, .selected] : .button
        guard animated, !DS.Motion.reduceMotion else { changes(); return }
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0, animations: changes)
    }

    func spinCustomIcon() {
        guard !customStack.isHidden, !DS.Motion.reduceMotion else { return }
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = Double.pi
        spin.duration = 0.5
        spin.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        customIconBox.layer.add(spin, forKey: "spin")
    }
}
