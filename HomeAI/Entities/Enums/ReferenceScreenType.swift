import Foundation

enum ReferenceScreenType {
    case currentRoom
    case reference
    
    var titleText: String {
        switch self {
        case .currentRoom: return "Upload a photo of your current room.".localized
        case .reference:   return "Upload a reference photo.".localized
        }
    }
    
    var subtitleText: String {
        "Get your dream design".localized
    }
}
