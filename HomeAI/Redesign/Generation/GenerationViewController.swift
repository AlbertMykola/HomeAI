import UIKit
import UserNotifications

/// A/05 · G1 Generating (+ G3 failed / G4 photo not suitable). Layout: Generation.storyboard.
/// Presented full screen; ⌄ collapses it while the runner keeps going (GenerationCenter).
final class GenerationViewController: UIViewController, DSWideLayoutFullWidth {

    // nav + photo
    @IBOutlet private var scanParticles: [UIView]!
    @IBOutlet private var animatedLayoutConstraints: [NSLayoutConstraint]!
    private lazy var particleGeometry = StoryboardGeometry(constraints: animatedLayoutConstraints)
    @IBOutlet private weak var collapseButton: DSPressableControl!
    @IBOutlet private weak var navTitleLabel: UILabel!
    @IBOutlet private weak var photoCardView: UIView!
    /// iPhone Duo unfolded, landscape (Figma Duo/L/05): scanning photo left, progress right (Generation.storyboard).
    @IBOutlet private var listOnlyConstraints: [NSLayoutConstraint]!
    @IBOutlet private var splitConstraints: [NSLayoutConstraint]!
    /// Failure states in the split (Figma Duo/L/05 G3/G4): picture on a tinted left pane, text and actions right.
    @IBOutlet private weak var failurePaneView: UIView?
    private lazy var layoutSwitch = DSLayoutSwitch(phone: listOnlyConstraints, unfolded: splitConstraints)
    /// Unfolded portrait and half folded (Figma Duo/HF/05): the scanning photo fills the top half, progress,
    /// steps and "Notify me" start under the hinge, so Duo can stand on a table while it works.
    @IBOutlet private var portraitConstraints: [NSLayoutConstraint]!
    @IBOutlet private var portraitReleasedConstraints: [NSLayoutConstraint]!

    var dsUsesFullWidth: Bool { dsWantsWideLandscape }

    private var isTabletop = false

