import UIKit

enum InteriorType: CaseIterable {
    case kitchen, bedroom, bathroom, livingroom, dinningroom, office, study, gaming, kids, attic, toilet, balcony, hallway, laundry, garage
    
    var icon: UIImage {
        switch self {
            case .kitchen: UIImage(named: "kitchen_room_icon")!
            case .bedroom: UIImage(named: "bedroom_room_icon")!
            case .bathroom: UIImage(named: "bathroom_room_icon")!
            case .livingroom: UIImage(named: "living_room_icon")!
            case .dinningroom: UIImage(named: "dinning_room_icon")!
            case .office: UIImage(named: "office_room_icon")!
            case .study: UIImage(named: "study_room_icon")!
            case .gaming: UIImage(named: "gaming_room_icon")!
            case .kids: UIImage(named: "kids_room_icon")!
            case .attic: UIImage(named: "attic_room_icon")!
            case .toilet: UIImage(named: "toilet_room_icon")!
            case .balcony: UIImage(named: "balcony _room_icon")!
            case .hallway: UIImage(named: "hallway_room_icon")!
            case .laundry: UIImage(named: "laundry_room_icon")!
            case .garage: UIImage(named: "garage_room_icon")!
        }
    }
    
    var name: String {
        switch self {
        case .kitchen: "Kitchen".localized
            case .bedroom: "Bedroom".localized
            case .bathroom: "Bathroom".localized
            case .livingroom: "Living room".localized
            case .dinningroom: "Dinning room".localized
            case .office: "Office".localized
            case .study: "Study room".localized
            case .gaming: "Gaming room".localized
            case .kids: "Kids room".localized
            case .attic: "Attic".localized
            case .toilet: "Toilet".localized
            case .balcony: "Balcony".localized
            case .hallway: "Hallway".localized
            case .laundry: "Laundry room".localized
            case .garage: "Garage".localized
        }
    }
}

enum ExteriorType: CaseIterable {
    case flat, house, cottage, mansion, townhouse, duplex, villa, cabin, farmhouse, bungalow, chalet, office
    
    var name: String {
        switch self {
            case .flat: "Flat".localized
            case .house: "House".localized
            case .cottage: "Cottage".localized
            case .mansion: "Mansion".localized
            case .townhouse: "Townhouse".localized
            case .duplex: "Duplex".localized
            case .villa: "Villa".localized
            case .cabin: "Cabin".localized
            case .farmhouse: "Farmhouse".localized
            case .bungalow: "Bungalow".localized
            case .chalet: "Chalet".localized
            case .office: "Office".localized
        }
    }
    
    var icon: String {
        switch self {
            case .flat: "flat_exterior_type_image.png"
            case .house: "house_exterior_type_image.png"
            case .cottage: "cottage_exterior_type_image.png"
            case .mansion: "mansion_exterior_type_image.png"
            case .townhouse: "townhouse_exterior_type_image.png"
            case .duplex: "duplex_exterior_type_image.png"
            case .villa: "villa_exterior_type_image.png"
            case .cabin: "cabin_exterior_type_image.png"
            case .farmhouse: "farmhouse_exterior_type_image.png"
            case .bungalow: "bungalow_exterior_type_image.png"
            case .chalet: "chalet_exterior_type_image.png"
            case .office: "office_exterior_type_image.png"
        }
    }
}

enum GardenType: CaseIterable {
    case frontGarden, cozy, minimalist, christmas, tropical, luxary, japaneese, english, mediterranean, bohemian, retro, rockery

    var name: String {
        switch self {
        case .frontGarden: "Front Garden".localized
        case .cozy: "Cozy".localized
        case .minimalist: "Minimalist".localized
        case .christmas: "Сhristmas".localized
        case .tropical: "Tropical".localized
        case .luxary: "Luxary".localized
        case .japaneese: "Japaneese".localized
        case .english: "English".localized
        case .mediterranean: "Mediterranean".localized
        case .bohemian: "Bohemian".localized
        case .retro: "Retro".localized
        case .rockery: "Rockery".localized
        }
    }
    
    var icon: String {
        switch self {
        case .frontGarden: "front_garden_garden_style_image"
        case .cozy: "cozy_garden_garden_style_image"
        case .minimalist: "minimalist_garden_style_image"
        case .christmas: "christmas_garden_style_image"
        case .tropical: "tropical_garden_style_image"
        case .luxary: "luxary_garden_style_image"
        case .japaneese: "japaneese_garden_style_image"
        case .english: "english_garden_style_image"
        case .mediterranean: "mediterranean_garden_style_image"
        case .bohemian: "bohemian_garden_style_image"
        case .retro: "retro_garden_style_image"
        case .rockery: "rockery_garden_style_image"
        }
    }
}
