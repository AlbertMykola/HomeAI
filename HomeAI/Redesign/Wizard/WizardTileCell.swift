import UIKit

/// Room / building tile (109×112). Selected: lime soft + 2 pt lime border + black check. Layout: Wizard.storyboard prototype.
final class WizardTileCell: DSAdaptiveCollectionViewCell {

    static let reuseID = "WizardTileCell"

    @IBOutlet private weak var tileView: UIView!
    @IBOutlet private weak var iconView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var checkView: UIView!
    @IBOutlet private weak var badgeView: UIView!
    @IBOutlet private weak var badgeLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        badgeLabel.text = "Detected".localized
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconView.image = nil
        iconView.contentMode = .scaleAspectFit
        transform = .identity
        alpha = 1
    }

    func configure(title: String, image: UIImage?) {
        titleLabel.text = title
        iconView.image = image
        accessibilityLabel = title
    }

    func setImage(_ image: UIImage?, fill: Bool) {
        iconView.contentMode = fill ? .scaleAspectFill : .scaleAspectFit
        iconView.layer.cornerRadius = fill ? 8 : 0
        iconView.image = image
    }

    func setDetected(_ detected: Bool) {
        badgeView.isHidden = !detected
    }

    func setSelected(_ selected: Bool, animated: Bool) {
        let changes = {
            self.tileView.backgroundColor = selected ? DS.Color.limeSoft : DS.Color.surface
            self.tileView.layer.borderWidth = selected ? 2 : 0
            self.tileView.layer.borderColor = DS.Color.lime.cgColor
            self.titleLabel.font = DS.Font.geologica(selected ? .semiBold : .medium, self.titleLabel.font.pointSize)
            self.checkView.alpha = selected ? 1 : 0
            self.checkView.transform = selected ? .identity : CGAffineTransform(scaleX: 0.4, y: 0.4)
        }
        accessibilityTraits = selected ? [.button, .selected] : .button
        guard animated, !DS.Motion.reduceMotion else { changes(); return }
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0, animations: changes)
        if selected {
            tileView.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0) {
                self.tileView.transform = .identity
            }
        }
    }
}
