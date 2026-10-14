import UIKit

/// I1 mosaic card: photo (r20), style tag pill, glass bookmark. Layout: InspirationCardCell.xib.
final class InspirationCardCell: UICollectionViewCell {
    static let reuseID = "InspirationCardCell"

    @IBOutlet private(set) weak var photoImageView: UIImageView!
    @IBOutlet private weak var tagView: UIView!
    @IBOutlet private weak var tagLabel: UILabel!
    @IBOutlet private weak var bookmarkControl: DSPressableControl!

    var onBookmark: (() -> Void)?
    /// The remote file is missing → the feed drops this idea instead of showing a grey card.
    var onImageFailed: (() -> Void)?
    private var imagePath: String?

    override func awakeFromNib() {
        super.awakeFromNib()
        isAccessibilityElement = false
        photoImageView.isAccessibilityElement = true
        photoImageView.accessibilityTraits = .button
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        photoImageView.image = nil
        onBookmark = nil
        onImageFailed = nil
    }

    func configure(idea: InspirationIdea, saved: Bool) {
        tagLabel.text = idea.style.localized
        photoImageView.accessibilityLabel = idea.title
        setSaved(saved, animated: false)
        imagePath = idea.image
        CatalogImage.load(idea.image) { [weak self] image in
            guard let self, self.imagePath == idea.image else { return }
            if image == nil { self.onImageFailed?() }
            let first = self.photoImageView.image == nil
            self.photoImageView.image = image
            if first, image != nil {
                self.photoImageView.alpha = 0
                UIView.animate(withDuration: 0.25) { self.photoImageView.alpha = 1 }
            }
        }
    }

    var image: UIImage? { photoImageView.image }

    /// Lime fill + pop 0.8 → 1.15 → 1.
    func setSaved(_ saved: Bool, animated: Bool) {
        let icon = bookmarkControl.subviews.compactMap { $0 as? UIImageView }.first
        icon?.image = UIImage(systemName: saved ? "bookmark.fill" : "bookmark")
        icon?.tintColor = saved ? .black : .white
        bookmarkControl.backgroundColor = saved ? DS.Color.lime : UIColor.black.withAlphaComponent(0.3)
        bookmarkControl.accessibilityLabel = saved ? "Remove from Ideas".localized : "Save idea".localized
        guard animated, !DS.Motion.reduceMotion else { return }
        Self.pop(bookmarkControl)
    }

    static func pop(_ view: UIView) {
        view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        UIView.animateKeyframes(withDuration: 0.35, delay: 0) {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.55) {
                view.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.55, relativeDuration: 0.45) { view.transform = .identity }
        }
    }

    @IBAction private func didTapBookmark(_ sender: Any) {
        onBookmark?()
    }
}
