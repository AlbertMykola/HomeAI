import UIKit

/// Runs App Intent actions once the main UI exists. An intent can arrive during a cold launch (launch screen),
/// during first-launch onboarding, or while the app is already open; it is kept until the tab bar is the root.
@MainActor
final class AppIntentRouter {

    enum Action: Equatable {
        case redesign(DesignOption)
        case projects
        case assistant
    }

    static let shared = AppIntentRouter()

    private var pending: (action: Action, source: String)?

    func handle(_ action: Action, source: String) {
        AmplitudeService.shared.logRedesignEvent("app_intent_opened", properties: ["intent": source])
        pending = (action, source)
        runPendingIfReady()
    }

    /// Called by `NavigationManager` after the tab bar becomes the root.
    func runPendingIfReady() {
        guard let pending, NavigationManager.shared.isMainUIReady else { return }
        self.pending = nil
        // Let the root cross-dissolve finish so pushes land on the visible tab.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            Self.perform(pending.action)
        }
    }

    private static func perform(_ action: Action) {
        let navigation = NavigationManager.shared
        switch action {
        case .redesign(let option):
            navigation.selectTab(.create)
            navigation.startDesign(option: option)
        case .projects:
            navigation.selectTab(.projects)
        case .assistant:
            navigation.selectTab(.create)
            navigation.showAssistant()
        }
    }
}
