import Adapty
import AdaptyUI
import SafariServices
import UIKit

/// A/B test of paywall kinds through Adapty. Each placement's flow (the variation Adapty assigned to this user)
/// decides: a flow made in Adapty's Paywall Builder (`hasViewConfiguration`) shows Adapty's own screen, any other
/// flow shows our `ProPaywallViewController`. Builder layouts are prefetched, so the choice is made synchronously
/// when a paywall opens; without a ready layout (offline, still loading) our paywall is the fallback.
@MainActor
final class PaywallProvider {

    static let shared = PaywallProvider()

    private static let placements = [
        Constants.Keys.obPlacement, Constants.Keys.appLaunchPlacement, Constants.Keys.optionPlacememt,
        Constants.Keys.reachedLimit, Constants.Keys.saveImagePlacement, Constants.Keys.shareImagePlacement,
        Constants.Keys.detailsEditPlacement, Constants.Keys.closeOfferPlacement
    ]

    private(set) var isActivated = false
    /// The close offer shows at most once per launch.
    private var didShowCloseOffer = false
    private var configurations: [String: AdaptyUI.FlowConfiguration] = [:]
    private var loading = Set<String>()
    /// Keeps each Builder screen's delegate alive (AdaptyFlowController holds it weakly).
    private var delegates: [ObjectIdentifier: BuilderPaywallDelegate] = [:]

    private init() {}

    /// Right after `Adapty.activate`.
    func activate() async {
        guard !isActivated else { return }
        do {
            try await AdaptyUI.activate()
            isActivated = true
        } catch {
            ErrorReporter.report(error, operation: "adaptyui_activate", details: .init(provider: "adapty"))
        }
    }

    /// Non-subscribers: Builder layouts of all placements, in the background (never delays the launch).
    func prefetchAll() {
        Task { @MainActor in
            for placement in Self.placements { await self.prefetch(placement: placement) }
        }
    }

    /// Waits until AdaptyUI is activated, at most `timeout` seconds.
    func waitUntilActivated(timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !isActivated, Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return isActivated
    }

    /// Loads the placement's flow and, for a Paywall Builder variation, its layout.
    func prefetch(placement: String) async {
        guard isActivated, configurations[placement] == nil, !loading.contains(placement) else { return }
        loading.insert(placement)
        defer { loading.remove(placement) }
        do {
            let flow = try await Adapty.getFlow(placementId: placement)
            guard flow.hasViewConfiguration else { return }
            configurations[placement] = try await AdaptyUI.getFlowConfiguration(forFlow: flow, loadTimeout: 10)
        } catch {
            // 404: nothing set up in Adapty for this placement (e.g. no close offer) — normal, not reported.
            if String(describing: error).contains("statusCode: 404") { return }
            ErrorReporter.report(error, operation: "paywall_builder_load",
                                 details: .init(provider: "adapty", extra: ["placement": placement]))
        }
    }

    /// The paywall for this placement: Adapty's Builder screen when the user's variation is one and its layout is
    /// ready, otherwise ours.
    func makePaywall(placement: String, source: String, onPurchase: (() -> Void)?) -> UIViewController {
        if let configuration = configurations.removeValue(forKey: placement),
           let controller = builderController(configuration: configuration, placement: placement, source: source,
                                              onPurchase: onPurchase) {
            // A layout serves one presentation; load a fresh one for next time.
            Task { await self.prefetch(placement: placement) }
            return controller
        }
        return ProPaywallViewController.make(placement: placement, source: source, onPurchase: onPurchase)
    }

