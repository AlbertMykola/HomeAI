import UIKit

/// NavBar of the wizard: glass back (←), stepper, glass close (✕). Layout: WizardNavBar.xib.
/// Taps go up the responder chain as `didTapWizardBack:` / `didTapWizardClose:`.
final class WizardNavBar: DSNibView {

    @IBOutlet private(set) weak var backButton: DSPressableControl!
    @IBOutlet private(set) weak var closeButton: DSPressableControl!
    @IBOutlet private weak var stepperStack: UIStackView!
    @IBOutlet private var stepViews: [UIView]!

    private var sortedSteps: [UIView] { stepViews.sorted { $0.tag < $1.tag } }

    /// Done segments 16 pt, current 28 pt, upcoming 8 pt grey. Animates the current one growing 8 → 28.
    func configure(step: Int, total: Int, animated: Bool) {
        let steps = sortedSteps
        steps.enumerated().forEach { $1.isHidden = $0 >= total }
        let apply = { (current: Int) in
            for (i, v) in steps.enumerated() where i < total {
                let width: CGFloat = i < current ? 16 : (i == current ? 28 : 8)
                v.constraints.first { $0.firstAttribute == .width }?.constant = width
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
