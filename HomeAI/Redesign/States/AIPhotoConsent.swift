import UIKit

/// App Review 5.1.2(i): before the first upload, name the third-party AI that receives the photo and request text
/// and get an explicit "Agree". Remembered per provider, so switching the provider (remote config) asks again.
enum AIPhotoConsent {

    private static func key(for provider: ImageGenerationProvider) -> String {
        "ai_photo_consent_\(provider.rawValue)"
    }

    static var currentProvider: ImageGenerationProvider {
        SupabaseAppConfigService.shared.imageGenerationProvider
    }

    static var providerName: String {
        switch currentProvider {
        case .openAI: return "OpenAI"
        case .gemini: return "Google Gemini"
        }
    }

    static var hasConsent: Bool {
        UserDefaults.standard.bool(forKey: key(for: currentProvider))
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
            title: String(format: "Your photo is sent to %@".localized, providerName),
            message: String(format: "To create your design, Rehomely sends your photo and request text to %@, a third-party AI service. They are used only to generate the image. Details are in our Privacy Policy.".localized,
                            providerName),
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
