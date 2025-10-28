//
//  StyleType.swift
//  HomeAI
//
//  Created by Mykola Albert on 11.09.2025.
//

import UIKit

enum StyleInteriorType: CaseIterable {
    
    case minimalist, classic, modern, japanese, chinese, scandinavian, loft, contemporary, industrial, hottic, bohemian, wabiSabi, vintage, artDeco, rustic, farmhouse, mediterranean, tropical
    
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
        }
    }
}

enum StyleExteriorType: CaseIterable {
    
    case modern, contemporary, minimalist, hightech, scandinavian, mediterranean, italianVilla, colonial, georgian, victorian, tudor, craftsman, cottageStyle, artDeco, rustic
    
    var image: String {
        switch self {
            
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
}


