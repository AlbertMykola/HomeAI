import UIKit

private struct Defaults {

    struct Text {
        static let headline = "ob_exterior_headline".localized
        static let description = "ob_exterior_description".localized
        static let next = "ob_continue".localized
    }

    struct Animation {
        static let firstStageDuration: TimeInterval = 0.8
        static let reboundDuration: TimeInterval = 0.3
        static let finalStageDuration: TimeInterval = 0.3
        static let holdDuration: TimeInterval = 0.6
        static let designWidth: CGFloat = 393
    }

    struct Overlay {
        static let fadeLocation: NSNumber = 0.51756
        static let tintAlpha: CGFloat = 0.5
    }

    struct Layout {
        static let compactHorizontalInset: CGFloat = 20
        static let regularHorizontalInset: CGFloat = 100
        static let dividerClipOffset: CGFloat = 4
        static let initialLeading: CGFloat = 389
        static let firstStageLeading: CGFloat = 191
        static let reboundLeading: CGFloat = 321
        static let currentPage: Int = 1
    }
}

final class OBExteriorViewController: UIViewController, OBPageChild {

    @IBOutlet private weak var bottomGradientView: UIView!
    @IBOutlet private weak var dividerView: UIView!
    @IBOutlet private weak var headlineLabel: UILabel!
    @IBOutlet private weak var nextButton: LiquidGlassButton!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var topGradientView: UIView!
    @IBOutlet private weak var pageControl: UIPageControl!

    @IBOutlet private weak var afterRevealTrailingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var afterRevealWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var dividerCenterXConstraint: NSLayoutConstraint!
    @IBOutlet private weak var dividerLineView: UIView!
    @IBOutlet private var contentHorizontalInsetConstraints: [NSLayoutConstraint]!

    @IBOutlet private var constraintsCollection: [NSLayoutConstraint]!
    weak var obDelegate: OBPageChildDelegate?

    private var revealAnimator: UIViewPropertyAnimator?
    private var revealRestartWorkItem: DispatchWorkItem?
    private var animationGeneration = 0
    private var isHeroRunning = false
    private var isHeroPaused = false
    private let bottomBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let bottomBlurMaskLayer = CAGradientLayer()
    private let bottomTintView = UIView()
    private let bottomGradientLayer = CAGradientLayer()
    private let topGradientLayer = CAGradientLayer()

    private struct RevealState {
        let leadingFraction: CGFloat

        static let initial = RevealState(
            leadingFraction: Defaults.Layout.initialLeading / Defaults.Animation.designWidth
        )
        static let firstStage = RevealState(
            leadingFraction: Defaults.Layout.firstStageLeading / Defaults.Animation.designWidth
        )
        static let rebound = RevealState(
            leadingFraction: Defaults.Layout.reboundLeading / Defaults.Animation.designWidth
        )
        static let final = RevealState(leadingFraction: 0)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        constraintsCollection.forEach { $0.scaleConstant() }
        view.clipsToBounds = true
        updateContentInsets()
        configureContent()
        configureDividerLine()
        configureGradientLayers()
        AmplitudeService.shared.logEvent(.showOBExterior)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        obPauseHeroAnimation()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        UIView.performWithoutAnimation {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            let overlayBounds = bottomGradientView.bounds
            bottomBlurView.frame = overlayBounds
            bottomBlurMaskLayer.frame = bottomBlurView.bounds
            bottomTintView.frame = overlayBounds
            bottomGradientLayer.frame = bottomTintView.bounds
            topGradientLayer.frame = topGradientView.bounds
            updateContentInsets()
            if !isHeroRunning, !isHeroPaused {
                applyRevealState(.initial)
            }
            CATransaction.commit()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.horizontalSizeClass != traitCollection.horizontalSizeClass else { return }
        updateContentInsets()
    }

    func obPrepareHeroForAppearance() {
        isHeroPaused = false
        applyRevealState(.initial)
        view.layoutIfNeeded()
    }

    func obPauseHeroAnimation() {
        guard isHeroRunning else { return }
        isHeroPaused = true
        stopRevealAnimation()
    }

