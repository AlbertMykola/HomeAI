import UIKit
import MessageUI

@MainActor
final class InspirationDetailFeedbackManager: NSObject, MFMailComposeViewControllerDelegate {

    // MARK: - Like

    func handleLike(from viewController: UIViewController, onLikeFeedback: (() -> Void)? = nil) {
        AmplitudeService.shared.logEvent(.detailLikeTap)
        let didShowLikeAlert = UserDefaults.standard.bool(forKey: Constants.Keys.didShowRateAlert)
        if didShowLikeAlert {
            DispatchQueue.main.async { onLikeFeedback?() }
        } else {
            showLikeAlert(in: viewController, onDismissed: onLikeFeedback)
        }
    }

    // MARK: - Dislike

    func handleDislike(from viewController: UIViewController, onFeedbackPromptDismissed: (() -> Void)? = nil) {
        AmplitudeService.shared.logEvent(.detailDislikeTap)

        let alert = UIAlertController(
            title: "Help us improve".localized,
            message: "Would you like to tell us what you didn't like?".localized,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Share feedback".localized, style: .default) { [weak self] _ in
            AmplitudeService.shared.logEvent(.detailDislikeConfirmShare)
            Self.afterSystemAlertDismissed {
                onFeedbackPromptDismissed?()
                self?.presentDislikeEmail(from: viewController)
            }
        })

        alert.addAction(UIAlertAction(title: "No, thanks".localized, style: .cancel) { _ in
            AmplitudeService.shared.logEvent(.detailDislikeCancelShare)
            Self.afterSystemAlertDismissed {
                onFeedbackPromptDismissed?()
            }
        })

        viewController.present(alert, animated: true)
    }

    // MARK: - Rate alert (auto-show after first generation)

    func showRateAlertIfNeeded(in viewController: UIViewController) {
        let isFirstGeneration = FreeGenerationManager.shared.currentCount == 1
        let didShowAlert = UserDefaults.standard.bool(forKey: Constants.Keys.didShowRateAlert)
        guard isFirstGeneration && !didShowAlert else { return }
        showLikeAlert(in: viewController, onDismissed: nil)
    }

    // MARK: - MFMailComposeViewControllerDelegate

    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult,
                               error: Error?) {
        let resultString: String
        switch result {
        case .cancelled: resultString = "cancelled"
        case .saved:     resultString = "saved"
        case .sent:      resultString = "sent"
        case .failed:    resultString = "failed"
        @unknown default: resultString = "unknown"
        }
        AmplitudeService.shared.logEvent(.detailDislikeMailResult(result: resultString))
        controller.dismiss(animated: true)
    }
}

// MARK: - Private
private extension InspirationDetailFeedbackManager {

    /// UIKit викликає completion actions одразу; коротка затримка дає закінчитись анімації закриття `UIAlertController`.
    static func afterSystemAlertDismissed(_ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32, execute: work)
    }

    func showLikeAlert(in viewController: UIViewController, onDismissed: (() -> Void)? = nil) {
        AmplitudeService.shared.logEvent(.detailLikeShowAlert)
        guard let alertView = Bundle.main.loadNibNamed("LikeAlertView", owner: nil, options: nil)?.first as? LikeAlertView else {
            return
        }
        alertView.show(in: viewController) {
            UserDefaults.standard.set(true, forKey: Constants.Keys.didShowRateAlert)
            UserDefaults.standard.synchronize()
            onDismissed?()
        }
    }

    func presentDislikeEmail(from viewController: UIViewController) {
        let userId = ApphudService.shared.userID
        let subject = "Dislike - HomeAI \(userId)"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        let systemVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model

        let body = """
        Hi HomeAI team,

        I'd like to share negative feedback.

        Comment:


        Technical details:
        - Apphud user ID: \(userId)
        - App version: \(appVersion) (\(build))
        - Device: \(deviceModel)
        - iOS: \(systemVersion)
        """

        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setToRecipients(["m.albert.apps@gmail.com"])
            mail.setSubject(subject)
            mail.setMessageBody(body, isHTML: false)
            viewController.present(mail, animated: true)
        } else {
            let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
            let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body
            let urlString = "mailto:m.albert.apps@gmail.com?subject=\(encodedSubject)&body=\(encodedBody)"
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
                AmplitudeService.shared.logEvent(.detailDislikeMailResult(result: "mailto_fallback"))
            }
        }
    }
}
