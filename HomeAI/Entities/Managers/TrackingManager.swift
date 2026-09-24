import AppTrackingTransparency
import AdSupport
import Foundation

struct TrackingManager {
    private static var isTrackingPermissionRequestInProgress = false
    private static var trackingPermissionCompletions: [(ATTrackingManager.AuthorizationStatus) -> Void] = []
    
    /**
     Запитує дозвіл на відстеження (ATT).
     Ця функція перевіряє поточний статус і показує алерт ТІЛЬКИ якщо статус `.notDetermined`.
     Вона повертає кінцевий статус у completion блоці.
     */
    static func requestPermission(completion: @escaping (ATTrackingManager.AuthorizationStatus) -> Void) {
        DispatchQueue.main.async {
            if #available(iOS 14, *) {
                let currentStatus = ATTrackingManager.trackingAuthorizationStatus
                guard currentStatus == .notDetermined else {
                    completion(currentStatus)
                    return
                }

                trackingPermissionCompletions.append(completion)
                guard !isTrackingPermissionRequestInProgress else { return }
                isTrackingPermissionRequestInProgress = true

                ATTrackingManager.requestTrackingAuthorization { status in
                    DispatchQueue.main.async {
                        let completions = trackingPermissionCompletions
                        trackingPermissionCompletions.removeAll()
                        isTrackingPermissionRequestInProgress = false
                        completions.forEach { $0(status) }
                    }
                }
            } else {
                completion(.authorized)
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