    func obStartHeroAnimation() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.view.window != nil, !self.isHeroRunning else { return }
            self.isHeroPaused = false
            self.startRevealAnimation()
        }
    }

    private func updateContentInsets() {
        let inset = traitCollection.horizontalSizeClass == .regular
            ? Defaults.Layout.regularHorizontalInset
            : Defaults.Layout.compactHorizontalInset
        contentHorizontalInsetConstraints.forEach { constraint in
            if constraint.constant != inset {
                constraint.constant = inset
            }
        }
    }

    private func configureDividerLine() {
        dividerLineView.backgroundColor = Constants.Colors.yellowPremium
    }

    private func configureContent() {
        pageControl.currentPage = Defaults.Layout.currentPage
        subtitleLabel.text = Defaults.Text.description
        configureHeadline()
        nextButton.setTitle(Defaults.Text.next, for: .normal)
        nextButton.applyLiquidGlass(
            LiquidGlassConfig(
                style: .filled,
                title: Defaults.Text.next,
                foregroundColor: .black,
                backgroundColor: Constants.Colors.yellowPremium,
                font: nextButton.titleLabel?.font,
                cornerStyle: .capsule
            )
        )
    }

    private func configureHeadline() {
        let headline = Defaults.Text.headline
        let baseFont = headlineLabel.font ?? UIFont.systemFont(ofSize: 28)
        let emphasizedFont = UIFont(name: "Geologica-SemiBold", size: baseFont.pointSize) ?? baseFont
        let attributed = NSMutableAttributedString(
            string: headline,
            attributes: [
                .font: baseFont,
                .foregroundColor: UIColor.white
            ]
        )
        if let firstWordRange = headline.range(of: headline.split(separator: " ").first.map(String.init) ?? "") {
            attributed.addAttributes(
                [
                    .font: emphasizedFont,
                    .foregroundColor: Constants.Colors.yellowPremium
                ],
                range: NSRange(firstWordRange, in: headline)
            )
        }
        headlineLabel.attributedText = attributed
    }

    private func configureGradientLayers() {
        bottomGradientView.clipsToBounds = true
        bottomBlurView.isUserInteractionEnabled = false
        bottomTintView.isUserInteractionEnabled = false
        bottomTintView.backgroundColor = .clear
        bottomGradientView.insertSubview(bottomBlurView, at: 0)
        bottomGradientView.addSubview(bottomTintView)
        bottomTintView.layer.addSublayer(bottomGradientLayer)
        bottomBlurView.layer.mask = bottomBlurMaskLayer

        configureGradientLayer(
            bottomBlurMaskLayer,
            colors: [
                UIColor.clear,
                UIColor.black,
                UIColor.black
            ],
            locations: [0, Defaults.Overlay.fadeLocation, 1]
        )

        configureGradientLayer(
            bottomGradientLayer,
            colors: [
                UIColor.clear,
                UIColor.black.withAlphaComponent(Defaults.Overlay.tintAlpha),
                UIColor.black.withAlphaComponent(Defaults.Overlay.tintAlpha)
            ],
            locations: [0, Defaults.Overlay.fadeLocation, 1]
        )
        configureGradientLayer(
            topGradientLayer,
            colors: [
                UIColor.black.withAlphaComponent(Defaults.Overlay.tintAlpha),
                UIColor.black.withAlphaComponent(Defaults.Overlay.tintAlpha),
                UIColor.clear
            ],
            locations: [0, 0.3, 1]
        )
        topGradientView.layer.addSublayer(topGradientLayer)
    }

    private func configureGradientLayer(
        _ layer: CAGradientLayer,
        colors: [UIColor],
        locations: [NSNumber]
    ) {
        layer.colors = colors.map(\.cgColor)
        layer.locations = locations
        layer.startPoint = CGPoint(x: 0.5, y: 0)
        layer.endPoint = CGPoint(x: 0.5, y: 1)
    }

    private func startRevealAnimation() {
        stopRevealAnimation()
        isHeroRunning = true
        view.layoutIfNeeded()

        if UIAccessibility.isReduceMotionEnabled {
            applyRevealState(.firstStage)
            view.layoutIfNeeded()
            return
        }
        runRevealCycle()
    }

    private func runRevealCycle() {
        animationGeneration += 1
        let generation = animationGeneration
        applyRevealState(.initial)
        view.layoutIfNeeded()

        animateReveal(
            to: .firstStage,
            duration: Defaults.Animation.firstStageDuration,
            generation: generation
        ) { [weak self] in
            self?.animateReveal(
                to: .rebound,
                duration: Defaults.Animation.reboundDuration,
                generation: generation
            ) { [weak self] in
                self?.animateReveal(
                    to: .final,
                    duration: Defaults.Animation.finalStageDuration,
                    generation: generation
                ) { [weak self] in
                    self?.scheduleNextRevealCycle(generation: generation)
                }
            }
        }
    }

    private func animateReveal(
        to state: RevealState,
        duration: TimeInterval,
        generation: Int,
        completion: @escaping () -> Void
    ) {
        let animator = UIViewPropertyAnimator(
            duration: duration,
            curve: .easeInOut
        ) { [weak self] in
            self?.applyRevealState(state)
            self?.view.layoutIfNeeded()
        }
        animator.addCompletion { [weak self] position in
            guard let self,
                  position == .end,
                  self.animationGeneration == generation,
                  self.view.window != nil
            else { return }
            self.revealAnimator = nil
            completion()
        }
        revealAnimator = animator
        animator.startAnimation()
    }

    private func scheduleNextRevealCycle(generation: Int) {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.animationGeneration == generation,
                  self.view.window != nil
            else { return }
            self.runRevealCycle()
        }
        revealRestartWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Defaults.Animation.holdDuration,
            execute: workItem
        )
    }

    private func applyRevealState(_ state: RevealState) {
        let layoutWidth = max(view.bounds.width, 1)
        let leading = layoutWidth * state.leadingFraction
        afterRevealTrailingConstraint.constant = 0
        afterRevealWidthConstraint.constant = max(layoutWidth - leading, 0)
        dividerCenterXConstraint.constant = leading + Defaults.Layout.dividerClipOffset - layoutWidth / 2
    }

    private func stopRevealAnimation() {
        isHeroRunning = false
        animationGeneration += 1
        revealRestartWorkItem?.cancel()
        revealRestartWorkItem = nil
        revealAnimator?.stopAnimation(true)
        revealAnimator = nil
    }

    @IBAction private func nextAction(_ sender: UIButton) {
        obDelegate?.obChildRequestsNext(self)
    }
}
