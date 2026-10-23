import UIKit
import Adapty
import SafariServices
import StoreKit

/// A/02 · P1 Paywall (+ trial off, P4 processing, Purchase failed / Restore alerts). Honest: ✕ and Restore are
/// visible from the first frame. Prices and the trial come from the Adapty paywall products (StoreKit);
/// Both trial states use weekly products. The toggle is available only when both offers exist.
/// Layout: Paywall.storyboard. Light only.
final class ProPaywallViewController: UIViewController {

    @IBOutlet private weak var closeButton: DSPressableControl!
    @IBOutlet private weak var restoreButton: DSPressableControl!
    @IBOutlet private weak var restoreLabel: UILabel!
    @IBOutlet private weak var contentStack: UIStackView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var stageView: UIView!
    @IBOutlet private weak var illustrationView: UIImageView!
    /// Wide landscape (iPhone Duo unfolded): illustration on the left, offer on the right (Paywall.storyboard).
    @IBOutlet private weak var wideHeroImageView: UIImageView!
    @IBOutlet private var singleColumnConstraints: [NSLayoutConstraint]!
    @IBOutlet private var twoColumnConstraints: [NSLayoutConstraint]!
    private var isTwoColumn = false
    @IBOutlet private var sparkleViews: [UIImageView]!
    @IBOutlet private weak var stageHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var cardView: UIView!
    @IBOutlet private weak var cardTitleLabel: UILabel!
    @IBOutlet private weak var cardBodyLabel: UILabel!
    @IBOutlet private weak var cardPriceLabel: UILabel!
    @IBOutlet private weak var trialToggle: DSPressableControl!
    @IBOutlet private weak var trialLabel: UILabel!
    @IBOutlet private weak var trialBadgeView: UIImageView!
    @IBOutlet private weak var timelineView: UIView!
    @IBOutlet private weak var railView: UIView!
    @IBOutlet private weak var railFillView: UIView!
    @IBOutlet private weak var railFillHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var dotTodayView: UIView!
    @IBOutlet private weak var dotChargeView: UIView!
    @IBOutlet private weak var dueTodayLabel: UILabel!
    @IBOutlet private weak var dueFreeLabel: UILabel!
    @IBOutlet private weak var dueTodayPriceLabel: UILabel!
    @IBOutlet private weak var todayRow: UIStackView!
    @IBOutlet private weak var chargeRow: UIStackView!
    @IBOutlet private weak var chargeDateLabel: UILabel!
    @IBOutlet private weak var chargePriceLabel: UILabel!
    @IBOutlet private weak var noteRow: UIStackView!
    @IBOutlet private weak var noteLabel: UILabel!
    @IBOutlet private weak var ctaButton: DSPrimaryButton!
    @IBOutlet private weak var ctaLabel: UILabel!
    @IBOutlet private weak var ctaSpinner: UIActivityIndicatorView!
    @IBOutlet private weak var termsButton: UIButton!
    @IBOutlet private weak var privacyButton: UIButton!

    var placement: String = Constants.Keys.optionPlacememt
    /// Analytics source (e.g. "assistant", "feature_watermark", "home_get_pro").
    var source: String = "in_app"
    var onPurchase: (() -> Void)?

    private var products: [AdaptyPaywallProduct] = []
    private var trialOn = true
    private var isPurchasing = false
    private var purchaseTimeout: DispatchWorkItem?
    private var didRunEntrance = false
    private let amplitude = AmplitudeService.shared
    private let sessionID = UUID().uuidString
    private var layoutSize = CGSize.zero
    private var baseFonts: [(UILabel, UIFont)] = []
    @IBOutlet private weak var contentScrollView: UIScrollView!
    private var baseConstraints: [(NSLayoutConstraint, CGFloat)] = []
    private var baseSpacings: [(UIStackView, CGFloat)] = []
    @IBOutlet private weak var footerHeight: NSLayoutConstraint!

