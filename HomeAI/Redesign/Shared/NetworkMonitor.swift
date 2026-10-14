import Foundation
import Network

extension Notification.Name {
    static let networkStatusDidChange = Notification.Name("networkStatusDidChange")
}

/// NWPathMonitor wrapper (Home offline banner, global offline states).
final class NetworkMonitor {

    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private(set) var isOnline = true

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            DispatchQueue.main.async {
                guard let self, self.isOnline != online else { return }
                self.isOnline = online
                NotificationCenter.default.post(name: .networkStatusDidChange, object: nil)
            }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }

    func start() {}
}
