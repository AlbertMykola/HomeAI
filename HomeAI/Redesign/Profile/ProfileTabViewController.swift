import UIKit
import StoreKit
import UserNotifications

/// App appearance (A/11 · S1 Appearance menu): System / Light / Dark, applied to the window with a 0.3 s cross-fade.
enum AppearanceMode: Int, CaseIterable {
    case system, light, dark

    private static let key = "redesign_appearance"

    static var current: AppearanceMode {
        get { AppearanceMode(rawValue: UserDefaults.standard.integer(forKey: key)) ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }

    var title: String {
        switch self {
        case .system: return "System".localized
        case .light: return "Light".localized
        case .dark: return "Dark".localized
        }
    }

    var style: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }

    static func apply(to window: UIWindow?, animated: Bool) {
        guard let window else { return }
        let change = { window.overrideUserInterfaceStyle = current.style }
        animated ? UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: change)
            : change()
    }
}

/// A/11 · S1 Profile (Free / Pro / full scroll). Layout: Profile.storyboard.
final class ProfileTabViewController: UIViewController {
    @IBOutlet private weak var appearanceMenuButton: UIButton!

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var contentStack: UIStackView!
    @IBOutlet private weak var largeTitleLabel: UILabel!
    @IBOutlet private weak var compactTitleLabel: UILabel!
    @IBOutlet private weak var headerBackgroundView: UIView!
    @IBOutlet private weak var freeCardView: UIView!
    @IBOutlet private weak var freeTitleLabel: UILabel!
    @IBOutlet private weak var freeSubtitleLabel: UILabel!
    @IBOutlet private weak var progressTrackView: UIView!
    @IBOutlet private weak var progressFillView: UIView!
    // Retain the entrance constraint while the proportional constraint is active.
    @IBOutlet private var progressFillWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var getProButton: DSPressableControl!
    @IBOutlet private weak var getProLabel: UILabel!
    @IBOutlet private weak var proCardView: UIView!
    @IBOutlet private weak var proTitleLabel: UILabel!
    @IBOutlet private weak var proSubtitleLabel: UILabel!
    @IBOutlet private weak var crownImageView: UIImageView!
    @IBOutlet private var perkLabels: [UILabel]!
    @IBOutlet private weak var resubscribeButton: DSPrimaryButton!
    @IBOutlet private weak var billingBanner: DSPressableControl!
    @IBOutlet private weak var billingLabel: UILabel!
    @IBOutlet private var groupViews: [UIView]!
    @IBOutlet private weak var restorePurchasesGroup: UIView!
    @IBOutlet private var rowViews: [UIView]!
    @IBOutlet private var rowTitleLabels: [UILabel]!
    @IBOutlet private weak var languageValueLabel: UILabel!
    @IBOutlet private weak var appearanceValueLabel: UILabel!
    @IBOutlet private weak var notificationsSwitch: UISwitch!
    @IBOutlet private weak var versionLabel: UILabel!
    @IBOutlet private weak var restoreOverlay: UIView!
    @IBOutlet private weak var restoreSpinner: UIActivityIndicatorView!
    @IBOutlet private weak var restoreLabel: UILabel!

    private var didRunEntrance = false
    private var entrancePrepared = false
    private var isAnimatingProgress = false
    private var progress: CGFloat = 0
    private var progressRatioConstraint: NSLayoutConstraint?
    private var fittedProgress: CGFloat?

