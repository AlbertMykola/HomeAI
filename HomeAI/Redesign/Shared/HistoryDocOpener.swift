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
        NavigationManager.shared.showResult(docID: doc.id, image: image, reveal: false)
    }

    /// Rebuilds the prompt state a version was made with (Again / Regenerate / Restyle).
    /// `baseImage` is the photo the new generation starts from (usually the project's original).
    static func restoredManager(for doc: ImageDoc, baseImage: UIImage) -> GemeniPromptManager {
        let option = doc.designOption ?? .interior
        let promptManager = GemeniPromptManager()
        promptManager.updateOption(option)
        promptManager.updateBaseImage(baseImage)
        if let mode = doc.savedDesignMode { promptManager.updateDesignMode(mode) }
        if let material = doc.savedSurfaceMaterial { promptManager.updateSurfaceMaterial(material) }
        if let custom = doc.surfaceCustomPrompt, !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            promptManager.updateSurfaceCustomPrompt(custom)
        }
        if let object = doc.objectToReplace, !object.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            promptManager.updateObjectToReplace(object)
        }
        if let replaceMode = doc.savedReplaceMode { promptManager.updateReplaceMode(replaceMode) }
        if let room = doc.savedInteriorRoomType { promptManager.updateRoom(room) }
        if let building = doc.savedExteriorBuildingType { promptManager.updateExteriorType(building) }
        if let garden = doc.savedGardenType { promptManager.updateGardenType(garden) }
        if let sub = doc.savedRearrangeSubOption { promptManager.updateRearrangeSubOption(sub) }
        if option != .rearrange {
            if let colorName = doc.colorName,
               let color = ColorType.allCases.first(where: { $0.name.caseInsensitiveCompare(colorName) == .orderedSame }) {
                promptManager.updateColor(color)
            }
            if let saved = savedStyle(for: option, doc: doc) {
                promptManager.updateStyle(saved.style)
            } else if doc.customPrompt?.isEmpty == false, let custom = doc.customPrompt {
                promptManager.updateCustomPrompt(custom)
            }
        }
        return promptManager
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

}
