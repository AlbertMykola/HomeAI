import Adapty
import StoreKit
import UIKit

private struct Defaults {
    struct Colors {
        static let background = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 11 / 255, green: 11 / 255, blue: 13 / 255, alpha: 1)
                : .systemBackground
        }
        static let card = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 20 / 255, green: 20 / 255, blue: 25 / 255, alpha: 1)
                : .secondarySystemBackground
        }
        static let cardBorder = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 44 / 255, green: 44 / 255, blue: 46 / 255, alpha: 1)
                : .separator
        }
        static let premiumGreen = UIColor(red: 165 / 255, green: 238 / 255, blue: 47 / 255, alpha: 1)
        static let continueGreen = UIColor(red: 0 / 255, green: 146 / 255, blue: 12 / 255, alpha: 1)
        static let primaryText = UIColor.label
        static let secondaryText = UIColor.secondaryLabel
        static let discount = UIColor(red: 234 / 255, green: 10 / 255, blue: 40 / 255, alpha: 1)
        static let continueTitle = UIColor.white
        static let selectedBadgeTitle = UIColor.black
        static let unselectedBadgeTitle = UIColor.white
        static let sliderKnobBorder = UIColor.white
    }

    struct Layout {
        static let cardCornerRadius: CGFloat = 12
        static let cardBorderWidth: CGFloat = 1.5
        static let badgeCornerRadius: CGFloat = 4
        static let comparisonDuration: TimeInterval = 3.5
        static let closeDelay: TimeInterval = 3
        static let topOverlayAlpha: CGFloat = 0.7
        static let bottomOverlayAlpha: CGFloat = 0.85
    }

    struct Text {
        static var roomTitle: String { "See your room in a new style".localized }
        static var nextDesignTitle: String { "Create the next design for your space".localized }
        static var saveTitle: String { "Keep the design you love".localized }
        static var editTitle: String { "Make your design feel just right".localized }
        static var benefits: [String] {
            [
                "Unlimited AI Renders".localized,
                "All Premium Styles".localized,
                "Ultra Fast Rendering".localized,
                "Design Every Corner".localized
            ]
        }
        static var noPayNow: String { "No Pay Now".localized }
        static var restore: String { "Restore".localized }
        static var terms: String { "Terms".localized }
        static var privacy: String { "Privacy".localized }
        static var notNow: String { "Not now".localized }
        static var error: String { "Error".localized }
        static var ok: String { "OK".localized }
    }
}

final class PaywallViewController: UIViewController {

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var heroContainerView: UIView!
    @IBOutlet private weak var afterClipView: UIView!
    @IBOutlet private weak var topGradientView: UIView!
    @IBOutlet private weak var bottomGradientView: UIView!
    @IBOutlet private weak var sliderView: UIView!
    @IBOutlet private weak var sliderKnobView: UIView!
    @IBOutlet private weak var afterClipWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var sliderCenterConstraint: NSLayoutConstraint!

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private var benefitRows: [UIView]!
    @IBOutlet private var benefitLabels: [UILabel]!

    @IBOutlet private weak var topPlanView: UIView!
    @IBOutlet private weak var topPlanBorderView: UIView!
    @IBOutlet private weak var topPlanButton: UIButton!
    @IBOutlet private weak var topPlanTitleLabel: UILabel!
    @IBOutlet private weak var topBillingLabel: UILabel!
    @IBOutlet private weak var topPriceLabel: UILabel!
    @IBOutlet private weak var topBadgeView: UIView!
    @IBOutlet private weak var topBadgeLabel: UILabel!

    @IBOutlet private weak var continueButton: UIButton!
    @IBOutlet private weak var noPayingLabel: UILabel!
    @IBOutlet private weak var restoreButton: UIButton!
    @IBOutlet private weak var termsButton: UIButton!
    @IBOutlet private weak var privacyButton: UIButton!
    @IBOutlet private weak var topCloseButton: UIButton!
    @IBOutlet private weak var indicator: UIActivityIndicatorView!

    @IBOutlet private var constraintsCollection: [NSLayoutConstraint]!

    var placement: String?
    var origin: PaywallOrigin = .inApp
    var onSuccessfulPurchase: (() -> Void)?

    private let adaptyService = AdaptyService.shared
    private let amplitude = AmplitudeService.shared

    private var selectedPaywallUIRow: PaywallUIRow = .top
    private var paywallPresentation: PaywallProductsPresentation?
    private var loadedProducts: [AdaptyPaywallProduct] = []
    private let paywallSessionID = UUID().uuidString
    private var productLoadStartedAt: Date?
    private var isPaywallLoading = true
    private var isPurchasing = false
    private var indicatorCounter = 0
    private var closeWorkItem: DispatchWorkItem?
    private var comparisonWorkItems: [DispatchWorkItem] = []
    private var hasPreparedHeroLayout = false
    private var hasStartedMotion = false
    private var heroHeightConstraint: NSLayoutConstraint?
    private var titleHeightConstraint: NSLayoutConstraint?
    private var benefitsHeightConstraint: NSLayoutConstraint?
    private var plansHeightConstraint: NSLayoutConstraint?
    private var paywallDock: UIView?
    private var hasLoadedCurrentFlow = false
    private var didLogAdaptyShow = false
    private var isPaywallVisible = false

