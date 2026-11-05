import AppIntents
import Foundation

// Siri / Shortcuts / Spotlight actions. Each one opens the app and is handed to `AppIntentRouter`,
// which waits until onboarding is done and the tab bar is on screen.

@available(iOS 16.0, *)
enum DesignSpaceAppEnum: String, AppEnum {
    case interior, exterior, garden

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Space"
    static var caseDisplayRepresentations: [DesignSpaceAppEnum: DisplayRepresentation] = [
        .interior: "Room",
        .exterior: "House exterior",
        .garden: "Garden"
    ]

    var option: DesignOption {
        switch self {
        case .interior: return .interior
        case .exterior: return .exterior
        case .garden: return .garden
        }
    }
}

@available(iOS 16.0, *)
struct RedesignRoomIntent: AppIntent {
    static var title: LocalizedStringResource = "Redesign a Room"
    static var description = IntentDescription("Opens ReHomely ready to restyle a photo of your space.")
    static var openAppWhenRun = true

    @Parameter(title: "Space", default: .interior)
    var space: DesignSpaceAppEnum

    init() {}

    init(space: DesignSpaceAppEnum) {
        self.space = space
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        AppIntentRouter.shared.handle(.redesign(space.option), source: "redesign_\(space.rawValue)")
        return .result()
    }
}

@available(iOS 16.0, *)
struct OpenProjectsIntent: AppIntent {
    static var title: LocalizedStringResource = "Open My Projects"
    static var description = IntentDescription("Shows your saved designs in ReHomely.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppIntentRouter.shared.handle(.projects, source: "projects")
        return .result()
    }
}

@available(iOS 16.0, *)
struct AskDesignerIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask AI Designer"
    static var description = IntentDescription("Opens the ReHomely AI designer chat.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppIntentRouter.shared.handle(.assistant, source: "assistant")
        return .result()
    }
}

/// Phrases must contain the app name; translations live in each `<lang>.lproj/AppShortcuts.strings`.
@available(iOS 16.0, *)
struct HomeAIShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RedesignRoomIntent(),
            phrases: [
                "Redesign a room in \(.applicationName)",
                "Redesign my \(\.$space) with \(.applicationName)",
                "New design in \(.applicationName)"
            ],
            shortTitle: "Redesign a Room",
            systemImageName: "wand.and.stars"
        )
        AppShortcut(
            intent: OpenProjectsIntent(),
            phrases: [
                "Open my projects in \(.applicationName)",
                "Show my designs in \(.applicationName)"
            ],
            shortTitle: "My Projects",
            systemImageName: "square.grid.2x2"
        )
        AppShortcut(
            intent: AskDesignerIntent(),
            phrases: [
                "Ask \(.applicationName) designer",
                "Ask the AI designer in \(.applicationName)"
            ],
            shortTitle: "Ask AI Designer",
            systemImageName: "bubble.left.and.text.bubble.right"
        )
    }
}
