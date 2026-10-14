import UIKit
import UserNotifications

/// Keeps a generation alive after G1 is collapsed (⌄) and tells the user when it's ready.
final class GenerationCenter {

    static let shared = GenerationCenter()
    private init() {}

    /// Set when the user opted in on G2 / already allowed notifications.
    var wantsReadyNotification = false

    private var collapsed: (runner: GenerationRunner, photo: UIImage?, styleTitle: String?)?

    func collapse(runner: GenerationRunner, photo: UIImage?, styleTitle: String?) {
        collapsed = (runner, photo, styleTitle)
        runner.onStateChange = { [weak self] state in
            guard let self else { return }
            switch state {
            case .succeeded(let outcome):
                self.notifyIfInBackground(styleTitle: styleTitle)
                if UIApplication.shared.applicationState == .active {
                    DS.Haptic.success()
                    DSToastView.show("Your design is ready".localized, style: .success, symbol: "sparkles",
                                     action: "Open".localized, duration: 4) {
                        NavigationManager.shared.showResult(docID: outcome.docID, image: outcome.model.image, reveal: true)
                    }
                }
                self.finished(runner: runner)
            case .failed:
                DSToastView.show("Your design couldn't be created. Your credit is back.".localized, style: .warning,
                                 symbol: "exclamationmark.triangle")
                self.finished(runner: runner)
            default:
                break
            }
        }
    }

    func finished(runner: GenerationRunner) {
        if collapsed?.runner === runner { collapsed = nil }
    }

    /// Local "Your design is ready" with the style name when the app isn't in front (dev notes G1 state 3).
    func notifyIfInBackground(styleTitle: String?) {
        guard wantsReadyNotification, UIApplication.shared.applicationState != .active else { return }
        let content = UNMutableNotificationContent()
        content.title = Constants.Text.brand
        content.body = styleTitle.map { String(format: "Your %@ design is ready ✨".localized, $0) }
            ?? "Your design is ready ✨".localized
        content.sound = .default
        content.userInfo = ["type": "generation_ready"]
        let request = UNNotificationRequest(identifier: "generation.ready.\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

/// Mail to support with device info (used after repeated failures).
@MainActor
enum SupportMail {
    static let address = "m.albert.apps@gmail.com"

    static func compose(from presenter: UIViewController, subject: String, body: String?) {
        let userId = AdaptyService.shared.userID
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let text = [body, "", "App \(version) · iOS \(UIDevice.current.systemVersion) · \(userId)"].compactMap { $0 }
            .joined(separator: "\n")
        let encodedSubject = "\(Constants.Text.brand) — \(subject)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "mailto:\(address)?subject=\(encodedSubject)&body=\(encodedBody)") {
            UIApplication.shared.open(url)
        }
    }
}
