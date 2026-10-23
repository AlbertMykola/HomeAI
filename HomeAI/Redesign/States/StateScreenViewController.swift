import UIKit
import AVFoundation
import SafariServices

/// A/12 full-screen states. Layout: States.storyboard.
/// Motion (all four): icon pops 0.3 → 1 (ease-out-back, 0.25 s) and wiggles ±12° (0.75 s);
/// text and buttons 60 ms apart; the primary button shimmers at 1.6 s.
final class StateScreenViewController: UIViewController {

    enum Kind {
        /// Moderation rejected the request (G3 frame, shield icon). Credit isn't spent.
        case contentBlocked(photo: UIImage?, policyID: String)
        /// Generation / assistant without network; returns by itself when the network is back.
        case offline
        /// Camera denied / restricted (shown instead of the viewfinder, always dark).
        case cameraOff
        /// Remote config: this version is below the minimum supported one. No way to close.
        case forceUpdate
    }

    @IBOutlet private weak var backButton: DSPressableControl!
    @IBOutlet private weak var photoContainer: UIView!
    @IBOutlet private weak var photoImageView: UIImageView!
    @IBOutlet private weak var contentStack: UIStackView!
    @IBOutlet private var contentBelowPhotoConstraint: NSLayoutConstraint!
    @IBOutlet private weak var iconBoxView: UIView!
    @IBOutlet private weak var iconImageView: UIImageView!
    @IBOutlet private weak var iconSizeConstraint: NSLayoutConstraint!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var bodyLabel: UILabel!
    @IBOutlet private weak var captionLabel: UILabel!
    @IBOutlet private weak var newsCardView: UIView!
    @IBOutlet private weak var newsTitleLabel: UILabel!
    @IBOutlet private weak var newsBodyLabel: UILabel!
    @IBOutlet private weak var actionsStack: UIStackView!
    @IBOutlet private weak var primaryButton: DSPrimaryButton!
    @IBOutlet private weak var primaryLabel: UILabel!
    @IBOutlet private weak var primaryIconView: UIImageView!
    @IBOutlet private weak var primarySpinner: UIActivityIndicatorView!
    @IBOutlet private weak var secondaryButton: DSPressableControl!
    @IBOutlet private weak var secondaryLabel: UILabel!

    private var kind: Kind = .offline
    /// contentBlocked: Edit request · offline: back online / Try again · cameraOff: camera now allowed.
    private var onPrimary: (() -> Void)?
    /// contentBlocked: — · cameraOff: Choose from library.
    private var onSecondary: (() -> Void)?
    private var didRunEntrance = false

