import UIKit

enum InteriorType: CaseIterable {
    case kitchen, bedroom, bathroom, livingroom, dinningroom, office, study, gaming, kids, attic, toilet, balcony, hallway, laundry, garage
    
    var icon: UIImage {
        let name: String
        switch self {
        case .kitchen: name = "kitchen_room_icon"
        case .bedroom: name = "bedroom_room_icon"
        case .bathroom: name = "bathroom_room_icon"
        case .livingroom: name = "living_room_icon"
        case .dinningroom: name = "dinning_room_icon"
        case .office: name = "office_room_icon"
        case .study: name = "study_room_icon"
        case .gaming: name = "gaming_room_icon"
        case .kids: name = "kids_room_icon"
        case .attic: name = "attic_room_icon"
        case .toilet: name = "toilet_room_icon"
        case .balcony: name = "balcony _room_icon"
        case .hallway: name = "hallway_room_icon"
        case .laundry: name = "laundry_room_icon"
        case .garage: name = "garage_room_icon"
        }
        return UIImage(named: name) ?? UIImage()
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

    var promptDescriptor: String {
        switch self {
        case .kitchen: "kitchen"
        case .bedroom: "bedroom"
        case .bathroom: "bathroom"
        case .livingroom: "living room"
        case .dinningroom: "dining room"
        case .office: "home office"
        case .study: "study room"
        case .gaming: "gaming room"
        case .kids: "children's room"
        case .attic: "attic"
        case .toilet: "toilet room"
        case .balcony: "balcony"
        case .hallway: "hallway"
        case .laundry: "laundry room"
        case .garage: "garage"
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

    var promptDescriptor: String {
        switch self {
        case .flat: "apartment building"
        case .house: "detached house"
        case .cottage: "cottage"
        case .mansion: "mansion"
        case .townhouse: "townhouse"
        case .duplex: "duplex"
        case .villa: "villa"
        case .cabin: "cabin"
        case .farmhouse: "farmhouse"
        case .bungalow: "bungalow"
        case .chalet: "chalet"
        case .office: "office building"
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
    case noStyle, custom, frontGarden, cozy, minimalist, christmas, tropical, luxary, japaneese, english, mediterranean, bohemian, retro, rockery

    var name: String {
        switch self {
        case .noStyle: "No Style".localized
        case .custom: "Custom".localized
        case .frontGarden: "Front Garden".localized
        case .cozy: "Cozy".localized
        case .minimalist: "Minimalist".localized
        case .christmas: "Сhristmas".localized
        case .tropical: "Tropical".localized
        case .luxary: "Luxary".localized
        case .japaneese: "Japanese".localized
        case .english: "English".localized
        case .mediterranean: "Mediterranean".localized
        case .bohemian: "Bohemian".localized
        case .retro: "Retro".localized
        case .rockery: "Rockery".localized
        }
    }

    var promptDescriptor: String {
        switch self {
        case .noStyle, .custom: ""
        case .frontGarden: "welcoming front garden"
        case .cozy: "cozy garden"
        case .minimalist: "minimalist garden"
        case .christmas: "Christmas garden"
        case .tropical: "tropical garden"
        case .luxary: "luxury garden"
        case .japaneese: "Japanese garden"
        case .english: "English garden"
        case .mediterranean: "Mediterranean garden"
        case .bohemian: "bohemian garden"
        case .retro: "retro garden"
        case .rockery: "rock garden"
        }
    }
    
    var icon: String {
        switch self {
        case .noStyle: "no_style_image.png"
        case .custom: "custom_style_image.png"
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
