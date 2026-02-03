import UIKit

enum SuggestionTemplateType: CaseIterable {
    // Interior suggestions
    case emptyRoom, kitchen, badroom, livingRoom
    
    // Exterior suggestions (додати коли будуть доступні)
    case houseExterior, house2Exterior, flatExterior, villaExterior
    
    // Garden suggestions (додати коли будуть доступні)
    case modernGarden, minimalistGarden, luxuryGarden, villaGarden
    
    // Replace
    case replaceModernKitchen, replaceMinimalistLivingRoom, replaceLuxuryGameRoome, replaceMinimalistBadroom
    
    // Папка в Supabase Storage (Images/template_suggestions/)
    private static let folderPath = "template_suggestions"
    
    var imageName: String {
        switch self {
        // Interior
        case .emptyRoom:
            return "emptyRoom_suggest_template"
        case .kitchen:
            return "kitchen_suggest_template"
        case .badroom:
            return "badroom_suggest_template"
        case .livingRoom:
            return "livingRoom_suggest_template"
        // Exterior
        case .houseExterior:
            return "house-exterior_suggest_template"
        case .house2Exterior:
            return "house-3-exterior_suggest_template"
        case .flatExterior:
            return "house-2-exterior_suggest_template"
        case .villaExterior:
            return "villa-exterior_suggest_template"
        // Garden
        case .modernGarden:
            return "modern-garden_suggest_template-elementor-io-optimized"
        case .minimalistGarden:
            return "minimalist-garden_suggest_template-elementor-io-optimized"
        case .luxuryGarden:
            return "luxury-garden_suggest_template-elementor-io-optimized"
        case .villaGarden:
            return "villa-garden_suggest_template-elementor-io-optimized"
        case .replaceModernKitchen:
            return "kitchen-replace_suggest_template"
        case .replaceMinimalistLivingRoom:
            return "livingRoom-replace_suggest_template"
        case .replaceLuxuryGameRoome:
            return "gameroom-replace_suggest_template"
        case .replaceMinimalistBadroom:
            return "badroom-replace_suggest_template"
        }
    }
    
    var imagePath: String {
        let fileName = "\(imageName).webp"
        if !Self.folderPath.isEmpty {
            return "\(Self.folderPath)/\(fileName)"
        }
        return fileName
    }
    
    // Отримати саджести для конкретної опції
    static func suggestions(for option: DesignOption) -> [SuggestionTemplateType] {
        switch option {
        case .interior, .reference, .newWalls, .newFlooring:
            return [.emptyRoom, .kitchen, .badroom, .livingRoom]
        case .exterior:
            return [.houseExterior, .flatExterior, .villaExterior, .house2Exterior]
        case .garden:
            return [.modernGarden, .minimalistGarden, .luxuryGarden, .villaGarden]
        case .replace, .delete:
            return [.replaceModernKitchen, .replaceMinimalistBadroom, .replaceLuxuryGameRoome, .replaceMinimalistLivingRoom]
        }
    }
}
