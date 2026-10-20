import UIKit

/// NavBar of the wizard: glass back (←), stepper, glass close (✕). Layout: Wizard.storyboard.
/// Taps go up the responder chain as `didTapWizardBack:` / `didTapWizardClose:`.
final class WizardNavBar: DSComponentView {

    @IBOutlet private(set) weak var backButton: DSPressableControl!
    @IBOutlet private(set) weak var closeButton: DSPressableControl!
    @IBOutlet private weak var stepperStack: UIStackView!
    @IBOutlet private var stepViews: [UIView]!

    private var sortedSteps: [UIView] { stepViews.sorted { $0.tag < $1.tag } }
    private var displayedStep = 0
    private var visibleSteps = 4

    override func layoutSubviews() {
        updateWidths()
        super.layoutSubviews()
    }

    private func updateWidths() {
        let metrics = OnboardingLayout(size: dsAdaptiveReferenceSize)
        for (i, view) in sortedSteps.enumerated() where i < visibleSteps {
            let points: CGFloat = i < displayedStep ? 16 : (i == displayedStep ? 28 : 8)
            if let constraint = view.constraints.first(where: { $0.firstAttribute == .width }) {
                let width = metrics.value(points)
                if abs(constraint.constant - width) > 0.01 { constraint.constant = width }
            }
        }
    }

    /// Done segments 16 pt, current 28 pt, upcoming 8 pt grey. Animates the current one growing 8 → 28.
    func configure(step: Int, total: Int, animated: Bool) {
        let steps = sortedSteps
        visibleSteps = total
        steps.enumerated().forEach { $1.isHidden = $0 >= total }
        let apply = { (current: Int) in
            self.displayedStep = current
            self.updateWidths()
            for (i, v) in steps.enumerated() where i < total {
                v.backgroundColor = i <= current ? DS.Color.textPrimary : UIColor(named: "dsStepOff")
            }
        }
        accessibilityLabel = String(format: "Step %d of %d".localized, step + 1, total)
        stepperStack.isAccessibilityElement = true
        stepperStack.accessibilityLabel = accessibilityLabel
        guard animated, step > 0, !DS.Motion.reduceMotion else {
            apply(step)
            return
        }
        apply(step - 1)
        layoutIfNeeded()
        let animator = DS.Motion.gentleSpring(duration: 0.45)
        animator.addAnimations {
            apply(step)
            self.layoutIfNeeded()
        }
        animator.startAnimation(afterDelay: 0.05)
    }
}
