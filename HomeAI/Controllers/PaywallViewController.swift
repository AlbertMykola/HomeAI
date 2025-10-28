import UIKit

private struct Defaults {
    struct Colors {
        static let button = UIColor(named: "PremiumButtonColor")
    }

    struct Text {
        static let headline = "Unlock Unlimited Access".localized
        static let description = "Unlimited interior, exterior, and garden transformations. All styles, custom presets, and high‑quality exports".localized
        static let enableFree = "Enable Free Trial".localized
        static let yearly = "Yearly Access".localized
        static let perWeek = "Per week".localized
        static let weekly =  "Weekly Access".localized
        static let continueTitle = "Continue".localized
        static let notNow = "Not now".localized
    }
}

enum PaywallOrigin {
    case onboarding
    case inApp
}

final class PaywallViewController: UIViewController, UIAdaptivePresentationControllerDelegate {

    // MARK: - Enums
    private enum PlanSelection { case annual, weekly }

    // MARK: - @IBOutlets
    @IBOutlet weak private var continueButton: UIButton!
    @IBOutlet weak private var closeButton: UIButton!

    @IBOutlet weak private var perWeekBottomLabel: CustomFontLabel!
    @IBOutlet weak private var priceBottomLabel: CustomFontLabel!
    @IBOutlet weak private var perWeekPriceBottomLabel: CustomFontLabel!
    @IBOutlet weak private var planBottomButtonLabel: CustomFontLabel!
    @IBOutlet weak private var perWeekTopLabel: CustomFontLabel!
    @IBOutlet weak private var perWeekPriceTopLabel: CustomFontLabel!
    @IBOutlet weak private var priceTopButtonLabel: CustomFontLabel!
    @IBOutlet weak private var planTopButtonLabel: CustomFontLabel!
    @IBOutlet weak private var enableFreeTrialLabel: CustomFontLabel!
    @IBOutlet weak private var descriptionLabel: CustomFontLabel!
    @IBOutlet weak private var headlineLabel: CustomFontLabel!

    @IBOutlet private var constraintsHeight: [NSLayoutConstraint]!
    @IBOutlet private var constraintsWidth: [NSLayoutConstraint]!

    @IBOutlet weak private var containerView: UIView!
    @IBOutlet weak private var topButtonContainerView: UIView!
    @IBOutlet weak private var bottomButtonContainerView: UIView!
    @IBOutlet weak private var saveContainerView: UIView!
    @IBOutlet weak private var bottomDotView: UIView!
    @IBOutlet weak private var topDotView: UIView!
    @IBOutlet weak private var bottomContainerView: UIView!

    private var engine: CarouselEngine<UIImage, PremiumCollectionCell>?
    private var apphud = ApphudService.shared
    private var products: [ApphudProductModel] = []
    private var selectedPlan: PlanSelection?
    private var loader: CustomLoaderView?
    private var selectedProduct = 0
    private var addedGradient = false

    var placement: String?
    var origin: PaywallOrigin = .inApp
    var onFinish: (() -> Void)?

    private var isClosing = false
    private var didFinishOnce = false
    private var amplitudeService = AmplitudeService.shared

    override func viewDidLoad() {
        super.viewDidLoad()

        presentationController?.delegate = self
        configTopCarusel()
        config()
        getProducts()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if origin == .onboarding {
            NavigationManager.shared.completeOnboarding()
        }
        ApphudService.shared.paywallShown()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        saveContainerView.layer.cornerRadius = saveContainerView.frame.height / 2
        if !addedGradient {
            bottomContainerView.setGradient(
                stops: [.init(percent: 0,   color: .systemBackground.withAlphaComponent(0)),
                        .init(percent: 20,  color: .systemBackground.withAlphaComponent(80)),
                        .init(percent: 100, color: .systemBackground)
                ],
                direction: .vertical
            )
            addedGradient = true
            continueButton.pulseView()
        }
    }

    private func config() {
        headlineLabel.text = Defaults.Text.headline
        descriptionLabel.text = Defaults.Text.description
        enableFreeTrialLabel.text = Defaults.Text.enableFree
        planTopButtonLabel.text = Defaults.Text.yearly
        planBottomButtonLabel.text = Defaults.Text.weekly
        perWeekTopLabel.text = Defaults.Text.perWeek
        perWeekBottomLabel.text = Defaults.Text.perWeek
        continueButton.setTitle(Defaults.Text.continueTitle, for: .normal)
        closeButton.setTitle(Defaults.Text.notNow, for: .normal)

        constraintsWidth.forEach { $0.scaleConstant() }
        constraintsHeight.forEach { $0.scaleConstant() }
        applySelection(to: topButtonContainerView, dot: topDotView, selected: true)
    }

