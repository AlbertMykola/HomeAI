import AppsFlyerLib
import UIKit

final class AppsFlyerService: NSObject {
    static let shared = AppsFlyerService()

    private var didConfigure = false
    private var hasPendingSession = false
    private var pendingUserActivities: [NSUserActivity] = []
    private var pendingOpenURLs: [(URL, [AnyHashable: Any]?)] = []

    private override init() {
        super.init()
    }

    /// `initialize` має бути до Scene `continue` / `openURL` (cold start OneLink).
    func configure(launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) {
        guard !didConfigure else { return }
        didConfigure = true

        let lib = AppsFlyerLib.shared()
        #if DEBUG
        lib.isDebug = true
        #endif
        lib.delegate = self
        lib.initialize(devKey: Constants.Keys.appsFlyer, appId: Constants.Keys.appleId)
        lib.deepLinkDelegate = self
        lib.handleLaunchOptions(launchOptions)
        flushPendingDeepLinks()
        lib.registerSessionReadyListener { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.hasPendingSession = true
                self?.startReadySessionIfTrackingResolved()
            }
        }
    }

    /// ATT belongs to the onboarding/lifecycle UI. A ready SDK must not present it over O1.
    func startReadySessionIfTrackingResolved() {
        guard hasPendingSession,
              UserDefaults.standard.bool(forKey: Constants.Keys.didLogTrackingPermission) else { return }
        hasPendingSession = false
        AppsFlyerLib.shared().start()
        AdaptyService.shared.setAppsFlyerAttribution()
    }

    func start() {
        configure()
    }

    /// SKAN CV оновлює AppsFlyer SDK з Conversion Studio. Без цього івенту CV лишається 0.
    func logSKANSubscription(isTrial: Bool, revenue: Decimal, currencyCode: String?, productId: String) {
        var values: [AnyHashable: Any] = [AFEventParamContentId: productId]
        let name: String

        if isTrial {
            // A trial start is not revenue; report revenue only after a charge occurs.
            name = AFEventStartTrial
        } else {
            name = AFEventSubscribe
            values[AFEventParamRevenue] = NSDecimalNumber(decimal: revenue)
            if let currencyCode, !currencyCode.isEmpty {
                values[AFEventParamCurrency] = currencyCode
            }
        }
        AppsFlyerLib.shared().logEvent(name, withValues: values)
    }

    func continueUserActivity(_ userActivity: NSUserActivity) {
        guard didConfigure else {
            pendingUserActivities.append(userActivity)
            return
        }
        _ = AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
    }

    func handleOpenURL(_ url: URL, options: [AnyHashable: Any]? = nil) {
        guard didConfigure else {
            pendingOpenURLs.append((url, options))
            return
        }
        AppsFlyerLib.shared().handleOpen(url, options: options)
    }

    func handle(connectionOptions: UIScene.ConnectionOptions) {
        connectionOptions.userActivities.forEach(continueUserActivity)
        handle(openURLContexts: connectionOptions.urlContexts)
    }

    func handle(openURLContexts: Set<UIOpenURLContext>) {
        openURLContexts.forEach { handleOpenURL($0.url) }
    }

    private func flushPendingDeepLinks() {
        let activities = pendingUserActivities
        pendingUserActivities.removeAll()
        activities.forEach { _ = AppsFlyerLib.shared().continue($0, restorationHandler: nil) }

        let urls = pendingOpenURLs
        pendingOpenURLs.removeAll()
        urls.forEach { AppsFlyerLib.shared().handleOpen($0.0, options: $0.1) }
    }
}

// MARK: - AppsFlyerLibDelegate

extension AppsFlyerService: AppsFlyerLibDelegate {
    func onConversionDataSuccess(_ conversionInfo: [AnyHashable: Any]) {
        DispatchQueue.main.async {
            AdaptyService.shared.setAppsFlyerAttribution(rawData: conversionInfo)
        }
    }

    func onConversionDataFail(_ error: Error) {
        #if DEBUG
        print("[AppsFlyer] Conversion data failed: \(error.localizedDescription)")
        #endif
    }
}

extension AppsFlyerService: AppsFlyerDeepLinkDelegate {
    func didResolveDeepLink(_ result: DeepLinkResult) {
        guard result.status == .found, let clickEvent = result.deepLink?.clickEvent else { return }
        DispatchQueue.main.async {
            AdaptyService.shared.setAppsFlyerAttribution(rawData: clickEvent)
        }
    }
}
