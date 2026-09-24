import UIKit
import Lottie

private struct Defaults {

    struct Text {
        static let headline = "ob_change_headline".localized
        static let description = "ob_change_description".localized
        static let next = "ob_welcome_get_started".localized
    }

    struct Overlay {
        static let fadeLocation: NSNumber = 0.51756
        static let tintAlpha: CGFloat = 0.5
    }

    struct Layout {
        static let compactHorizontalInset: CGFloat = 20
        static let regularHorizontalInset: CGFloat = 100
        static let currentPage: Int = 3
    }

    struct Lottie {
        static let animationName = "iphone ob 4"
    }
}

final class RateOBViewController: UIViewController, OBPageChild {

    @IBOutlet private weak var lottieContainerView: UIView!
    @IBOutlet private weak var bottomGradientView: UIView!
    @IBOutlet private weak var headlineLabel: UILabel!
    @IBOutlet private weak var nextButton: LiquidGlassButton!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var topGradientView: UIView!
    @IBOutlet private weak var pageControl: UIPageControl!

    @IBOutlet private var contentHorizontalInsetConstraints: [NSLayoutConstraint]!
    @IBOutlet private var constraintsCollection: [NSLayoutConstraint]!

    weak var obDelegate: OBPageChildDelegate?

    private var lottieView: LottieAnimationView?
    private var isHeroRunning = false
    private let bottomBlurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let bottomBlurMaskLayer = CAGradientLayer()
    private let bottomTintView = UIView()
    private let bottomGradientLayer = CAGradientLayer()
    private let topGradientLayer = CAGradientLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        constraintsCollection.forEach { $0.scaleConstant() }
        view.clipsToBounds = true
        updateContentInsets()
        configureContent()
        configureLottie()
        configureGradientLayers()
        AmplitudeService.shared.logEvent(.showOBRate)
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
            CATransaction.commit()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.horizontalSizeClass != traitCollection.horizontalSizeClass else { return }
        updateContentInsets()
    }

    func obPrepareHeroForAppearance() {
        if UIAccessibility.isReduceMotionEnabled {
            lottieView?.currentProgress = 1
            lottieView?.pause()
            return
        }
        lottieView?.currentProgress = 0
        lottieView?.pause()
    }

    func obPauseHeroAnimation() {
        isHeroRunning = false
        lottieView?.pause()
    }

    func obStartHeroAnimation() {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.view.window != nil else { return }
            self.startLottieIfNeeded()
        }
    }

    func obSetActionLoading(_ loading: Bool) {
        nextButton.setLoading(loading)
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

    private func configureLottie() {
        lottieContainerView.clipsToBounds = true
        lottieContainerView.backgroundColor = .black
        lottieView?.removeFromSuperview()

        let animationView = LottieAnimationView(name: Defaults.Lottie.animationName)
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.contentMode = .scaleAspectFill
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.loopMode = .loop
        animationView.animationSpeed = 1

        lottieContainerView.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.topAnchor.constraint(equalTo: lottieContainerView.topAnchor),
            animationView.leadingAnchor.constraint(equalTo: lottieContainerView.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: lottieContainerView.trailingAnchor),
            animationView.bottomAnchor.constraint(equalTo: lottieContainerView.bottomAnchor)
        ])
        lottieView = animationView
    }

    private func startLottieIfNeeded() {
        guard !isHeroRunning else { return }
        if UIAccessibility.isReduceMotionEnabled {
            lottieView?.currentProgress = 1
            lottieView?.pause()
            return
        }
        isHeroRunning = true
        lottieView?.currentProgress = 0
        lottieView?.play()
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

    @IBAction private func nextAction(_ sender: UIButton) {
        obDelegate?.obChildRequestsNext(self)
    }
}
