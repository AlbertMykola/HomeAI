import AppTrackingTransparency
import AdSupport
import Foundation

struct TrackingManager {
    
    /**
     Запитує дозвіл на відстеження (ATT).
     Ця функція перевіряє поточний статус і показує алерт ТІЛЬКИ якщо статус `.notDetermined`.
     Вона повертає кінцевий статус у completion блоці.
     */
    static func requestPermission(completion: @escaping (ATTrackingManager.AuthorizationStatus) -> Void) {
        
        if #available(iOS 14, *) {
            let currentStatus = ATTrackingManager.trackingAuthorizationStatus
            print("[ATT] Поточний статус (до запиту): \(currentStatus.name)")

            switch currentStatus {
            case .authorized, .denied, .restricted:
                // Якщо статус вже відомий (authorized, denied, or restricted),
                // алерт не буде показаний. Просто повертаємо поточний статус.
                print("[ATT] Статус вже відомий: \(currentStatus.name). Запит не буде показаний.")
                DispatchQueue.main.async {
                    completion(currentStatus)
                }
                
            case .notDetermined:
                // Це єдиний випадок, коли алерт МАЄ з'явитися.
                print("[ATT] Статус 'notDetermined'. Запускаємо запит...")
                
                // Виконуємо сам запит
                ATTrackingManager.requestTrackingAuthorization { status in
                    // Відповідь повертається у фоновому потоці,
                    // тому важливо повернутися на головний потік.
                    DispatchQueue.main.async {
                        print("[ATT] Отримано відповідь. Новий статус: \(status.name)")
                        completion(status)
                    }
                }
            @unknown default:
                print("[ATT] Невідомий статус.")
                DispatchQueue.main.async {
                    completion(currentStatus)
                }
            }
        } else {
            // Для iOS < 14, ми не можемо показати запит.
            // Стара логіка 'isAdvertisingTrackingEnabled' працюватиме.
            print("[ATT] iOS < 14. Повертаємо 'authorized' для сумісності.")
            DispatchQueue.main.async {
                completion(.authorized) // Припускаємо, що дозвіл є (як у старі часи)
            }
        }
    }
    
    /**
     Отримує IDFA. Викликайте ЦЮ функцію ТІЛЬКИ ПІСЛЯ того, як отримали `.authorized` статус.
     */
    static func getIDFA() -> String? {
        guard ASIdentifierManager.shared().advertisingIdentifier.uuidString != "00000000-0000-0000-0000-000000000000" else {
            print("[ATT] IDFA - це нулі. Дозвіл не отримано.")
            return nil
        }
        
        let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        print("[ATT] Успішно отримано IDFA: \(idfa)")
        return idfa
    }
}

// Додайте це розширення в той самий файл для зручного логування
@available(iOS 14, *)
extension ATTrackingManager.AuthorizationStatus {
    var name: String {
        switch self {
        case .notDetermined: "notDetermined"
        case .restricted: "restricted"
        case .denied: "denied"
        case .authorized: "authorized"
        @unknown default: "unknown"
        }
    }
}
