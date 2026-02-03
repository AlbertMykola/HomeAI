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
        switch self {
            
        case .deleteObject: UIImage(named: "delete_object_icon")!
        case .replaceObject: UIImage(named: "replace_object_icon")!
        case .newWalls:UIImage(named: "new_walls_icon")!
        case .newFloor: UIImage(named: "new_floor_icon")!
        case .newStyle: UIImage(named: "new_style_icon")!
        case .newColor: UIImage(named: "new_color_icon")!
        }
    }
}
