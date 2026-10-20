import UIKit

/// A/04 · W1-t Photo tips (sheet). Layout: Wizard.storyboard.
final class PhotoTipsSheetViewController: UIViewController {

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var closeButton: DSPressableControl!
    @IBOutlet private var exampleLabels: [UILabel]!
    @IBOutlet private var exampleImageViews: [UIImageView]!
    @IBOutlet private var tipIconViews: [UIImageView]!
    @IBOutlet private var tipLabels: [UILabel]!
    @IBOutlet private var tipRows: [UIView]!
    @IBOutlet private weak var gotItLabel: UILabel!
    @IBOutlet private weak var gotItButton: DSPrimaryButton!

    var option: DesignOption = .interior

    static func present(from presenter: UIViewController, option: DesignOption = .interior) {
        let vc = AppStoryboard.instantiate(PhotoTipsSheetViewController.self)
        vc.option = option
        DSSheet.present(vc, from: presenter, height: 640)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "Get the best result".localized
        let content = guidance
        let examples = content.examples
        exampleLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = examples[$0].localized }
        exampleImageViews.sorted { $0.tag < $1.tag }.enumerated().forEach { index, imageView in
            imageView.image = UIImage(named: content.images[index])
            imageView.contentMode = option == .floolPlan ? .scaleAspectFit : .scaleAspectFill
            imageView.accessibilityIdentifier = "photoTips.example.\(option.rawValue).\(index)"
        }
        tipIconViews.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.image = UIImage(systemName: content.icons[$0]) }
        tipLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = content.tips[$0] }
        gotItLabel.text = "Got it".localized
        tipRows.forEach { $0.alpha = 0 }
    }

    private var guidance: (tips: [String], examples: [String], images: [String], icons: [String]) {
        let description = option == .furnish ? DesignOption.interior.tipsDescription : option.tipsDescription
        let interior = ["Turn on the lights or shoot by day", "Step back, show the whole room",
                        "Hold the phone level, at chest height", "Clutter is fine, we'll handle it"].map(\.localized)
        let restored = description.components(separatedBy: .newlines).filter { !$0.isEmpty }
        var tips = [.exterior, .garden, .floolPlan, .replace].contains(option) && restored.count == 4 ? restored : interior
        var examples = ["Wide & bright", "Too close / dark"]
        var images = ["tips_good", "tips_bad"]
        var icons = ["sun.max", "viewfinder", "hand.raised", "eye"]
        switch option {
        case .exterior:
            examples = ["View at eye level", "Too Close"]
            images = ["ob_2_before_image", "exterrior_badexample_1_image"]
            icons = ["sun.max", "car", "paintpalette", "viewfinder"]
        case .garden:
            examples = ["Clear view", "Too Messy"]
            images = ["ob_3_before_image", "garden_badexample_1_image"]
            icons = ["sun.max", "leaf", "square.grid.2x2", "viewfinder"]
        case .floolPlan:
            examples = ["Clean lines", "Blurred"]
            images = ["floorplan_demo_two", "plan_badexample_1_image"]
            icons = ["square.split.2x2", "viewfinder", "pencil.slash", "crop"]
        case .replace:
            examples = ["Correct Selection ", "Full screen painted"]
            images = ["replace_goodexample_1_image", "replace_badexample_1_image"]
            icons = ["paintbrush.pointed", "rectangle.dashed", "scribble", "viewfinder"]
        case .newFlooring:
            tips[0] = "Upload a photo to redesign your floor".localized
        case .newWalls:
            tips[0] = "Upload a photo of your current walls.".localized
        case .furnish:
            tips[0] = "Upload a photo of your empty room".localized
        case .reference:
            tips[0] = "Upload a photo of your current room.".localized
            tips[1] = "Upload a reference photo.".localized
        case .delete:
            tips[0] = "Select an object and let AI remove it instantly.".localized
        case .rearrange:
            tips[0] = "New layout with same furniture".localized
        case .interior:
            break
        }
        return (tips, examples, images, icons)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tipRows.sorted { $0.tag < $1.tag }.enumerated().forEach {
            DS.Motion.enter($1, delay: 0.1 + Double($0) * 0.06, dx: 16)
        }
    }

    @IBAction private func didTapClose(_ sender: Any) {
        dismiss(animated: true)
    }
}
