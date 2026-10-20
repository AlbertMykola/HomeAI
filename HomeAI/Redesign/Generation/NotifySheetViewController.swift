import UIKit
import UserNotifications

/// A/05 · G2 "Get one ping when it's ready?" — push pre-prompt (asked at most twice).
/// Layout: Generation.storyboard.
final class NotifySheetViewController: UIViewController {

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var previewView: UIView!
    @IBOutlet private weak var nowLabel: UILabel!
    @IBOutlet private weak var messageLabel: UILabel!
    @IBOutlet private weak var thumbImageView: UIImageView!
    @IBOutlet private weak var turnOnButton: DSPrimaryButton!
    @IBOutlet private weak var turnOnLabel: UILabel!
    @IBOutlet private weak var bellIconView: UIImageView!
    @IBOutlet private weak var notNowButton: UIButton!

    private static let shownCountKey = "redesign_push_preprompt_count"
    private var photo: UIImage?
    private var styleTitle: String?
    private var onDone: (() -> Void)?
    private let amplitude = AmplitudeService.shared

    static func present(from presenter: UIViewController, photo: UIImage?, styleTitle: String?, onDone: @escaping () -> Void) {
        // The catalog must show the preprompt in every locale without spending the user's two views.
        #if DEBUG
        let fixture = AppQA.enabled
        #else
        let fixture = false
        #endif
        if !fixture {
            let shown = UserDefaults.standard.integer(forKey: shownCountKey)
            guard shown < 2 else {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
                    DispatchQueue.main.async(execute: onDone)
                }
                return
            }
            UserDefaults.standard.set(shown + 1, forKey: shownCountKey)
        }
        let vc = AppStoryboard.instantiate(NotifySheetViewController.self)
        vc.photo = photo
        vc.styleTitle = styleTitle
        vc.onDone = onDone
        DSSheet.present(vc, from: presenter, height: 400)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "Get one ping when it's ready?".localized
        subtitleLabel.text = "We'll send a single notification for this design. No spam, ever.".localized
        nowLabel.text = "now".localized
        messageLabel.text = styleTitle.map { String(format: "Your %@ design is ready ✨".localized, $0) }
            ?? "Your design is ready ✨".localized
        thumbImageView.image = photo
        turnOnLabel.text = "Turn on notifications".localized
        notNowButton.setTitle("Not now".localized, for: .normal)
        amplitude.logRedesignEvent("push_preprompt_view")
        previewView.alpha = 0
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DS.Motion.enter(previewView, delay: 0.1, dy: -14, scale: 0.94, duration: 0.35)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let bell = self?.bellIconView, !DS.Motion.reduceMotion else { return }
            let ring = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            let a = CGFloat.pi * 16 / 180
            ring.values = [0, a, -a, a * 0.5, -a * 0.5, 0]
            ring.duration = 0.45
            bell.layer.add(ring, forKey: "ring")
        }
    }

    @IBAction private func didTapTurnOn(_ sender: Any) {
        amplitude.logRedesignEvent("push_preprompt_accept")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                GenerationCenter.shared.wantsReadyNotification = granted
                let onDone = self.onDone
                self.dismiss(animated: true) { onDone?() }
            }
        }
    }

    @IBAction private func didTapNotNow(_ sender: Any) {
        amplitude.logRedesignEvent("push_preprompt_dismiss")
        dismiss(animated: true)
    }
}
