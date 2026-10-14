import UIKit

/// PR1 project card: cover (current version) with Vn pill, title, "3 versions · Today";
/// select mode adds a check circle and a 3 pt lime ring. Layout: ProjectCell.xib.
final class ProjectCell: UICollectionViewCell {
    static let reuseID = "ProjectCell"

    @IBOutlet private(set) weak var coverImageView: UIImageView!
    @IBOutlet private weak var selectionRingView: UIView!
    @IBOutlet private weak var versionLabel: UILabel!
    @IBOutlet private weak var checkView: UIView!
    @IBOutlet private weak var checkIconView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!

    private var path: String?

    override func prepareForReuse() {
        super.prepareForReuse()
        coverImageView.image = nil
        path = nil
        transform = .identity
    }

    func configure(project: DesignProject, versions: [ImageDoc], selecting: Bool, selected: Bool) {
        guard let doc = versions.last else { return }
        let title = ProjectStore.shared.displayTitle(for: project, versions: versions)
        titleLabel.text = title
        subtitleLabel.text = DesignProject.versionsLine(count: versions.count, date: project.updatedAt)
        versionLabel.text = "V\(versions.count)"
        isAccessibilityElement = true
        accessibilityLabel = "\(title), \(subtitleLabel.text ?? "")"
        let p = HistoryDocOpener.thumbnailPath(for: doc)
        path = p
        ThumbnailLoader.load(path: p, pointSize: CGSize(width: 170, height: 200)) { [weak self] image in
            guard let self, self.path == p else { return }
            self.coverImageView.image = image
        }
        setSelecting(selecting, animated: false)
        setChosen(selected, animated: false)
    }

    /// Check circles pop in (0.3 → 1, ease-out-back 400 ms) when select mode starts.
    func setSelecting(_ selecting: Bool, animated: Bool, delay: TimeInterval = 0) {
        accessibilityTraits = selecting ? [.button] : .button
        guard animated, !DS.Motion.reduceMotion else {
            checkView.isHidden = !selecting
            checkView.alpha = 1
            checkView.transform = .identity
            return
        }
        if selecting {
            checkView.isHidden = false
            checkView.alpha = 0
            checkView.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
            DS.Motion.animate(0.15, delay: delay) { self.checkView.alpha = 1 }
            DS.Motion.animate(0.4, delay: delay, timing: DS.Motion.easeOutBack) { self.checkView.transform = .identity }
        } else {
            UIView.animate(withDuration: 0.2, animations: {
                self.checkView.alpha = 0
                self.checkView.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
            }, completion: { _ in
                self.checkView.isHidden = true
                self.checkView.transform = .identity
                self.checkView.alpha = 1
            })
        }
    }

    func setChosen(_ chosen: Bool, animated: Bool) {
        let changes = {
            self.selectionRingView.isHidden = !chosen
            self.checkView.backgroundColor = chosen ? DS.Color.lime : UIColor.white.withAlphaComponent(0.35)
            self.checkView.layer.borderWidth = chosen ? 1 : 2
            self.checkIconView.isHidden = !chosen
        }
        accessibilityTraits = chosen ? [.button, .selected] : .button
        changes()
        if animated, chosen, !DS.Motion.reduceMotion { InspirationCardCell.pop(checkView) }
    }
}
