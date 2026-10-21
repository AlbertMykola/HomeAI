import UIKit

/// App Review 5.1.2(i): before the first upload, say that the photo and request text go to a third-party AI service
/// and get an explicit "Agree". Provider-neutral text (Albert, 2026-10-21), so one agreement covers both providers;
/// earlier per-provider agreements still count.
enum AIPhotoConsent {

    private static func key(for provider: ImageGenerationProvider) -> String {
        "ai_photo_consent_\(provider.rawValue)"
    }

    static var currentProvider: ImageGenerationProvider {
        SupabaseAppConfigService.shared.imageGenerationProvider
    }

    static var hasConsent: Bool {
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: key(for: currentProvider))
            || [ImageGenerationProvider.gemini, .openAI].contains { defaults.bool(forKey: key(for: $0)) }
    }

    /// Runs `action` right away if the user already agreed, otherwise asks first. "Not now" does nothing.
    static func run(from presenter: UIViewController, _ action: @escaping () -> Void) {
        #if DEBUG
        if AppQA.enabled { return action() }
        #endif
        guard !hasConsent else { return action() }
        let provider = currentProvider
        AmplitudeService.shared.logRedesignEvent("ai_consent_shown", properties: ["provider": provider.rawValue])
        DSAlertViewController.show(
            from: presenter,
            title: "Your photo is sent for processing".localized,
            message: "To create your design, Rehomely sends your photo and request text to a third-party AI service. They are used only to generate the image. Details are in our Privacy Policy.".localized,
            actions: [
                .init(title: "Not now".localized, style: .cancel) {
                    AmplitudeService.shared.logRedesignEvent("ai_consent_declined", properties: ["provider": provider.rawValue])
                },
                .init(title: "I agree".localized, style: .primary) {
                    UserDefaults.standard.set(true, forKey: key(for: provider))
                    AmplitudeService.shared.logRedesignEvent("ai_consent_accepted", properties: ["provider": provider.rawValue])
                    action()
                }
            ])
    }
}