    /// iPhone Duo hinge (iOS 27.1): half open = tabletop — the scan stays above the fold whatever the orientation.
    private func observeHinge() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--qa-tabletop") { isTabletop = true; return }
        #endif
        guard #available(iOS 27.1, *) else { return }
        view.addInteraction(UIHingeInteraction { [weak self] _, update in
            guard let self else { return }
            let tabletop = update.hinge?.status == .partiallyOpen
            guard tabletop != self.isTabletop else { return }
            self.isTabletop = tabletop
            self.view.setNeedsLayout()
            UIView.animate(withDuration: DS.Motion.reduceMotion ? 0 : 0.45) { self.view.layoutIfNeeded() }
        })
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let landscape = dsWantsWideLandscape && !isTabletop
        if layoutSwitch.set(unfolded: landscape) { navigationController?.view.setNeedsLayout() }
        failurePaneView?.isHidden = !landscape
        let size = view.bounds.size
        let portrait = isTabletop || (!landscape && UIDevice.isFoldablePhone && DSWideLayout.isWide(size.width) && size.height > size.width)
        // The released constraints belong to the phone set, which the landscape switch also turns off.
        let released = UILayoutPriority(portrait || landscape ? 1 : 999)
        portraitReleasedConstraints.forEach { if $0.priority != released { $0.priority = released } }
        let split = UILayoutPriority(portrait ? 999 : 1)
        portraitConstraints.forEach { if $0.priority != split { $0.priority = split } }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // A shadow without a path is re-derived from the layer's alpha off-screen on every frame of the scan
        // animation; with it the GPU just draws a rect (App Hangs while generating on iPhone 13/14).
        scanEdgeView.layer.shadowPath = UIBezierPath(rect: scanEdgeView.bounds).cgPath
    }
    @IBOutlet private weak var photoClipView: UIView!
    @IBOutlet private weak var photoImageView: UIImageView!
    @IBOutlet private weak var scannedAreaView: UIView!
    @IBOutlet private weak var scannedHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var scanLineView: UIView!
    @IBOutlet private weak var scanEdgeView: UIView!
    @IBOutlet private weak var pointsView: UIView!
    // progress + steps
    @IBOutlet private weak var progressStack: UIStackView!
    @IBOutlet private weak var percentLabel: UILabel!
    @IBOutlet private weak var etaLabel: UILabel!
    @IBOutlet private weak var trackView: UIView!
    @IBOutlet private weak var fillView: UIView!
    @IBOutlet private weak var fillWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var stepsStack: UIStackView!
    @IBOutlet private var stepRows: [UIStackView]!
    @IBOutlet private var stepRings: [UIView]!
    @IBOutlet private var stepDoneViews: [UIView]!
    @IBOutlet private var stepSpinnerViews: [UIView]!
    @IBOutlet private var stepLabels: [UILabel]!
    // notify
    @IBOutlet private weak var notifyControl: DSPressableControl!
    @IBOutlet private weak var notifyIconView: UIImageView!
    @IBOutlet private weak var notifyLabel: UILabel!
    @IBOutlet private weak var notifyAccessoryView: UIImageView!
    // failure
    @IBOutlet private weak var failureView: UIView!
    @IBOutlet private weak var failureBackButton: DSPressableControl!
    @IBOutlet private weak var failurePhotoView: UIImageView!
    @IBOutlet private weak var failureIconView: UIView!
    @IBOutlet private weak var failureIconImageView: UIImageView!
    @IBOutlet private weak var failureTextStack: UIStackView!
    @IBOutlet private weak var failureTitleLabel: UILabel!
    @IBOutlet private weak var failureBodyLabel: UILabel!
    @IBOutlet private weak var failureCodeLabel: UILabel!
    @IBOutlet private weak var failureActionsStack: UIStackView!
    @IBOutlet private weak var failurePrimaryButton: DSPrimaryButton!
    @IBOutlet private weak var failurePrimaryLabel: UILabel!
    @IBOutlet private weak var failurePrimaryIcon: UIImageView!
    @IBOutlet private weak var failureSecondaryButton: UIButton!

    var runner: GenerationRunner!
    var sourcePhoto: UIImage?
    var styleTitle: String?
    /// "Change photo" / "Choose another photo" — back to W1 with the same settings.
    var onChangePhoto: (() -> Void)?
    /// A/12 Content blocked → "Edit request" goes back to the step with the prompt / settings.
    var onEditRequest: (() -> Void)?

    private var progress: CGFloat = 0
    private var displayLink: CADisplayLink?
    private var scanTimer: Timer?
    private var failureCount = 0
    private var isShowingNotPhotoSuitable = false
    private var isShowingUnreachable = false
    private var didRunEntrance = false

    private var expectedDuration: TimeInterval { 30 }

    override var preferredStatusBarStyle: UIStatusBarStyle { .default }

    override func viewDidLoad() {
        super.viewDidLoad()
        observeHinge()
        navTitleLabel.text = "Creating your design".localized
        etaLabel.text = String(format: "~%d s left".localized, 30)
        [percentLabel, failureTitleLabel, failureBodyLabel, failureCodeLabel].forEach {
            $0?.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        photoImageView.image = sourcePhoto
        failurePhotoView.image = sourcePhoto
        let titles = ["Analyzing your room".localized,
                      runner.promptManager.designMode == .renovationDesign ? "Planning a fresh layout".localized
                                                                            : "Keeping walls & windows".localized,
                      styleTitle.map { String(format: "Applying %@ style".localized, $0) } ?? "Applying your style".localized,
                      "Final touches".localized]
        sorted(stepLabels).enumerated().forEach { $1.text = titles[$0] }
        scanEdgeView.layer.shadowColor = DS.Color.lime.cgColor
        setupSpinners()
        updateNotifyCard()
        render(progress: 0)
        runner.onStateChange = { [weak self] state in self?.handle(state) }
        [photoCardView, progressStack, notifyControl].forEach { $0?.alpha = 0 }
        stepRows.forEach { $0.alpha = 0 }
        handle(runner.state)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startDisplayLink()
        startScanLoop()
        if !didRunEntrance {
            didRunEntrance = true
            DS.Motion.enter(photoCardView, delay: 0, scale: 0.96, duration: 0.5, spring: true)
            DS.Motion.enter(progressStack, delay: 0.15, dy: 10)
            sorted(stepRows).enumerated().forEach { DS.Motion.enter($1, delay: 0.25 + Double($0) * 0.06, dy: 8) }
            DS.Motion.enter(notifyControl, delay: 0.5, dy: 20, spring: true)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        displayLink?.invalidate()
        displayLink = nil
        scanTimer?.invalidate()
    }

    private func sorted<T: UIView>(_ views: [T]) -> [T] { views.sorted { $0.tag < $1.tag } }

    // MARK: State

    private func handle(_ state: GenerationRunner.State) {
        switch state {
        case .idle, .running:
            failureView.isHidden = true
            setProgressHidden(false)
        case .blocked(let access):
            if access == .dailyLimitExceeded {
                DailyGenerationLimitManager.shared.presentDailyLimitAlert(from: self)
            } else {
                NavigationManager.shared.showPremium(placement: Constants.Keys.reachedLimit, origin: .inApp) { [weak self] in
                    self?.runner.start()
                }
            }
        case .succeeded(let outcome):
            finish(with: outcome)
        case .failed(let failure):
            failureCount += 1
            setProgressHidden(true)
            showFailure(failure)
        }
    }

    private func setProgressHidden(_ hidden: Bool) {
        [collapseButton, navTitleLabel, photoCardView, progressStack, stepsStack, notifyControl].forEach { $0?.isHidden = hidden }
    }

    // MARK: Progress (estimate — no backend progress yet; eases to 90 %, never sticks at 99 %)

    private func startDisplayLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func tick() {
        guard runner.isRunning, let startedAt = runner.startedAt else { return }
        let t = Date().timeIntervalSince(startedAt)
        let target = 0.9 * (1 - exp(-t / (expectedDuration / 2.6)))
        progress += (CGFloat(target) - progress) * 0.08
        render(progress: progress)
        let left = Int(max(3, expectedDuration - t).rounded())
        etaLabel.text = t > expectedDuration ? "Almost there…".localized : String(format: "~%d s left".localized, left)
    }

    private func render(progress: CGFloat) {
        let value = Int((progress * 100).rounded())
        if percentLabel.text != "\(value)%" {
            percentLabel.text = "\(value)%"
            percentLabel.accessibilityLabel = String(format: "%d percent".localized, value)
        }
        fillWidthConstraint.constant = trackView.bounds.width * min(max(progress, 0), 1)
        updateSteps(for: progress)
    }

    private var activeStep = -1

    /// 0–20 Analyzing, 20–45 Keeping walls, 45–85 Applying style, 85–100 Final touches.
    private func updateSteps(for progress: CGFloat) {
        let step: Int
        switch progress {
        case ..<0.20: step = 0
        case ..<0.45: step = 1
        case ..<0.85: step = 2
        case ..<1.0: step = 3
        default: step = 4
        }
        guard step != activeStep else { return }
        activeStep = step
        let labels = sorted(stepLabels), rings = sorted(stepRings), dones = sorted(stepDoneViews)
        let spinners = sorted(stepSpinnerViews)
        for i in 0..<4 {
            let isDone = i < step, isActive = i == step
            UIView.animate(withDuration: 0.25) {
                dones[i].alpha = isDone ? 1 : 0
                rings[i].alpha = isDone || isActive ? 0 : 1
                spinners[i].alpha = isActive ? 1 : 0
                labels[i].textColor = isDone || isActive ? DS.Color.textPrimary : DS.Color.textTertiary
            }
            labels[i].font = DS.Font.geologica(isActive ? .semiBold : .regular, labels[i].font.pointSize)
            if isDone, dones[i].transform == .identity, i == step - 1 {
                dones[i].transform = CGAffineTransform(scaleX: 0.4, y: 0.4)
                UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0) {
                    dones[i].transform = .identity
                }
            }
            if isActive, !DS.Motion.reduceMotion {
                labels[i].transform = CGAffineTransform(translationX: 0, y: 6)
                UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseOut) { labels[i].transform = .identity }
            }
        }
        if step < 4 {
            UIAccessibility.post(notification: .announcement, argument: labels[step].text)
        }
    }

    private func setupSpinners() {
        for spinner in stepSpinnerViews {
            let arc = CAShapeLayer()
            arc.path = UIBezierPath(arcCenter: CGPoint(x: 11, y: 11), radius: 8, startAngle: 0, endAngle: .pi * 1.5,
                                    clockwise: true).cgPath
            arc.strokeColor = DS.Color.textPrimary.resolvedColor(with: traitCollection).cgColor
            arc.fillColor = UIColor.clear.cgColor
            arc.lineWidth = 2
            arc.lineCap = .round
            arc.frame = CGRect(x: 0, y: 0, width: 22, height: 22)
            spinner.layer.addSublayer(arc)
            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0
            spin.toValue = Double.pi * 2
            spin.duration = 0.9
            spin.repeatCount = .infinity
            arc.add(spin, forKey: "spin")
        }
    }

    // MARK: Scan (2.1 s top → bottom, repeats while generating) + analysis points

    private func startScanLoop() {
        guard !DS.Motion.reduceMotion else {
            scannedHeightConstraint.constant = photoClipView.bounds.height * 0.5
            return
        }
        scanTimer?.invalidate()
        runScanPass()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 2.4, repeats: true) { [weak self] _ in
            guard let self, self.runner.isRunning else { return }
            self.runScanPass()
        }
    }

    private func runScanPass() {
        scannedHeightConstraint.constant = 0
        scanLineView.alpha = 1
        scanEdgeView.alpha = 1
        photoClipView.layoutIfNeeded()
        UIView.animate(withDuration: 2.1, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
            self.scannedHeightConstraint.constant = self.photoClipView.bounds.height
            self.photoClipView.layoutIfNeeded()
        } completion: { _ in
            UIView.animate(withDuration: 0.2) {
                self.scanLineView.alpha = 0
                self.scanEdgeView.alpha = 0
            }
        }
        flashPoints()
    }

    private func flashPoints() {
        scanParticles.forEach { $0.layer.removeAllAnimations(); $0.alpha = 0 }
        let bounds = pointsView.bounds.insetBy(dx: 20, dy: 20)
        guard bounds.width > 0 else { return }
        for (i, dot) in scanParticles.sorted(by: { $0.tag < $1.tag }).enumerated() {
            particleGeometry.setFrame(dot, CGRect(x: bounds.minX + .random(in: 0...bounds.width),
                                                 y: bounds.minY + .random(in: 0...bounds.height), width: 6, height: 6))
            dot.backgroundColor = .white
            dot.layer.cornerRadius = 3
            dot.layer.shadowColor = DS.Color.lime.cgColor
            dot.layer.shadowOpacity = 0.8
            dot.layer.shadowRadius = 3
            dot.layer.shadowOffset = .zero
            dot.layer.shadowPath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: 6, height: 6)).cgPath
            dot.alpha = 0
            dot.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
            let delay = Double(i) * 0.12 + .random(in: 0...0.4)
            UIView.animateKeyframes(withDuration: 0.9, delay: delay, options: []) {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.35) {
                    dot.alpha = 0.85
                    dot.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
                }
                UIView.addKeyframe(withRelativeStartTime: 0.35, relativeDuration: 0.25) { dot.transform = .identity }
                UIView.addKeyframe(withRelativeStartTime: 0.7, relativeDuration: 0.3) { dot.alpha = 0 }
            }
        }
    }

    // MARK: Success → result reveal

    private func finish(with outcome: GenerationRunner.Outcome) {
        DS.Haptic.success()
        UIView.animate(withDuration: 0.4) {
            self.progress = 1
            self.render(progress: 1)
            self.trackView.layoutIfNeeded()
        }
        etaLabel.text = "Done".localized
        GenerationCenter.shared.notifyIfInBackground(styleTitle: styleTitle)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            if self.presentingViewController != nil && self.view.window != nil {
                self.dismiss(animated: false) {
                    NavigationManager.shared.showResult(docID: outcome.docID, image: outcome.model.image, reveal: true)
                }
            }
            GenerationCenter.shared.finished(runner: self.runner)
        }
    }

    // MARK: Failure (G3 / G4)

    private func showFailure(_ failure: GenerationRunner.Failure) {
        if case .contentBlocked = failure {
            // A/12 Content blocked: full-screen state over G1; Edit request → back to the step with the prompt.
            DS.Haptic.error()
            let policy = String(runner.attemptID.prefix(4)).uppercased()
            let onEdit = onEditRequest ?? onChangePhoto
            let state = StateScreenViewController.make(.contentBlocked(photo: sourcePhoto, policyID: policy)) { [weak self] in
                guard let self else { return }
                GenerationCenter.shared.finished(runner: self.runner)
                self.dismiss(animated: false) { onEdit?() }
            }
            present(state, animated: true)
            return
        }
        failureView.isHidden = false
        failureView.alpha = 0
        UIView.animate(withDuration: 0.25) { self.failureView.alpha = 1 }
        switch failure {
        case .photoNotSuitable:
            isShowingNotPhotoSuitable = true
            isShowingUnreachable = false
            DS.Haptic.warning()
            failureIconImageView.image = UIImage(systemName: "viewfinder")
            failureTitleLabel.text = "We couldn't find a room here".localized
            failureBodyLabel.text = "Try a wider photo of the whole room in good light. No credit was used.".localized
            failureCodeLabel.text = nil
            failurePrimaryLabel.text = "Choose another photo".localized
            failurePrimaryIcon.image = UIImage(systemName: "photo")
            failureSecondaryButton.setTitle("See photo tips".localized, for: .normal)
        case .contentBlocked:
            return
        case .serviceUnreachable:
            isShowingNotPhotoSuitable = false
            isShowingUnreachable = true
            DS.Haptic.warning()
            failureIconImageView.image = UIImage(systemName: "wifi.exclamationmark")
            failureTitleLabel.text = "Service unavailable".localized
            failureBodyLabel.text = "The service is unavailable on your network. Check your internet connection or try again later.".localized
            failureCodeLabel.text = nil
            failurePrimaryLabel.text = "Try again".localized
            failurePrimaryIcon.image = UIImage(systemName: "arrow.clockwise")
            failureSecondaryButton.setTitle("OK".localized, for: .normal)
        case .failed(let code, _):
            isShowingNotPhotoSuitable = false
            isShowingUnreachable = false
            DS.Haptic.error()
            failureIconImageView.image = UIImage(systemName: "arrow.clockwise")
            failureTitleLabel.text = "Something went wrong".localized
            failureBodyLabel.text = "Our servers hiccuped. Your credit is back — try again, it usually works.".localized
            let shortID = String(runner.attemptID.prefix(4)).uppercased()
            failureCodeLabel.text = String(format: "Error %@ · ID %@".localized, code, shortID)
            failurePrimaryLabel.text = "Try again".localized
            failurePrimaryIcon.image = UIImage(systemName: "arrow.clockwise")
            failureSecondaryButton.setTitle(failureCount >= 2 ? "Contact support".localized : "Change photo".localized,
                                            for: .normal)
        }
        animateFailureEntrance()
    }

    private func animateFailureEntrance() {
        let m = DS.Motion.self
        m.enter(failurePhotoView, delay: 0, scale: 0.92, duration: 0.45)
        m.enter(failureIconView, delay: 0.3, scale: 0.4, duration: 0.4, pop: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let icon = self?.failureIconView, !DS.Motion.reduceMotion else { return }
            let wiggle = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            let a = CGFloat.pi / 15
            wiggle.values = [0, a, -a, 0]
            wiggle.duration = 0.4
            icon.layer.add(wiggle, forKey: "wiggle")
        }
        failureTextStack.arrangedSubviews.enumerated().forEach { m.enter($1, delay: 0.45 + Double($0) * 0.07, dy: 8) }
        failureActionsStack.arrangedSubviews.enumerated().forEach { m.enter($1, delay: 0.6 + Double($0) * 0.08, dy: 16) }
        m.enter(failureCodeLabel, delay: 0.85)
        UIAccessibility.post(notification: .screenChanged, argument: failureTitleLabel)
    }

    // MARK: Actions

    @IBAction private func didTapCollapse(_ sender: Any) {
        GenerationCenter.shared.collapse(runner: runner, photo: sourcePhoto, styleTitle: styleTitle)
        dismiss(animated: true)
    }

    @IBAction private func didTapFailureBack(_ sender: Any) {
        dismiss(animated: true)
        GenerationCenter.shared.finished(runner: runner)
    }

    @IBAction private func didTapFailurePrimary(_ sender: Any) {
        if isShowingNotPhotoSuitable {
            changePhoto()
            return
        }
        UIView.animate(withDuration: 0.25) { self.failureView.alpha = 0 } completion: { _ in
            self.failureView.isHidden = true
        }
        progress = 0
        activeStep = -1
        render(progress: 0)
        runner.retry()
        startScanLoop()
    }

    @IBAction private func didTapFailureSecondary(_ sender: Any) {
        if isShowingUnreachable {
            didTapFailureBack(sender)
        } else if isShowingNotPhotoSuitable {
            PhotoTipsSheetViewController.present(from: self)
        } else if failureCount >= 2 {
            SupportMail.compose(from: self, subject: "Generation failed", body: failureCodeLabel.text)
        } else {
            changePhoto()
        }
    }

    private func changePhoto() {
        let onChangePhoto = self.onChangePhoto
        GenerationCenter.shared.finished(runner: runner)
        dismiss(animated: true) { onChangePhoto?() }
    }

    // MARK: Notify (G2)

    @IBAction private func didTapNotify(_ sender: Any) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    NotifySheetViewController.present(from: self, photo: self.sourcePhoto, styleTitle: self.styleTitle) {
                        [weak self] in self?.updateNotifyCard()
                    }
                case .denied:
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                default:
                    GenerationCenter.shared.wantsReadyNotification = true
                    self.updateNotifyCard()
                }
            }
        }
    }

    private func updateNotifyCard() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let on = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            DispatchQueue.main.async {
                if on { GenerationCenter.shared.wantsReadyNotification = true }
                self.notifyControl.backgroundColor = on ? DS.Color.limeSoft : DS.Color.surface
                self.notifyLabel.text = on ? "We'll notify you when it's ready".localized : "Notify me when it's ready".localized
                self.notifyAccessoryView.image = UIImage(systemName: on ? "checkmark.circle" : "chevron.right")
                self.notifyAccessoryView.tintColor = on ? DS.Color.link : DS.Color.textTertiary
                self.notifyControl.isUserInteractionEnabled = !on
            }
        }
    }
}
