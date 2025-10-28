import Foundation
import Security

final class FreeGenerationManager {
    static let shared = FreeGenerationManager()
    private let key = "generationCount"
    private let maxCount = 3

    private init() {}

    // Зберігати у Keychain
    private func saveCount(_ count: Int) {
        guard let data = "\(count)".data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        let setQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemAdd(setQuery as CFDictionary, nil)
    }

    // Зчитати з Keychain
    private func loadCount() -> Int {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        if status == errSecSuccess,
            let data = dataTypeRef as? Data,
            let str = String(data: data, encoding: .utf8),
            let val = Int(str) {
            return val
        }
        return 0
    }

    // Для зовнішнього доступу
    var canGenerateForFree: Bool {
        // Якщо є підписка, тут інтегруйте свою перевірку підписки!
        // if ApphudService.shared.hasActiveSubscription { return true }
        return loadCount() < maxCount
    }

    func increment() {
        let count = loadCount()
        saveCount(count + 1)
    }

    func reset() {
        saveCount(0)
    }
}
