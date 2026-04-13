import UIKit

final class InspirationDetailEditorRouter {

    private let allActions: [EditorActionType] = [
        .deleteObject, .replaceObject, .newWalls, .newFloor, .newStyle, .newColor
    ]

    // MARK: - Visible actions

    func visibleActions(for option: DesignOption?, showsLimited: Bool) -> [EditorActionType] {
        if showsLimited {
            return [.deleteObject, .replaceObject]
        }
        guard let option else { return allActions }
        switch option {
        case .exterior, .garden:
            return allActions.filter { $0 != .newWalls && $0 != .newFloor }
        default:
            return allActions
        }
    }

    // MARK: - Design option inference

    func inferredDesignOption(from data: ImageDetailModel) -> DesignOption {
        switch data.option {
        case .interior, .exterior, .garden:
            return data.option
        default:
            let styleName = data.style.trimmingCharacters(in: .whitespacesAndNewlines)
            if StyleExteriorType.allCases.contains(where: { $0.name.caseInsensitiveCompare(styleName) == .orderedSame }) {
                return .exterior
            }
            if GardenType.allCases.contains(where: { $0.name.caseInsensitiveCompare(styleName) == .orderedSame }) {
                return .garden
            }
            if StyleInteriorType.allCases.contains(where: { $0.name.caseInsensitiveCompare(styleName) == .orderedSame }) {
                return .interior
            }
            return .interior
        }
    }

    // MARK: - Action routing

    func route(
        action: EditorActionType,
        currentImage: UIImage?,
        data: ImageDetailModel?,
        promptManager: GemeniPromptManager?,
        onStyleAction: () -> Void,
        onColorAction: () -> Void,
        dismiss: @escaping () -> Void
    ) {
        AmplitudeService.shared.logEvent(.selectingEdit(type: action))

        guard ApphudService.shared.hasActiveSubscription else {
            NavigationManager.shared.showPremium(placement: Constants.Keys.detailsEditPlacement)
            return
        }

        switch action {
        case .deleteObject:
            let manager = GemeniPromptManager()
            manager.updateOption(.replace)
            if let image = currentImage { manager.updateBaseImage(image) }
            let deletionPrompt = "remove the selected object and fill the area with realistic background matching the surroundings"
            if let data {
                NavigationManager.shared.setPendingInspirationDetailReopen(model: data, promptManager: promptManager)
            }
            NavigationManager.shared.showObjectSelection(
                promptManager: manager,
                requiresPromptInput: false,
                replacementDescription: deletionPrompt
            )
            dismiss()

        case .replaceObject:
            let manager = GemeniPromptManager()
            manager.updateOption(.replace)
            if let image = currentImage { manager.updateBaseImage(image) }
            if let data {
                NavigationManager.shared.setPendingInspirationDetailReopen(model: data, promptManager: promptManager)
            }
            NavigationManager.shared.showObjectSelection(promptManager: manager)
            dismiss()

        case .newWalls:
            let manager = GemeniPromptManager()
            manager.updateOption(.newWalls)
            if let image = currentImage { manager.updateBaseImage(image) }
            if let data {
                NavigationManager.shared.setPendingInspirationDetailReopen(model: data, promptManager: promptManager)
            }
            NavigationManager.shared.showSurfaceMaterialPicker(promptManager: manager)
            dismiss()

        case .newFloor:
            let manager = GemeniPromptManager()
            manager.updateOption(.newFlooring)
            if let image = currentImage { manager.updateBaseImage(image) }
            if let data {
                NavigationManager.shared.setPendingInspirationDetailReopen(model: data, promptManager: promptManager)
            }
            NavigationManager.shared.showSurfaceMaterialPicker(promptManager: manager)
            dismiss()

        case .newStyle:
            onStyleAction()

        case .newColor:
            onColorAction()
        }
    }
}
