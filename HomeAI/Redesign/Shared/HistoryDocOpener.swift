import UIKit

/// Opens a saved generation (ImageDoc) in the result screen, restoring the prompt state so
/// regenerate / edit keep working. Shared by Home (Recent projects) and Projects.
enum HistoryDocOpener {

    static func thumbnailPath(for doc: ImageDoc) -> String {
        let fm = FileManager.default
        if let preview = doc.previewPath, fm.fileExists(atPath: preview) { return preview }
        return doc.storagePath
    }

    static func open(doc: ImageDoc, image: UIImage) {
        let fileManager = FileManager.default
        let repo = ImageHistoryService()
        let option = doc.designOption ?? .interior
        var resolvedStyleName = doc.style
        var resolvedColorName = doc.colorName
        var canRegenerate = doc.canRegenerate && (doc.originalPath.flatMap { fileManager.fileExists(atPath: $0) } ?? false)

        let promptManager = GemeniPromptManager()
        promptManager.updateOption(option)
        promptManager.updateBaseImage(image)
        if let mode = doc.savedDesignMode { promptManager.updateDesignMode(mode) }
        if let material = doc.savedSurfaceMaterial { promptManager.updateSurfaceMaterial(material) }
        if let custom = doc.surfaceCustomPrompt, !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            promptManager.updateSurfaceCustomPrompt(custom)
        }
        if let object = doc.objectToReplace, !object.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            promptManager.updateObjectToReplace(object)
        }
        if let replaceMode = doc.savedReplaceMode { promptManager.updateReplaceMode(replaceMode) }

        switch option {
        case .interior:
            if let room = doc.savedInteriorRoomType { promptManager.updateRoom(room) } else { canRegenerate = false }
        case .exterior:
            if let building = doc.savedExteriorBuildingType { promptManager.updateExteriorType(building) } else { canRegenerate = false }
        case .garden:
            if let garden = doc.savedGardenType { promptManager.updateGardenType(garden) } else { canRegenerate = false }
        case .rearrange:
            if let sub = doc.savedRearrangeSubOption {
                promptManager.updateRearrangeSubOption(sub)
                resolvedStyleName = sub.displayTitle
            } else {
                canRegenerate = false
            }
        default:
            break
        }

        if option != .rearrange {
            if let colorName = doc.colorName,
               let color = ColorType.allCases.first(where: { $0.name.caseInsensitiveCompare(colorName) == .orderedSame }) {
                promptManager.updateColor(color)
            } else {
                let random = ColorType.allCases.randomElement() ?? .random
                promptManager.updateColor(random)
                resolvedColorName = random.name
            }
            if let saved = savedStyle(for: option, doc: doc) {
                promptManager.updateStyle(saved.style)
                resolvedStyleName = saved.name
            } else if let random = randomStyle(for: option) {
                promptManager.updateStyle(random.style)
                resolvedStyleName = random.name
            }
        }

        let model = ImageDetailModel(
            previewsImage: nil,
            image: image,
            color: resolvedColorName ?? "Random",
            style: resolvedStyleName ?? "",
            option: option,
            canRegenerate: canRegenerate,
            storagePath: doc.storagePath,
            originalPath: doc.originalPath
        )
        guard let detail = NavigationManager.shared.showInspirationDetail(model: model, promptManager: promptManager) else { return }

        Task { @MainActor [weak detail] in
            guard fileManager.fileExists(atPath: doc.storagePath),
                  let full = try? await repo.loadImage(at: doc.storagePath) else { return }
            detail?.updateAfterImage(full)
        }
        if let originalPath = doc.originalPath, fileManager.fileExists(atPath: originalPath) {
            if canRegenerate { detail.startBeforeLoading() }
            let regenerate = canRegenerate
            Task { @MainActor [weak detail] in
                guard let original = try? await repo.loadImage(at: originalPath) else { return }
                if regenerate { promptManager.updateBaseImage(original) }
                detail?.updateBeforeImage(original)
            }
        }
    }

    private static func savedStyle(for option: DesignOption, doc: ImageDoc) -> (style: UnifiedStyle, name: String)? {
        switch option {
        case .interior, .replace:
            if let style = doc.savedInteriorStyle { return (.interior(style), style.name) }
        case .exterior:
            if let style = doc.savedExteriorStyle { return (.exterior(style), style.name) }
        default:
            break
        }
        guard let name = doc.style else { return nil }
        switch option {
        case .interior:
            return StyleInteriorType.allCases.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
                .map { (.interior($0), name) }
        case .exterior:
            return StyleExteriorType.allCases.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
                .map { (.exterior($0), name) }
        default:
            return nil
        }
    }

    private static func randomStyle(for option: DesignOption) -> (style: UnifiedStyle, name: String)? {
        switch option {
        case .interior, .replace:
            return StyleInteriorType.allCases.randomElement().map { (.interior($0), $0.name) }
        case .exterior:
            return StyleExteriorType.allCases.randomElement().map { (.exterior($0), $0.name) }
        default:
            return nil
        }
    }
}
