import UIKit

/// P2 · "You've used your free designs" sheet shown on Generate with 0 credits.
/// Layout: Wizard.storyboard.
final class OutOfCreditsSheetViewController: UIViewController {

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var photoImageView: UIImageView!
    @IBOutlet private weak var lockedView: UIView!
    @IBOutlet private weak var seeProLabel: UILabel!
    @IBOutlet private weak var seeProButton: DSPrimaryButton!
    @IBOutlet private weak var notNowButton: UIButton!

    private var photo: UIImage?
    private var onUnlocked: (() -> Void)?

    static func present(from presenter: UIViewController, photo: UIImage?, onUnlocked: @escaping () -> Void) {
        let vc = AppStoryboard.instantiate(OutOfCreditsSheetViewController.self)
        vc.photo = photo
        vc.onUnlocked = onUnlocked
        DSSheet.present(vc, from: presenter, height: 470)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "You've used your free designs".localized
        subtitleLabel.text = "Go Pro to keep redesigning. Your photo and settings are saved.".localized
        seeProLabel.text = "See Pro plans".localized
        notNowButton.setTitle("Not now".localized, for: .normal)
        photoImageView.image = photo
    }

    @IBAction private func didTapSeePro(_ sender: Any) {
        let onUnlocked = self.onUnlocked
        dismiss(animated: true) {
            NavigationManager.shared.showPremium(placement: Constants.Keys.reachedLimit, origin: .inApp) {
                onUnlocked?()
            }
        }
    }

    @IBAction private func didTapNotNow(_ sender: Any) {
        dismiss(animated: true)
    }
}