    /// An Adapty Builder screen (paywall, offer, or a whole onboarding flow). `onClose` / `onPurchased` replace the
    /// default dismiss and Welcome screen, e.g. when the controller is the window's root during onboarding.
    func builderController(configuration: AdaptyUI.FlowConfiguration, placement: String, source: String,
                           onPurchase: (() -> Void)?,
                           onClose: ((AdaptyFlowController) -> Void)? = nil,
                           onPurchased: ((AdaptyFlowController) -> Void)? = nil,
                           onFailure: ((AdaptyFlowController) -> Void)? = nil) -> AdaptyFlowController? {
        let delegate = BuilderPaywallDelegate(placement: placement, source: source, onPurchase: onPurchase)
        delegate.closeHandler = onClose
        delegate.purchasedHandler = onPurchased
        delegate.failureHandler = onFailure
        do {
            let controller = try AdaptyUI.flowController(with: configuration, delegate: delegate)
            controller.modalPresentationStyle = .fullScreen
            delegates[ObjectIdentifier(controller)] = delegate
            delegate.onFinish = { [weak self, weak controller] in
                guard let self, let controller else { return }
                self.delegates.removeValue(forKey: ObjectIdentifier(controller))
            }
            return controller
        } catch {
            ErrorReporter.report(error, operation: "paywall_builder_show",
                                 details: .init(provider: "adapty", extra: ["placement": placement]))
            return nil
        }
    }

    /// After a paywall is closed without a purchase: the offer set up in Adapty for `close_offer_placement`
    /// (a Builder screen), once per launch. Nothing configured there → nothing shown.
    func paywallDidClose(placement: String, presenter: UIViewController?) {
        guard placement != Constants.Keys.closeOfferPlacement, !didShowCloseOffer,
              !AdaptyService.shared.hasActiveSubscription, let presenter,
              let configuration = configurations.removeValue(forKey: Constants.Keys.closeOfferPlacement),
              let offer = builderController(configuration: configuration, placement: Constants.Keys.closeOfferPlacement,
                                            source: "close_offer_\(placement)", onPurchase: nil) else { return }
        didShowCloseOffer = true
        presenter.present(offer, animated: true)
    }
}

/// Events of one Adapty Paywall Builder screen: the same analytics as our paywall (`paywall_kind` = builder),
/// purchases recorded through `AdaptyService`, our paywall as the fallback when the screen can't render.
@MainActor
private final class BuilderPaywallDelegate: AdaptyFlowControllerDelegate {

    let placement: String
    let source: String
    let onPurchase: (() -> Void)?
    var onFinish: (() -> Void)?
    var closeHandler: ((AdaptyFlowController) -> Void)?
    var purchasedHandler: ((AdaptyFlowController) -> Void)?
    var failureHandler: ((AdaptyFlowController) -> Void)?
    private let sessionID = UUID().uuidString
    private let amplitude = AmplitudeService.shared
    private var flowName = ""
    private var variationID = ""

    init(placement: String, source: String, onPurchase: (() -> Void)?) {
        self.placement = placement
        self.source = source
        self.onPurchase = onPurchase
    }

    private func properties(product: AdaptyPaywallProduct? = nil) -> [String: Any] {
        var props: [String: Any] = ["paywall_session_id": sessionID, "placement": placement, "source": source,
                                    "paywall_variant": "adapty_builder", "paywall_kind": "builder",
                                    "flow_name": flowName, "variation_id": variationID]
        if let product {
            props["product_id"] = product.vendorProductId
            props["price"] = NSDecimalNumber(decimal: product.price).doubleValue
            props["currency"] = product.currencyCode ?? "unknown"
        }
        return props
    }

    func flowControllerDidAppear(_ controller: AdaptyFlowController) {
        amplitude.logPaywallEvent("paywall_view", properties: properties())
        amplitude.logEvent(.showPaywall(id: placement))
        Task { await AdaptyService.shared.prepareForPurchase() }
    }

    func flowControllerDidDisappear(_ controller: AdaptyFlowController) {
        onFinish?()
    }

    func flowController(_ controller: AdaptyFlowController, didPerform action: AdaptyUI.Action) {
        switch action {
        case .close:
            amplitude.logEvent(.closeButtonAction)
            amplitude.logPaywallEvent("paywall_closed", properties: properties())
            if let closeHandler { return closeHandler(controller) }
            let presenter = controller.presentingViewController, placement = self.placement
            controller.dismiss(animated: true) {
                PaywallProvider.shared.paywallDidClose(placement: placement, presenter: presenter)
            }
        case let .openURL(url, _):
            controller.present(SFSafariViewController(url: url), animated: true)
        case .custom:
            break
        }
    }

