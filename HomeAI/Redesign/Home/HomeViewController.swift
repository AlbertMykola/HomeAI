import UIKit

/// A/03 · Home (tab Create). Layout: Home.storyboard.
final class HomeViewController: UIViewController {

    // MARK: Outlets — header
    @IBOutlet private weak var topGlowView: UIView!
    @IBOutlet private weak var headerView: UIView!
    @IBOutlet private weak var headerBackgroundView: UIVisualEffectView!
    @IBOutlet private weak var headerHairline: UIView!
    @IBOutlet private weak var logoLabel: UILabel!
    @IBOutlet private weak var creditsControl: DSPressableControl!
    @IBOutlet private weak var creditsIconView: UIImageView!
    @IBOutlet private weak var creditsLabel: UILabel!
    @IBOutlet private weak var getProControl: DSPressableControl!
    @IBOutlet private weak var getProLabel: UILabel!
    @IBOutlet private weak var proBadgeView: UIView!
    @IBOutlet private weak var offlineBannerView: UIView!
    @IBOutlet private weak var offlineLabel: UILabel!
    @IBOutlet private weak var offlineTopConstraint: NSLayoutConstraint!

    // MARK: Outlets — content
    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var contentStack: UIStackView!
    @IBOutlet private weak var freeBannerContainer: UIView!
    @IBOutlet private weak var freeBannerControl: DSPressableControl!
    @IBOutlet private weak var freeBannerIcon: UIImageView!
    @IBOutlet private weak var freeBannerLabel: UILabel!
    @IBOutlet private weak var freeBannerProLabel: UILabel!

    @IBOutlet private weak var heroView: UIView!
    @IBOutlet private weak var heroClipView: UIView!
    @IBOutlet private weak var heroAfterImageView: UIImageView!
    @IBOutlet private weak var heroBeforeImageView: UIImageView!
    @IBOutlet private weak var heroBeforeClipView: UIView!
    @IBOutlet private weak var heroBeforeWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var heroDividerView: UIView!
    @IBOutlet private weak var heroHandleView: UIImageView!
    @IBOutlet private weak var heroTextStack: UIStackView!
    @IBOutlet private weak var heroTitleLabel: UILabel!
    @IBOutlet private weak var heroSubtitleLabel: UILabel!
    @IBOutlet private weak var heroTagView: UIView!
    @IBOutlet private weak var heroTagIcon: UIImageView!
    @IBOutlet private weak var heroTagLabel: UILabel!
    @IBOutlet private weak var uploadButton: DSPrimaryButton!
    @IBOutlet private weak var uploadTitleLabel: UILabel!
    @IBOutlet private weak var costPillView: UIView!

    @IBOutlet private var moreCards: [DSPressableControl]!
    @IBOutlet private var moreCardLabels: [UILabel]!
    @IBOutlet private var moreCardImages: [UIImageView]!
    @IBOutlet private var moreCardIcons: [UIImageView]!
    @IBOutlet private weak var quickHeaderView: UIView!
    @IBOutlet private weak var quickTitleLabel: UILabel!
    @IBOutlet private var toolTiles: [DSPressableControl]!
    @IBOutlet private var toolLabels: [UILabel]!
    @IBOutlet private var toolLabelHeights: [NSLayoutConstraint]!
    @IBOutlet private weak var planHeaderView: UIView!
    @IBOutlet private weak var planTitleLabel: UILabel!
    @IBOutlet private var planCards: [DSPressableControl]!
    @IBOutlet private var planTitleLabels: [UILabel]!
    @IBOutlet private var planSubtitleLabels: [UILabel]!
    @IBOutlet private var planLabelMinimumHeights: [NSLayoutConstraint]!
    @IBOutlet private weak var recentSectionView: UIView!
    @IBOutlet private weak var recentTitleLabel: UILabel!
    @IBOutlet private weak var recentLinkButton: UIButton!
    @IBOutlet private weak var recentCollectionView: UICollectionView!

