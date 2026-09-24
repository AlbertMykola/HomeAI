import UIKit

enum DesignOption: String, CaseIterable {
    case interior
    case exterior
    case garden
    case reference
    case floolPlan
    case replace
    case delete
    case newFlooring
    case newWalls
    case rearrange
    case furnish


    struct Info {
        let title: String
        let description: String
        let icon: UIImage
        let heroImage: UIImage
        let beforeAfter: UIImage
        let tipsDescription: String
        let badExample: [PhotoTipsModel]
        let goodExample: [PhotoTipsModel]
    }

    private var info: Info {
        switch self {
        case .interior:
            return .init(
                title: "Interior Design".localized,
                description: "Change your indoor space".localized,
                icon: UIImage(named: "interior_redesign_icon") ?? UIImage(),
                heroImage: UIImage(named: "options_interior_design_image") ?? UIImage(),
                beforeAfter: UIImage(named: "interior_before_after_image") ?? UIImage(),
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
                description: "Transform the look of your home".localized,
                icon: UIImage(named: "exterior_redesign_icon") ?? UIImage(),
                heroImage: UIImage(named: "options_exterior_design_image") ?? UIImage(),
                beforeAfter: UIImage(named: "exterior_before_after_image") ?? UIImage(),
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
                description: "Restyle your outdoor space".localized,
                icon: UIImage(named: "garden_redesign_icon") ?? UIImage(),
                heroImage: UIImage(named: "options_garden_design_image")
                    ?? UIImage(named: "minimalist_garden_style_image")
                    ?? UIImage(),
                beforeAfter: UIImage(named: "garden_before_after_image") ?? UIImage(),

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
                description: "Match any styles".localized,
                icon: UIImage(named: "options_reference_style_icon") ?? UIImage(),
                heroImage: UIImage(named: "ob_design_newstyle_image")
                    ?? UIImage(named: "options_interior_design_image")
                    ?? UIImage(),
                beforeAfter: UIImage(named: "reference_before_after_image") ?? UIImage(),

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
                description: "Swap furniture instantly".localized,
                icon: UIImage(named: "options_replace_object_icon") ?? UIImage(),
                heroImage: UIImage(named: "ob_design_replace_image") ?? UIImage(),
                beforeAfter: UIImage(named: "replace_before_after_image") ?? UIImage(),
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
                description: "Try new floor styles".localized,
                icon: UIImage(named: "options_new_flooring_icon") ?? UIImage(),
                heroImage: UIImage(named: "ob_design_newFloor_image") ?? UIImage(),
                beforeAfter: UIImage(named: "newflooring_before_after_image") ?? UIImage(),

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
                description: "Repaint your walls".localized,
                icon: UIImage(named: "new_walls_icon") ?? UIImage(),
                heroImage: UIImage(named: "ob_design_newwalls_image") ?? UIImage(), beforeAfter: UIImage(named: "newwalls_before_after_image") ?? UIImage(),
                tipsDescription: "Use natural light whenever possible, or switch on all lights in the room.\nShoot at eye level to keep the perspective natural and realistic.\nPTake photos from a corner or doorway to capture more of the space.\nClear away clutter and tidy up to achieve a clean, polished look.".localized,
                badExample: [
                    PhotoTipsModel(image: "replace_badexample_1_image", state: "Full screen painted".localized),
                    PhotoTipsModel(image: "replace_badexample_2_image", state: "Outlined object".localized)],
                goodExample: [
                    PhotoTipsModel(image: "replace_goodexample_1_image", state: "Correct Selection ".localized),
                    PhotoTipsModel(image: "replace_goodexample_2_image", state: "Clear highlight".localized)])
        case .delete:
            return .init(
                title: "Remove Objects".localized,
                description: "Remove unwanted items".localized,
                icon: UIImage(named: "options_remove_object_icon") ?? UIImage(),
                heroImage: UIImage(named: "ob_design_delete_image") ?? UIImage(),
                beforeAfter: UIImage(named: "delete_object_before_after_image") ?? UIImage(),
                tipsDescription: "Use natural light whenever possible, or switch on all lights in the room.\nShoot at eye level to keep the perspective natural and realistic.\nPTake photos from a corner or doorway to capture more of the space.\nClear away clutter and tidy up to achieve a clean, polished look.".localized,
                badExample: [
                    PhotoTipsModel(image: "replace_badexample_1_image", state: "Full screen painted".localized),
                    PhotoTipsModel(image: "replace_badexample_2_image", state: "Outlined object".localized)],
                goodExample: [
                    PhotoTipsModel(image: "replace_goodexample_1_image", state: "Correct Selection ".localized),
                    PhotoTipsModel(image: "replace_goodexample_2_image", state: "Clear highlight".localized)])
        case .rearrange:
            return .init(
                title: "Rearrange Furniture".localized,
                description: "Optimize your layout".localized,
                icon: UIImage(named: "") ?? UIImage(),
                heroImage: UIImage(named: "") ?? UIImage(),
                beforeAfter: UIImage(named: "rearrange_before_after_image") ?? UIImage(),
                tipsDescription: "Use natural light whenever possible, or switch on all lights in the room.\nShoot at eye level to keep the perspective natural and realistic.\nPTake photos from a corner or doorway to capture more of the space.\nClear away clutter and tidy up to achieve a clean, polished look.".localized,
                badExample: [
                    PhotoTipsModel(image: "interrior_badexample_1_image", state: "Too Close".localized),
                    PhotoTipsModel(image: "interrior_badexample_2_image", state: "Too Dark".localized),
                    PhotoTipsModel(image: "interrior_badexample_3_image", state: "Too Mess".localized)],
                goodExample: [
                    PhotoTipsModel(image: "interrior_goodexample_1_image", state: "View at eye level".localized),
                    PhotoTipsModel(image: "interrior_goodexample_2_image", state: "Good light".localized),
                    PhotoTipsModel(image: "interrior_goodexample_3_image", state: "Clean Room".localized)])
        case .furnish:
            return .init(
            title: "Furnish Room".localized,
            description: "Fill empty spaces".localized,
            icon: UIImage(named: "") ?? UIImage(),
            heroImage: UIImage(named: "") ?? UIImage(),
            beforeAfter: UIImage(named: "furnish_before_after_image") ?? UIImage(),
            tipsDescription: "".localized,
            badExample: [
                PhotoTipsModel(image: "", state: "".localized),
                PhotoTipsModel(image: "", state: "".localized)],
            goodExample: [
                PhotoTipsModel(image: "", state: " ".localized),
                PhotoTipsModel(image: "", state: "".localized)])
        case .floolPlan:
            return .init(
            title: "Floor Plan".localized,
            description: "Turn plans into 3D".localized,
            icon: UIImage(named: "") ?? UIImage(),
            heroImage: UIImage(named: "") ?? UIImage(),
            beforeAfter: UIImage(named: "floor_before_after_image") ?? UIImage(),
            tipsDescription: "Full 2D floor plan with every room clearly visible.\nSharp, high-quality image with clean lines.\nSimple layout without extra notes or markings.\nAvoid blurry, cropped, or low-resolution plans.".localized,
            badExample: [
                PhotoTipsModel(image: "plan_badexample_1_image", state: "Blurred".localized),
                PhotoTipsModel(image: "plan_badexample_2_image", state: "Cropped".localized)],
            goodExample: [
                PhotoTipsModel(image: "plan_goodexample_1_image", state: "Clean lines".localized),
                PhotoTipsModel(image: "plan_goodexample_2_image", state: "Full plan".localized)])
        }
    }

    var title: String { info.title }
    var description: String { info.description }
    /// Сумісність: раніше один UIImage на опцію; тепер це та сама **іконка**, що й `icon`.
    var image: UIImage { info.icon }
    var icon: UIImage { info.icon }
    var heroImage: UIImage { info.heroImage }
    var tipsDescription: String { info.tipsDescription }
    var badExample: [PhotoTipsModel] { info.badExample }
    var beforeAfter: UIImage { info.beforeAfter }
    var goodExample: [PhotoTipsModel] { info.goodExample }

    var model: OptionsCollectionModel {
        .init(title: title, description: description, icon: icon, heroImage: heroImage)
    }

    static var models: [OptionsCollectionModel] {
        allCases.map { $0.model }
    }
}