    override func viewDidLoad() {
        super.viewDidLoad()
        largeTitleLabel.text = "Profile".localized
        compactTitleLabel.text = "Profile".localized
        let titles = [0: "Language", 1: "Appearance", 2: "Notifications", 3: "Restore purchases",
                      5: "Help & feedback", 6: "Rate Rehomely", 7: "Share with a friend", 8: "Privacy policy", 9: "Terms of use"]
        rowTitleLabels.forEach { $0.text = titles[$0.tag]?.localized }
        let perks = ["4K export", "No watermark", "All tools"]
        perkLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = perks[$0].localized }
        restoreLabel.text = "Restoring purchases…".localized
        billingLabel.text = "Payment issue. Update payment method to keep Pro.".localized
        (resubscribeButton.subviews.compactMap { $0 as? UILabel }.first)?.text = "Resubscribe".localized

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        versionLabel.text = "\(Constants.Text.brand) \(version) (\(build))"
        versionLabel.isUserInteractionEnabled = true
        versionLabel.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(copyDiagnostics(_:))))

        configureAppearanceMenu()
        scrollView.delegate = self
        scrollView.contentInset.bottom = 24
        NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        refresh()
        if !didRunEntrance && !entrancePrepared {
            // Prepare before the first visible frame, rather than hiding an already visible screen.
            entrancePrepared = true
            contentStack.arrangedSubviews.filter { !$0.isHidden }.forEach {
                $0.alpha = 0
                $0.transform = CGAffineTransform(translationX: 0, y: DS.Motion.reduceMotion ? 0 : 12)
            }
            progressRatioConstraint?.isActive = false
            progressFillWidthConstraint.isActive = true
            progressFillWidthConstraint.constant = 0
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bottom = OnboardingLayout(size: view.dsAdaptiveReferenceSize).value(24)
        if scrollView.contentInset.bottom != bottom { scrollView.contentInset.bottom = bottom }
        if (!entrancePrepared && !isAnimatingProgress) || DS.Motion.reduceMotion {
            fitProgressToTrack()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didRunEntrance else { return }
        didRunEntrance = true
        // Figma A/11 S1: blocks 60 ms apart; free-designs bar grows from 0 (spring, 0.4–1.2 s);
        // shimmer over Get Pro at 1.6 s and 4.2 s; Pro crown wiggles at 0.8 s.
        contentStack.arrangedSubviews.filter { !$0.isHidden }.enumerated().forEach {
            DS.Motion.enter($1, delay: 0.06 * Double($0), dy: 12)
        }
        var animateProgress = !DS.Motion.reduceMotion
        #if DEBUG
        if AppQA.enabled && AppQA.snapshot { animateProgress = false }
        #endif
        if !freeCardView.isHidden, animateProgress {
            isAnimatingProgress = true
            let grow = UIViewPropertyAnimator(duration: 0.8, dampingRatio: 0.8) {
                self.fitProgressToTrack()
                self.view.layoutIfNeeded()
            }
            grow.addCompletion { [weak self] _ in self?.isAnimatingProgress = false }
            grow.startAnimation(afterDelay: 0.4)
            [1.6, 4.2].forEach { t in
                DispatchQueue.main.asyncAfter(deadline: .now() + t) { [weak self] in
                    guard let self else { return }
                    Self.shimmer(over: self.getProButton)
                }
            }
        }
        if !animateProgress { fitProgressToTrack() }
        entrancePrepared = false
        if !proCardView.isHidden { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.wiggleCrown() } }
    }

    // MARK: State

    private func fitProgressToTrack() {
        guard progressRatioConstraint?.isActive != true || fittedProgress != progress else { return }
        progressFillWidthConstraint.isActive = false
        progressRatioConstraint?.isActive = false
        let ratio = progressFillView.widthAnchor.constraint(equalTo: progressTrackView.widthAnchor, multiplier: progress)
        progressRatioConstraint = ratio
        fittedProgress = progress
        ratio.isActive = true
    }

    @objc private func refresh() {
        let isPro = AdaptyService.shared.hasActiveSubscription
        restorePurchasesGroup.isHidden = isPro
        freeCardView.isHidden = isPro
        proCardView.isHidden = !isPro
        if isPro {
            let status = AdaptyService.shared.proStatus
            let date = status?.expiresAt.map { DateFormatter.localizedString(from: $0, dateStyle: .medium, timeStyle: .none) }
            if let status, !status.willRenew, let date {
                proSubtitleLabel.text = String(format: "Pro until %@".localized, date)
                resubscribeButton.isHidden = false
            } else if let date {
                proSubtitleLabel.text = String(format: "Unlimited designs · renews %@".localized, date)
                resubscribeButton.isHidden = true
            } else {
                proSubtitleLabel.text = "Unlimited designs".localized
                resubscribeButton.isHidden = true
            }
            billingBanner.isHidden = !(status?.billingIssue ?? false)
        } else {
            billingBanner.isHidden = true
            let limit = max(FreeGenerationManager.shared.limit, 1)
            let left = FreeGenerationManager.shared.remainingFreeGenerations
            freeTitleLabel.text = "Free plan".localized
            freeSubtitleLabel.text = left == 0 ? "No free designs left".localized
                : String(format: "%d of %d free designs left".localized, left, limit)
            progress = CGFloat(left) / CGFloat(limit)
            if let price = AdaptyService.shared.cachedWeeklyPrice {
                getProLabel.text = String(format: "Get Pro · %@ / week".localized, price)
            } else {
                getProLabel.text = "Get Pro".localized
            }
            view.setNeedsLayout()
        }
        languageValueLabel.text = Self.currentLanguageName
        appearanceValueLabel.text = AppearanceMode.current.title
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let enabled = UserDefaults.standard.object(forKey: Self.notificationsKey) as? Bool ?? true
                self.notificationsSwitch.setOn(settings.authorizationStatus == .authorized && enabled, animated: false)
            }
        }
    }

    static var currentLanguageName: String {
        let code = AppLocalization.language
        return Locale(identifier: code).localizedString(forIdentifier: code)?.capitalized(with: Locale(identifier: code)) ?? code
    }

    // MARK: Rows

    @IBAction private func didTapRow(_ sender: UIControl) {
        DS.Haptic.selection()
        AmplitudeService.shared.logRedesignEvent("profile_row", properties: ["row": sender.tag])
        switch sender.tag {
        case 0: navigationController?.pushViewController(AppStoryboard.instantiate(LanguageViewController.self),
                                                         animated: true)
        case 1: break // pull-down menu (configureAppearanceMenu)
        case 3: restorePurchases()
        case 5: SupportMail.compose(from: self, subject: "Help & feedback".localized, body: nil)
        case 6: rate()
        case 7: shareApp(from: sender)
        case 8: open(Constants.API.privacy)
        case 9: open(Constants.API.terms)
        default: break
        }
    }

    /// Appearance → pull-down menu with a check next to the current mode (iOS 14+ UIMenu on the row).
    private func configureAppearanceMenu() {
        guard let row = rowViews.first(where: { $0.tag == 1 }) as? UIControl else { return }
        let button = appearanceMenuButton!
        // The row's pressable disables decoration during decoding; this storyboard child is interactive.
        button.isUserInteractionEnabled = true
        row.isAccessibilityElement = false
        button.accessibilityIdentifier = "profile.appearance.menu"
        button.showsMenuAsPrimaryAction = true
        button.accessibilityLabel = "Appearance".localized
        button.accessibilityValue = AppearanceMode.current.title
        button.menu = makeAppearanceMenu()
    }

    private func makeAppearanceMenu() -> UIMenu {
        UIMenu(children: AppearanceMode.allCases.map { mode in
            UIAction(title: mode.title, state: mode == AppearanceMode.current ? .on : .off) { [weak self] _ in
                AppearanceMode.current = mode
                AppearanceMode.apply(to: self?.view.window, animated: true)
                DS.Haptic.selection()
                self?.appearanceValueLabel.text = mode.title
                self?.appearanceMenuButton?.accessibilityValue = mode.title
                self?.appearanceMenuButton?.menu = self?.makeAppearanceMenu()
            }
        })
    }

    private static let notificationsKey = "redesign_notifications_enabled"

    @IBAction private func didToggleNotifications(_ sender: UISwitch) {
        let on = sender.isOn
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch (on, settings.authorizationStatus) {
                case (true, .notDetermined):
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                        DispatchQueue.main.async {
                            UserDefaults.standard.set(granted, forKey: Self.notificationsKey)
                            sender.setOn(granted, animated: true)
                            if granted { LocalNotificationService.shared.sync(requestPermissionIfNeeded: false) }
                        }
                    }
                case (true, .denied):
                    sender.setOn(false, animated: true)
                    self.showOpenSettingsAlert()
                case (true, _):
                    UserDefaults.standard.set(true, forKey: Self.notificationsKey)
                    LocalNotificationService.shared.sync(requestPermissionIfNeeded: false)
                case (false, _):
                    UserDefaults.standard.set(false, forKey: Self.notificationsKey)
                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                }
            }
        }
    }

    private func showOpenSettingsAlert() {
        let alert = UIAlertController(title: "Notifications are off".localized,
                                      message: "Turn them on in iPhone Settings to know when your design is ready.".localized,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings".localized, style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        })
        present(alert, animated: true)
    }

    private func restorePurchases() {
        restoreOverlay.isHidden = false
        restoreOverlay.alpha = 0
        restoreSpinner.startAnimating()
        UIView.animate(withDuration: 0.2) { self.restoreOverlay.alpha = 1 }
        Task { @MainActor in
            var restored = false
            do {
                _ = try await AdaptyService.shared.restore()
                restored = AdaptyService.shared.hasActiveSubscription
            } catch {
                restored = false
            }
            UIView.animate(withDuration: 0.2, animations: { self.restoreOverlay.alpha = 0 }) { _ in
                self.restoreOverlay.isHidden = true
            }
            let alert = UIAlertController(
                title: restored ? "Purchases restored".localized : "Nothing to restore".localized,
                message: restored ? "Welcome back to Pro.".localized
                    : "We couldn't find an active subscription for this Apple ID.".localized,
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK".localized, style: .default))
            present(alert, animated: true)
            if restored { DS.Haptic.success() }
            refresh()
        }
    }

    @IBAction private func didTapManage(_ sender: Any) {
        guard let scene = view.window?.windowScene else { return }
        Task { @MainActor in
            do {
                try await AppStore.showManageSubscriptions(in: scene)
            } catch {
                self.open("https://apps.apple.com/account/subscriptions")
            }
            self.refresh()
        }
    }

    @IBAction private func didTapGetPro(_ sender: Any) {
        AmplitudeService.shared.logRedesignEvent("profile_get_pro", properties: [:])
        NavigationManager.shared.showPremium(placement: Constants.Keys.optionPlacememt)
    }

    private func rate() {
        if let scene = view.window?.windowScene {
            SKStoreReviewController.requestReview(in: scene)
        } else {
            open("itms-apps://itunes.apple.com/app/id\(Constants.Keys.appleId)?action=write-review")
        }
    }

    private func shareApp(from source: UIView) {
        let link = "https://apps.apple.com/app/id\(Constants.Keys.appleId)"
        let text = String(format: "I redesign my rooms with %@: %@".localized, Constants.Text.brand, link)
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = source
        present(vc, animated: true)
    }

    private func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
    }

    /// Long tap on the version copies diagnostics for support.
    @objc private func copyDiagnostics(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let info = [versionLabel.text ?? "", "iOS \(UIDevice.current.systemVersion)",
                    "Device \(UIDevice.current.model)", "User \(AdaptyService.shared.userID)",
                    "Pro \(AdaptyService.shared.hasActiveSubscription)"]
        UIPasteboard.general.string = info.joined(separator: "\n")
        DS.Haptic.success()
        DSToastView.show("Diagnostics copied".localized, style: .success)
    }

    // MARK: Motion helpers

    private func wiggleCrown() {
        guard !DS.Motion.reduceMotion else { return }
        let wiggle = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        wiggle.values = [0, -0.25, 0.2, -0.12, 0.06, 0]
        wiggle.duration = 0.8
        crownImageView.layer.add(wiggle, forKey: "wiggle")
    }

    /// White diagonal sweep (Button/Dark · Get Pro).
    static func shimmer(over view: UIView) {
        guard !DS.Motion.reduceMotion else { return }
        let band = CAGradientLayer()
        band.colors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.withAlphaComponent(0.35).cgColor,
                       UIColor.white.withAlphaComponent(0).cgColor]
        band.startPoint = CGPoint(x: 0, y: 0.5)
        band.endPoint = CGPoint(x: 1, y: 0.5)
        band.frame = CGRect(x: -100, y: -view.bounds.height, width: 70, height: view.bounds.height * 3)
        band.transform = CATransform3DMakeRotation(.pi / 9, 0, 0, 1)
        view.layer.addSublayer(band)
        let move = CABasicAnimation(keyPath: "position.x")
        move.fromValue = -60
        move.toValue = view.bounds.width + 60
        move.duration = 0.9
        move.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        move.isRemovedOnCompletion = false
        move.fillMode = .forwards
        CATransaction.begin()
        CATransaction.setCompletionBlock { band.removeFromSuperlayer() }
        band.add(move, forKey: "sweep")
        CATransaction.commit()
    }
}

