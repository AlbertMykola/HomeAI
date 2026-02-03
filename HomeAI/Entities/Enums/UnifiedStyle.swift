//
//  UnifiedStyle.swift
//  HomeAI
//
//  Created by Mykola Albert on 28.11.2025.
//

import Foundation

enum UnifiedStyle {
    case interior(StyleInteriorType)
    case exterior(StyleExteriorType)
    case garden(String)
    case reference(String)

    var name: String {
        switch self {
        case .interior(let s): return s.name
        case .exterior(let s): return s.name
        case .garden(let n): return n
        case .reference(let n): return n
        }
    }

    var defaultLighting: String? {
        switch self {
        case .interior(let s): return s.defaultLighting
        case .exterior: return "daylight"
        case .garden: return "bright daylight"
        case .reference: return nil
        }
    }
}
