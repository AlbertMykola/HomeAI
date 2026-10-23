import Foundation
import UIKit
import AudioToolbox
import CoreHaptics
import SafariServices

public enum AlertTimeout: Double {
    case low = 0.95
    case medium = 1.7
    case long = 2.5
}

extension UIViewController {
        
    func hapticVibration(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        if UIDevice.current.hasHapticFeedback {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.impactOccurred()
        } else {
            AudioServicesPlaySystemSound(1519)
        }
    }
    
    func hardHapticVibration() {
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
    }
    
    func presentExternalURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let safari = SFSafariViewController(url: url)
        safari.modalPresentationStyle = .pageSheet
        presentSafely(safari)
    }

    /// Present only when the VC can actually show a modal (window, not mid-transition).
    func presentSafely(_ viewController: UIViewController, animated: Bool = true, retryCount: Int = 0, completion: (() -> Void)? = nil) {
        guard isViewLoaded, view.window != nil, canPresentModal else {
            retryPresentSafely(viewController, animated: animated, retryCount: retryCount, completion: completion)
            return
        }
        if let presented = presentedViewController {
            if presented.isBeingDismissed {
                retryPresentSafely(viewController, animated: animated, retryCount: retryCount, completion: completion)
                return
            }
            presented.presentSafely(viewController, animated: animated, retryCount: retryCount, completion: completion)
            return
        }
        present(viewController, animated: animated, completion: completion)
    }

    var canPresentModal: Bool {
        isViewLoaded
            && view.window != nil
            && !isBeingDismissed
            && !isBeingPresented
            && !isMovingFromParent
            && !isMovingToParent
            && transitionCoordinator == nil
    }

    private func retryPresentSafely(_ viewController: UIViewController, animated: Bool, retryCount: Int, completion: (() -> Void)?) {
        guard retryCount < 3 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.presentSafely(viewController, animated: animated, retryCount: retryCount + 1, completion: completion)
        }
    }

    func presentHidingAlert(title: String?, message: String, timeOut: AlertTimeout = .low, completion: (() -> ())? = nil) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        presentSafely(alertController)

        DispatchQueue.main.asyncAfter(deadline: .now() + timeOut.rawValue) {
            alertController.dismiss(animated: true)
            completion?()
        }
    }
}

extension UIDevice {
    
    // MARK: - Internal methods
    var hasHapticFeedback: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    /// Foldable iPhones (iPhone Duo): the inner display is used in both orientations and in Split View.
    static let isFoldablePhone: Bool = {
        let foldableModels: Set<String> = ["iPhone19,4"]
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return foldableModels.contains(simulated)
        }
        var info = utsname()
        uname(&info)
        let model = withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        return foldableModels.contains(model)
    }()

    /// iPad and classic iPhones stay portrait; iPhone Duo rotates (Info.plist lists landscape for iPhone).
    static var isPortraitLocked: Bool {
        current.userInterfaceIdiom == .pad || !isFoldablePhone
    }

    static var portraitLockedInterfaceOrientations: UIInterfaceOrientationMask {
        isPortraitLocked ? .portrait : .allButUpsideDown
    }

    static func lockToPortraitIfNeeded(in windowScene: UIWindowScene) {
        guard isPortraitLocked else { return }

        if #available(iOS 16.0, *) {
            let preferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
            windowScene.requestGeometryUpdate(preferences) { _ in }
        }
    }
}
