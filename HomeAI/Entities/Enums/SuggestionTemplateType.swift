import UIKit

enum SuggestionTemplateType: CaseIterable {
    // Interior suggestions
    case emptyRoom, kitchen, badroom, livingRoom
    
    // Exterior — приклади будинків для redesign
    case exterior1, exterior2, exterior3, exterior4
    
    // Garden suggestions (додати коли будуть доступні)
    case modernGarden, minimalistGarden, luxuryGarden, villaGarden
    
    // Reference style — приклади для кроку reference photo
    case reference1, reference2, reference3, reference4
    
    // Replace Object — приклади для заміни предметів
    case replace1, replace2, replace3, replace4

    // Furnish Room — порожні кімнати для меблювання
    case furnishEmptyLiving, furnishEmptyBedroom, furnishEmptyKitchen, furnishEmptyDining

    // Floor Plan — приклади планів для конвертації в 3D
    case floorPlan1, floorPlan2, floorPlan3, floorPlan4

    // New Flooring — приклади кімнат для зміни підлоги
    case newFloor1, newFloor2, newFloor3, newFloor4
    
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
        // Reference style
        case .reference1:
            return "badroom-reference_suggest_template"
        case .reference2:
            return "kitchen-reference_suggest_template"
        case .reference3:
            return "livroom-reference_suggest_template"
        case .reference4:
            return "reference_suggest_template"
            // Exterior
        case .exterior1:
            return "house-exterior_suggest_template-1"
        case .exterior2:
            return "house-exterior_suggest_template-2"
        case .exterior3:
            return "house-exterior_suggest_template"
        case .exterior4:
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
        case .replace1:
            return "replace_suggest_template1"
        case .replace2:
            return "replace_suggest_template2"
        case .replace3:
            return "replace_suggest_template3"
        case .replace4:
            return "replace_suggest_template4"
        // Furnish Room
        case .furnishEmptyLiving:
            return "empty-living_furnish_template"
        case .furnishEmptyBedroom:
            return "empty-bedroom_furnish_template"
        case .furnishEmptyKitchen:
            return "empty-kitchen_furnish_template"
        case .furnishEmptyDining:
            return "empty-dining_furnish_template"
        // Floor Plan
        case .floorPlan1:
            return "planRoom_suggest_template"          
        case .floorPlan2:
            return "planRoom_2_suggest_template-1"
        case .floorPlan3:
            return "planRoom_3_suggest_template"
        case .floorPlan4:
            return "planRoom_4_suggest_template"
        // New Flooring
        case .newFloor1:
            return "new_floor_suggest_template"
        case .newFloor2:
            return "new_floor_suggest_template2"
        case .newFloor3:
            return "new_floor_suggest_template3"
        case .newFloor4:
            return "new_floor_suggest_template4"
        }
    }
    
    var imagePath: String {
        let fileName = "\(imageName).webp"
        if !Self.folderPath.isEmpty {
            return "\(Self.folderPath)/\(fileName)"
        }
        return fileName
    }
    
    private static let interiorSuggestions: [SuggestionTemplateType] = [
        .emptyRoom, .kitchen, .badroom, .livingRoom
    ]

    private static let referenceStyleSuggestions: [SuggestionTemplateType] = [
        .reference1, .reference2, .reference3, .reference4
    ]
    
    private static let newFlooringSuggestions: [SuggestionTemplateType] = [
        .newFloor1, .newFloor2, .newFloor3, .newFloor4
    ]

    private static let replaceSuggestions: [SuggestionTemplateType] = [
        .replace1, .replace2, .replace3, .replace4
    ]

    private static let exteriorSuggestions: [SuggestionTemplateType] = [
        .exterior1, .exterior2, .exterior3, .exterior4
    ]
    
    // Отримати саджести для конкретної опції
    static func suggestions(for option: DesignOption, referenceScreen: ReferenceScreenType? = nil) -> [SuggestionTemplateType] {
        switch option {
        case .reference:
            return referenceStyleSuggestions
        case .interior, .newWalls:
            return interiorSuggestions
        case .newFlooring:
            return newFlooringSuggestions
        case .exterior:
            return exteriorSuggestions
        case .garden:
            return [.modernGarden, .minimalistGarden, .luxuryGarden, .villaGarden]
        case .replace, .delete:
            return replaceSuggestions
        case .furnish:
            return [.furnishEmptyLiving, .furnishEmptyBedroom, .furnishEmptyKitchen, .furnishEmptyDining]
        case .floolPlan:
            return [.floorPlan1, .floorPlan2, .floorPlan3, .floorPlan4]
        case .rearrange:
            return []
        }
    }
}