extension ProfileTabViewController: UIScrollViewDelegate {
    /// Large title collapses into a blurred "Profile" bar after 40 pt.
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Initial safe-area/layout callbacks must not reveal the title before its entrance.
        guard didRunEntrance else { return }
        let p = min(max(scrollView.contentOffset.y / 40, 0), 1)
        headerBackgroundView.alpha = p
        compactTitleLabel.alpha = p
        largeTitleLabel.alpha = 1 - p
    }
}

/// A/11 · S2 Language. iOS per-app language: a tap opens the app's page in Settings (the change needs a relaunch).
/// Layout: Profile.storyboard.
final class LanguageViewController: UIViewController {

    @IBOutlet private weak var navTitleLabel: UILabel!
    @IBOutlet private weak var hintLabel: UILabel!
    @IBOutlet private weak var contentStack: UIStackView!
    @IBOutlet private var languageRows: [DSPressableControl]!
    @IBOutlet private var nativeLabels: [UILabel]!
    @IBOutlet private var englishLabels: [UILabel]!
    @IBOutlet private var checkViews: [UIImageView]!

    /// Languages the app ships (lproj folders).
    private static let codes = ["en", "uk", "de", "es", "fr", "it", "pl", "pt-BR", "ja", "ko", "nl", "cs", "da", "nb", "ru"]
    private var current = AppLocalization.language

