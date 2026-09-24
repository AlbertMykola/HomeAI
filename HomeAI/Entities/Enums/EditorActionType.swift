//
//  EditorActionType.swift
//  HomeAI
//
//  Created by Mykola Albert on 28.01.2026.
//

import UIKit

enum EditorActionType: CaseIterable {
    case deleteObject, replaceObject, newWalls, newFloor, newStyle, newColor
    
    var title: String {
        
        switch self {
        case .deleteObject: "Delete Object".localized
        case .replaceObject: "Replace Object".localized
        case .newWalls: "New Walls".localized
        case .newFloor: "New Floor".localized
        case .newStyle: "New Style".localized
        case .newColor: "New Color".localized
        }
    }
    
    var icon: UIImage {
        let name: String
        switch self {
        case .deleteObject: name = "delete_object_icon"
        case .replaceObject: name = "replace_object_icon"
        case .newWalls: name = "new_walls_icon"
        case .newFloor: name = "new_floor_icon"
        case .newStyle: name = "new_style_icon"
        case .newColor: name = "new_color_icon"
        }
        return UIImage(named: name) ?? UIImage()
    }
}
