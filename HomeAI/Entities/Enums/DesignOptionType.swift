import UIKit

enum DesignOption: CaseIterable {
    case interior
    case exterior
    case garden
    case reference

    struct Info {
        let title: String
        let description: String
        let image: UIImage
        let glassColor: UIColor
    }

    private var info: Info {
        switch self {
        case .interior:
            return .init(
                title: "Interior Design".localized,
                description: "Transform your space — snap a room and let AI do the rest.".localized,
                image: UIImage(named: "interior_design_icon") ?? UIImage(),
                glassColor: UIColor(red: 76/255, green: 60/255, blue: 47/255, alpha: 1)
            )
        case .exterior:
            return .init(
                title: "Exterior Design",
                description: "Upload a photo of your home, choose your style and let AI redesign your facade!".localized,
                image: UIImage(named: "exterior_desing_icon") ?? UIImage(),
                glassColor: UIColor(red: 87/255, green: 117/255, blue: 39/255, alpha: 1)
            )
        case .garden:
            return .init(
                title: "Garden Design",
                description: "Take a photo, and let AI reveal your garden's full potential.".localized,
                image: UIImage(named: "garden_design_icon") ?? UIImage(),
                glassColor: UIColor(red: 49/255, green: 49/255, blue: 37/255, alpha: 1)
            )
        case .reference:
            return .init(
                title: "Reference Style",
                description: "Bring your ideas to life — select a reference style and discover a new vibe with AI.".localized,
                image: UIImage(named: "reference_design_icon") ?? UIImage(),
                glassColor: UIColor(red: 157/255, green: 142/255, blue: 129/255, alpha: 1)
            )
        }
    }

    var title: String { info.title }
    var description: String { info.description }
    var image: UIImage { info.image }
    var glassColor: UIColor { info.glassColor }

    var model: OptionsCollectionModel {
        .init(title: title, description: description, imageName: image, glassColor: glassColor)
    }

    static var models: [OptionsCollectionModel] {
        allCases.map { $0.model }
    }
}
