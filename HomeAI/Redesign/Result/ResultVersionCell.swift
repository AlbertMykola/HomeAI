import UIKit

/// Versions strip item (Original / V1… / Again), 56 pt thumb r16. Layout: ResultVersionCell.xib.
final class ResultVersionCell: UICollectionViewCell {

    static let reuseID = "ResultVersionCell"

    @IBOutlet private weak var thumbImageView: UIImageView!
    @IBOutlet private weak var ringView: UIView!
    @IBOutlet private weak var againIconView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!

    private var path: String?

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbImageView.image = nil
        path = nil
    }

    func configure(title: String, path: String, current: Bool) {
        titleLabel.text = title
        titleLabel.font = DS.Font.geologica(current ? .semiBold : .regular, 11)
        titleLabel.textColor = current ? DS.Color.textPrimary : DS.Color.textTertiary
        ringView.isHidden = !current
        ringView.layer.borderColor = UIColor.black.cgColor
        ringView.layer.borderWidth = 2.5
        againIconView.isHidden = true
        thumbImageView.backgroundColor = DS.Color.surface
        self.path = path
        ThumbnailLoader.load(path: path, pointSize: CGSize(width: 56, height: 56)) { [weak self] image in
            guard let self, self.path == path else { return }
            self.thumbImageView.image = image
        }
        accessibilityLabel = title
        accessibilityTraits = current ? [.button, .selected] : .button
        isAccessibilityElement = true
    }

    func configureAgain(title: String) {
        titleLabel.text = title
        titleLabel.font = DS.Font.geologica(.regular, 11)
        titleLabel.textColor = DS.Color.textTertiary
        thumbImageView.image = nil
        thumbImageView.backgroundColor = .white
        ringView.isHidden = false
        ringView.layer.borderColor = UIColor(red: 0.82, green: 0.82, blue: 0.84, alpha: 1).cgColor
        ringView.layer.borderWidth = 1.5
        againIconView.isHidden = false
        accessibilityLabel = "Generate again with the same settings".localized
        accessibilityTraits = .button
        isAccessibilityElement = true
    }
}
