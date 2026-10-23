import UIKit

/// Figma's 393 × 852 canvas, measured against the current window (including Duo resize).
struct OnboardingLayout {
    let scale: CGFloat

    init(size: CGSize) {
        let fitted = min(size.width / 393, size.height / 852)
        // Landscape windows (iPhone Duo unfolded) are short, not small: keep text and controls readable and let
        // the screen scroll instead of shrinking everything to the height.
        scale = size.width > size.height ? max(fitted, 0.92) : fitted
    }

    var referenceHeight: CGFloat { 852 * scale }
    func value(_ points: CGFloat) -> CGFloat { points.scaledByHeight(height: referenceHeight) }

    func inset(in width: CGFloat, base: CGFloat = 24) -> CGFloat {
        max(value(base), (width - value(393 - base * 2)) / 2)
    }

    func font(_ weight: GeologicaWeight, _ points: CGFloat) -> UIFont {
        DS.Font.geologica(weight, value(points))
    }
}

/// An invisible storyboard-authored horizontal viewport. Vertical safe areas stay on the page.
final class OnboardingViewportView: UIView {
    override func awakeFromNib() {
        super.awakeFromNib()
        insetsLayoutMarginsFromSafeArea = false
        preservesSuperviewLayoutMargins = false
        layoutMargins = .zero
    }
}

enum OnboardingPreview {
    static var enabled: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--onboarding-preview")
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        #else
        false
        #endif
    }

    static var still: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--onboarding-still") || (AppQA.enabled && AppQA.snapshot)
        #else
        false
        #endif
    }

    static var page: Int {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "--onboarding-page"), args.indices.contains(index + 1) {
            return min(3, max(0, Int(args[index + 1]) ?? 0))
        }
        #endif
        return 0
    }
}

/// Intrinsic widths intentionally distinguish completed, current and upcoming steps.
final class OnboardingStepper: UIView {
    var currentPage = 0 { didSet { setNeedsLayout() } }
    var scale: CGFloat = 1 { didSet { invalidateIntrinsicContentSize(); setNeedsLayout() } }
    @IBOutlet private var steps: [UIView]!
    @IBOutlet private var stepWidths: [NSLayoutConstraint]!
    @IBOutlet private weak var stack: UIStackView!

    override func awakeFromNib() {
        super.awakeFromNib()
        isAccessibilityElement = true
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: CGFloat(70 + currentPage * 8) * scale, height: 6 * scale)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        stack.spacing = 6 * scale
        for step in steps {
            let index = step.tag
            let width: CGFloat = index == currentPage ? 28 : (index < currentPage ? 16 : 8)
            stepWidths.first { ($0.firstItem as? UIView) === step }?.constant = width * scale
            step.backgroundColor = index <= currentPage ? UIColor.black.withAlphaComponent(currentPage == 3 ? 0.7 : 1) : UIColor(white: 0.85, alpha: 1)
            step.layer.cornerRadius = 3 * scale
        }
        accessibilityValue = "\(currentPage + 1) / 4"
    }
}

enum OnboardingGoal: String, CaseIterable {
    case interior, exterior, garden, surfaces

    var title: String { "onboarding_goal_\(rawValue)".localized }
    var subtitle: String { "onboarding_goal_\(rawValue)_detail".localized }
    var image: String {
        switch self {
        case .interior: return "clay_interior"
        case .exterior: return "clay_exterior"
        case .garden: return "clay_garden"
        case .surfaces: return "clay_paint"
        }
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: Constants.Keys.onboardingGoal)
        UserDefaults.standard.set(rawValue, forKey: HomeFocus.defaultsKey)
    }
}