    // MARK: State
    private let amplitude = AmplitudeService.shared
    private var recentProjects: [(project: DesignProject, versions: [ImageDoc])] = []
    private var historyObserver: NSObjectProtocol?
    private var networkObserver: NSObjectProtocol?
    private var projectsObserver: NSObjectProtocol?
    private var didRunEntrance = false
    private var heroAutoCycleStopped = false
    private var lastHeroWidth: CGFloat = 0
    private var heroCycleAnimators: [UIViewPropertyAnimator] = []
    private var heroCycleWorkItem: DispatchWorkItem?
    private var microTimers: [Timer] = []
    private static var freeBannerDismissedThisSession = false

    private enum Tool: Int, CaseIterable {
        case paint, floor, replace, remove, furnish, rearrange
    }

    enum More {
        case interior, exterior, garden, reference

        static func options(for focus: HomeFocus) -> [More] {
            switch focus {
            case .interior: return [.exterior, .garden, .reference]
            case .surfaces: return [.interior, .exterior, .garden, .reference]
            case .exterior: return [.interior, .garden, .reference]
            case .garden: return [.interior, .exterior, .reference]
            }
        }

        var title: String {
            switch self {
            case .interior: return "Interior".localized
            case .exterior: return "Exterior".localized
            case .garden: return "Garden".localized
            case .reference: return "By reference".localized
            }
        }

        var symbol: String {
            switch self {
            case .interior: return "sofa"
            case .exterior: return "house"
            case .garden: return "tree"
            case .reference: return "photo.on.rectangle"
            }
        }

        var imageName: String {
            switch self {
            case .interior: return "home_hero_after"
            case .exterior: return "home_card_exterior"
            case .garden: return "home_card_garden"
            case .reference: return "home_card_reference"
            }
        }

