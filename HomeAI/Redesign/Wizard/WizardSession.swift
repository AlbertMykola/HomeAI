import UIKit

/// State shared by the A/04 wizard steps (W1 photo → W2 room → W3 style → W4 final touches).
final class WizardSession {

    enum Step: Int { case photo, room, style, final }

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
    var place: Place?
    var style: Style?
    var palette: Palette = .auto
    var keepStructure = true
    var details: String = ""

    init(option: DesignOption) {
        self.option = option
        promptManager.updateOption(option)
    }

    /// Garden has no W2 (room/building) step.
    var steps: [Step] {
        option == .garden ? [.photo, .style, .final] : [.photo, .room, .style, .final]
    }

    func index(of step: Step) -> Int { steps.firstIndex(of: step) ?? 0 }

    var kindTitle: String {
        switch option {
        case .exterior: return "Exterior redesign".localized
        case .garden: return "Garden redesign".localized
        default: return "Interior redesign".localized
        }
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
        promptManager.updateColor(palette.colorType)
        promptManager.updateDesignMode(keepStructure ? .structuralPreservation : .renovationDesign)
        promptManager.updateExtraDetails(details)
    }
}
