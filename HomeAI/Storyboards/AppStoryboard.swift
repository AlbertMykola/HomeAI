import UIKit

/// Loads the editable Interface Builder scenes used by the app.
enum AppStoryboard {
    static func instantiate<T: UIViewController>(_ type: T.Type, identifier sceneIdentifier: String? = nil) -> T {
        let identifier = String(describing: type)
        let name: String
        switch identifier {
        case "AssistantAttachSheetViewController", "AssistantHistoryViewController", "AssistantProjectPickerViewController", "AssistantViewController": name = "Assistant"
        case "PaintEditorViewController", "RemoveEditorViewController", "ReplaceEditorViewController": name = "Editors"
        case "GenerationViewController", "NotifySheetViewController": name = "Generation"
        case "HomeViewController": name = "Home"
        case "IdeaDetailViewController", "InspirationFeedViewController": name = "Inspiration"
        case "LaunchViewController", "OBPageViewController", "OnboardingGoalViewController", "OnboardingPageViewController": name = "Onboarding"
        case "PaywallViewController", "ProFeatureSheetViewController", "ProPaywallViewController", "WelcomeProViewController": name = "Paywall"
        case "LanguageViewController", "ProfileTabViewController": name = "Profile"
        case "ProjectDetailViewController", "ProjectsViewController": name = "Projects"
        case "ChangeStyleSheetViewController", "CompareViewController", "DislikeSheetViewController", "ResultViewController", "ShareSheetViewController": name = "Result"
        case "TabBarController": name = "Root"
        case "DSAlertViewController", "StateScreenViewController": name = "States"
        case "ExteriorToolViewController", "FloorPlanToolViewController", "FloorToolViewController", "FurnishToolViewController", "GardenToolViewController", "RearrangeToolViewController", "ReferenceToolViewController", "WallsToolViewController": name = "Tools"
        case "StylePreviewViewController", "CameraViewController", "CustomStyleSheetViewController", "OutOfCreditsSheetViewController", "PhotoTipsSheetViewController", "WizardFinalViewController", "WizardPhotoViewController", "WizardRoomViewController", "WizardStyleViewController": name = "Wizard"
        default: preconditionFailure("No storyboard scene for \(identifier)")
        }
        return UIStoryboard(name: name, bundle: .main).instantiateViewController(withIdentifier: sceneIdentifier ?? identifier) as! T
    }

    static func component<T: UIView>(_ type: T.Type) -> T {
        UIStoryboard(name: "Components", bundle: .main)
            .instantiateViewController(withIdentifier: String(describing: type)).view as! T
    }

    static func toast() -> DSToastView { component(DSToastView.self) }
}
