//
//  StyleType.swift
//  HomeAI
//
//  Created by Mykola Albert on 11.09.2025.
//

import UIKit

enum StyleInteriorType: CaseIterable {
    
    case noStyle,custom, minimalist, classic, modern, glam, marble, japanese, chinese, scandinavian, loft, contemporary, industrial, hottic, bohemian, wabiSabi, vintage, pink, halloween, cartoon, medieval, artDeco, rustic, baroque, cyberpunk, rainbow, wood, farmhouse, creepy, chocolate, mediterranean, tropical
    
    var image: String {
        switch self {
            
        case .minimalist: "minimalist_interior_style_image.png"
        case .classic: "classic_interior_style_image.png"
        case .modern: "modern_interior_style_image.png"
        case .japanese: "japanese_interior_style_image.png"
        case .chinese: "chinese_interior_style_image.png"
        case .scandinavian: "scandinavian_interior_style_image.png"
        case .loft: "loft_interior_style_image.png"
        case .contemporary: "contemporary_interior_style_image.png"
        case .industrial: "industrial_interior_style_image.png"
        case .hottic: "hottic_interior_style_image.png"
        case .bohemian: "bohemian_interior_style_image.png"
        case .wabiSabi: "wabi-sabi_interior_style_image.png"
        case .vintage: "vintage_interior_style_image.png"
        case .artDeco: "art_deco_interior_style_image.png"
        case .rustic: "rustic_interior_style_image.png"
        case .farmhouse: "farmhouse_interior_style_image.png"
        case .mediterranean: "mediterranean_interior_style_image.png"
        case .tropical: "tropical_interior_style_image.png"
        case .noStyle: "no_style_image.png"
        case .custom: "custom_style_image.png"
        case .glam: "glam_interior_style_image.png"
        case .marble: "marble_interior_style_image.png"
        case .pink: "pink_interior_style_image.png"
        case .halloween: "halloween_interior_style_image.png"
        case .cartoon: "cartoon_interior_style_image.png"
        case .medieval: "medieval_interior_style_image.png"
        case .baroque: "baroque_interior_style_image.png"
        case .cyberpunk: "cyberpunk_interior_style_image.png"
        case .rainbow: "rainbow_interior_style_image.png"
        case .wood: "wood_interior_style_image.png"
        case .creepy: "creepy_interior_style_image.png"
        case .chocolate: "chocolate_interior_style_image.png"
        }
    }
    
    var name: String {
        switch self {
            
        case .minimalist: "Minimalist".localized
        case .classic: "Classic".localized
        case .modern: "Modern".localized
        case .japanese: "Japanese".localized
        case .chinese: "Chinese".localized
        case .scandinavian: "Scandinavian".localized
        case .loft: "Loft".localized
        case .contemporary: "Contemporary".localized
        case .industrial: "Industrial".localized
        case .hottic: "Hottic".localized
        case .bohemian: "Bohemian".localized
        case .wabiSabi: "Wabi-sabi".localized
        case .vintage: "Vintage".localized
        case .artDeco: "Art Deco".localized
        case .rustic: "Rustic".localized
        case .farmhouse: "Farmhouse".localized
        case .mediterranean: "Mediterranean".localized
        case .tropical: "Tropical".localized
        case .noStyle: "No Style".localized
        case .custom: "Custom".localized
        case .glam: "Glam".localized
        case .marble: "Marble".localized
        case .pink: "Pink".localized
        case .halloween: "Halloween".localized
        case .cartoon: "Cartoon".localized
        case .medieval: "Medieval".localized
        case .baroque: "Baroque".localized
        case .cyberpunk: "Cyberpunk".localized
        case .rainbow: "Rainbow".localized
        case .wood: "Wood".localized
        case .creepy: "Creepy".localized
        case .chocolate: "Chocolate".localized
        }
    }
    
    var defaultLighting: String {
        switch self {
        case .scandinavian, .minimalist, .modern, .contemporary: return "daylight"
        case .classic, .artDeco: return "golden hour"
        case .industrial, .loft: return "moody"
        case .japanese, .wabiSabi: return "soft daylight"
        case .rustic, .farmhouse, .mediterranean: return "golden hour"
        case .vintage, .bohemian: return "evening warm"
        case .tropical: return "bright daylight"
        case .chinese: return "daylight"
        case .hottic: return "golden hour"
        case .noStyle: return "daylight"
        case .custom: return "daylight"
        case .glam: return "evening warm"
        case .marble: return "daylight"
        case .pink: return "soft daylight"
        case .halloween: return "moody"
        case .cartoon: return "bright daylight"
        case .medieval: return "golden hour"
        case .baroque: return "golden hour"
        case .cyberpunk: return "neon night"
        case .rainbow: return "bright daylight"
        case .wood: return "warm daylight"
        case .creepy: return "moody"
        case .chocolate: return "golden hour"
        }
    }
    
    var isNew: Bool {
        switch self {
        case .glam, .halloween, .marble, .medieval, .pink, .cartoon, .baroque, .chocolate, .creepy, .cyberpunk, .rainbow, .wood: true
        default: false
        }
    }
}

enum StyleExteriorType: CaseIterable {
    
    case noStyle, custom, modern, contemporary, minimalist, hightech, scandinavian, mediterranean, italianVilla, colonial, georgian, victorian, tudor, craftsman, cottageStyle, artDeco, rustic
    
    var image: String {
        switch self {
        case .noStyle: "no_style_image.png"
        case .custom: "custom_style_image.png"
        case .modern: "modern_exterior_style_image.png"
        case .contemporary: "contemporary_exterior_style_image.png"
        case .minimalist: "minimalist_exterior_style_image.png"
        case .hightech: "high_tech_exterior_style_image.png"
        case .scandinavian: "scandinavian_exterior_style_image.png"
        case .mediterranean: "mediterranean_exterior_style_image.png"
        case .italianVilla: "italian_villa_exterior_style_image.png"
        case .colonial: "colonial_exterior_style_image.png"
        case .georgian: "georgian_exterior_style_image.png"
        case .victorian: "victorian_exterior_style_image.png"
        case .tudor: "tudor_exterior_style_image.png"
        case .craftsman: "craftsman_exterior_style_image.png"
        case .cottageStyle: "cottage_style_exterior_style_image.png"
        case .artDeco: "art_deco_exterior_style_image.png"
        case .rustic: "rustic_exterior_style_image.png"
        }
    }
    
    var name: String {
        switch self {
        case .noStyle: "No Style".localized
        case .custom: "Custom".localized
        case .modern: "Modern".localized
        case .contemporary: "Contemporary".localized
        case .minimalist: "Minimalist".localized
        case .hightech: "High-tech".localized
        case .scandinavian: "Scandinavian".localized
        case .mediterranean: "Mediterranean".localized
        case .italianVilla: "Italian Villa".localized
        case .colonial: "Colonial".localized
        case .georgian: "Georgian".localized
        case .victorian: "Victorian".localized
        case .tudor: "Tudor".localized
        case .craftsman: "Craftsman".localized
        case .cottageStyle: "Cottage style".localized
        case .artDeco: "Art Deco".localized
        case .rustic: "Rustic".localized
        }
    }
    
    var defaultLighting: String {
        switch self {
        case .noStyle: return "daylight"
        case .custom: return "daylight"
        case .modern, .minimalist, .hightech, .scandinavian: return "daylight"
        case .contemporary: return "soft daylight"
        case .mediterranean, .italianVilla, .colonial, .georgian, .victorian, .tudor, .cottageStyle: return "golden hour"
        case .craftsman, .rustic: return "evening warm"
        case .artDeco: return "moody"
        }
    }
}