    func flowController(_ controller: AdaptyFlowController, didStartPurchase product: AdaptyPaywallProduct) {
        amplitude.logPaywallEvent("purchase_start", properties: properties(product: product))
    }

    func flowController(_ controller: AdaptyFlowController, didFinishPurchase product: AdaptyPaywallProduct,
                        purchaseResult: AdaptyPurchaseResult) {
        switch purchaseResult {
        case .userCancelled:
            amplitude.logPaywallEvent("purchase_cancelled", properties: properties(product: product))
        case .pending:
            amplitude.logPaywallEvent("purchase_pending", properties: properties(product: product))
        case let .success(profile, transaction):
            guard let outcome = AdaptyService.shared.recordPurchase(profile: profile, transaction: transaction,
                                                                     product: product) else {
                amplitude.logPaywallEvent("purchase_failed", properties: properties(product: product))
                return
            }
            var props = properties(product: product)
            props["started_free_trial"] = outcome.startedFreeTrial ?? false
            amplitude.logPaywallEvent("purchase_success", properties: props)
            amplitude.logEvent(.boughtProduct)
            if let purchasedHandler { return purchasedHandler(controller) }
            showWelcome(from: controller)
        }
    }

    func flowController(_ controller: AdaptyFlowController, didFailPurchase product: AdaptyPaywallProduct,
                        error: AdaptyError) {
        amplitude.logPaywallEvent("purchase_failed", properties: properties(product: product))
        ErrorReporter.report(error, operation: "purchase",
                             details: .init(provider: "adapty", extra: ["product_id": product.vendorProductId,
                                                                        "paywall_kind": "builder"]))
    }

    func flowControllerDidStartRestore(_ controller: AdaptyFlowController) {
        amplitude.logEvent(.restore)
    }

    func flowController(_ controller: AdaptyFlowController, didFinishRestoreWith profile: AdaptyProfile) {
        AdaptyService.shared.applyProfile(profile)
        guard AdaptyService.shared.hasActiveSubscription else { return }
        if let purchasedHandler { return purchasedHandler(controller) }
        let onPurchase = self.onPurchase
        controller.dismiss(animated: true) { onPurchase?() }
    }

    func flowController(_ controller: AdaptyFlowController, didFailRestoreWith error: AdaptyError) {
        ErrorReporter.report(error, operation: "restore", details: .init(provider: "adapty"))
    }

    func flowController(_ controller: AdaptyFlowController, didReceiveError error: AdaptyUIError) {
        ErrorReporter.report(error, operation: "paywall_builder_render",
                             details: .init(provider: "adapty", extra: ["placement": placement]))
        fallBackToNative(from: controller)
    }

    func flowController(_ controller: AdaptyFlowController, didFailLoadingProductsWith error: AdaptyError) -> Bool {
        ErrorReporter.report(error, operation: "paywall_load",
                             details: .init(provider: "adapty", extra: ["placement": placement,
                                                                        "paywall_kind": "builder"]))
        fallBackToNative(from: controller)
        return false
    }

    // MARK: Private

    private func showWelcome(from controller: AdaptyFlowController) {
        let onPurchase = self.onPurchase
        let welcome = WelcomeProViewController.make { onPurchase?() }
        welcome.modalTransitionStyle = .crossDissolve
        let presenter = controller.presentingViewController
        controller.dismiss(animated: false) { presenter?.present(welcome, animated: true) }
    }

    /// The Builder screen couldn't render or load products: our paywall takes its place.
    private func fallBackToNative(from controller: AdaptyFlowController) {
        // Onboarding root: its own handler moves on (our onboarding).
        if let failureHandler { return failureHandler(controller) }
        guard let presenter = controller.presentingViewController else { return }
        let native = ProPaywallViewController.make(placement: placement, source: source, onPurchase: onPurchase)
        controller.dismiss(animated: false) { presenter.present(native, animated: false) }
    }
}