    private func configTopCarusel() {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: .init())
        cv.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(cv)
        NSLayoutConstraint.activate([
            cv.topAnchor.constraint(equalTo: containerView.topAnchor),
            cv.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            cv.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            cv.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        let reg = UICollectionView.CellRegistration<PremiumCollectionCell, UIImage>(
            cellNib: UINib(nibName: "PremiumCollectionCell", bundle: nil)
        ) { cell, _, image in
            cell.configure(image: image)
        }

        let itemH = CGFloat(130).scaledByHeight()
        let layoutCfg = CarouselLayoutConfig(
            itemSize: CGSize(width: CGFloat(200).scaledByHeight(), height: itemH),
            itemContentInsets: .init(top: 0, leading: 6, bottom: 0, trailing: 6),
            sectionInsets: .init(top: 0, leading: 16, bottom: 0, trailing: 16),
            interGroupSpacing: 0,
            groupHeight: (itemH + 20),
            orthogonalBehavior: .continuous,
            repeatFactor: 7,
            pixelsPerSecond: 30
        )

        let rows: [[UIImage]] = [
            [UIImage(named:"carusel_1_image")!, UIImage(named:"carusel_2_image")!, UIImage(named:"carusel_3_image")!, UIImage(named:"carusel_4_image")!, UIImage(named:"carusel_5_image")!, UIImage(named:"carusel_6_image")!, UIImage(named:"carusel_7_image")!, UIImage(named:"carusel_8_image")!, UIImage(named:"carusel_9_image")!, UIImage(named:"carusel_10_image")!, UIImage(named:"carusel_11_image")!, UIImage(named:"carusel_12_image")!, UIImage(named:"carusel_13_image")!, UIImage(named:"carusel_14_image")!, UIImage(named:"carusel_15_image")!],
            [UIImage(named:"carusel_7_image")!, UIImage(named:"carusel_8_image")!, UIImage(named:"carusel_7_image")!, UIImage(named:"carusel_8_image")!, UIImage(named:"carusel_1_image")!, UIImage(named:"carusel_2_image")!, UIImage(named:"carusel_5_image")!, UIImage(named:"carusel_6_image")!, UIImage(named:"carusel_9_image")!, UIImage(named:"carusel_10_image")!, UIImage(named:"carusel_15_image")!, UIImage(named:"carusel_14_image")!, UIImage(named:"carusel_4_image")!, UIImage(named:"carusel_12_image")!, UIImage(named:"carusel_3_image")!],
            [UIImage(named:"carusel_15_image")!, UIImage(named:"carusel_14_image")!, UIImage(named:"carusel_13_image")!, UIImage(named:"carusel_12_image")!, UIImage(named:"carusel_11_image")!, UIImage(named:"carusel_10_image")!, UIImage(named:"carusel_9_image")!, UIImage(named:"carusel_8_image")!, UIImage(named:"carusel_7_image")!, UIImage(named:"carusel_6_image")!, UIImage(named:"carusel_5_image")!, UIImage(named:"carusel_4_image")!, UIImage(named:"carusel_3_image")!, UIImage(named:"carusel_2_image")!, UIImage(named:"carusel_1_image")!],
        ]

        let engine = CarouselEngine<UIImage, PremiumCollectionCell>(
            collectionView: cv,
            layoutConfig: layoutCfg,
            cellRegistration: reg
        )
        self.engine = engine
        engine.configure(rows: rows)
    }

    private func getProducts() {
        amplitudeService.logEvent(.getProducts)
        showLoader()
        Task { @MainActor in
            apphud.fetchPaywallProducts(placementID: placement ?? "") { [weak self] items, error in
                guard let self = self else { return }

                if let error = error {
                    amplitudeService.logEvent(.error(message: error.localizedDescription))
                    self.presentHidingAlert(title: "Opps..", message: error.localizedDescription)
                    return
                }

                guard let apphudProducts = items, !apphudProducts.isEmpty else { return }
                amplitudeService.logEvent(.gotProducts)

                self.products = apphudProducts.compactMap { product in
                    guard let sk = product.skProduct,
                          let priceStr = sk.formattedPrice,
                          let symbol = sk.currencySymbol
                    else { return nil }

                    let perWeek = sk.weeklyPrice?.formatted

                    return ApphudProductModel(name: product.productId, price: priceStr, symbol: symbol, perWeek: perWeek, isTrial: sk.isTrial)
                }
                self.updateProductButtons()
            }
        }
    }

    private func applySelection(to view: UIView, dot: UIView, selected: Bool) {
        view.layer.borderWidth = selected ? 1.5 : 0.0
        view.layer.borderColor = selected ? UIColor.systemYellow.cgColor : nil
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        dot.isHidden = !selected
    }

    private func updateProductButtons() {
        priceTopButtonLabel.text = products.first?.price
        perWeekPriceTopLabel.text = products.first?.perWeek

        priceBottomLabel.text = products.last?.price
        perWeekPriceBottomLabel.text = products.last?.perWeek
        continueButton.isEnabled = true
        hideLoader()
    }

    private func showLoader() {
        amplitudeService.logEvent(.showLoader)
        guard loader == nil else { return }
        let v = CustomLoaderView.loadFromNib()
        v.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(v)
        NSLayoutConstraint.activate([
            v.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            v.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            v.topAnchor.constraint(equalTo: view.topAnchor),
            v.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        loader = v
        v.start()
        view.isUserInteractionEnabled = false
    }

    private func hideLoader() {
        amplitudeService.logEvent(.stopLoader)

        view.isUserInteractionEnabled = true
        loader?.stop()
        loader?.removeFromSuperview()
        loader = nil
    }

    private func buyProduct(index: Int) {
        amplitudeService.logEvent(.presBuyProduct(index: index))
        showLoader()
        Task { @MainActor in
            apphud.buyProduct(index: index) { [weak self] result in
                guard let self else { return }

                switch result {
                case .success:
                    self.amplitudeService.logEvent(.boughtProduct)
                    self.hideLoader()
                    close()
                case .failure(let error):
                    self.amplitudeService.logEvent(.error(message: error.localizedDescription))
                    self.presentHidingAlert(title: "Opps..", message: error.localizedDescription)
                }

                self.hideLoader()
            }
        }
    }

    private func finishIfNeeded() {
        guard !didFinishOnce else { return }
        didFinishOnce = true
        onFinish?()
    }

    private func close() {
        guard !isClosing else { return }
        isClosing = true
        
        ApphudService.shared.paywallClosed()
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let top = self.presentedViewController {
                top.dismiss(animated: false) { [weak self] in
                    self?.dismiss(animated: true) { [weak self] in
                        self?.finishIfNeeded()
                        self?.isClosing = false
                    }
                }
            } else {
                self.dismiss(animated: true) { [weak self] in
                    self?.finishIfNeeded()
                    self?.isClosing = false
                }
            }
        }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        finishIfNeeded()
    }

    // MARK: - @IBActions
    @IBAction private func annuallyAction(_ sender: UIButton) {
        hapticVibration()
        selectedPlan = .annual
        applySelection(to: topButtonContainerView, dot: topDotView, selected: true)
        applySelection(to: bottomButtonContainerView, dot: bottomDotView, selected: false)
        selectedProduct = 0
        buyProduct(index: 0)
    }

    @IBAction private func weeklyAction(_ sender: UIButton) {
        hapticVibration()
        selectedPlan = .weekly
        applySelection(to: topButtonContainerView, dot: topDotView, selected: false)
        applySelection(to: bottomButtonContainerView, dot: bottomDotView, selected: true)
        selectedProduct = 1
        buyProduct(index: 1)
    }

    @IBAction private func onSwitch(_ sender: UISwitch) {
        amplitudeService.logEvent(.pressSwitch)
        hapticVibration()
        sender.isOn ? weeklyAction(UIButton()) : annuallyAction(UIButton())
    }

    @IBAction private func closeAction(_ sender: UIButton) {
        amplitudeService.logEvent(.closeButtonAction)
        close()
    }

    @IBAction private func restoreAction(_ sender: UIButton) {
        amplitudeService.logEvent(.restore)
        showLoader()
        hapticVibration()
        Task { @MainActor in
            do {
                let message = try await self.apphud.restore()
                hideLoader()
                presentHidingAlert(title: "", message: message)
            } catch {
                presentHidingAlert(title: "", message: error.localizedDescription)
            }
        }
    }

    @IBAction private func continueAction(_ sender: UIButton) {
        amplitudeService.logEvent(.continueAction)
        buyProduct(index: selectedProduct)
    }
}
