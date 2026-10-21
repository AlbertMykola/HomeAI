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

    /// No blocking alert (Albert, 2026-10-21): the provider and the Privacy Policy are named under the generate
    /// button (`disclosureText`), and tapping it counts as agreeing. Stored the same way as before, so
    /// `hasConsent` / analytics downstream keep working.
    static func run(from presenter: UIViewController, _ action: @escaping () -> Void) {
        #if DEBUG
        if AppQA.enabled { return action() }
        #endif
        if !hasConsent {
            let provider = currentProvider
            UserDefaults.standard.set(true, forKey: key(for: provider))
            AmplitudeService.shared.logRedesignEvent("ai_consent_accepted",
                                                     properties: ["provider": provider.rawValue, "mode": "inline"])
        }
        action()
    }

    /// "Photo and request are processed by <provider>. Privacy Policy" — the link part is accent-colored.
    static func disclosureText(font: UIFont, color: UIColor, linkColor: UIColor) -> NSAttributedString {
        let link = "Privacy Policy".localized
        let sentence = String(format: "Your photo and request are processed by %@.".localized, providerName)
        let text = NSMutableAttributedString(string: sentence + " ", attributes: [.font: font, .foregroundColor: color])
        text.append(NSAttributedString(string: link, attributes: [
            .font: font, .foregroundColor: linkColor, .underlineStyle: NSUnderlineStyle.single.rawValue
        ]))
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        text.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: text.length))
        return text
    }
}