        var option: DesignOption {
            switch self {
            case .interior: return .interior
            case .exterior: return .exterior
            case .garden: return .garden
            case .reference: return .reference
            }
        }
    }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        localize()
        configureLogo()
        configureHero()
        configureRecent()
        scrollView.delegate = self
        observeChanges()
        hideForEntrance()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        updateCredits()
        updateOfflineState(animated: false)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updatePlanLabelMinimumHeights()

    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updatePlanLabelMinimumHeights()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCompactHeader()
        updatePlanLabelMinimumHeights()
        if abs(heroWidth - lastHeroWidth) > 0.5 {
            let fraction = lastHeroWidth > 0 ? min(1, max(0, heroBeforeWidthConstraint.constant / lastHeroWidth)) : 110 / 353
            lastHeroWidth = heroWidth
            if heroAutoCycleStopped {
                heroBeforeWidthConstraint.constant = heroWidth * fraction
            } else {
                stopHeroCycle()
                heroBeforeWidthConstraint.constant = heroRestingWidth
                if didRunEntrance { startHeroCycle(after: 1) }
            }
        }
    }

    private func updatePlanLabelMinimumHeights() {
        guard isViewLoaded, let titles = planTitleLabels, let subtitles = planSubtitleLabels,
              planLabelMinimumHeights.count == titles.count + subtitles.count else { return }
        // Match the storyboard's two cards: 20 pt screen insets, 13 pt gap and 16 pt card padding.
        // A whole-point measure reserves the last line at fractional pixel boundaries,
        // without freezing UILabel's intrinsic wrapping to a previous viewport width.
        let layout = OnboardingLayout(size: view.dsLayoutSize)
        let width = floor((view.dsLayoutSize.width - layout.value(40 + 13)) / 2 - layout.value(32))
        guard width > 0 else { return }
        for constraint in planLabelMinimumHeights {
            guard let label = constraint.firstItem as? UILabel else { continue }
            let height = ceil(label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
            if abs(constraint.constant - height) > 0.1 { constraint.constant = height }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !didRunEntrance {
            didRunEntrance = true
            runEntrance()
        } else {
            startHeroCycle(after: 0.6)
            scheduleMicroAnimations()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopHeroCycle()
        microTimers.forEach { $0.invalidate() }
        microTimers.removeAll()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .default }

    deinit {
        [historyObserver, networkObserver, projectsObserver].compactMap { $0 }.forEach(NotificationCenter.default.removeObserver)
    }

    // MARK: Setup

    private func localize() {
        heroTitleLabel.text = HomeFocus.current.heroTitle
        heroSubtitleLabel.text = HomeFocus.current.heroSubtitle
        heroTitleLabel.accessibilityIdentifier = "home.hero.title"
        heroSubtitleLabel.accessibilityIdentifier = "home.hero.subtitle"
        heroTagLabel.accessibilityIdentifier = "home.hero.tag"
        uploadTitleLabel.text = "Upload a photo".localized
        getProLabel.text = "Get Pro".localized
        getProControl.accessibilityLabel = "Get Pro".localized
        creditsLabel.accessibilityIdentifier = "home.credits.label"
        getProLabel.accessibilityIdentifier = "home.pro.label"
        [logoLabel, creditsLabel, getProLabel].forEach {
            $0?.adjustsFontSizeToFitWidth = true
            $0?.minimumScaleFactor = 0.75
        }
        logoLabel.setContentCompressionResistancePriority(UILayoutPriority(749), for: .horizontal)
        getProLabel.setContentCompressionResistancePriority(UILayoutPriority(751), for: .horizontal)
        freeBannerLabel.text = "1 free design left".localized
        freeBannerProLabel.text = "Get Pro".localized
        offlineLabel.text = "No internet. Designs need a connection.".localized
        quickTitleLabel.text = "Quick edits".localized
        planTitleLabel.text = "Plan & ideas".localized
        recentTitleLabel.text = "Recent projects".localized
        recentLinkButton.setTitle("See all".localized, for: .normal)

        let alternatives = More.options(for: HomeFocus.current)
        sortedByTag(moreCardLabels).enumerated().forEach { $1.text = alternatives[safe: $0]?.title }
        sortedByTag(moreCardImages).enumerated().forEach {
            $1.image = alternatives[safe: $0].flatMap { UIImage(named: $0.imageName) }
        }
        sortedByTag(moreCardIcons).enumerated().forEach {
            $1.image = alternatives[safe: $0].flatMap { UIImage(systemName: $0.symbol) }
        }
        sortedByTag(moreCards).enumerated().forEach {
            let alternative = alternatives[safe: $0]
            $1.isHidden = alternative == nil
            $1.accessibilityIdentifier = alternative.map { "home.more.\($0.option.rawValue)" }
        }
        let toolTitles = ["Paint walls", "New floor", "Replace", "Remove", "Furnish", "Rearrange"]
        sortedByTag(toolLabels).enumerated().forEach { index, label in
            label.text = toolTitles[index].localized
            label.accessibilityIdentifier = "home.tool.\(index).title"
            // Reserve two lines with the existing storyboard constraint.
            toolLabelHeights.first { ($0.firstItem as? UILabel) === label }?.constant = ceil(label.font.lineHeight * 2)
        }
        let planTitles = ["Floor plan → 3D", "Ask AI designer"]
        let planSubtitles = ["Turn a sketch into a room", "Ideas, colors, budget"]
        sortedByTag(planTitleLabels).enumerated().forEach {
            $1.text = planTitles[$0].localized
            $1.accessibilityIdentifier = "home.plan.\($0).title"
        }
        sortedByTag(planSubtitleLabels).enumerated().forEach {
            $1.text = planSubtitles[$0].localized
            $1.accessibilityIdentifier = "home.plan.\($0).subtitle"
        }
        for control in moreCards + toolTiles + planCards {
            control.accessibilityLabel = control.subviewsLabels.joined(separator: ", ")
        }
    }

    private func configureLogo() {
        let text = NSMutableAttributedString(string: "Re", attributes: [
            .foregroundColor: DS.Color.textPrimary, .kern: -0.52
        ])
        text.append(NSAttributedString(string: "homely", attributes: [
            .foregroundColor: DS.Color.limeText, .kern: -0.52
        ]))
        logoLabel.attributedText = text
        logoLabel.accessibilityLabel = Constants.Text.brand
        logoLabel.accessibilityTraits = .header
    }

    private func configureHero() {
        let focus = HomeFocus.current
        heroTagLabel.text = focus.title
        heroTagIcon.image = UIImage(systemName: focus.symbol)
        heroAfterImageView.image = focus.afterImage
        heroBeforeImageView.image = focus.beforeImage

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleHeroPan(_:)))
        pan.delegate = self
        heroClipView.addGestureRecognizer(pan)
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapHero))
        heroClipView.addGestureRecognizer(tap)
        heroClipView.isAccessibilityElement = false
        heroTitleLabel.accessibilityTraits = .header
    }

    private func configureRecent() {

        recentCollectionView.dataSource = self
        recentCollectionView.delegate = self
        recentSectionView.isHidden = true
        reloadRecent()
    }

    private func observeChanges() {
        historyObserver = NotificationCenter.default.addObserver(forName: .imageHistoryDidChange, object: nil,
                                                                 queue: .main) { [weak self] _ in
            self?.reloadRecent()
            self?.updateCredits()
        }
        projectsObserver = NotificationCenter.default.addObserver(forName: .projectsDidChange, object: nil,
                                                                  queue: .main) { [weak self] _ in
            self?.reloadRecent()
        }
        networkObserver = NotificationCenter.default.addObserver(forName: .networkStatusDidChange, object: nil,
                                                                 queue: .main) { [weak self] _ in
            self?.updateOfflineState(animated: true)
        }
    }

    // MARK: Credits & banners

    private func updateCredits() {
        let isPro = AdaptyService.shared.hasActiveSubscription
        creditsControl.isHidden = isPro
        getProControl.isHidden = isPro
        proBadgeView.isHidden = !isPro
        let remaining = FreeGenerationManager.shared.remainingFreeGenerations
        creditsLabel.text = String(format: "%d free".localized, remaining)
        updateCompactHeader()
        creditsControl.accessibilityLabel = String(format: "%d free designs left".localized, remaining)
        costPillView.isHidden = isPro

        let showBanner = !isPro && remaining == 1 && !Self.freeBannerDismissedThisSession
        if showBanner != !freeBannerContainer.isHidden {
            freeBannerContainer.isHidden = !showBanner
            if showBanner, didRunEntrance {
                DS.Motion.enter(freeBannerContainer, delay: 0.1, dy: -16, spring: true)
            }
        }
    }

    /// Keep the count and purchase action readable when their translations are longer than English.
    private func updateCompactHeader() {
        let full = "Get Pro".localized
        let logoWidth = logoLabel.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: 44)).width
        let creditWidth = (creditsLabel.text ?? "").size(withAttributes: [.font: creditsLabel.font!]).width
        let proWidth = full.size(withAttributes: [.font: getProLabel.font!]).width
        let required = logoWidth + creditWidth + proWidth + 46 + 41 + 24
        let text = required > view.dsLayoutSize.width - 40 ? "Pro" : full
        if getProLabel.text != text { getProLabel.text = text }
    }

    private func updateOfflineState(animated: Bool) {
        let offline = !NetworkMonitor.shared.isOnline
        let generationControls: [DSPressableControl] = [uploadButton] + moreCards + toolTiles + [planCards[0]]
        generationControls.forEach { $0.dimmed = offline }
        guard offline == offlineBannerView.isHidden else { return }
        if offline {
            offlineBannerView.isHidden = false
            headerView.alpha = 0
            guard animated, !DS.Motion.reduceMotion else { return }
            offlineBannerView.transform = CGAffineTransform(translationX: 0, y: -60)
            UIView.animate(withDuration: 0.7, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0) {
                self.offlineBannerView.transform = .identity
            } completion: { _ in
                self.shake(self.offlineBannerView)
            }
        } else {
            let hide = {
                self.offlineBannerView.alpha = 0
                self.offlineBannerView.transform = CGAffineTransform(translationX: 0, y: -60)
                self.headerView.alpha = 1
            }
            let done = { (_: Bool) in
                self.offlineBannerView.isHidden = true
                self.offlineBannerView.alpha = 1
                self.offlineBannerView.transform = .identity
            }
            if animated { UIView.animate(withDuration: 0.35, animations: hide, completion: done) } else { hide(); done(true) }
        }
    }

    private func shake(_ view: UIView) {
        let anim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        anim.values = [0, 6, -6, 4, 0]
        anim.duration = 0.3
        view.layer.add(anim, forKey: "shake")
    }

    /// Generation entry points are blocked offline (toast instead).
    private func guardOnline() -> Bool {
        guard NetworkMonitor.shared.isOnline else {
            DS.Haptic.warning()
            DSToastView.show("You're offline".localized, style: .warning)
            return false
        }
        return true
    }

    // MARK: Actions

    @IBAction private func didTapUpload(_ sender: Any) {
        guard guardOnline() else { return }
        open(option: HomeFocus.current.option, source: "home_hero")
    }

    @objc private func didTapHero() {
        didTapUpload(heroView as Any)
    }

    @IBAction private func didTapMoreCard(_ sender: UIControl) {
        guard guardOnline(), let more = More.options(for: HomeFocus.current)[safe: sender.tag] else { return }
        open(option: more.option, source: "home_more")
    }

    @IBAction private func didTapTool(_ sender: UIControl) {
        guard guardOnline(), let tool = Tool(rawValue: sender.tag) else { return }
        switch tool {
        case .paint: open(option: .newWalls, source: "home_quick_edit")
        case .floor: open(option: .newFlooring, source: "home_quick_edit")
        case .replace: open(option: .replace, source: "home_quick_edit")
        case .remove: open(option: .delete, source: "home_quick_edit")
        case .furnish: open(option: .furnish, source: "home_quick_edit")
        case .rearrange: open(option: .rearrange, source: "home_quick_edit")
        }
    }

    @IBAction private func didTapFloorPlan(_ sender: Any) {
        guard guardOnline() else { return }
        open(option: .floolPlan, source: "home_plan")
    }

    @IBAction private func didTapAssistant(_ sender: Any) {
        amplitude.logEvent(.selectOption(name: Constants.Keys.amplitudeChatAssistantOption))
        NavigationManager.shared.showAssistant()
    }

    @IBAction private func didTapSeeAll(_ sender: Any) {
        (tabBarController as? TabBarController)?.select(.projects)
    }

    @IBAction private func didTapCredits(_ sender: Any) {
        NavigationManager.shared.showPremium(placement: Constants.Keys.optionPlacememt, origin: .inApp) { [weak self] in
            self?.updateCredits()
        }
    }

    @IBAction private func didTapGetPro(_ sender: Any) {
        didTapCredits(sender)
    }

    @IBAction private func didTapFreeBanner(_ sender: Any) {
        didTapCredits(sender)
    }

    @IBAction private func didTapCloseFreeBanner(_ sender: Any) {
        Self.freeBannerDismissedThisSession = true
        UIView.animate(withDuration: 0.3) {
            self.freeBannerContainer.isHidden = true
            self.contentStack.layoutIfNeeded()
        }
    }

    private func open(option: DesignOption, source: String) {
        amplitude.logEvent(.selectOption(name: option.title))
        NavigationManager.shared.startDesign(option: option)
    }

    // MARK: Recent projects

    private func reloadRecent() {
        recentProjects = Array(ProjectStore.shared.allProjects().prefix(10))
        recentSectionView.isHidden = recentProjects.isEmpty
        recentCollectionView.reloadData()
    }

    // MARK: Hero before/after

    private var heroWidth: CGFloat { max(heroClipView.bounds.width, 1) }
    private var heroRestingWidth: CGFloat { heroWidth * 110 / 353 }

    @objc private func handleHeroPan(_ pan: UIPanGestureRecognizer) {
        switch pan.state {
        case .began:
            heroAutoCycleStopped = true
            stopHeroCycle()
            DS.Haptic.selection()
            fallthrough
        case .changed:
            let x = pan.location(in: heroClipView).x
            heroBeforeWidthConstraint.constant = min(max(x, 0), heroWidth)
        default:
            break
        }
    }

    /// 6 s loop (Figma Motion · 2): hold → +180 pt → −60 pt → back, ease-in-out.
    private func startHeroCycle(after delay: TimeInterval) {
        guard !heroAutoCycleStopped, !DS.Motion.reduceMotion else { return }
        stopHeroCycle()
        let work = DispatchWorkItem { [weak self] in self?.runHeroCycle() }
        heroCycleWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func runHeroCycle() {
        guard !heroAutoCycleStopped, view.window != nil else { return }
        let rest = heroRestingWidth
        let steps: [(CGFloat, TimeInterval)] = [(rest + heroWidth * 180 / 353, 1.2),
                                              (rest - heroWidth * 60 / 353, 1.3), (rest, 1.2)]
        func step(_ index: Int) {
            guard index < steps.count else {
                startHeroCycle(after: 2.3)
                return
            }
            let (target, duration) = steps[index]
            let animator = UIViewPropertyAnimator(duration: duration, curve: .easeInOut) {
                self.heroBeforeWidthConstraint.constant = target
                self.heroClipView.layoutIfNeeded()
            }
            animator.addCompletion { position in
                guard position == .end else { return }
                step(index + 1)
            }
            heroCycleAnimators = [animator]
            animator.startAnimation()
        }
        step(0)
    }

    private func stopHeroCycle() {
        heroCycleWorkItem?.cancel()
        heroCycleAnimators.forEach { $0.stopAnimation(true) }
        heroCycleAnimators.removeAll()
        if !heroAutoCycleStopped {
            heroBeforeWidthConstraint.constant = heroRestingWidth
        }
    }

    // MARK: Motion

    private var entranceViews: [UIView?] {
        [topGlowView, logoLabel, creditsControl, getProControl, heroView, heroTextStack, uploadButton,
         costPillView, heroTagView, heroHandleView, quickHeaderView, planHeaderView, recentSectionView]
            + moreCards + toolTiles + planCards
    }

    private func hideForEntrance() {
        entranceViews.forEach { $0?.alpha = 0 }
    }

    /// Entrance timeline (dev notes §7).
    private func runEntrance() {
        view.layoutIfNeeded()
        heroBeforeWidthConstraint.constant = heroRestingWidth
        let m = DS.Motion.self
        if m.reduceMotion {
            entranceViews.forEach { v in UIView.animate(withDuration: 0.2) { v?.alpha = 1 } }
            return
        }
        UIView.animate(withDuration: 0.6, delay: 0, options: .curveEaseOut) { self.topGlowView.alpha = 1 }
        m.enter(logoLabel, delay: 0.05, dy: 8)
        m.enter(creditsControl, delay: 0.22, scale: 0.6, duration: 0.4, pop: true)
        m.enter(getProControl, delay: 0.30, scale: 0.6, duration: 0.4, pop: true)
        m.enter(heroView, delay: 0.12, dy: 16, scale: 0.96, duration: 0.55, spring: true)
        m.enter(heroTextStack, delay: 0.38, dy: 10)
        m.enter(uploadButton, delay: 0.50, dy: 12)
        m.enter(costPillView, delay: 0.58, scale: 0.6, duration: 0.4, pop: true)
        m.enter(heroTagView, delay: 0.45, scale: 0.7, duration: 0.4, pop: true)
        m.enter(heroHandleView, delay: 0.8, scale: 0.4, duration: 0.4, pop: true)
        sortedByTag(moreCards).enumerated().forEach { m.enter($1, delay: 0.55 + Double($0) * 0.07, dx: 28) }
        m.enter(quickHeaderView, delay: 0.75, dy: 8)
        sortedByTag(toolTiles).enumerated().forEach {
            m.enter($1, delay: 0.8 + Double($0) * 0.05, dy: 10, scale: 0.92, spring: true)
        }
        m.enter(planHeaderView, delay: 1.05, dy: 10)
        sortedByTag(planCards).enumerated().forEach { m.enter($1, delay: 1.11 + Double($0) * 0.06, dy: 10) }
        m.enter(recentSectionView, delay: 1.17, dy: 10)
        if !freeBannerContainer.isHidden {
            m.enter(freeBannerContainer, delay: 0.95, dy: -16, spring: true)
        }
        startHeroCycle(after: 1.1)
        scheduleMicroAnimations()
    }

    /// Sparkle spin + pulse (0.4 s, 3.6 s), shimmer (1.7 s, 4.7 s), CTA pulse (3.2 s).
    private func scheduleMicroAnimations() {
        guard !DS.Motion.reduceMotion else { return }
        microTimers.forEach { $0.invalidate() }
        let plan: [(TimeInterval, () -> Void)] = [
            (0.4, { [weak self] in self?.spinSparkle() }),
            (1.7, { [weak self] in self?.uploadButton.runShimmer() }),
            (3.2, { [weak self] in self?.uploadButton.pulse() }),
            (3.6, { [weak self] in self?.spinSparkle() }),
            (4.7, { [weak self] in self?.uploadButton.runShimmer() })
        ]
        microTimers = plan.map { delay, block in
            Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in block() }
        }
    }

    private func spinSparkle() {
        let icon: UIImageView = freeBannerContainer.isHidden ? creditsIconView : freeBannerIcon
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = Double.pi
        spin.duration = 0.6
        spin.timingFunction = CAMediaTimingFunction(name: .easeOut)
        let pulse = CAKeyframeAnimation(keyPath: "transform.scale")
        pulse.values = [1, 1.25, 1]
        pulse.keyTimes = [0, 0.5, 1]
        pulse.duration = 0.6
        icon.layer.add(spin, forKey: "spin")
        icon.layer.add(pulse, forKey: "pulse")
    }

    private func sortedByTag<T: UIView>(_ views: [T]) -> [T] {
        views.sorted { $0.tag < $1.tag }
    }
}

