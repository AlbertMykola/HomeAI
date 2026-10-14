import UIKit

/// Recent project card on Home (150×214). Layout: HomeProjectCell.xib.
final class HomeProjectCell: UICollectionViewCell {

    static let reuseID = "HomeProjectCell"

    @IBOutlet private weak var thumbImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!

    private var representedPath: String?
    var thumbImage: UIImage? { thumbImageView.image }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbImageView.image = nil
        representedPath = nil
        transform = .identity
    }

    func configure(with doc: ImageDoc) {
        titleLabel.text = doc.projectTitle
        subtitleLabel.text = String(format: "%d version · %@".localized, 1, doc.createdAt.projectRelativeString)
        isAccessibilityElement = true
        accessibilityLabel = "\(doc.projectTitle), \(subtitleLabel.text ?? "")"
        accessibilityTraits = .button

        let path = HistoryDocOpener.thumbnailPath(for: doc)
        representedPath = path
        ThumbnailLoader.load(path: path, pointSize: CGSize(width: 150, height: 160)) { [weak self] image in
            guard let self, self.representedPath == path else { return }
            self.thumbImageView.image = image
        }
    }
}
