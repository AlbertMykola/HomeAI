import UIKit

/// State shared by the A/04 wizard steps (W1 photo → W2 room → W3 style → W4 final touches).
final class WizardSession {

    enum Step: Int { case photo, room, style, final, tool }

    enum Palette: Int, CaseIterable {
        case auto, warm, sage, cool, earthy, bold

        var colorType: ColorType {
            switch self {
            case .auto: return .random
            case .warm: return .beige
            case .sage: return .fresh
            case .cool: return .calm
            case .earthy: return .earthy
            case .bold: return .lively
            }
        }

        var title: String {
            switch self {
            case .auto: return "Auto".localized
            case .warm: return "Warm".localized
            case .sage: return "Sage".localized
            case .cool: return "Cool".localized
            case .earthy: return "Earthy".localized
            case .bold: return "Bold".localized
            }
        }
    }

    /// What the user picked on W2 (depends on the option).
    enum Place: Equatable {
        case room(InteriorType)
        case building(ExteriorType)

        var title: String {
            switch self {
            case .room(let r): return r.name
            case .building(let b): return b.name
            }
        }
    }

    /// What the user picked on W3.
    enum Style: Equatable {
        case interior(StyleInteriorType)
        case exterior(StyleExteriorType)
        case garden(GardenType)
        case custom(String)

        var title: String {
            switch self {
            case .interior(let s): return s.name
            case .exterior(let s): return s.name
            case .garden(let g): return g.name
            case .custom: return "Custom".localized
            }
        }
    }

    let option: DesignOption
    let promptManager = GemeniPromptManager()

    var photo: UIImage?
    var isDemoPhoto = false
    var detectedPlace: Place?
    /// Result → T5 / T6 / T8: the tool edits the current version; Apply hands the prompt back for a new version
    /// in the same project instead of starting a new design.
    var onResultEdit: ((GemeniPromptManager) -> Void)?
    var isResultEdit: Bool { onResultEdit != nil }
    var place: Place?
    var style: Style?
    var palette: Palette = .auto
    var keepStructure = true
    var details: String = ""
    /// Exact palette from an Inspiration idea (W4 palette tap clears it).
    var colorOverride: ColorType?
    /// Style came from Inspiration ("Try on my room") → W3 is skipped.
    private(set) var isStylePreset = false

    init(option: DesignOption) {
        self.option = option
        promptManager.updateOption(option)
    }

    /// Interior: W1–W4. Every other tool: W1 + its own settings screen (A/07, step 2/2).
    var steps: [Step] {
        switch option {
        case .interior: return isStylePreset ? [.photo, .room, .final] : [.photo, .room, .style, .final]
        case .replace, .delete: return [.photo]
        default: return [.photo, .tool]
        }
    }

    func index(of step: Step) -> Int { steps.firstIndex(of: step) ?? 0 }

    var kindTitle: String {
        switch option {
        case .exterior: return "Exterior redesign".localized
        case .garden: return "Garden redesign".localized
        case .floolPlan: return "Floor plan to 3D".localized
        default: return "Interior redesign".localized
        }
    }

    /// Style picked elsewhere (Assistant idea) → interior skips W3.
    func presetStyle(_ preset: Style) {
        style = preset
        if option == .interior { isStylePreset = true }
    }

    /// A/08 · I2 "Try on my room": style + palette of the idea.
    func applyInspiration(_ idea: InspirationIdea) {
        switch option {
        case .interior:
            style = idea.interiorStyle.map { .interior($0) } ?? .custom("\(idea.style) interior style")
            isStylePreset = true
        case .exterior:
            style = idea.exteriorStyle.map { .exterior($0) }
        case .garden:
            style = idea.gardenStyle.map { .garden($0) }
        default:
            break
        }
        colorOverride = idea.colorType
    }

    /// Pushes everything into the prompt manager right before generation.
    func applyToPromptManager() {
        guard let photo else { return }
        promptManager.updateOption(option)
        promptManager.updateBaseImage(photo.normalizedForGeneration())
        switch place {
        case .room(let room): promptManager.updateRoom(room)
        case .building(let building): promptManager.updateExteriorType(building)
        case nil: break
        }
        switch style {
        case .interior(let s): promptManager.updateStyle(.interior(s))
        case .exterior(let s): promptManager.updateStyle(.exterior(s))
        case .garden(let g): promptManager.updateStyle(.garden(g.name))
        case .custom(let text): promptManager.updateCustomPrompt(text)
        case nil: break
        }
        promptManager.updateColor(colorOverride ?? palette.colorType)
        promptManager.updateDesignMode(keepStructure ? .structuralPreservation : .renovationDesign)
        promptManager.updateExtraDetails(details)
    }
}
