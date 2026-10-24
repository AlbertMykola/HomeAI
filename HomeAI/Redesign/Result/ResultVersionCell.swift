import UIKit

/// Versions strip item (Original / V1… / Again), 56 pt thumb r16. Layout: Result.storyboard prototype.
final class ResultVersionCell: UICollectionViewCell {

    static let reuseID = "ResultVersionCell"

    @IBOutlet private weak var thumbImageView: UIImageView!
    @IBOutlet private weak var ringView: UIView!
    @IBOutlet private weak var againIconView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!

    private var path: String?
    private var referenceLayout: DSReferenceLayout!
    /// Set by Result: the panel's scale (larger on a wide Duo panel). Falls back to the window scale.
    var panelScale: CGFloat?
    private var referenceScale: CGFloat { panelScale ?? OnboardingLayout(size: window?.bounds.size ?? UIScreen.main.bounds.size).scale }

    override func awakeFromNib() {
        super.awakeFromNib()
        referenceLayout = DSReferenceLayout(root: contentView, prefix: "resultVersion.")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        referenceLayout?.apply(scale: referenceScale)
        againIconView.transform = CGAffineTransform(scaleX: referenceScale, y: referenceScale)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbImageView.image = nil
        path = nil
    }

    func configure(title: String, path: String, current: Bool) {
        titleLabel.text = title
        titleLabel.font = DS.Font.geologica(current ? .semiBold : .regular, 11 * referenceScale)
        titleLabel.textColor = current ? DS.Color.textPrimary : DS.Color.textTertiary
        ringView.isHidden = !current
        ringView.layer.borderColor = DS.Color.textPrimary.resolvedColor(with: traitCollection).cgColor
        ringView.layer.borderWidth = 2.5
        againIconView.isHidden = true
        thumbImageView.backgroundColor = DS.Color.surface
        self.path = path
        ThumbnailLoader.load(path: path, pointSize: CGSize(width: 56 * referenceScale, height: 56 * referenceScale)) { [weak self] image in
            guard let self, self.path == path else { return }
            self.thumbImageView.image = image
        }
        accessibilityLabel = title
        accessibilityTraits = current ? [.button, .selected] : .button
        isAccessibilityElement = true
    }

    func configureAgain(title: String) {
        titleLabel.text = title
        titleLabel.font = DS.Font.geologica(.regular, 11 * referenceScale)
        titleLabel.textColor = DS.Color.textTertiary
        thumbImageView.image = nil
        thumbImageView.backgroundColor = DS.Color.card
        ringView.isHidden = false
        ringView.layer.borderColor = UIColor(red: 0.82, green: 0.82, blue: 0.84, alpha: 1).cgColor
        ringView.layer.borderWidth = 1.5
        againIconView.isHidden = false
        accessibilityLabel = "Generate again with the same settings".localized
        accessibilityTraits = .button
        isAccessibilityElement = true
    }
}
