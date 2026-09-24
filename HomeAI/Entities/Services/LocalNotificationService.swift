import UIKit
import UserNotifications

final class LocalNotificationService: NSObject {
    static let shared = LocalNotificationService()

    private enum Defaults {
        static let idPrefix = "homeai.local.reengage."
        static let hour = 20
        static let minute = 12
        static let count = 15
        static let minimumLeadMinutes = 10
    }

    private override init() {
        super.init()
    }

    func start() {
        UNUserNotificationCenter.current().delegate = self
    }

    func handleTap(_ response: UNNotificationResponse) {
        guard response.notification.request.identifier.hasPrefix(Defaults.idPrefix) else { return }
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        DispatchQueue.main.async {
            NavigationManager.shared.handleLocalPushOpen()
        }
    }

    func sync(requestPermissionIfNeeded: Bool = true) {
        Task { @MainActor in
            await self.performSync(requestPermissionIfNeeded: requestPermissionIfNeeded)
        }
    }

    @MainActor
    private func performSync(requestPermissionIfNeeded: Bool) async {
        if AdaptyService.shared.hasActiveSubscription {
            cancelPending()
            return
        }
        guard hasCompletedOnboarding, NavigationManager.shared.isShowingMainApp else { return }

        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            scheduleUpcomingPushes()
        case .notDetermined:
            guard requestPermissionIfNeeded, !shouldDeferPermissionPrompt else { return }
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
            if granted {
                scheduleUpcomingPushes()
            }
        default:
            break
        }
    }

    // MARK: - Schedule

    private func scheduleUpcomingPushes() {
        cancelPending()
        guard let firstSlot = nextDeliveryDate() else { return }
        let calendar = Calendar.current
        let startIndex = (calendar.ordinality(of: .day, in: .era, for: firstSlot) ?? 0) % Defaults.count

        for offset in 0..<Defaults.count {
            guard let fireDate = calendar.date(byAdding: .day, value: offset, to: firstSlot) else { continue }
            let messageIndex = (startIndex + offset) % Defaults.count
            let content = UNMutableNotificationContent()
            content.title = "local_push_\(messageIndex + 1)_title".localized
            content.body = "local_push_\(messageIndex + 1)_body".localized
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: Defaults.idPrefix + String(offset),
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func cancelPending() {
        let ids = (0..<Defaults.count).map { Defaults.idPrefix + String($0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }

    private func nextDeliveryDate() -> Date? {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = Defaults.hour
        components.minute = Defaults.minute
        components.second = 0
        guard let todaySlot = calendar.date(from: components) else { return nil }
        let earliest = now.addingTimeInterval(TimeInterval(Defaults.minimumLeadMinutes * 60))
        if todaySlot > earliest {
            return todaySlot
        }
        return calendar.date(byAdding: .day, value: 1, to: todaySlot)
    }

    private var hasCompletedOnboarding: Bool {
        let didShow: Bool? = UserDefaultsManager.shared.getValue(forKey: Constants.Keys.didShowOnboarding)
        return didShow == true
    }

    private var shouldDeferPermissionPrompt: Bool {
        let top = UIApplication.getTopViewController()
        return top is PaywallViewController || top is OBPageViewController || top is LaunchViewController
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension LocalNotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        handleTap(response)
        completionHandler()
    }
}
