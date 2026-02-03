import Foundation

class UserDefaultsManager {
    
    // MARK: - Singleton
    static public let shared = UserDefaultsManager()
    
    // MARK: - Keys
    private let userDefaults = UserDefaults.standard
    
    // MARK: - User Defaults Accessors
    func saveValue<T: Encodable>(_ value: T, forKey key: String) {
        do {
            let encodedData = try JSONEncoder().encode(value)
            userDefaults.set(encodedData, forKey: key)
            userDefaults.synchronize()
        } catch {
            print("Error saving value to UserDefaults: \(error.localizedDescription)")
        }
    }
    
    func getValue<T: Decodable>(forKey key: String) -> T? {
        guard let encodedData = userDefaults.data(forKey: key) else {
            return nil
        }
        do {
            let decodedValue = try JSONDecoder().decode(T.self, from: encodedData)
            return decodedValue
        } catch {
            print("Error retrieving value from UserDefaults: \(error.localizedDescription)")
            return nil
        }
    }
    
    func removeValue(forKey key: String) {
        userDefaults.removeObject(forKey: key)
        userDefaults.synchronize()
    }
    
    func clearUserDefaults() {
        if let appDomain = Bundle.main.bundleIdentifier {
            userDefaults.removePersistentDomain(forName: appDomain)
            userDefaults.synchronize()
        }
    }
}

extension UserDefaults {

    subscript<T>(key: String) -> T? {
        get {
            return value(forKey: key) as? T
        }
        set {
            set(newValue, forKey: key)
        }
    }
}
