import UIKit
import Firebase
import FirebaseCrashlytics
import FBSDKCoreKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        #if DEBUG
        if AppQA.enabled { QANetworkBlocker.install() }
        if AppQA.enabled || ProcessInfo.processInfo.arguments.contains("--paywall-layout-preview") || OnboardingPreview.enabled {
            _ = AmplitudeService.shared
            return true
        }
        #endif
        SentryService.shared.start()
        LocalNotificationService.shared.start()
        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
        _ = AmplitudeService.shared
        AdaptyService.shared.start(id: Constants.Keys.adapty)
        AppsFlyerService.shared.configure(launchOptions: launchOptions)

        DispatchQueue.main.async {
            if FirebaseApp.app() == nil {
                FirebaseApp.configure()
            }
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
            AmplitudeService.shared.logEvent(.openApp)
            let userID = AdaptyService.shared.userID
            if !userID.isEmpty {
                Crashlytics.crashlytics().setUserID(userID)
                SentryService.shared.setUserId(userID)
            }
        }

        Task {
            async let workerConfig = WorkerConfigService.shared.refreshIfNeeded()
            async let supabaseConfig = SupabaseAppConfigService.shared.refreshIfNeeded()
            _ = await (workerConfig, supabaseConfig)
        }

        return true
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        UIDevice.portraitLockedInterfaceOrientations
    }

    // MARK: UISceneSession Lifecycle
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {

    }

    func application(_ application: UIApplication,
                     continue userActivity: NSUserActivity,
                     restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        AppsFlyerService.shared.continueUserActivity(userActivity)
        return true
    }

    func application(_ application: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        AppsFlyerService.shared.handleOpenURL(url, options: options)
        return true
    }
}