    override func viewDidLoad() {
        super.viewDidLoad()
        navTitleLabel.text = "Language".localized
        hintLabel.text = "The app follows your iPhone language by default.".localized
        let english = Locale(identifier: "en")
        for (i, code) in Self.codes.enumerated() {
            let native = Locale(identifier: code).localizedString(forIdentifier: code)?.capitalized(with: Locale(identifier: code))
            nativeLabels.first { $0.tag == i }?.text = native ?? code
            englishLabels.first { $0.tag == i }?.text = english.localizedString(forIdentifier: code) ?? code
        }
        applyCheck(animated: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DS.Motion.enter(contentStack, delay: 0, dy: 12)
    }

    private func applyCheck(animated: Bool) {
        let index = Self.codes.firstIndex(of: current) ?? Self.codes.firstIndex { current.hasPrefix($0) } ?? 0
        let changes = { self.checkViews.forEach { $0.alpha = $0.tag == index ? 1 : 0 } }
        languageRows.forEach { $0.accessibilityTraits = $0.tag == index ? [.button, .selected] : .button }
        animated ? UIView.animate(withDuration: 0.25, animations: changes) : changes()
    }

    @IBAction private func didTapLanguage(_ sender: UIControl) {
        DS.Haptic.selection()
        let code = Self.codes[sender.tag]
        guard code != current else { return }
        let alert = UIAlertController(title: "Change language".localized,
                                      message: "iOS sets the app language in Settings. We'll open them for you; Rehomely restarts in the new language.".localized,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings".localized, style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        })
        present(alert, animated: true)
    }

    @IBAction private func didTapBack(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
}