    static func make(placement: String, source: String, onPurchase: (() -> Void)?) -> ProPaywallViewController {
        let vc = AppStoryboard.instantiate(ProPaywallViewController.self)
        vc.placement = placement
        vc.source = source
        vc.onPurchase = onPurchase
        vc.modalPresentationStyle = .fullScreen
        vc.overrideUserInterfaceStyle = .light
        return vc
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let wideLandscape = DSWideLayout.isWide(view.bounds.width - (view.window?.safeAreaInsets.left ?? 0)
                                                - (view.window?.safeAreaInsets.right ?? 0))
            && view.bounds.width > view.bounds.height
        dsApplyWideColumn(fullWidth: wideLandscape, portraitColumn: 420)
        guard wideLandscape != isTwoColumn else { return }
        isTwoColumn = wideLandscape
        singleColumnConstraints.forEach { $0.priority = UILayoutPriority(wideLandscape ? 1 : 999) }
        twoColumnConstraints.forEach { $0.priority = UILayoutPriority(wideLandscape ? 999 : 1) }
        wideHeroImageView.isHidden = !wideLandscape
        stageView.isHidden = wideLandscape
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        contentScrollView.contentInsetAdjustmentBehavior = .never
        restoreLabel.text = "Restore".localized
        restoreButton.accessibilityLabel = restoreLabel.text
        closeButton.accessibilityLabel = "Close".localized
        titleLabel.text = "Ready to go PRO?".localized
        subtitleLabel.text = "Unlimited designs. Cancel anytime.".localized
        cardTitleLabel.text = "Rehomely PRO".localized
        cardPriceLabel.accessibilityIdentifier = "paywall.price"
        cardBodyLabel.text = "Unlimited AI redesigns for any room, real paint colors and HD export.".localized
        dueTodayLabel.text = "Due today".localized
        termsButton.setTitle("Terms of Use".localized, for: .normal)
        privacyButton.setTitle("Privacy Policy".localized, for: .normal)
        [chargeDateLabel, cardPriceLabel, trialLabel, noteLabel].forEach {
            $0?.numberOfLines = 0
            $0?.lineBreakMode = .byWordWrapping
        }
        [termsButton, privacyButton].forEach { button in
            guard let button, let title = button.title(for: .normal) else { return }
            button.setAttributedTitle(NSAttributedString(string: title, attributes: [
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: UIColor(hex: "3E7A00"),
                .font: DS.Font.geologica(.regular, 14)
            ]), for: .normal)
        }
        captureLayoutMetrics(in: view)
        setLoading(true)
        loadProducts()
        if !DS.Motion.reduceMotion {
            [titleLabel, subtitleLabel, stageView, cardView, trialToggle, timelineView, noteRow, ctaButton]
                .forEach { $0?.alpha = 0 }
        }
        cardTitleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        cardBodyLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        amplitude.logPaywallEvent("paywall_view", properties: properties())
        amplitude.logEvent(.showPaywall(id: placement))
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        defer { fitTimeline() }
        guard view.dsLayoutSize != layoutSize else { return }
        layoutSize = view.dsLayoutSize
        let layout = OnboardingLayout(size: layoutSize)
        let scale = layout.scale
        baseFonts.forEach { label, font in label.font = font.withSize(font.pointSize * scale) }
        baseSpacings.forEach { stack, spacing in stack.spacing = spacing * scale }
        baseConstraints.forEach { constraint, value in
            let tapTarget = constraint.firstItem as? DSPressableControl
            let isTapSize = constraint.secondItem == nil && (constraint.firstAttribute == .height || constraint.firstAttribute == .width) && value >= 40
            constraint.constant = isTapSize && tapTarget != nil ? max(44, value * scale) : value * scale
        }
        // Exact reference rhythm (the title/subtitle gap is smaller than the other gaps).
        [(titleLabel as UIView, 3.0), (subtitleLabel as UIView, 11.0), (stageView!, 6.0),
         (cardView!, 11.0), (trialToggle!, 20.0), (timelineView!, 10.0)].forEach {
            contentStack.setCustomSpacing(CGFloat($0.1) * scale, after: $0.0)
        }
        let legalWidth = view.dsLayoutSize.width - 2 * layout.value(20)
        let baseLegalFont = DS.Font.geologica(.regular, max(11, 14 * scale))
        let textWidth = [termsButton, privacyButton].compactMap { $0?.title(for: .normal) }.reduce(CGFloat.zero) {
            $0 + ($1 as NSString).size(withAttributes: [.font: baseLegalFont]).width
        }
        // Reserve a few points for each button's pixel-rounded intrinsic width.
        let legalSize = max(11, baseLegalFont.pointSize * min(1, max(0, legalWidth - layout.value(30) - 4) / max(1, textWidth)))
        let legalFont = baseLegalFont.withSize(legalSize)
        [termsButton, privacyButton].forEach { button in
            guard let button, let title = button.title(for: .normal) else { return }
            button.contentEdgeInsets = .zero
            button.titleLabel?.font = legalFont
            button.setAttributedTitle(NSAttributedString(string: title, attributes: [
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: UIColor(hex: "3E7A00"), .font: legalFont
            ]), for: .normal)
        }
        if let footer = termsButton.superview as? UIStackView {
            let availableWidth = legalWidth
            let naturalWidth = [termsButton, privacyButton].compactMap { $0 }.reduce(CGFloat.zero) {
                $0 + $1.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)).width
            } + layout.value(30)
            let vertical = naturalWidth > availableWidth
            footer.axis = vertical ? .vertical : .horizontal
            footer.spacing = layout.value(vertical ? 4 : 12)
            footer.arrangedSubviews.compactMap { $0 as? UILabel }.forEach {
                $0.isHidden = vertical
                $0.font = legalFont
            }
            let height = ceil(legalFont.lineHeight) * (vertical ? 2 : 1) + (vertical ? footer.spacing : 0)
            footerHeight.constant = height
        }
    }

    private func fitTimeline() {
        let layout = OnboardingLayout(size: view.dsLayoutSize)
        let width = view.dsLayoutSize.width - layout.value(62)
        let natural = [dueTodayLabel, dueFreeLabel, dueTodayPriceLabel].reduce(CGFloat.zero) { total, label in
            total + (label?.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude,
                                               height: CGFloat.greatestFiniteMagnitude)).width ?? 0)
        } + layout.value(18)
        let axis: NSLayoutConstraint.Axis = natural > width ? .vertical : .horizontal
        if todayRow.axis != axis {
            todayRow.axis = axis
            todayRow.alignment = axis == .vertical ? .fill : .center
        }
    }

    private func captureLayoutMetrics(in view: UIView) {
        if let label = view as? UILabel, let font = label.font { baseFonts.append((label, font)) }
        if let stack = view as? UIStackView {
            stack.insetsLayoutMarginsFromSafeArea = false
            baseSpacings.append((stack, stack.spacing))
        }
        // UIKit's safe-area and stack internals remain managed by UIKit.
        baseConstraints += view.constraints.filter { $0.identifier?.hasPrefix("paywall.") == true }.map { ($0, $0.constant) }
        view.subviews.forEach(captureLayoutMetrics)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didRunEntrance else { return }
        didRunEntrance = true
        AdaptyService.shared.paywallShown()
        runEntrance()
    }

    // MARK: Products

    private func loadProducts() {
        #if DEBUG
        if AppQA.enabled { setLoading(false); render(animated: false); return }
        #endif
        products = []
        trialOn = false
        trialToggle.isHidden = true
        AdaptyService.shared.fetchPaywallPresentation(placementID: placement) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let loaded):
                self.products = loaded.products
                let selection = WeeklyPaywallProducts.selection(from: loaded.products)
                // No eligible trial → straight to "trial off".
                self.trialOn = selection.trialIndex != nil
                self.setLoading(false)
                self.render(animated: false)
            case .failure:
                self.setLoading(false)
                self.ctaLabel.text = "Try again".localized
                self.cardPriceLabel.text = "Couldn't load prices. Check your connection.".localized
            }
        }
    }

    private var selectedIndex: Int? {
        WeeklyPaywallProducts.selection(from: products).selectedIndex(trialEnabled: trialOn)
    }
    private var selectedProduct: AdaptyPaywallProduct? { selectedIndex.flatMap { products.indices.contains($0) ? products[$0] : nil } }

    /// Text + visibility for trial on / off ("Smart Animate" → cross-fade + spring).
    private func render(animated: Bool) {
        #if DEBUG
        if AppQA.enabled { renderQAFixture(); return }
        #endif
        guard let product = selectedProduct else { return }
        let price = product.localizedPrice ?? product.paywallFormattedCurrencyAmount(product.paywallPriceDecimal)
        let period = "week".localized
        let days = product.paywallTrialDays ?? 3
        let hasTrial = trialOn && product.paywallHasFreeTrial
        let apply = {
            self.subtitleLabel.text = hasTrial
                ? String(format: "Enjoy %d days free — cancel anytime.".localized, days)
                : "Unlimited designs. Cancel anytime.".localized
            if hasTrial {
                self.cardPriceLabel.text = String(format: "%d-day free trial, then %@/%@".localized, days, price, period)
                self.trialLabel.text = "Free Trial Enabled".localized
                self.dueFreeLabel.text = String(format: "%d days free".localized, days)
                self.dueTodayPriceLabel.text = Self.zeroPrice(like: price)
                let charge = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
                self.chargeDateLabel.text = String(format: "Due %@".localized,
                                                   DateFormatter.localizedString(from: charge, dateStyle: .medium, timeStyle: .none))
                self.chargePriceLabel.text = price
                self.noteLabel.text = "No payment now".localized
                self.ctaLabel.text = "Start Free Trial".localized
            } else {
                self.cardPriceLabel.text = String(format: "%@/%@, billed today".localized, price, period)
                self.trialLabel.text = "Enable Free Trial".localized
                self.dueTodayPriceLabel.text = price
                self.noteLabel.text = String(format: "%@ · Cancel anytime".localized, "Billed weekly".localized)
                self.ctaLabel.text = "Continue".localized
            }
            self.dueFreeLabel.isHidden = !hasTrial
            self.chargeRow.alpha = hasTrial ? 1 : 0
            self.dotChargeView.alpha = hasTrial ? 1 : 0
            self.railView.alpha = hasTrial ? 1 : 0
            self.railFillView.alpha = hasTrial ? 1 : 0
            self.trialToggle.backgroundColor = hasTrial ? DS.Color.limeSoft : UIColor(hex: "F4F4F4")
            self.trialToggle.layer.borderWidth = hasTrial ? 1.5 : 0
            self.trialBadgeView.image = UIImage(systemName: hasTrial ? "checkmark.seal.fill" : "seal")
            self.trialBadgeView.tintColor = hasTrial ? UIColor(hex: "7BC41A") : UIColor(hex: "C7CBC2")
            self.trialToggle.accessibilityLabel = self.trialLabel.text
            self.ctaButton.accessibilityLabel = self.ctaLabel.text
        }
        trialToggle.isHidden = !WeeklyPaywallProducts.selection(from: products).canToggleTrial
        trialToggle.accessibilityTraits = hasTrial ? [.button, .selected] : .button
        if animated {
            UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0,
                           animations: apply)
            if hasTrial, !DS.Motion.reduceMotion { popBadge() }
        } else {
            apply()
        }
    }

    /// "$0.00" in the same format as StoreKit's localized price ("$7.99" → "$0.00", "7,99 €" → "0,00 €").
    #if DEBUG
    private func renderQAFixture() {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: AppQA.language ?? "en_US")
        formatter.currencyCode = "USD"
        let price = formatter.string(from: 7.99) ?? "$7.99"
        subtitleLabel.text = trialOn
            ? String(format: "Enjoy %d days free — cancel anytime.".localized, 3)
            : "Unlimited designs. Cancel anytime.".localized
        cardPriceLabel.text = trialOn
            ? String(format: "%d-day free trial, then %@/%@".localized, 3, price, "week".localized)
            : String(format: "%@/%@, billed today".localized, price, "week".localized)
        trialLabel.text = (trialOn ? "Free Trial Enabled" : "Enable Free Trial").localized
        dueFreeLabel.text = String(format: "%d days free".localized, 3)
        dueFreeLabel.isHidden = !trialOn
        dueTodayPriceLabel.text = trialOn ? (formatter.string(from: 0) ?? "$0.00") : price
        let date = DateFormatter()
        date.locale = formatter.locale
        date.dateStyle = .medium
        chargeDateLabel.text = String(format: "Due %@".localized, date.string(from: Date().addingTimeInterval(3 * 86_400)))
        chargePriceLabel.text = price
        noteLabel.text = trialOn ? "No payment now".localized : String(format: "%@ · Cancel anytime".localized, "Billed weekly".localized)
        ctaLabel.text = (trialOn ? "Start Free Trial" : "Continue").localized
        ctaButton.accessibilityLabel = ctaLabel.text
        trialToggle.accessibilityLabel = trialLabel.text
        trialToggle.accessibilityTraits = trialOn ? [.button, .selected] : .button
        trialToggle.isHidden = false
        [chargeRow, dotChargeView, railView, railFillView].forEach { $0?.alpha = trialOn ? 1 : 0 }
        trialToggle.backgroundColor = trialOn ? DS.Color.limeSoft : UIColor(hex: "F4F4F4")
        trialToggle.layer.borderWidth = trialOn ? 1.5 : 0
        trialBadgeView.image = UIImage(systemName: trialOn ? "checkmark.seal.fill" : "seal")
        trialBadgeView.tintColor = trialOn ? UIColor(hex: "7BC41A") : UIColor(hex: "C7CBC2")
    }
    #endif

    static func zeroPrice(like price: String) -> String {
        guard let range = price.range(of: "\\d[\\d.,\\s\u{00A0}\u{202F}]*\\d|\\d", options: .regularExpression) else { return price }
        let reversed = Array(price[range].reversed())
        let digits = reversed.prefix { $0.isNumber }.count
        // Fraction part = 1–2 trailing digits after a separator.
        let zero = (digits <= 2 && reversed.count > digits)
            ? "0" + String(reversed[digits]) + String(repeating: "0", count: digits) : "0"
        return price.replacingCharacters(in: range, with: zero)
    }

    private func setLoading(_ loading: Bool) {
        ctaButton.isUserInteractionEnabled = !loading
        ctaButton.inactive = loading
        trialToggle.isUserInteractionEnabled = !loading
        if loading {
            // Never show the XIB's sample prices / dates before StoreKit answers.
            [cardPriceLabel, dueFreeLabel, dueTodayPriceLabel, chargeDateLabel, chargePriceLabel].forEach { $0?.text = " " }
            ctaLabel.text = "Loading…".localized
        }
    }

    // MARK: Entrance (Figma A/02 P1: stagger 0–1.4 s; CTA shimmer 1.6 / 4.8 s, pulse at 3.3 s)

    private func runEntrance() {
        guard !DS.Motion.reduceMotion else {
            [titleLabel, subtitleLabel, stageView, cardView, trialToggle, timelineView, noteRow, ctaButton]
                .forEach { v in UIView.animate(withDuration: 0.3) { v?.alpha = 1 } }
            return
        }
        let m = DS.Motion.self
        m.enter(titleLabel, delay: 0.0, dy: 12)
        m.enter(subtitleLabel, delay: 0.08, dy: 12)
        m.enter(stageView, delay: 0.15, scale: 0.88, duration: 0.6, spring: true)
        m.enter(cardView, delay: 0.45, dy: 12)
        m.enter(trialToggle, delay: 0.6, dy: 12)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.popBadge() }
        m.enter(timelineView, delay: 0.75, dy: 8)
        railFillHeightConstraint.constant = 1
        view.layoutIfNeeded()
        m.animate(0.6, delay: 0.95, timing: UICubicTimingParameters(animationCurve: .easeInOut)) {
            self.railFillHeightConstraint.constant = self.railView.bounds.height
            self.view.layoutIfNeeded()
        }
        m.enter(noteRow, delay: 1.0, dy: 8)
        m.enter(ctaButton, delay: 0.85, dy: 20, duration: 0.5)
        sparkleViews.enumerated().forEach { i, sparkle in animateSparkle(sparkle, delay: 0.6 + Double(i) * 0.25) }
        floatIllustration()
        [1.6, 4.8].forEach { t in
            DispatchQueue.main.asyncAfter(deadline: .now() + t) { [weak self] in self?.ctaButton.runShimmer() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.3) { [weak self] in
            guard let cta = self?.ctaButton, self?.isPurchasing == false else { return }
            UIView.animate(withDuration: 0.25, animations: { cta.transform = CGAffineTransform(scaleX: 1.03, y: 1.03) }) { _ in
                UIViewPropertyAnimator(duration: 0.45, dampingRatio: 0.6) { cta.transform = .identity }.startAnimation()
            }
        }
    }

    /// Badge pops 0.3 → 1 with a −90° → 0 turn.
    private func popBadge() {
        trialBadgeView.alpha = 1
        trialBadgeView.transform = CGAffineTransform(rotationAngle: -.pi / 2).scaledBy(x: 0.3, y: 0.3)
        DS.Motion.animate(0.45, timing: DS.Motion.easeOutBack) { self.trialBadgeView.transform = .identity }
    }

    /// Illustration floats 0 → −7 → 0 → −5 → 0 over 6 s.
    private func floatIllustration() {
        let float = CAKeyframeAnimation(keyPath: "transform.translation.y")
        float.values = [0, 0, -7, 0, -5, 0]
        float.keyTimes = [0, 0.1667, 0.4167, 0.6667, 0.8333, 1]
        float.timingFunctions = (0..<5).map { _ in CAMediaTimingFunction(name: .easeInEaseOut) }
        float.duration = 6
        float.repeatCount = .infinity
        illustrationView.layer.add(float, forKey: "float")
    }

    /// Sparkles pop in and keep twinkling (scale 1 → 0.55 → 1.1 → 0.8) while slowly turning 120°.
    private func animateSparkle(_ view: UIView, delay: TimeInterval) {
        view.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        DS.Motion.animate(0.3, delay: delay, timing: DS.Motion.easeOutBack, { view.transform = .identity }) {
            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            scale.values = [1, 0.55, 1.1, 0.8, 1]
            scale.keyTimes = [0, 0.3, 0.6, 0.9, 1]
            scale.duration = 5
            scale.repeatCount = .infinity
            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0
            spin.toValue = CGFloat.pi * 2 / 3
            spin.duration = 6
            spin.repeatCount = .infinity
            view.layer.add(scale, forKey: "twinkle")
            view.layer.add(spin, forKey: "spin")
        }
    }

    // MARK: Actions

    @IBAction private func didTapClose(_ sender: Any) {
        guard !isPurchasing else { return }
        amplitude.logEvent(.closeButtonAction)
        amplitude.logPaywallEvent("paywall_closed", properties: properties())
        dismiss(animated: true)
    }

    @IBAction private func didTapTrial(_ sender: Any) {
        var canToggle = WeeklyPaywallProducts.selection(from: products).canToggleTrial
        #if DEBUG
        canToggle = canToggle || AppQA.enabled
        #endif
        guard canToggle, !isPurchasing else { return }
        trialOn.toggle()
        DS.Haptic.selection()
        amplitude.logPaywallEvent("trial_toggle", properties: properties().merging(["on": trialOn]) { _, n in n })
        render(animated: true)
    }

    @IBAction private func didTapCTA(_ sender: Any) {
        guard !isPurchasing else { return }
        guard let index = selectedIndex else {
            setLoading(true)
            loadProducts()
            return
        }
        purchase(index: index)
    }

    private func purchase(index: Int) {
        guard products.indices.contains(index), products[index].paywallIsWeeklySubscription else {
            setLoading(true)
            loadProducts()
            return
        }
        isPurchasing = true
        setProcessing(true)
        DS.Haptic.medium()
        amplitude.logEvent(.presBuyProduct(index: index))
        amplitude.logPaywallEvent("purchase_start", properties: properties(index: index))
        // P4: never block without a way out — 30 s timeout → Purchase failed.
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.isPurchasing else { return }
            self.isPurchasing = false
            self.setProcessing(false)
            self.showPurchaseFailed(index: index)
        }
        purchaseTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: timeout)
        AdaptyService.shared.buyProduct(index: index) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.isPurchasing else { return }
                self.purchaseTimeout?.cancel()
                self.isPurchasing = false
                self.setProcessing(false)
                switch result {
                case .success(let outcome):
                    var props = self.properties(index: index)
                    props["started_free_trial"] = outcome.startedFreeTrial ?? false
                    self.amplitude.logPaywallEvent("purchase_success", properties: props)
                    self.amplitude.logEvent(.boughtProduct)
                    self.showWelcome()
                case .failure(let error):
                    let nsError = error as NSError
                    let cancelled = (error as? AdaptyServiceError) == .purchaseCancelled
                        || (nsError.domain == SKError.errorDomain && nsError.code == SKError.paymentCancelled.rawValue)
                    if cancelled || (error as? AdaptyServiceError) == .purchasePending {
                        self.amplitude.logPaywallEvent(cancelled ? "purchase_cancelled" : "purchase_pending",
                                                       properties: self.properties(index: index))
                        return
                    }
                    self.amplitude.logPaywallEvent("purchase_failed", properties: self.properties(index: index))
                    self.showPurchaseFailed(index: index)
                }
            }
        }
    }

    /// P4: spinner + "Confirming with App Store…", plans and ✕ dimmed to 0.4 and not tappable.
    private func setProcessing(_ on: Bool) {
        ctaSpinner.isHidden = !on
        on ? ctaSpinner.startAnimating() : ctaSpinner.stopAnimating()
        ctaLabel.text = on ? "Confirming with App Store…".localized : (trialOn && selectedProduct?.paywallHasFreeTrial == true
            ? "Start Free Trial".localized : "Continue".localized)
        ctaButton.isUserInteractionEnabled = !on
        UIView.animate(withDuration: 0.2) {
            [self.closeButton, self.restoreButton, self.trialToggle, self.cardView].forEach { $0?.alpha = on ? 0.4 : 1 }
        }
        [closeButton, restoreButton, trialToggle].forEach { $0?.isUserInteractionEnabled = !on }
    }

    private func showPurchaseFailed(index: Int) {
        DS.Haptic.error()
        DSAlertViewController.show(from: self, title: "Purchase failed".localized,
                                   message: "Something went wrong with the App Store. You weren't charged.".localized,
                                   actions: [.init(title: "OK".localized, style: .cancel),
                                             .init(title: "Try again".localized, style: .primary) { [weak self] in
                                                 self?.purchase(index: index)
                                             }])
    }

    private func showWelcome() {
        let onPurchase = self.onPurchase
        let welcome = WelcomeProViewController.make { onPurchase?() }
        welcome.modalTransitionStyle = .crossDissolve
        let presenter = presentingViewController
        dismiss(animated: false) { presenter?.present(welcome, animated: true) }
    }

    @IBAction private func didTapRestore(_ sender: Any) {
        guard !isPurchasing else { return }
        DS.Haptic.light()
        amplitude.logEvent(.restore)
        isPurchasing = true
        setProcessing(true)
        ctaLabel.text = "Restoring…".localized
        Task { @MainActor [weak self] in
            guard let self else { return }
            let restored = (try? await AdaptyService.shared.restore()) != nil && AdaptyService.shared.hasActiveSubscription
            self.isPurchasing = false
            self.setProcessing(false)
            if restored {
                DS.Haptic.success()
                DSAlertViewController.show(from: self, title: "Purchases restored".localized,
                                           message: "Welcome back to Pro.".localized,
                                           actions: [.init(title: "OK".localized, style: .primary) { [weak self] in
                                               let onPurchase = self?.onPurchase
                                               self?.dismiss(animated: true) { onPurchase?() }
                                           }])
            } else {
                DSAlertViewController.show(from: self, title: "Nothing to restore".localized,
                                           message: "We couldn't find an active subscription for this Apple ID.".localized,
                                           actions: [.init(title: "OK".localized, style: .cancel)])
            }
        }
    }

    @IBAction private func didTapTerms(_ sender: Any) {
        amplitude.logEvent(.paywallTerms(placement: placement))
        openSafari(Constants.API.terms)
    }

    @IBAction private func didTapPrivacy(_ sender: Any) {
        amplitude.logEvent(.paywallPrivacy(placement: placement))
        openSafari(Constants.API.privacy)
    }

    private func openSafari(_ string: String) {
        guard let url = URL(string: string) else { return }
        present(SFSafariViewController(url: url), animated: true)
    }

    private func properties(index: Int? = nil) -> [String: Any] {
        var props: [String: Any] = ["paywall_session_id": sessionID, "placement": placement, "source": source,
                                    "paywall_variant": "redesign_a_p1", "trial_on": trialOn]
        if let index, products.indices.contains(index) {
            let product = products[index]
            props["product_id"] = product.vendorProductId
            props["price"] = NSDecimalNumber(decimal: product.price).doubleValue
            props["currency"] = product.currencyCode ?? "unknown"
        }
        return props
    }
}
