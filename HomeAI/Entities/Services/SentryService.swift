import Foundation
import Sentry

final class SentryService {
    static let shared = SentryService()

    private init() {}

    func start() {
        SentrySDK.start { options in
            options.dsn = Constants.Keys.sentryDSN
            #if DEBUG
            options.environment = "development"
            #else
            options.environment = "production"
            #endif
            options.enableAppHangTracking = true
            options.enableWatchdogTerminationTracking = true
            options.enableAutoSessionTracking = true
            // Apple's own crash and hang diagnostics (delivered on a later launch): includes crashes our handler
            // can't report, e.g. watchdog kills or users who crash and never open the app again.
            options.enableMetricKit = true
            // Automatic HTTP 5xx capture only for our own backends (Cloudflare workers, Supabase); SDK hosts like
            // AppsFlyer or Adapty report their own outages. Our ErrorReporter events are unaffected.
            options.failedRequestTargets = ["workers.dev", "supabase.co"]
        }
    }

    func setUserId(_ id: String) {
        let user = User()
        user.userId = id
        SentrySDK.setUser(user)
    }
}
