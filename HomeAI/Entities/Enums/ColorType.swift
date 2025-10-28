//
//  ColorType.swift
//  HomeAI
//
//  Created by Mykola Albert on 12.09.2025.
//

enum ColorType: CaseIterable {
    case random, lively, stormy, minimalistic, beige, pastel, floral, winterBerry, beach, ocean, calm, blush, elegant, harmony, azure, lilac, earthy, velvet, sensual, spicied, fresh
    
    var name: String {
        switch self {
            
        case .random: "Random".localized
        case .lively: "Lively".localized
        case .stormy: "Stormy".localized
        case .minimalistic: "Minimalistic".localized
        case .beige: "Beige".localized
        case .pastel: "Pastel".localized
        case .floral: "Floral".localized
        case .winterBerry: "Winter Berry".localized
        case .beach: "Beach".localized
        case .ocean: "Ocean".localized
        case .calm: "Calm".localized
        case .blush: "Blush".localized
        case .elegant: "Elegant".localized
        case .harmony: "Harmony".localized
        case .azure: "Azure".localized
        case .lilac: "Lilac".localized
        case .earthy: "Earthy".localized
        case .velvet: "Velvet".localized
        case .sensual: "Sensual".localized
        case .spicied: "Spicied".localized
        case .fresh: "Fresh".localized
        }
    }
    
    var image: String {
        switch self {
            
            case .random: "random_color_type_image.png"
            case .lively: "lively_color_type_image.png"
            case .stormy: "stormy_color_type_image.png"
            case .minimalistic: "minimalistic_color_type_image.png"
            case .beige: "beige_color_type_image.png"
            case .pastel: "pastel_color_type_image.png"
            case .floral: "floral_color_type_image.png"
            case .winterBerry: "winterBerry_color_type_image.png"
            case .beach: "beach_color_type_image.png"
            case .ocean: "ocean_color_type_image.png"
            case .calm: "calm_color_type_image.png"
            case .blush: "blush_color_type_image.png"
            case .elegant: "elegant_color_type_image.png"
            case .harmony: "harmony_color_type_image.png"
            case .azure: "azure_color_type_image.png"
            case .lilac: "lilac_color_type_image.png"
            case .earthy: "earthy_color_type_image.png"
            case .velvet: "velvet_color_type_image.png"
            case .sensual: "sensual_color_type_image.png"
            case .spicied: "spicied_color_type_image.png"
            case .fresh: "fresh_color_type_image.png"
        }
    }
    
    
    var colors: [String] {
        switch self {
            
        case .random: ["random"]
        case .lively: ["242D34", "3D5F51", "B6BF8A", "AC86DD", "DDC5DF", "F2E9E4"]
        case .stormy: ["17314A", "6A5568", "A35890", "9FABB7", "DAE1E9", "EFEFEF"]
        case .minimalistic: ["FFFFFF", "E2E0E0", "B3B3B3", "959595", "757575", "404040"]
        case .beige: ["FAD3C0", "FFF1E2", "EDD9C2", "F8D8E1", "FECCA8", "DEC3AF"]
        case .pastel: ["D3F0F4", "FEF9E5", "DBE9E0", "F0F0F0", "E5D1E8", "D5F1DF"]
        case .floral: ["A9C8DA", "6693B2", "F1E9DF", "FFBB94", "E57986", "A4607B"]
        case .winterBerry: ["3E3D65", "55545C", "8AAE90", "8E8DAC", "F2EEE3", "BE8E8A"]
        case .beach: ["385066", "607A91", "A3C5DC", "F3F1E9", "D8DBD6", "EFEFEF"]
        case .ocean: ["0C151D", "324663", "7D92AD", "B4CDEC", "FFFFFF", "F2F4F5"]
        case .calm: ["3E3D65", "55545C", "8AAE90", "8E8DAC", "F2EEE3", "BE8E8A"]
        case .blush: ["101729", "BE8E8A", "80626A", "E5C6C3", "F6E2E1", "EEE6D2"]
        case .elegant: ["000000", "222052", "B7B7B7", "D2B589", "EEE6D2", "F6E2E1"]
        case .harmony: ["5D564F", "857F75", "CDBFA6", "A58B71", "F2EEE3", "80626A"]
        case .azure: ["E5D5BC", "F9F9F5", "C5EDE9", "92D1BD", "57B3DA", "E2F8BF"]
        case .lilac: ["B9D2E2", "E3D8F2", "F2F4F5", "A7BBC7", "D3E3F0", "BD82AE"]
        case .earthy: ["EEE3D3", "6B5742", "B8A495", "C2BAA1", "9DAD84", "697C4A"]
        case .velvet: ["594049", "8D707A", "B9A1A5", "DBC9B1", "F5EEE7", "E5CBD0"]
        case .sensual: ["050505", "610D27", "AD9D8E", "CBAE8E", "D9D9D9", "854543"]
        case .spicied: ["2C1D1A", "881F1E", "C26E35", "F4B34F", "ECCDB8", "EAE3D1"]
        case .fresh: ["290907", "54483C", "73855D", "7E9FB0", "D2D4CF", "EEEAE1"]
        }
    }
}
