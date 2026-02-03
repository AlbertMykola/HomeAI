//
//  InspirationType.swift
//  HomeAI
//
//  Created by Mykola Albert on 09.09.2025.
//

import Foundation

enum InspirationType: String, CaseIterable {
    
    case all = "ALL"
    case kitchen = "Kitchen"
    case bedroom = "Bedroom"
    case study = "Study"
    
    var images: [String] {
        switch self {
        case .all:
                ["inspiration_bathroom_image.png", "inspiration_kitchen_image.png", "inspiration_bedroom_image.png", "inspiration_study_image.png", "inspiration_study_1_image.png", "inspiration_kitchen_1_image.png", "inspiration_study_2_image.png", "inspiration_study_3_image.png", "inspiration_study_4_image.png", "inspiration_bedroom_1_image.png"]
            case .kitchen: ["inspiration_kitchen_image.png", "inspiration_kitchen_1_image.png"]
            case .bedroom: ["inspiration_bedroom_image.png"]
            case .study: ["inspiration_study_image.png", "inspiration_study_1_image.png", "inspiration_study_2_image.png", "inspiration_study_3_image.png", "inspiration_study_4_image.png"]
        }
    }
}
