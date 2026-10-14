import UIKit

/// Redesign (variant A) tokens. Colors live in Assets.xcassets/RedesignColors so XIBs and code share them.
enum DS {

    enum Color {
        static let lime = UIColor(named: "dsLime")!
        static let limeTop = UIColor(named: "dsLimeTop")!
        static let limeBottom = UIColor(named: "dsLimeBottom")!
        static let limeSoft = UIColor(named: "dsLimeSoft")!
        static let limeText = UIColor(named: "dsLimeText")!
        static let link = UIColor(named: "dsLink")!
        static let surface = UIColor(named: "dsSurface")!
        static let textPrimary = UIColor(named: "dsTextPrimary")!
        static let textSecondary = UIColor(named: "dsTextSecondary")!
        static let textTertiary = UIColor(named: "dsTextTertiary")!
        static let limeTint = UIColor(named: "dsLimeTint")!
    }

    enum Font {
        static func geologica(_ weight: GeologicaWeight, _ size: CGFloat) -> UIFont {
            UIFont.geologica(.standard(weight), size: size)
        }
    }

    // MARK: - Motion

    enum Motion {
        /// cubic-bezier(0.45, 1.45, 0.8, 1) — "pop" used across Figma timelines.
        static let easeOutBack = UICubicTimingParameters(controlPoint1: CGPoint(x: 0.45, y: 1.45),
                                                         controlPoint2: CGPoint(x: 0.8, y: 1))
        /// Figma "gentle" spring (≈ damping 0.78, response 0.5).
        static func gentleSpring(duration: TimeInterval = 0.55) -> UIViewPropertyAnimator {
            UIViewPropertyAnimator(duration: duration, dampingRatio: 0.78)
        }

        static var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }

        /// Runs `animations` after `delay` using a property animator (ease-out by default).
        @discardableResult
        static func animate(_ duration: TimeInterval,
                            delay: TimeInterval = 0,
                            timing: UITimingCurveProvider = UICubicTimingParameters(animationCurve: .easeOut),
                            _ animations: @escaping () -> Void,
                            completion: (() -> Void)? = nil) -> UIViewPropertyAnimator {
            let animator = UIViewPropertyAnimator(duration: duration, timingParameters: timing)
            animator.addAnimations(animations)
            animator.addCompletion { _ in completion?() }
            animator.startAnimation(afterDelay: delay)
            return animator
        }

        /// Entrance used by most screens: fade + offset (+ optional scale) → identity.
        static func enter(_ view: UIView?, delay: TimeInterval, dy: CGFloat = 0, dx: CGFloat = 0,
                          scale: CGFloat = 1, duration: TimeInterval = 0.45, pop: Bool = false, spring: Bool = false) {
            guard let view else { return }
            if reduceMotion {
                view.alpha = 0
                animate(0.2, delay: min(delay, 0.1)) { view.alpha = 1 }
                return
            }
            view.alpha = 0
            view.transform = CGAffineTransform(translationX: dx, y: dy).scaledBy(x: scale, y: scale)
            if spring {
                let animator = gentleSpring(duration: duration + 0.15)
                animator.addAnimations { view.alpha = 1; view.transform = .identity }
                animator.startAnimation(afterDelay: delay)
            } else {
                animate(duration, delay: delay, timing: pop ? easeOutBack : UICubicTimingParameters(animationCurve: .easeOut)) {
                    view.alpha = 1
                    view.transform = .identity
                }
            }
        }
    }

    // MARK: - Haptics

    enum Haptic {
        static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
        static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
        static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
        static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    }
}

extension UIColor {
    /// "EFE8DD" or "#EFE8DD".
    convenience init(hex: String) {
        let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                  blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }
}
