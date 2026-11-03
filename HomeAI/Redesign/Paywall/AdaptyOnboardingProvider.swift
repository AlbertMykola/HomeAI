import Adapty
import AdaptyUI
import UIKit

/// First launch: the onboarding set up in Adapty for `Constants.Keys.onboardingPlacement` replaces ours, so it can be
/// changed without an app update. A Flow made in the Builder (onboarding screens, paywall, offer in one) is shown as
/// is; a legacy Adapty Onboarding hands its "open paywall" buttons to our paywall routing. Nothing set up there,
/// no network, or a load past the timeout → our onboarding.
@MainActor
final class AdaptyOnboardingProvider: NSObject {

    static let shared = AdaptyOnboardingProvider()

    /// The launch screen waits at most this long for Adapty before our onboarding shows.
    private static let loadTimeout: TimeInterval = 6

    /// Called when the remote onboarding is finished (closed, purchased) or can't be shown: go to the app.
    private var onFinish: ((_ showPaywall: Bool) -> Void)?
    private var onFallback: (() -> Void)?
    private var finished = false

    /// The remote onboarding controller, or nil (use ours). `onFinish(showPaywall)` leaves the onboarding;
    /// `onFallback` shows ours if the remote one fails after it was shown.
    func makeOnboarding(onFinish: @escaping (_ showPaywall: Bool) -> Void,
                        onFallback: @escaping () -> Void) async -> UIViewController? {
        self.onFinish = onFinish
        self.onFallback = onFallback
        finished = false
        #if DEBUG
        if AppQA.enabled { return nil }
        #endif
        guard await PaywallProvider.shared.waitUntilActivated(timeout: Self.loadTimeout) else { return nil }
        let placement = Constants.Keys.onboardingPlacement

        let flow: AdaptyFlow?
        do {
            flow = try await Adapty.getFlow(placementId: placement, loadTimeout: Self.loadTimeout)
        } catch {
            flow = nil
            #if DEBUG
            print("[AdaptyOnboarding] no flow for \(placement): \(error)")
            #endif
        }
        if let flow, flow.hasViewConfiguration {
            guard RemoteFlowGate.allows(flow.remoteConfigs) else { return nil }
            do {
                let configuration = try await AdaptyUI.getFlowConfiguration(forFlow: flow, loadTimeout: Self.loadTimeout)
                AmplitudeService.shared.logRedesignEvent("remote_onboarding_shown",
                                                         properties: ["kind": "flow", "flow_name": flow.name,
                                                                      "variation_id": flow.variationId])
                return PaywallProvider.shared.builderController(
                    configuration: configuration, placement: placement, source: "onboarding", onPurchase: nil,
                    onClose: { [weak self] _ in self?.finish(showPaywall: false) },
                    onPurchased: { [weak self] _ in self?.finish(showPaywall: false) },
                    onFailure: { [weak self] _ in self?.fallBack() })
            } catch {
                ErrorReporter.report(error, operation: "remote_onboarding_load",
                                     details: .init(provider: "adapty", extra: ["kind": "flow"]))
            }
        }
        return await legacyOnboarding(placement: placement)
    }

    private func legacyOnboarding(placement: String) async -> UIViewController? {
        do {
            let onboarding = try await Adapty.getOnboarding(placementId: placement, loadTimeout: Self.loadTimeout)
            guard RemoteFlowGate.allows(onboarding.remoteConfig.map { [$0] } ?? []) else { return nil }
            let configuration = try AdaptyUI.getOnboardingConfiguration(forOnboarding: onboarding)
            let controller = try AdaptyUI.onboardingController(with: configuration, delegate: self,
                                                               statusBarStyle: .darkContent)
            AmplitudeService.shared.logRedesignEvent("remote_onboarding_shown",
                                                     properties: ["kind": "onboarding", "name": onboarding.name,
                                                                  "variation_id": onboarding.variationId])
            return controller
        } catch {
            // No onboarding in this placement is the normal "use ours" case, so this isn't reported.
            #if DEBUG
            print("[AdaptyOnboarding] none for \(placement): \(error)")
            #endif
            return nil
        }
    }

    private func finish(showPaywall: Bool) {
        guard !finished else { return }
        finished = true
        onFinish?(showPaywall)
    }

    private func fallBack() {
        guard !finished else { return }
        finished = true
        onFallback?()
    }
}

// MARK: - Legacy Adapty Onboarding

extension AdaptyOnboardingProvider: AdaptyOnboardingControllerDelegate {

    func onboardingController(_ controller: AdaptyOnboardingController,
                              didFinishLoading action: OnboardingsDidFinishLoadingAction) {}

    /// Last screen's close → the app, with the onboarding paywall like our onboarding ends.
    func onboardingController(_ controller: AdaptyOnboardingController, onCloseAction action: AdaptyOnboardingsCloseAction) {
        finish(showPaywall: true)
    }

    /// "Open paywall" button: its action id names the placement (empty → the onboarding paywall), shown over the
    /// onboarding; a purchase there ends the onboarding.
    func onboardingController(_ controller: AdaptyOnboardingController,
                              onPaywallAction action: AdaptyOnboardingsOpenPaywallAction) {
        let placement = action.actionId.isEmpty ? Constants.Keys.obPlacement : action.actionId
        let paywall = PaywallProvider.shared.makePaywall(placement: placement, source: "remote_onboarding") { [weak self] in
            self?.finish(showPaywall: false)
        }
        controller.present(paywall, animated: true)
    }

    func onboardingController(_ controller: AdaptyOnboardingController,
                              onCustomAction action: AdaptyOnboardingsCustomAction) {}

    func onboardingController(_ controller: AdaptyOnboardingController,
                              onStateUpdatedAction action: AdaptyOnboardingsStateUpdatedAction) {}

    func onboardingController(_ controller: AdaptyOnboardingController,
                              onAnalyticsEvent event: AdaptyOnboardingsAnalyticsEvent) {}

    func onboardingController(_ controller: AdaptyOnboardingController, didFailWithError error: AdaptyUIError) {
        ErrorReporter.report(error, operation: "remote_onboarding_render",
                             details: .init(provider: "adapty", extra: ["kind": "onboarding"]))
        fallBack()
    }

    func onboardingsControllerLoadingPlaceholder(_ controller: AdaptyOnboardingController) -> UIView? { nil }
}
