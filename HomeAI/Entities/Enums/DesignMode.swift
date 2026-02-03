import UIKit

enum DesignMode: String, CaseIterable, Codable {
    
    case structuralPreservation
    case renovationDesign
    
    var title: String {
        switch self {
        case .structuralPreservation: return "Keep Layout".localized
        case .renovationDesign: return "Change Layout".localized
        }
    }
    
    var subtitle: String {
        switch self {
        case .structuralPreservation:
            return "Follow the current room".localized
        case .renovationDesign:
            return "Redesign without restrictions".localized
        }
    }
    
    var gradient: [UIColor] {
        switch self {
            
        case .structuralPreservation:
            [UIColor(red: 255/255, green: 198/255, blue: 58/255, alpha: 1), UIColor(red: 245/255, green: 175/255, blue: 1/255, alpha: 1)]
        case .renovationDesign:
            [UIColor(red: 101/255, green: 250/255, blue: 30/255, alpha: 1), UIColor(red: 75/255, green: 182/255, blue: 24/255, alpha: 1)]
        }
    }
}