    static func make(_ kind: Kind, onPrimary: (() -> Void)? = nil, onSecondary: (() -> Void)? = nil) -> StateScreenViewController {
        let vc = AppStoryboard.instantiate(StateScreenViewController.self)
        vc.kind = kind
        vc.onPrimary = onPrimary
        vc.onSecondary = onSecondary
        vc.modalPresentationStyle = .fullScreen
        if case .forceUpdate = kind { vc.isModalInPresentation = true }
        if case .cameraOff = kind { vc.overrideUserInterfaceStyle = .dark }
        return vc
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .default }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        dsApplyWideColumn()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
        NotificationCenter.default.addObserver(self, selector: #selector(networkChanged), name: .networkStatusDidChange,
                                               object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appBecameActive),
                                               name: UIApplication.didBecomeActiveNotification, object: nil)
        [iconBoxView, titleLabel, bodyLabel, captionLabel, newsCardView, primaryButton, secondaryButton].forEach { $0?.alpha = 0 }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didRunEntrance else { return }
        didRunEntrance = true
        runEntrance()
    }

    private func configure() {
        photoContainer.isHidden = true
        contentBelowPhotoConstraint.isActive = false
        newsCardView.superview?.isHidden = true
        captionLabel.isHidden = true
        secondaryButton.isHidden = true
        backButton.isHidden = false
        iconBoxView.backgroundColor = DS.Color.surface
        iconImageView.tintColor = DS.Color.textPrimary
        iconSizeConstraint.constant = 120
        switch kind {
        case .contentBlocked(let photo, let policyID):
            if let photo {
                photoImageView.image = photo
                photoContainer.isHidden = false
                contentBelowPhotoConstraint.isActive = true
            }
            iconSizeConstraint.constant = 64
            iconBoxView.backgroundColor = UIColor(named: "dsInk")
            iconImageView.tintColor = .white
            iconImageView.image = UIImage(systemName: "checkmark.shield")
            titleLabel.text = "We can't create this one".localized
            bodyLabel.text = "This request goes against our content rules. Your credit is back.".localized
            captionLabel.text = String(format: "Policy · ID %@".localized, policyID)
            captionLabel.isHidden = false
            primaryLabel.text = "Edit request".localized
            primaryIconView.image = UIImage(systemName: "arrow.clockwise")
            secondaryLabel.text = "Content rules".localized
            secondaryButton.isHidden = false
            AmplitudeService.shared.logRedesignEvent("content_blocked", properties: ["policy": policyID])
        case .offline:
            iconImageView.image = UIImage(systemName: "wifi.slash")
            titleLabel.text = "You're offline".localized
            bodyLabel.text = "Designs are created in the cloud. Connect to Wi-Fi or mobile data to continue.".localized
            captionLabel.text = "Your projects are saved on this iPhone.".localized
            captionLabel.isHidden = false
            primaryLabel.text = "Try again".localized
            primaryIconView.image = UIImage(systemName: "arrow.clockwise")
        case .cameraOff:
            iconImageView.image = UIImage(systemName: "camera")
            titleLabel.text = "Camera access is off".localized
            bodyLabel.text = "Allow camera in Settings to take room photos. You can still pick one from your library.".localized
            primaryLabel.text = "Open Settings".localized
            primaryIconView.image = UIImage(systemName: "slider.horizontal.3")
            secondaryLabel.text = "Choose from library".localized
            secondaryButton.isHidden = false
            secondaryButton.dsBorderColor = UIColor.white.withAlphaComponent(0.18)
            secondaryButton.layer.borderWidth = 1
            secondaryButton.backgroundColor = UIColor(hex: "1C1C1E")
            (backButton.subviews.compactMap { $0 as? UIImageView }.first)?.image = UIImage(systemName: "xmark")
        case .forceUpdate:
            backButton.isHidden = true
            iconSizeConstraint.constant = 96
            iconBoxView.backgroundColor = DS.Color.lime
            iconBoxView.layer.cornerRadius = 26
            (iconBoxView as? DSView)?.pill = false
            iconImageView.tintColor = .black
            iconImageView.image = UIImage(systemName: "house")
            titleLabel.text = "Time to update".localized
            bodyLabel.text = String(format: "This version of %@ is no longer supported. Update to keep designing. Your projects stay safe.".localized,
                                    Constants.Text.brand)
            newsTitleLabel.text = "What's new".localized
            newsBodyLabel.text = ["Paint with real colors", "Faster generations", "New AI designer"]
                .map { "• " + $0.localized }.joined(separator: "\n")
            newsCardView.superview?.isHidden = false
            primaryLabel.text = "Update now".localized
            primaryIconView.image = UIImage(systemName: "arrow.down.to.line")
        }
    }

    private func runEntrance() {
        let m = DS.Motion.self
        if !photoContainer.isHidden { m.enter(photoContainer, delay: 0, scale: 0.94) }
        if !DS.Motion.reduceMotion {
            iconBoxView.alpha = 0
            iconBoxView.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
            m.animate(0.25, delay: 0.1, timing: m.easeOutBack, {
                self.iconBoxView.alpha = 1
                self.iconBoxView.transform = .identity
            }, completion: { [weak self] in
                let wiggle = CAKeyframeAnimation(keyPath: "transform.rotation.z")
                let a = CGFloat.pi / 15
                wiggle.values = [0, a, -a, a / 2, 0]
                wiggle.duration = 0.75
                self?.iconBoxView.layer.add(wiggle, forKey: "wiggle")
            })
        } else {
            iconBoxView.alpha = 1
        }
        [titleLabel, bodyLabel, captionLabel, newsCardView, primaryButton, secondaryButton].enumerated().forEach {
            m.enter($1, delay: 0.3 + 0.06 * Double($0), dy: 12)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in self?.primaryButton.runShimmer() }
        UIAccessibility.post(notification: .screenChanged, argument: titleLabel)
    }

    // MARK: Actions

    @IBAction private func didTapBack(_ sender: Any) {
        dismiss(animated: true)
    }

    @IBAction private func didTapPrimary(_ sender: Any) {
        switch kind {
        case .contentBlocked:
            let onPrimary = self.onPrimary
            dismiss(animated: true) { onPrimary?() }
        case .offline:
            // Manual check with a spinner in the button; the screen also closes by itself when online.
            primaryLabel.alpha = 0
            primaryIconView.alpha = 0
            primarySpinner.startAnimating()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
                guard let self else { return }
                self.primarySpinner.stopAnimating()
                self.primaryLabel.alpha = 1
                self.primaryIconView.alpha = 1
                if NetworkMonitor.shared.isOnline { self.closeAndResume() } else { DS.Haptic.warning() }
            }
        case .cameraOff:
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        case .forceUpdate:
            if let url = URL(string: "itms-apps://apps.apple.com/app/id\(Constants.Keys.appleId)") { UIApplication.shared.open(url) }
        }
    }

    @IBAction private func didTapSecondary(_ sender: Any) {
        switch kind {
        case .contentBlocked:
            guard let url = URL(string: Constants.API.terms) else { return }
            present(SFSafariViewController(url: url), animated: true)
        case .cameraOff:
            let onSecondary = self.onSecondary
            dismiss(animated: true) { onSecondary?() }
        default: break
        }
    }

    @objc private func networkChanged() {
        guard case .offline = kind, NetworkMonitor.shared.isOnline else { return }
        closeAndResume()
    }

    /// Back from Settings with the camera allowed → open the camera right away.
    @objc private func appBecameActive() {
        guard case .cameraOff = kind, AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        let onPrimary = self.onPrimary
        dismiss(animated: true) { onPrimary?() }
    }

    private func closeAndResume() {
        DS.Haptic.success()
        let onPrimary = self.onPrimary
        dismiss(animated: true) { onPrimary?() }
    }
}

/// Shows A/12 Offline (full screen) where nothing works without network; runs `action` now or once back online.
enum OfflineGate {
    static func run(from presenter: UIViewController, _ action: @escaping () -> Void) {
        guard !NetworkMonitor.shared.isOnline else { return action() }
        DS.Haptic.warning()
        presenter.present(StateScreenViewController.make(.offline, onPrimary: action), animated: true)
    }
}

/// A/12 Force update: remote config `minSupportedVersion` above this build → full-screen, non-dismissable screen.
enum ForceUpdate {
    private static var isShown = false

    static func presentIfNeeded(_ config: WorkerAppConfig, over root: UIViewController?) {
        var config = config
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-forceUpdate") { config.minSupportedVersion = "99.0" }
        #endif
        guard !isShown, let min = config.minSupportedVersion, !min.isEmpty,
              let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              current.compare(min, options: .numeric) == .orderedAscending,
              var top = root else { return }
        while let presented = top.presentedViewController { top = presented }
        isShown = true
        AmplitudeService.shared.logRedesignEvent("force_update_shown", properties: ["min": min, "current": current])
        top.present(StateScreenViewController.make(.forceUpdate), animated: true)
    }
}
