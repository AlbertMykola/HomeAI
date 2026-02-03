import UIKit

enum DesignOption: String, CaseIterable {
    case interior
    case exterior
    case garden
    case reference
    case replace
    case delete
    case newFlooring
    case newWalls

    struct Info {
        let title: String
        let description: String
        let image: UIImage
        let glassColor: UIColor
        let startColor: UIColor
        let endLocationPercent: CGFloat
        let tipsDescription: String
        let badExample: [PhotoTipsModel]
        let goodExample: [PhotoTipsModel]
    }

    private var info: Info {
        switch self {
        case .interior:
            return .init(
                title: "Interior Design".localized,
                description: "Transform your space — snap a room and let AI do the rest.".localized,
                image: UIImage(named: "interior_design_icon") ?? UIImage(),
                glassColor: UIColor(red: 163/255, green: 162/255, blue: 159/255, alpha: 1),
                startColor: .black.withAlphaComponent(0),
                endLocationPercent: 51,
                tipsDescription: "Use natural light whenever possible, or switch on all lights in the room.\nShoot at eye level to keep the perspective natural and realistic.\nPTake photos from a corner or doorway to capture more of the space.\nClear away clutter and tidy up to achieve a clean, polished look.".localized,
                badExample: [
                    PhotoTipsModel(image: "interrior_badexample_1_image", state: "Too Close".localized),
                    PhotoTipsModel(image: "interrior_badexample_2_image", state: "Too Dark".localized),
                    PhotoTipsModel(image: "interrior_badexample_3_image", state: "Too Mess".localized)],
                goodExample: [
                    PhotoTipsModel(image: "interrior_goodexample_1_image", state: "View at eye level".localized),
                    PhotoTipsModel(image: "interrior_goodexample_2_image", state: "Good light".localized),
                    PhotoTipsModel(image: "interrior_goodexample_3_image", state: "Clean Room".localized)])
        case .exterior:
            return .init(
                title: "Exterior Design".localized,
                description: "Upload a photo of your home, choose your style and let AI redesign your facade!".localized,
                image: UIImage(named: "exterior_desing_icon") ?? UIImage(),
                glassColor: UIColor(red: 136/255, green: 151/255, blue: 173/255, alpha: 1),
                startColor: UIColor(red: 128/255, green: 141/255, blue: 161/255, alpha: 0),
                endLocationPercent: 30,
                tipsDescription: "Photograph the building in daylight.\nRemove cars, people, trash bins, and other distractions from the scene.\nPreserve natural and realistic colors.\nUpload images in high resolution and sharp focus.".localized,
                badExample: [
                    PhotoTipsModel(image: "exterrior_badexample_1_image", state: "Too Close".localized),
                    PhotoTipsModel(image: "exterrior_badexample_2_image", state: "Too Dark".localized),
                    PhotoTipsModel(image: "exterrior_badexample_3_image", state: "Too Far".localized)
                ],
                goodExample: [
                    PhotoTipsModel(image: "exterrior_goodexample_1_image", state: "View at eye level".localized),
                    PhotoTipsModel(image: "exterrior_goodexample_2_image", state: "Good light".localized),
                    PhotoTipsModel(image: "exterrior_goodexample_3_image", state: "High resolution".localized)])
        case .garden:
            return .init(
                title: "Garden Design".localized,
                description: "Take a photo, and let AI reveal your garden's full potential.".localized,
                image: UIImage(named: "garden_design_icon") ?? UIImage(),
                glassColor: UIColor(red: 124/255, green: 122/255, blue: 130/255, alpha: 1),
                startColor: .black.withAlphaComponent(0),
                endLocationPercent: 27,
                tipsDescription: "Use natural daylight and avoid harsh sunlight or deep shadows.\nKeep the garden clean and well-maintained, without tools or temporary objects.\nShow the overall layout clearly, including paths, plants, and open areas.\nEnsure sharp focus, accurate colors, and a straight horizon.".localized,
                badExample: [
                    PhotoTipsModel(image: "garden_badexample_1_image", state: "Too Messy".localized),
                    PhotoTipsModel(image: "garden_badexample_2_image", state: "Too Close".localized),
                    PhotoTipsModel(image: "garden_badexample_3_image", state: "Too Dark".localized)],
                goodExample: [
                    PhotoTipsModel(image: "garden_goodexample_1_image", state: "Clear view".localized),
                    PhotoTipsModel(image: "garden_goodexample_2_image", state: "Good focus".localized),
                    PhotoTipsModel(image: "garden_goodexample_3_image", state: "Good light".localized)])
        case .reference:
            return .init(
                title: "Reference Style".localized,
                description: "Bring your ideas to life — select a reference style and discover a new vibe with AI.".localized,
                image: UIImage(named: "reference_design_icon") ?? UIImage(),
                glassColor: UIColor(red: 90/255, green: 77/255, blue: 65/255, alpha: 1),
                startColor: .black.withAlphaComponent(0),
                endLocationPercent: 32,
                tipsDescription: "Use natural light whenever possible, or switch on all lights in the room.\nShoot at eye level to keep the perspective natural and realistic.\nPTake photos from a corner or doorway to capture more of the space.\nClear away clutter and tidy up to achieve a clean, polished look.".localized,
                badExample: [
                    PhotoTipsModel(image: "interrior_badexample_1_image", state: "Too Close".localized),
                    PhotoTipsModel(image: "interrior_badexample_2_image", state: "Too Dark".localized),
                    PhotoTipsModel(image: "interrior_badexample_3_image", state: "Too Mess".localized)],
                goodExample: [
                    PhotoTipsModel(image: "interrior_goodexample_1_image", state: "View at eye level".localized),
                    PhotoTipsModel(image: "interrior_goodexample_2_image", state: "Good light".localized),
                    PhotoTipsModel(image: "interrior_goodexample_3_image", state: "Clean Room".localized)])
        case .replace:
            return .init(
                title: "Replace Object".localized,
                description: "Replace objects in your photo with AI-powered precision.".localized,
                image: UIImage(named: "replace_desing_icon") ?? UIImage(),
                glassColor: UIColor(red: 66/255, green: 55/255, blue: 44/255, alpha: 1),
                startColor: .black.withAlphaComponent(0),
                endLocationPercent: 38,
                tipsDescription: "Clearly highlight only the object you want to replace.\nDo not cover or mark the entire image area.\nAvoid outlining or drawing around the selected object.\nMake sure the selected object is fully visible and not cropped.".localized,
                badExample: [
                    PhotoTipsModel(image: "replace_badexample_1_image", state: "Full screen painted".localized),
                    PhotoTipsModel(image: "replace_badexample_2_image", state: "Outlined object".localized)],
                goodExample: [
                    PhotoTipsModel(image: "replace_goodexample_1_image", state: "Correct Selection ".localized),
                    PhotoTipsModel(image: "replace_goodexample_2_image", state: "Clear highlight".localized)])
        case .newFlooring:
            return .init(
                title: "New Flooring".localized,
                description: "Try new flooring in seconds. AI instantly detects and replaces your floor.".localized,
                image: UIImage(named: "florring_design_icon") ?? UIImage(),
                glassColor: UIColor(red: 158/255, green: 157/255, blue: 125/255, alpha: 1),
                startColor: UIColor(red: 138/255, green: 138/255, blue: 116/255, alpha: 0),
                endLocationPercent: 36,
                tipsDescription: "Use natural light whenever possible, or switch on all lights in the room.\nShoot at eye level to keep the perspective natural and realistic.\nPTake photos from a corner or doorway to capture more of the space.\nClear away clutter and tidy up to achieve a clean, polished look.".localized,
                badExample: [
                    PhotoTipsModel(image: "replace_badexample_1_image", state: "Full screen painted".localized),
                    PhotoTipsModel(image: "replace_badexample_2_image", state: "Outlined object".localized)],
                goodExample: [
                    PhotoTipsModel(image: "replace_goodexample_1_image", state: "Correct Selection ".localized),
                    PhotoTipsModel(image: "replace_goodexample_2_image", state: "Clear highlight".localized)])
        case .newWalls:
            return .init(
                title: "New Walls".localized,
                description: "Reimagine your walls with AI. Instantly preview colors, textures, and finishes in your space.".localized,
                image: UIImage(named: "walls_design_icon") ?? UIImage(),
                glassColor: UIColor(red: 150/255, green: 131/255, blue: 107/255, alpha: 1),
                startColor: UIColor(red: 138/255, green: 138/255, blue: 116/255, alpha: 0),
                endLocationPercent: 32,
                tipsDescription: "Use natural light whenever possible, or switch on all lights in the room.\nShoot at eye level to keep the perspective natural and realistic.\nPTake photos from a corner or doorway to capture more of the space.\nClear away clutter and tidy up to achieve a clean, polished look.".localized,
                badExample: [
                    PhotoTipsModel(image: "replace_badexample_1_image", state: "Full screen painted".localized),
                    PhotoTipsModel(image: "replace_badexample_2_image", state: "Outlined object".localized)],
                goodExample: [
                    PhotoTipsModel(image: "replace_goodexample_1_image", state: "Correct Selection ".localized),
                    PhotoTipsModel(image: "replace_goodexample_2_image", state: "Clear highlight".localized)])
        case .delete:
            return .init(
                title: "Delete Objects".localized,
                description: "Select an object and let AI remove it instantly.".localized,
                image: UIImage(named: "delete_object_design_image") ?? UIImage(),
                glassColor: UIColor(red: 134/255, green: 126/255, blue: 121/255, alpha: 1),
                startColor: .black.withAlphaComponent(0),
                endLocationPercent: 32,
                tipsDescription: "Use natural light whenever possible, or switch on all lights in the room.\nShoot at eye level to keep the perspective natural and realistic.\nPTake photos from a corner or doorway to capture more of the space.\nClear away clutter and tidy up to achieve a clean, polished look.".localized,
                badExample: [
                    PhotoTipsModel(image: "replace_badexample_1_image", state: "Full screen painted".localized),
                    PhotoTipsModel(image: "replace_badexample_2_image", state: "Outlined object".localized)],
                goodExample: [
                    PhotoTipsModel(image: "replace_goodexample_1_image", state: "Correct Selection ".localized),
                    PhotoTipsModel(image: "replace_goodexample_2_image", state: "Clear highlight".localized)])
        }
    }

    var title: String { info.title }
    var description: String { info.description }
    var image: UIImage { info.image }
    var glassColor: UIColor { info.glassColor }
    var startColor: UIColor { info.startColor }
    var endLocationPercent: CGFloat { info.endLocationPercent }
    var tipsDescription: String { info.tipsDescription }
    var badExample: [PhotoTipsModel] { info.badExample }
    var goodExample: [PhotoTipsModel] { info.goodExample }

    var model: OptionsCollectionModel {
        .init(title: title, description: description, imageName: image, glassColor: glassColor, startColor: startColor, endLocationPercent: endLocationPercent)
    }

    static var models: [OptionsCollectionModel] {
        allCases.map { $0.model }
    }
}