    private var sortedBenefitLabels: [UILabel] {
        benefitLabels.sorted { $0.tag < $1.tag }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        traitCollection.userInterfaceStyle == .dark ? .lightContent : .darkContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        modalPresentationCapturesStatusBarAppearance = true
        configureStaticContent()
        configureChrome()
        configureResponsiveLayout()
        configureCloseControls()
        configureIndicator()
        applyTheme()
        setPaywallLoading(true)
        #if DEBUG
        if AppQA.enabled || ProcessInfo.processInfo.arguments.contains("--paywall-layout-preview") {
            applyLayoutPreviewProducts()
            return
        }
        #endif
        loadPaywallProducts()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateResponsiveSizes()
        prepareHeroLayoutIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isPaywallVisible = true
        logAdaptyShowIfReady()
        amplitude.logEvent(.showPaywall(id: placement ?? ""))
        logPaywall("paywall_shown")
        scheduleTopCloseButtonAppearance()
        startMotionIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isPaywallVisible = false
        cancelScheduledWork()
        if isBeingDismissed || isMovingFromParent {
            adaptyService.paywallClosed()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateResponsiveSizes()
        continueButton.layer.cornerRadius = continueButton.bounds.height / 2
        sliderKnobView.layer.cornerRadius = sliderKnobView.bounds.height / 2
        topGradientView.updateGradientFrame()
        bottomGradientView.updateGradientFrame()
        prepareHeroLayoutIfNeeded()
        updateShimmerFramesIfNeeded()
        startContinueShineIfNeeded()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        applyTheme()
        if isPaywallLoading {
            stopProductSkeleton()
            startProductSkeleton()
        }
    }

    private func configureStaticContent() {
        switch placement {
        case Constants.Keys.reachedLimit:
            titleLabel.text = Defaults.Text.nextDesignTitle
        case Constants.Keys.saveImagePlacement, Constants.Keys.shareImagePlacement:
            titleLabel.text = Defaults.Text.saveTitle
        case Constants.Keys.detailsEditPlacement:
            titleLabel.text = Defaults.Text.editTitle
        default:
            titleLabel.text = Defaults.Text.roomTitle
        }
        zip(sortedBenefitLabels, Defaults.Text.benefits).forEach { label, text in
            label.text = text
        }
        noPayingLabel.text = Defaults.Text.noPayNow
        restoreButton.setTitle(Defaults.Text.restore, for: .normal)
        termsButton.setTitle(Defaults.Text.terms, for: .normal)
        privacyButton.setTitle(Defaults.Text.privacy, for: .normal)
    }

    #if DEBUG
    private func applyLayoutPreviewProducts() {
        let weekly = PaywallProductsPresentation.ProductRow(
            storeIndex: 0,
            title: PaywallProductCopy.weeklyAccessTitle,
            priceDisplay: PaywallPriceDisplay(
                billedPrice: "$8.99", billingPeriod: PaywallProductCopy.weeklyBillingPeriod,
                emphasizedPrice: "$8.99", emphasizedPeriod: PaywallProductCopy.perWeek
            ),
            badge: .init(kind: .trial, title: PaywallProductCopy.trialBadgeTitle(days: 3)),
            hasFreeTrial: true
        )
        let presentation = PaywallProductsPresentation(top: weekly)
        paywallPresentation = presentation
        applyPaywallPresentation(presentation)
        setPaywallLoading(false)
    }
    #endif

    private func configureChrome() {
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.backgroundColor = .clear
        scrollView.clipsToBounds = true

        [topPlanView].forEach {
            $0?.layer.cornerRadius = Defaults.Layout.cardCornerRadius
            $0?.layer.cornerCurve = .continuous
            $0?.clipsToBounds = false
        }
        benefitRows.forEach { $0.clipsToBounds = false }
        topPlanView.superview?.clipsToBounds = false
        topPlanView.superview?.superview?.clipsToBounds = false
        [topPlanBorderView].forEach { borderView in
            borderView?.backgroundColor = .clear
            borderView?.isUserInteractionEnabled = false
            borderView?.layer.cornerRadius = Defaults.Layout.cardCornerRadius
            borderView?.layer.cornerCurve = .continuous
            borderView?.layer.borderWidth = Defaults.Layout.cardBorderWidth
        }
        [topBadgeView].forEach {
            $0?.layer.cornerRadius = Defaults.Layout.badgeCornerRadius
            $0?.layer.cornerCurve = .continuous
            $0?.layer.zPosition = 10
        }
        topPlanView?.bringSubviewToFront(topBadgeView)

        heroContainerView.clipsToBounds = true
        afterClipView.clipsToBounds = true
        sliderKnobView.layer.borderWidth = 2
        sliderKnobView.layer.shadowOpacity = 0.5
        sliderKnobView.layer.shadowRadius = 6

        continueButton.layer.cornerCurve = .continuous
        continueButton.clipsToBounds = true
        continueButton.adjustsImageWhenDisabled = false
        continueButton.setTitleColor(Defaults.Colors.continueTitle, for: .normal)
        continueButton.setTitleColor(Defaults.Colors.continueTitle, for: .disabled)

        [restoreButton, termsButton, privacyButton].forEach {
            $0?.setContentHuggingPriority(.required, for: .horizontal)
            $0?.setContentCompressionResistancePriority(.required, for: .horizontal)
        }
    }

    /// Move the purchase controls out of the scrolling content. The original XIB
    /// still owns the views and actions; Auto Layout sizes the dock to the safe area.
    private func configureResponsiveLayout() {
        guard let contentContainer = heroContainerView.superview,
              let ctaContainer = continueButton.superview,
              let legalContainer = restoreButton.superview?.superview,
              ctaContainer.superview === contentContainer,
              legalContainer.superview === contentContainer else { return }

        let scaled: (CGFloat) -> CGFloat = { $0.scaledByHeight() }
        var scaledConstraints = Set<ObjectIdentifier>()
        constraintsCollection.forEach { constraint in
            guard scaledConstraints.insert(ObjectIdentifier(constraint)).inserted else { return }
            constraint.scaleConstant()
        }

        heroHeightConstraint = heroContainerView.constraints.first { $0.firstAttribute == .height }
        titleHeightConstraint = titleLabel.superview?.constraints.first { $0.firstAttribute == .height }
        benefitsHeightConstraint = benefitRows.first?.superview?.superview?.constraints.first { $0.firstAttribute == .height }
        plansHeightConstraint = topPlanView.superview?.superview?.constraints.first { $0.firstAttribute == .height }
        titleLabel.superview?.constraints.first {
            ($0.firstItem as? UIView) === titleLabel && $0.firstAttribute == .top
        }?.constant = scaled(12)
        titleLabel.superview?.constraints.first {
            ($0.firstItem as? UIView) === titleLabel.superview && $0.firstAttribute == .bottom
        }?.constant = scaled(6)
        plansContentTopConstraint()?.constant = scaled(12)
        plansHeightConstraint?.constant = scaled(88)
        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8
        titleLabel.font = UIFontMetrics(forTextStyle: .title2).scaledFont(
            for: UIFont(name: "Geologica-SemiBold", size: scaled(25)) ?? .systemFont(ofSize: scaled(25), weight: .semibold)
        )
        titleLabel.adjustsFontForContentSizeCategory = true
        sortedBenefitLabels.forEach { label in
            label.numberOfLines = 2
            label.font = UIFontMetrics(forTextStyle: .body).scaledFont(
                for: UIFont(name: "Geologica-Regular", size: scaled(14)) ?? .systemFont(ofSize: scaled(14))
            )
            label.adjustsFontForContentSizeCategory = true
        }
        let planTitleSize: CGFloat = 16
        let billingSize: CGFloat = 12
        let priceSize: CGFloat = 18
        for label in [topPlanTitleLabel] {
            let fontSize = scaled(planTitleSize)
            label?.font = UIFontMetrics(forTextStyle: .headline).scaledFont(
                for: UIFont(name: "Geologica-SemiBold", size: fontSize) ?? .systemFont(ofSize: fontSize, weight: .semibold)
            )
            label?.adjustsFontForContentSizeCategory = true
            label?.minimumScaleFactor = 0.8
            label?.adjustsFontSizeToFitWidth = true
        }
        for label in [topBillingLabel] {
            let fontSize = scaled(billingSize)
            label?.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(
                for: UIFont(name: "Geologica-Regular", size: fontSize) ?? .systemFont(ofSize: fontSize)
            )
            label?.numberOfLines = 2
            label?.adjustsFontForContentSizeCategory = true
            label?.minimumScaleFactor = 0.8
            label?.adjustsFontSizeToFitWidth = true
        }
        for (plan, billingLabel) in [(topPlanView, topBillingLabel)] {
            if let plan, let billingLabel {
                billingLabel.trailingAnchor.constraint(lessThanOrEqualTo: plan.trailingAnchor, constant: -16).isActive = true
            }
        }
        for label in [topPriceLabel] {
            let fontSize = scaled(priceSize)
            label?.font = UIFontMetrics(forTextStyle: .headline).scaledFont(
                for: UIFont(name: "Geologica-SemiBold", size: fontSize) ?? .systemFont(ofSize: fontSize, weight: .semibold)
            )
            label?.adjustsFontForContentSizeCategory = true
            label?.minimumScaleFactor = 0.8
            label?.adjustsFontSizeToFitWidth = true
        }
        continueButton.titleLabel?.font = UIFont(
            name: "Geologica-SemiBold", size: scaled(16)
        ) ?? .systemFont(ofSize: scaled(16), weight: .semibold)
        noPayingLabel.font = UIFont(
            name: "Geologica-Light", size: scaled(13)
        ) ?? .systemFont(ofSize: scaled(13))
        [restoreButton, termsButton, privacyButton].forEach { button in
            button?.titleLabel?.font = UIFont(
                name: "Geologica-Regular", size: scaled(11)
            ) ?? .systemFont(ofSize: scaled(11))
        }
        restoreButton.superview?.subviews.compactMap { $0 as? UILabel }.forEach { label in
            label.font = UIFont.systemFont(ofSize: scaled(11))
        }

        for container in [ctaContainer, legalContainer] {
            container.removeFromSuperview()
            container.translatesAutoresizingMaskIntoConstraints = false
        }

        let dock = UIView()
        dock.translatesAutoresizingMaskIntoConstraints = false
        dock.backgroundColor = Defaults.Colors.background
        dock.addSubview(ctaContainer)
        dock.addSubview(legalContainer)
        view.addSubview(dock)
        paywallDock = dock

        // The XIB's original root-to-scroll bottom and horizontal constraints are
        // replaced with a safe-area dock and a centered readable width on iPad.
        for constraint in view.constraints {
            let involvesScroll = (constraint.firstItem as? UIView) === scrollView ||
                (constraint.secondItem as? UIView) === scrollView
            let involvesClose = (constraint.firstItem as? UIView) === topCloseButton ||
                (constraint.secondItem as? UIView) === topCloseButton
            if involvesScroll && [.bottom, .leading, .trailing].contains(constraint.firstAttribute) {
                constraint.isActive = false
            }
            if involvesClose && constraint.firstAttribute == .leading {
                constraint.isActive = false
            }
        }

        // Keep the CTA dock proportional to the reference screen height.
        ctaContainer.constraints.first { $0.firstAttribute == .height }?.constant = scaled(96)
        ctaContainer.constraints.first {
            ($0.firstItem as? UIView) === continueButton && $0.firstAttribute == .top
        }?.constant = scaled(10)
        ctaContainer.constraints.first {
            ($0.firstItem as? UIView) === continueButton && $0.firstAttribute == .height
        }?.constant = max(44, scaled(54))
        legalContainer.constraints.first { $0.firstAttribute == .height }?.constant = scaled(44)
        restoreButton.superview?.constraints.first { $0.firstAttribute == .height }?.constant = scaled(28)

        let fillWidth = scrollView.widthAnchor.constraint(equalTo: view.widthAnchor)
        fillWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            scrollView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            fillWidth,
            scrollView.widthAnchor.constraint(lessThanOrEqualToConstant: 560),
            scrollView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor),
            scrollView.bottomAnchor.constraint(equalTo: dock.topAnchor),
            dock.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            dock.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            dock.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            ctaContainer.leadingAnchor.constraint(equalTo: dock.leadingAnchor),
            ctaContainer.trailingAnchor.constraint(equalTo: dock.trailingAnchor),
            ctaContainer.topAnchor.constraint(equalTo: dock.topAnchor),
            legalContainer.leadingAnchor.constraint(equalTo: dock.leadingAnchor),
            legalContainer.trailingAnchor.constraint(equalTo: dock.trailingAnchor),
            legalContainer.topAnchor.constraint(equalTo: ctaContainer.bottomAnchor),
            legalContainer.bottomAnchor.constraint(equalTo: dock.bottomAnchor),
            topCloseButton.leadingAnchor.constraint(equalTo: dock.leadingAnchor, constant: 12)
        ])
        view.bringSubviewToFront(topCloseButton)
        view.bringSubviewToFront(indicator)
    }

    private func updateResponsiveSizes() {
        let isAccessibilitySize = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let isCompactViewport = UIScreen.main.bounds.height <= 700 && !isAccessibilitySize
        titleLabel.numberOfLines = isAccessibilitySize ? 3 : 2
        topPriceLabel.isHidden = isAccessibilitySize
        let scaled: (CGFloat) -> CGFloat = { $0.scaledByHeight() }
        let responsivePlansHeight: CGFloat = isAccessibilitySize
            ? scaled(120)
            : scaled(88)
        if plansHeightConstraint?.constant != responsivePlansHeight {
            plansHeightConstraint?.constant = responsivePlansHeight
        }
        let heroHeight = scaled(isCompactViewport ? 280 : 300)
        heroContainerView.alpha = 1
        if heroHeightConstraint?.constant != heroHeight {
            heroHeightConstraint?.constant = heroHeight
        }
        let titleHeight: CGFloat = isAccessibilitySize ? scaled(110) : scaled(82)
        if titleHeightConstraint?.constant != titleHeight {
            titleHeightConstraint?.constant = titleHeight
        }
        let benefitsHeight: CGFloat = isAccessibilitySize
            ? scaled(220)
            : scaled(120)
        if benefitsHeightConstraint?.constant != benefitsHeight {
            benefitsHeightConstraint?.constant = benefitsHeight
        }

        let contentContainer = heroContainerView.superview
        let contentSpacing: [(String, CGFloat)] = [
            ("content-title-gap", isCompactViewport ? 6 : 8),
            ("content-benefits-gap", isCompactViewport ? 6 : 8),
            ("content-plans-gap", isCompactViewport ? 6 : 8)
        ]
        contentSpacing.forEach { identifier, value in
            contentContainer?.constraints.first { $0.identifier == identifier }?.constant = scaled(value)
        }
        plansContentTopConstraint()?.constant = scaled(isCompactViewport ? 8 : 12)

        let benefitRowGap = scaled(isCompactViewport ? 5 : 10)
        benefitRows.first?.superview?.constraints
            .filter { $0.identifier?.hasPrefix("benefit-row-gap-") == true }
            .forEach { $0.constant = benefitRowGap }
        let iconSizes: [(CGFloat, CGFloat)] = isCompactViewport
            ? [(24, 24), (24, 24), (24, 24), (24, 24)]
            : [(33, 32), (30, 32), (33, 34), (32, 32)]
        for (row, size) in zip(benefitRows, iconSizes) {
            guard let icon = row.subviews.first(where: { $0 is UIImageView }) else { continue }
            icon.constraints.first { $0.firstAttribute == .width }?.constant = scaled(size.0)
            icon.constraints.first { $0.firstAttribute == .height }?.constant = scaled(size.1)
        }
    }

    private func plansContentTopConstraint() -> NSLayoutConstraint? {
        guard let plansContent = topPlanView.superview else { return nil }
        return plansContent.superview?.constraints.first {
            ($0.firstItem as? UIView) === plansContent && $0.firstAttribute == .top
        }
    }

    private func paywallProperties(productIndex: Int? = nil) -> [String: Any] {
        var properties: [String: Any] = [
            "paywall_session_id": paywallSessionID,
            "placement": placement ?? Constants.Keys.defaults,
            "origin": {
                switch origin { case .onboarding: return "onboarding"; case .inApp: return "in_app" }
            }(),
            "paywall_variant": "native_responsive_v1",
            "storefront": SKPaymentQueue.default().storefront?.countryCode ?? "unknown"
        ]
        if let productIndex, loadedProducts.indices.contains(productIndex) {
            let product = loadedProducts[productIndex]
            properties["product_id"] = product.vendorProductId
            properties["product_index"] = productIndex
            properties["variation_id"] = product.variationId
            properties["paywall_name"] = product.paywallName
            properties["ab_test_name"] = product.paywallABTestName
            properties["price"] = NSDecimalNumber(decimal: product.price).doubleValue
            properties["currency"] = product.currencyCode ?? "unknown"
            properties["trial_offer_presented"] = product.paywallHasFreeTrial
        }
        return properties
    }

    private func logPaywall(_ name: String, productIndex: Int? = nil, extra: [String: Any] = [:]) {
        var properties = paywallProperties(productIndex: productIndex)
        properties.merge(extra) { _, new in new }
        amplitude.logPaywallEvent(name, properties: properties)
    }

    private func errorProperties(_ error: Error) -> [String: Any] {
        let nsError = error as NSError
        return ["error_domain": nsError.domain, "error_code": nsError.code]
    }

    private func applyTheme() {
        view.backgroundColor = Defaults.Colors.background
        titleLabel.textColor = Defaults.Colors.primaryText
        sortedBenefitLabels.forEach { $0.textColor = Defaults.Colors.primaryText }
        [topPlanTitleLabel].forEach { $0?.textColor = Defaults.Colors.primaryText }
        [topBillingLabel, noPayingLabel].forEach { $0?.textColor = Defaults.Colors.secondaryText }
        [restoreButton, termsButton, privacyButton].forEach {
            $0?.setTitleColor(Defaults.Colors.secondaryText, for: .normal)
        }
        restoreButton.superview?.subviews
            .compactMap { $0 as? UILabel }
            .forEach { $0.textColor = Defaults.Colors.secondaryText.withAlphaComponent(0.5) }

        [topPlanView].forEach { $0?.backgroundColor = Defaults.Colors.card }
        sliderView.backgroundColor = Defaults.Colors.premiumGreen
        sliderKnobView.backgroundColor = Defaults.Colors.premiumGreen
        sliderKnobView.layer.borderColor = resolvedCGColor(Defaults.Colors.sliderKnobBorder)
        sliderKnobView.layer.shadowColor = resolvedCGColor(Defaults.Colors.premiumGreen)

        continueButton.backgroundColor = Defaults.Colors.continueGreen
        continueButton.setTitleColor(Defaults.Colors.continueTitle, for: .normal)
        indicator.color = Defaults.Colors.premiumGreen

        applyHeroGradients()
        applyCloseButtonColor()
        if let presentation = paywallPresentation {
            apply(row: presentation.top, titleLabel: topPlanTitleLabel, billingLabel: topBillingLabel, priceLabel: topPriceLabel)
            updateSelection(animated: false)
        } else {
            applyPlanStyle(topPlanView, borderView: topPlanBorderView, selected: false)
        }
        setNeedsStatusBarAppearanceUpdate()
    }

    private func resolvedCGColor(_ color: UIColor) -> CGColor {
        color.resolvedColor(with: traitCollection).cgColor
    }

    private func applyHeroGradients() {
        topGradientView.isUserInteractionEnabled = false
        bottomGradientView.isUserInteractionEnabled = false
        let overlay = Defaults.Colors.background.resolvedColor(with: traitCollection)
        let topAlpha: CGFloat = traitCollection.userInterfaceStyle == .dark
            ? Defaults.Layout.topOverlayAlpha
            : 0.75
        let bottomAlpha: CGFloat = traitCollection.userInterfaceStyle == .dark
            ? Defaults.Layout.bottomOverlayAlpha
            : 1
        topGradientView.setGradient(stops: [
            UIView.GradientStop(percent: 0, color: overlay.withAlphaComponent(topAlpha)),
            UIView.GradientStop(percent: 100, color: overlay.withAlphaComponent(0))
        ])
        bottomGradientView.setGradient(stops: [
            UIView.GradientStop(percent: 0, color: overlay.withAlphaComponent(0)),
            UIView.GradientStop(percent: 100, color: overlay.withAlphaComponent(bottomAlpha))
        ])
        topGradientView.updateGradientFrame()
        bottomGradientView.updateGradientFrame()
        heroContainerView.bringSubviewToFront(sliderView)
        heroContainerView.bringSubviewToFront(sliderKnobView)
    }

    private func configureCloseControls() {
        topCloseButton.isHidden = false
        topCloseButton.alpha = 0
        topCloseButton.isEnabled = false

        var configuration = topCloseButton.configuration ?? .plain()
        configuration.image = UIImage(
            systemName: "xmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        )
        topCloseButton.configuration = configuration
    }

    private func applyCloseButtonColor() {
        var configuration = topCloseButton.configuration ?? .plain()
        configuration.baseForegroundColor = Defaults.Colors.secondaryText
        topCloseButton.configuration = configuration
    }

    private func configureIndicator() {
        indicator.hidesWhenStopped = true
        indicator.color = Defaults.Colors.premiumGreen
        indicator.stopAnimating()
    }

    private func scheduleTopCloseButtonAppearance() {
        closeWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseOut) {
                self.topCloseButton.alpha = 1
            } completion: { _ in
                self.topCloseButton.isEnabled = true
            }
        }
        closeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Defaults.Layout.closeDelay, execute: workItem)
    }

    private func startMotionIfNeeded() {
        guard !hasStartedMotion else { return }
        hasStartedMotion = true
        guard !UIAccessibility.isReduceMotionEnabled else {
            setFinalMotionState()
            return
        }
        runComparisonCycle()
    }

    private func prepareHeroLayoutIfNeeded() {
        let width = heroContainerView.bounds.width
        guard width > 1, !hasPreparedHeroLayout else { return }
        hasPreparedHeroLayout = true
        afterClipWidthConstraint.constant = 0
        sliderCenterConstraint.constant = -width / 2
        sliderView.alpha = 0
        sliderKnobView.alpha = 0
        sliderKnobView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
    }

    private func runComparisonCycle() {
        comparisonWorkItems.forEach { $0.cancel() }
        comparisonWorkItems.removeAll()

        let width = heroContainerView.bounds.width
        UIView.performWithoutAnimation {
            self.afterClipWidthConstraint.constant = 0
            self.sliderCenterConstraint.constant = -width / 2
            self.sliderView.alpha = 0
            self.sliderKnobView.alpha = 0
            self.sliderKnobView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            self.view.layoutIfNeeded()
        }

        scheduleComparisonStep(after: 0.2) { [weak self] in
            UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut) {
                self?.sliderView.alpha = 1
                self?.sliderKnobView.alpha = 1
                self?.sliderKnobView.transform = .identity
            }
        }

        scheduleComparisonStep(after: 0.3) { [weak self] in
            guard let self else { return }
            self.afterClipWidthConstraint.constant = self.heroContainerView.bounds.width
            self.sliderCenterConstraint.constant = self.heroContainerView.bounds.width / 2
            UIView.animate(
                withDuration: 1.5,
                delay: 0,
                options: [.curveEaseOut, .beginFromCurrentState]
            ) {
                self.view.layoutIfNeeded()
            }
        }

        scheduleComparisonStep(after: 1.8) { [weak self] in
            guard let self else { return }
            self.afterClipWidthConstraint.constant = self.heroContainerView.bounds.width / 2
            self.sliderCenterConstraint.constant = 0
            UIView.animate(
                withDuration: 0.8,
                delay: 0,
                options: [.curveEaseInOut, .beginFromCurrentState]
            ) {
                self.view.layoutIfNeeded()
            }
        }

        scheduleComparisonStep(after: Defaults.Layout.comparisonDuration) { [weak self] in
            self?.runComparisonCycle()
        }
    }

    private func scheduleComparisonStep(after delay: TimeInterval, action: @escaping () -> Void) {
        let item = DispatchWorkItem(block: action)
        comparisonWorkItems.append(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func setFinalMotionState() {
        view.layoutIfNeeded()
        heroContainerView.alpha = 1
        afterClipWidthConstraint.constant = heroContainerView.bounds.width / 2
        sliderCenterConstraint.constant = 0
        sliderView.alpha = 1
        sliderKnobView.alpha = 1
        sliderKnobView.transform = .identity
        view.layoutIfNeeded()
    }

    private func cancelScheduledWork() {
        closeWorkItem?.cancel()
        comparisonWorkItems.forEach { $0.cancel() }
        comparisonWorkItems.removeAll()
    }

    private func loadPaywallProducts() {
        requestPaywallProducts(placementID: placement ?? Constants.Keys.defaults, isFallbackAttempt: false)
    }

    private func logAdaptyShowIfReady() {
        guard isPaywallVisible, hasLoadedCurrentFlow, !didLogAdaptyShow else { return }
        didLogAdaptyShow = true
        adaptyService.paywallShown()
    }

    private func requestPaywallProducts(placementID: String, isFallbackAttempt: Bool) {
        productLoadStartedAt = Date()
        logPaywall("paywall_products_load_started", extra: [
            "requested_placement": placementID,
            "is_fallback": isFallbackAttempt
        ])
        if !isFallbackAttempt {
            startIndicator()
            amplitude.logEvent(.getProducts)
        }

        adaptyService.fetchPaywallPresentation(placementID: placementID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let payload):
                    self.stopIndicator()
                    self.amplitude.logEvent(.gotProducts)
                    self.loadedProducts = payload.products
                    self.hasLoadedCurrentFlow = true
                    self.logAdaptyShowIfReady()
                    self.logPaywall("paywall_products_loaded", extra: [
                        "requested_placement": placementID,
                        "is_fallback": isFallbackAttempt,
                        "product_count": payload.products.count,
                        "load_latency_ms": self.productLoadStartedAt.map { max(0, Int(Date().timeIntervalSince($0) * 1_000)) } ?? 0
                    ])
                    self.paywallPresentation = payload.presentation
                    UIView.performWithoutAnimation {
                        self.applyPaywallPresentation(payload.presentation)
                        self.setPaywallLoading(false)
                        self.view.layoutIfNeeded()
                    }
                case .failure(let error):
                    var failure = self.errorProperties(error)
                    failure["requested_placement"] = placementID
                    failure["is_fallback"] = isFallbackAttempt
                    failure["load_latency_ms"] = self.productLoadStartedAt.map { max(0, Int(Date().timeIntervalSince($0) * 1_000)) } ?? 0
                    self.logPaywall("paywall_products_load_failed", extra: failure)
                    let canFallback = !isFallbackAttempt && placementID != Constants.Keys.defaults
                    if canFallback {
                        self.requestPaywallProducts(
                            placementID: Constants.Keys.defaults,
                            isFallbackAttempt: true
                        )
                    } else {
                        self.stopIndicator()
                        self.setPaywallLoading(false)
                        self.showPaywallError(error)
                    }
                }
            }
        }
    }

    private func applyPaywallPresentation(_ presentation: PaywallProductsPresentation) {
        apply(row: presentation.top, titleLabel: topPlanTitleLabel, billingLabel: topBillingLabel, priceLabel: topPriceLabel)
        applyBadgeContent(to: topBadgeView, label: topBadgeLabel, badge: presentation.top.badge)
        selectedPaywallUIRow = presentation.preferredUIRow
        updateSelection(animated: false)
        logPaywall("paywall_product_selected", productIndex: presentation.storeIndex(for: selectedPaywallUIRow), extra: [
            "selection_source": "default"
        ])
    }

    private func apply(
        row: PaywallProductsPresentation.ProductRow,
        titleLabel: UILabel,
        billingLabel: UILabel,
        priceLabel: UILabel
    ) {
        titleLabel.text = row.title
        billingLabel.text = row.priceDisplay.billingSubtitle
        priceLabel.attributedText = row.priceDisplay.makeEmphasizedAttributedString(
            amountFont: priceLabel.font ?? .systemFont(ofSize: 18, weight: .bold),
            periodFont: billingLabel.font ?? .systemFont(ofSize: 12),
            textColor: Defaults.Colors.primaryText
        )
    }

    private func applyBadgeContent(to view: UIView, label: UILabel, badge: PaywallProductsPresentation.Badge?) {
        view.isHidden = badge == nil
        label.text = badge?.title
    }

    private func applyBadgeStyle(to view: UIView, label: UILabel, row: PaywallUIRow, selected: Bool) {
        guard let badge = paywallPresentation?.productRow(for: row)?.badge else {
            view.isHidden = true
            return
        }

        view.isHidden = false
        label.text = badge.title

        if selected {
            view.backgroundColor = Defaults.Colors.premiumGreen
            label.textColor = Defaults.Colors.selectedBadgeTitle
        } else {
            view.backgroundColor = Defaults.Colors.discount
            label.textColor = Defaults.Colors.unselectedBadgeTitle
        }
    }

    private func selectProduct(_ row: PaywallUIRow) {
        guard !isPaywallLoading, paywallPresentation?.productRow(for: row) != nil else { return }
        hapticVibration()
        amplitude.logEvent(.pressSwitch)
        selectedPaywallUIRow = row
        updateSelection(animated: true)
        if let index = paywallPresentation?.storeIndex(for: row) {
            logPaywall("paywall_product_selected", productIndex: index)
        }
    }

    private func updateSelection(animated: Bool) {
        let updates = {
            let topSelected = self.selectedPaywallUIRow == .top
            self.applyPlanStyle(self.topPlanView, borderView: self.topPlanBorderView, selected: topSelected)
            self.applyBadgeStyle(to: self.topBadgeView, label: self.topBadgeLabel, row: .top, selected: topSelected)
            self.updateSelectedProductCopy()
        }
        if animated {
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState], animations: updates)
        } else {
            updates()
        }
    }

    private func applyPlanStyle(_ planView: UIView, borderView: UIView, selected: Bool) {
        borderView.layer.borderColor = resolvedCGColor(
            selected ? Defaults.Colors.premiumGreen : Defaults.Colors.cardBorder
        )
        planView.layer.shadowColor = resolvedCGColor(.systemBlue)
        planView.layer.shadowOpacity = selected ? 0 : 0.15
        planView.layer.shadowRadius = 4
    }

    private func updateSelectedProductCopy() {
        let hasTrial = paywallPresentation?.productRow(for: selectedPaywallUIRow)?.hasFreeTrial == true
        noPayingLabel.text = hasTrial ? Defaults.Text.noPayNow : "Cancel anytime".localized
        continueButton.setTitle(hasTrial ? PaywallProductCopy.tryFreeTrial : PaywallProductCopy.continue, for: .normal)
    }

    private func setPaywallLoading(_ loading: Bool) {
        isPaywallLoading = loading
        [topPlanTitleLabel, topBillingLabel, topPriceLabel].forEach {
            $0?.alpha = loading ? 0 : 1
        }
        if loading {
            topBadgeView.isHidden = true
        } else {
            stopProductSkeleton()
            topPlanView.bringSubviewToFront(topBadgeView)
        }
        setPurchaseControlsEnabled(!loading && !isPurchasing)
    }

    private func setPurchaseControlsEnabled(_ enabled: Bool) {
        let active = enabled && paywallPresentation != nil
        continueButton.isEnabled = active
        topPlanButton.isEnabled = active
    }

    private func startProductSkeleton() {
        let colors = UIView.paywallSkeletonShimmerColors(for: traitCollection)
        [topPlanView].forEach { plan in
            guard let plan, plan.bounds.width > 1 else { return }
            if plan.isPaywallShimmering {
                plan.updateShimmerFrame()
            } else {
                plan.startShimmer(highlightColor: colors.highlight, backgroundColor: colors.background)
            }
        }
    }

    private func stopProductSkeleton() {
        [topPlanView].forEach { $0?.stopShimmer() }
    }

    private func updateShimmerFramesIfNeeded() {
        guard isPaywallLoading else { return }
        startProductSkeleton()
    }

    private func startContinueShineIfNeeded() {
        guard continueButton.bounds.width > 1 else { return }
        continueButton.titleLabel?.layer.zPosition = 2
        if continueButton.layer.sublayers?.contains(where: { $0.name == "PaywallHighlightShimmerLayer" }) == true {
            continueButton.updateHighlightShimmerFrame()
        } else {
            continueButton.startHighlightShimmer()
        }
    }

    private func purchaseSelectedProduct() {
        guard !isPaywallLoading, !isPurchasing,
              let index = paywallPresentation?.storeIndex(for: selectedPaywallUIRow) else { return }

        isPurchasing = true
        setPurchaseControlsEnabled(false)
        startIndicator()
        amplitude.logEvent(.presBuyProduct(index: index))
        let purchaseAttemptID = UUID().uuidString
        let purchaseStartedAt = Date()
        logPaywall("purchase_requested", productIndex: index, extra: ["purchase_attempt_id": purchaseAttemptID])
        adaptyService.buyProduct(index: index) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.stopIndicator()
                self.isPurchasing = false
                self.setPurchaseControlsEnabled(true)
                switch result {
                case .success(let outcome):
                    var outcomeProperties: [String: Any] = [
                        "purchase_attempt_id": purchaseAttemptID,
                        "purchase_latency_ms": max(0, Int(Date().timeIntervalSince(purchaseStartedAt) * 1_000)),
                        "transaction_verified": outcome.transactionVerified
                    ]
                    if let startedFreeTrial = outcome.startedFreeTrial {
                        outcomeProperties["started_free_trial"] = startedFreeTrial
                    }
                    self.logPaywall("purchase_succeeded", productIndex: index, extra: outcomeProperties)
                    if outcome.startedFreeTrial == true {
                        self.logPaywall("trial_started", productIndex: index, extra: outcomeProperties)
                    }
                    self.amplitude.logEvent(.boughtProduct)
                    self.closePaywall(fromPurchase: true)
                case .failure(let error):
                    var failure = self.errorProperties(error)
                    failure["purchase_attempt_id"] = purchaseAttemptID
                    failure["purchase_latency_ms"] = max(0, Int(Date().timeIntervalSince(purchaseStartedAt) * 1_000))
                    if (error as? AdaptyServiceError) == .purchaseCancelled ||
                        ((error as NSError).domain == SKError.errorDomain && (error as NSError).code == SKError.paymentCancelled.rawValue) {
                        self.logPaywall("purchase_cancelled", productIndex: index, extra: failure)
                        return
                    }
                    if (error as? AdaptyServiceError) == .purchasePending {
                        self.logPaywall("purchase_pending", productIndex: index, extra: failure)
                        return
                    }
                    self.logPaywall("purchase_failed", productIndex: index, extra: failure)
                    self.showPaywallError(error)
                }
            }
        }
    }

    private func startIndicator() {
        indicatorCounter += 1
        guard indicatorCounter == 1 else { return }
        indicator.startAnimating()
        amplitude.logEvent(.showLoader)
    }

    private func stopIndicator() {
        guard indicatorCounter > 0 else { return }
        indicatorCounter -= 1
        guard indicatorCounter == 0 else { return }
        indicator.stopAnimating()
        amplitude.logEvent(.stopLoader)
    }

    private func showPaywallError(_ error: Error) {
        let nsError = error as NSError
        guard !(nsError.domain == SKError.errorDomain && nsError.code == SKError.paymentCancelled.rawValue) else { return }
        amplitude.logEvent(.error(message: error.localizedDescription))
        showAlert(title: Defaults.Text.error, message: error.localizedDescription)
    }

    private func showAlert(title: String?, message: String) {
        amplitude.logEvent(.alert(message: message))
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Defaults.Text.ok, style: .default))
        presentSafely(alert)
    }

    private func closePaywall(fromPurchase: Bool = false) {
        cancelScheduledWork()
        indicatorCounter = 0
        indicator.stopAnimating()
        if !fromPurchase {
            amplitude.logEvent(.closeButtonAction)
            logPaywall("paywall_closed", productIndex: paywallPresentation?.storeIndex(for: selectedPaywallUIRow))
        }
        dismiss(animated: true) { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                LocalNotificationService.shared.sync(requestPermissionIfNeeded: true)
            }
            guard fromPurchase else { return }
            self?.onSuccessfulPurchase?()
            self?.onSuccessfulPurchase = nil
        }
    }

    @IBAction private func topProductAction(_ sender: UIButton) {
        selectProduct(.top)
    }

    @IBAction private func continueAction(_ sender: UIButton) {
        hapticVibration(.medium)
        amplitude.logEvent(.continueAction)
        purchaseSelectedProduct()
    }

    @IBAction private func restoreAction(_ sender: UIButton) {
        hapticVibration()
        amplitude.logEvent(.restore)
        startIndicator()
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.stopIndicator() }
            do {
                let message = try await self.adaptyService.restore()
                self.showAlert(title: nil, message: message)
            } catch {
                self.showPaywallError(error)
            }
        }
    }

    @IBAction private func termsAction(_ sender: UIButton) {
        hapticVibration()
        amplitude.logEvent(.paywallTerms(placement: placement ?? ""))
        presentExternalURL(Constants.API.terms)
    }

    @IBAction private func privacyAction(_ sender: UIButton) {
        hapticVibration()
        amplitude.logEvent(.paywallPrivacy(placement: placement ?? ""))
        presentExternalURL(Constants.API.privacy)
    }

    @IBAction private func closeAction(_ sender: UIButton) {
        hapticVibration()
        closePaywall()
    }
}
