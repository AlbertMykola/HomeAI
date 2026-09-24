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
        }
    }

    func setUserId(_ id: String) {
        let user = User()
        user.userId = id
        SentrySDK.setUser(user)
    }
}
