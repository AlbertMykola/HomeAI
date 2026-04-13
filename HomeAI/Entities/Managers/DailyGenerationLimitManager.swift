import Foundation
import Security
import UIKit

/// Денний ліміт **15 генерацій** для **підписників** (Keychain). Без підписки ліміт — одна безкоштовна загалом (`FreeGenerationManager`).
final class DailyGenerationLimitManager {

    static let shared = DailyGenerationLimitManager()

    private let service = (Bundle.main.bundleIdentifier ?? "HomeAI") + ".dailyGenerationLimit"
    private let dayAccount = "daily_gen_calendar_day_v1"
    private let countAccount = "daily_gen_count_v1"
    private let maxPerDay = 15

    private init() {}

    /// Чи залишилась квота на сьогодні для преміуму (15 / день). Для не-підписників не використовується для блокування.
    var hasRemainingToday: Bool {
        countForToday() < maxPerDay
    }

    /// Лише для підписників: після успішної генерації збільшити денний лічильник.
    func recordSuccessfulGeneration() {
        guard ApphudService.shared.hasActiveSubscription else { return }
        incrementTodayCount()
    }

    @MainActor
    func presentDailyLimitAlert(from viewController: UIViewController?) {
        AmplitudeService.shared.logEvent(.dailyGenerationLimitReached)
        let title = "Daily limit reached".localized
        let message = "You've used all 15 image generations for today. Please try again tomorrow.".localized
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK".localized, style: .default))
        let presenter = viewController ?? UIApplication.getTopViewController()
        presenter?.present(alert, animated: true)
    }

    private func calendarDayString(for date: Date = Date()) -> String {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        guard let y = c.year, let m = c.month, let d = c.day else { return "" }
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private func countForToday() -> Int {
        let today = calendarDayString()
        guard let storedDay = loadString(account: dayAccount), storedDay == today else {
            return 0
        }
        return Int(loadString(account: countAccount) ?? "0") ?? 0
    }

    private func incrementTodayCount() {
        let today = calendarDayString()
        var count = countForToday()
        if loadString(account: dayAccount) != today {
            count = 0
        }
        count += 1
        saveString(today, account: dayAccount)
        saveString(String(count), account: countAccount)
    }

    private func saveString(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func loadString(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        guard status == errSecSuccess,
              let data = dataTypeRef as? Data,
              let str = String(data: data, encoding: .utf8) else {
            return nil
        }
        return str
    }
}

// MARK: - Єдина перевірка перед Processing / генерацією

enum GenerationAccess {

    enum Result {
        case allowed
        case dailyLimitExceeded
        case requiresSubscription
    }

    /// Підписка: лише денний ліміт 15. Без підписки: лише одна безкоштовна генерація (`FreeGenerationManager`).
    static func evaluate() -> Result {
        if ApphudService.shared.hasActiveSubscription {
            if !DailyGenerationLimitManager.shared.hasRemainingToday { return .dailyLimitExceeded }
            return .allowed
        }
        if !FreeGenerationManager.shared.canGenerateForFree { return .requiresSubscription }
        return .allowed
    }

    /// Повертає `true`, якщо можна запускати Processing / генерацію. Інакше показує потрібний UI і повертає `false`.
    @MainActor
    @discardableResult
    static func requestProcessingIfAllowed(presentingFrom viewController: UIViewController?) -> Bool {
        switch evaluate() {
        case .allowed:
            return true
        case .dailyLimitExceeded:
            DailyGenerationLimitManager.shared.presentDailyLimitAlert(from: viewController)
            return false
        case .requiresSubscription:
            NavigationManager.shared.showPremium(placement: Constants.Keys.reachedLimit)
            return false
        }
    }
}
