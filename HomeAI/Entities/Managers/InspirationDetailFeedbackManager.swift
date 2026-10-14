import UIKit
import MessageUI
import StoreKit

@MainActor
final class InspirationDetailFeedbackManager: NSObject, MFMailComposeViewControllerDelegate {

    private var pendingSystemReviewWork: DispatchWorkItem?

    // MARK: - Like

    func handleLike(from viewController: UIViewController, onLikeFeedback: (() -> Void)? = nil) {
        AmplitudeService.shared.logEvent(.detailLikeTap)
        let didShowCustomAlert = UserDefaults.standard.bool(forKey: Constants.Keys.didShowRateAlert)
        if didShowCustomAlert {
            requestSystemReview(in: viewController)
            DispatchQueue.main.async { onLikeFeedback?() }
            return
        }
        pendingSystemReviewWork?.cancel()
        presentLikeAlert(in: viewController, persistDismissal: true, onDismissed: onLikeFeedback)
    }

    // MARK: - Dislike

    func handleDislike(from viewController: UIViewController, onFeedbackPromptDismissed: (() -> Void)? = nil) {
        AmplitudeService.shared.logEvent(.detailDislikeTap)
        pendingSystemReviewWork?.cancel()

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

        viewController.presentSafely(alert)
    }

    // MARK: - System review (Apple лімітить частоту)

    func showSystemReviewIfNeeded(in viewController: UIViewController, isGeneratedResult: Bool) {
        pendingSystemReviewWork?.cancel()
        guard isGeneratedResult else { return }
        let work = DispatchWorkItem { [weak self, weak viewController] in
            guard let self, let viewController, viewController.view.window != nil else { return }
            self.requestSystemReview(in: viewController)
        }
        pendingSystemReviewWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55, execute: work)
    }

    func requestSystemReview(in viewController: UIViewController) {
        guard SupabaseAppConfigService.shared.obSwRateAlert else { return }
        guard viewController.canPresentModal else { return }
        AmplitudeService.shared.logEvent(.detailReviewRequest)

        guard let scene = viewController.view.window?.windowScene else { return }
        SKStoreReviewController.requestReview(in: scene)
    }

    func presentLikeAlert(in viewController: UIViewController, persistDismissal: Bool = true, onDismissed: (() -> Void)? = nil) {
        guard viewController.canPresentModal else { return }
        AmplitudeService.shared.logEvent(.detailLikeShowAlert)
        guard let alertView = Bundle.main.loadNibNamed("LikeAlertView", owner: nil, options: nil)?.first as? LikeAlertView else {
            return
        }
        alertView.show(in: viewController) {
            if persistDismissal {
                UserDefaults.standard.set(true, forKey: Constants.Keys.didShowRateAlert)
                UserDefaults.standard.synchronize()
            }
            onDismissed?()
        }
    }

    // MARK: - MFMailComposeViewControllerDelegate

    nonisolated func mailComposeController(_ controller: MFMailComposeViewController,
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
        Task { @MainActor in
            AmplitudeService.shared.logEvent(.detailDislikeMailResult(result: resultString))
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - Private
private extension InspirationDetailFeedbackManager {

    /// UIKit викликає completion actions одразу; коротка затримка дає закінчитись анімації закриття `UIAlertController`.
    static func afterSystemAlertDismissed(_ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32, execute: work)
    }

    func presentDislikeEmail(from viewController: UIViewController) {
        let userId = AdaptyService.shared.userID
        let subject = "Dislike - Rehomely \(userId)"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        let systemVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model

        let body = """
        Hi Rehomely team,

        I'd like to share negative feedback.

        Comment:


        Technical details:
        - Adapty profile ID: \(userId)
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
            viewController.presentSafely(mail)
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
