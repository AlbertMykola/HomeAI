import UIKit
import FBSDKCoreKit
import UserNotifications

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    private enum ShortcutType {
        static let exclusiveOffer = "com.homeai.exclusiveOffer"
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        UIDevice.lockToPortraitIfNeeded(in: windowScene)
        #if DEBUG
        if AppQA.enabled {
            NavigationManager.shared.setupWindow(with: windowScene)
            return
        }
        if OnboardingPreview.enabled {
            let previewWindow = UIWindow(windowScene: windowScene)
            previewWindow.overrideUserInterfaceStyle = .light
            previewWindow.rootViewController = ProcessInfo.processInfo.arguments.contains("--onboarding-splash")
                ? AppStoryboard.instantiate(LaunchViewController.self) : AppStoryboard.instantiate(OBPageViewController.self)
            previewWindow.makeKeyAndVisible()
            window = previewWindow
            return
        }
        if ProcessInfo.processInfo.arguments.contains("--paywall-layout-preview") {
            let previewWindow = UIWindow(windowScene: windowScene)
            let preview = AppStoryboard.instantiate(PaywallViewController.self)
            let previewArguments = ProcessInfo.processInfo.arguments
            if previewArguments.contains("--paywall-placement-save") {
                preview.placement = Constants.Keys.saveImagePlacement
            } else if previewArguments.contains("--paywall-placement-edit") {
                preview.placement = Constants.Keys.detailsEditPlacement
            } else if previewArguments.contains("--paywall-placement-default") {
                preview.placement = Constants.Keys.defaults
            } else {
                preview.placement = Constants.Keys.reachedLimit
            }
            previewWindow.rootViewController = preview
            previewWindow.makeKeyAndVisible()
            window = previewWindow
            return
        }
        #endif
        NavigationManager.shared.setupWindow(with: windowScene)
        #if DEBUG
        // `-slowAnimations 4`: every animation in the app window runs 4× slower (transition / jank checks).
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-slowAnimations"), let factor = Float(args[safe: i + 1] ?? "4"), factor > 0 {
            windowScene.windows.forEach { $0.layer.speed = 1 / factor }
        }
        #endif

        if let response = connectionOptions.notificationResponse {
            LocalNotificationService.shared.handleTap(response)
        }

        if let shortcutItem = connectionOptions.shortcutItem {
            handle(shortcutItem: shortcutItem)
        }

        AppsFlyerService.shared.handle(connectionOptions: connectionOptions)
    }

    func windowScene(_ windowScene: UIWindowScene,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        let handled = handle(shortcutItem: shortcutItem)
        completionHandler(handled)
    }

    @discardableResult
    private func handle(shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard shortcutItem.type == ShortcutType.exclusiveOffer else { return false }

        let userId = AdaptyService.shared.userID
        let subject = "Get an Exclusive Offer - Rehomely \(userId)"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        let systemVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model

        let body = """
        Hi Rehomely team,

        I'd love to get an exclusive offer for Rehomely.

        My details:
        - Adapty profile ID: \(userId)
        - App version: \(appVersion) (\(build))
        - Device: \(deviceModel)
        - iOS: \(systemVersion)

        Please let me know what special offer is available for my account.

        Best regards,
        """

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body
        let urlString = "mailto:m.albert.apps@gmail.com?subject=\(encodedSubject)&body=\(encodedBody)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return true
        }

        return false
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        #if DEBUG
        if AppQA.enabled || ProcessInfo.processInfo.arguments.contains("--paywall-layout-preview") || OnboardingPreview.enabled { return }
        #endif
        AppEvents.shared.activateApp()
        Task { @MainActor in
            AdaptyService.shared.setMetaAttributionForCAPIIfNeeded()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            LocalNotificationService.shared.sync(requestPermissionIfNeeded: false)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Log ATT permission only once per install.
            if UserDefaults.standard.bool(forKey: Constants.Keys.didLogTrackingPermission) {
                return
            }
            // First launch asks after O4; returning users retain the existing launch behavior.
            guard NavigationManager.shared.isShowingMainApp else { return }
            print("[SceneDelegate] Виклик TrackingManager.requestPermission...")
            
            TrackingManager.requestPermission { status in
                
                let granted = (status == .authorized)
                
                AmplitudeService.shared.logEvent(.trackingPermission(granted: granted))
                UserDefaults.standard.set(true, forKey: Constants.Keys.didLogTrackingPermission)
                AppsFlyerService.shared.startReadySessionIfTrackingResolved()
                
                if !granted {
                    print("[SceneDelegate] Дозвіл на відстеження НЕ надано.")
                }
            }
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        NavigationManager.shared.showOpenOffer()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        AppsFlyerService.shared.continueUserActivity(userActivity)
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        AppsFlyerService.shared.handle(openURLContexts: URLContexts)
    }
}
