import Foundation

/// Values from the gitignored `HomeAI/Resources/Secrets.plist` (copy `Secrets.example.plist` there and fill it).
/// Missing file or empty value → nil.
enum AppSecrets {
    private static let values: [String: String] = {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: String] else { return [:] }
        return dict
    }()

    static func value(for key: String) -> String? {
        let value = values[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
}