// MARK: - Scroll (glass header)

extension HomeViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === self.scrollView else { return }
        let y = scrollView.contentOffset.y + scrollView.adjustedContentInset.top
        let progress = min(max((y - 20) / 20, 0), 1)
        headerBackgroundView.alpha = progress
        headerHairline.alpha = progress
    }
}

extension HomeViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let v = pan.velocity(in: heroClipView)
        return abs(v.x) > abs(v.y)
    }
}

// MARK: - Recent projects collection

extension HomeViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        recentProjects.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: HomeProjectCell.reuseID, for: indexPath)
        if let cell = cell as? HomeProjectCell, let item = recentProjects[safe: indexPath.item] {
            cell.configure(project: item.project, versions: item.versions)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let doc = recentProjects[safe: indexPath.item]?.versions.last else { return }
        DS.Haptic.light()
        NavigationManager.shared.showResult(docID: doc.id, image: nil, reveal: false)
    }

    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        UIView.animate(withDuration: 0.12) {
            collectionView.cellForItem(at: indexPath)?.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.55, initialSpringVelocity: 0) {
            collectionView.cellForItem(at: indexPath)?.transform = .identity
        }
    }
}

private extension UIView {
    var subviewsLabels: [String] {
        subviews.flatMap { sub -> [String] in
            if let label = sub as? UILabel, let text = label.text { return [text] }
            return sub.subviewsLabels
        }
    }
}

// MARK: - Home focus (tag in the hero corner; chosen on onboarding O4)

enum HomeFocus: String {
    case interior, exterior, garden, surfaces

    static let defaultsKey = "redesign_home_focus"

    static var current: HomeFocus {
        #if DEBUG
        if AppQA.enabled, let focus = AppQA.homeFocus { return focus }
        #endif
        return UserDefaults.standard.string(forKey: defaultsKey).flatMap(HomeFocus.init(rawValue:)) ?? .interior
    }

    var option: DesignOption {
        switch self {
        case .interior: return .interior
        case .exterior: return .exterior
        case .garden: return .garden
        case .surfaces: return .newWalls
        }
    }

    var title: String {
        switch self {
        case .interior: return "Interior".localized
        case .exterior: return "Exterior".localized
        case .garden: return "Garden".localized
        case .surfaces: return "onboarding_goal_surfaces".localized
        }
    }

    var heroTitle: String {
        switch self {
        case .interior: return "Redesign a room".localized
        case .exterior: return "home_hero_exterior_title".localized
        case .garden: return "home_hero_garden_title".localized
        case .surfaces: return "home_hero_surfaces_title".localized
        }
    }

    var heroSubtitle: String {
        switch self {
        case .interior: return "New style in ~30 s. Your layout stays.".localized
        case .exterior: return "home_hero_exterior_subtitle".localized
        case .garden: return "home_hero_garden_subtitle".localized
        case .surfaces: return "home_hero_surfaces_subtitle".localized
        }
    }

    var symbol: String {
        switch self {
        case .interior: return "sofa"
        case .exterior: return "house"
        case .garden: return "tree"
        case .surfaces: return "paintroller"
        }
    }

    var beforeImage: UIImage? {
        switch self {
        case .interior: return UIImage(named: "home_hero_before")
        case .exterior: return UIImage(named: "ob_2_before_image")
        case .garden: return UIImage(named: "ob_3_before_image")
        case .surfaces: return UIImage(named: "ob_tool_walls_before")
        }
    }

    var afterImage: UIImage? {
        switch self {
        case .interior: return UIImage(named: "home_hero_after")
        case .exterior: return UIImage(named: "ob_2_after_image")
        case .garden: return UIImage(named: "ob_3_after_image")
        case .surfaces: return UIImage(named: "ob_tool_walls_after")
        }
    }
}
