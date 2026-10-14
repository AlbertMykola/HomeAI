import UIKit

/// Tappable card / button whose content is laid out in a XIB.
/// Press: scale 0.96 + haptic .light; release: spring back (dev notes, H1 §9).
class DSPressableControl: UIControl {

    @IBInspectable var pill: Bool = false { didSet { setNeedsLayout() } }
    @IBInspectable var shadowOpacity: Float = 0 { didSet { applyShadow() } }
    @IBInspectable var shadowRadius: CGFloat = 0 { didSet { applyShadow() } }
    @IBInspectable var shadowOffsetY: CGFloat = 0 { didSet { applyShadow() } }
    @IBInspectable var shadowColor: UIColor = .black { didSet { applyShadow() } }
    @IBInspectable var pressedScale: CGFloat = 0.96
    @IBInspectable var hapticOnPress: Bool = true
    /// Dimmed look used e.g. offline (opacity 0.45) while still receiving taps.
    @IBInspectable var dimmed: Bool = false { didSet { alpha = dimmed ? 0.45 : 1 } }

    /// Selector sent up the responder chain on tap (set in Interface Builder, e.g. "didTapUpload:").
    @IBInspectable var actionName: String?

    private var pressAnimator: UIViewPropertyAnimator?

    override func awakeFromNib() {
        super.awakeFromNib()
        layer.cornerCurve = .continuous
        if let actionName, !actionName.isEmpty {
            addTarget(self, action: #selector(dispatchNamedAction), for: .touchUpInside)
        }
        // Everything inside is decoration — the control itself handles touches.
        allSubviews(of: self).forEach { $0.isUserInteractionEnabled = false }
        isAccessibilityElement = true
        accessibilityTraits = .button
        if accessibilityLabel == nil {
            accessibilityLabel = allSubviews(of: self).compactMap { ($0 as? UILabel)?.text }.joined(separator: ", ")
        }
    }

    /// Walks this control's own responder chain (a nil target would start at the first responder instead).
    @objc private func dispatchNamedAction() {
        guard let actionName, !actionName.isEmpty else { return }
        let selector = NSSelectorFromString(actionName)
        var responder: UIResponder? = next
        while let r = responder {
            if r.responds(to: selector) {
                UIApplication.shared.sendAction(selector, to: r, from: self, for: nil)
                return
            }
            responder = r.next
        }
        #if DEBUG
        print("[DSPressableControl] nobody handles \(actionName)")
        #endif
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if pill { layer.cornerRadius = bounds.height / 2 }
        if shadowOpacity > 0 {
            layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
        }
    }

    override var isHighlighted: Bool {
        didSet {
            guard oldValue != isHighlighted else { return }
            animatePress(isHighlighted)
        }
    }

    private func animatePress(_ pressed: Bool) {
        pressAnimator?.stopAnimation(true)
        if pressed, hapticOnPress { DS.Haptic.light() }
        let animator = pressed
            ? UIViewPropertyAnimator(duration: 0.12, curve: .easeOut)
            : UIViewPropertyAnimator(duration: 0.45, dampingRatio: 0.55)
        animator.addAnimations { [weak self] in
            guard let self else { return }
            self.transform = pressed ? CGAffineTransform(scaleX: self.pressedScale, y: self.pressedScale) : .identity
        }
        animator.startAnimation()
        pressAnimator = animator
    }

    private func applyShadow() {
        layer.shadowColor = shadowColor.cgColor
        layer.shadowOpacity = shadowOpacity
        layer.shadowRadius = shadowRadius
        layer.shadowOffset = CGSize(width: 0, height: shadowOffsetY)
    }

    private func allSubviews(of view: UIView) -> [UIView] {
        view.subviews + view.subviews.flatMap { allSubviews(of: $0) }
    }
}

/// Lime gradient pill (Button/Primary). Icon + title are laid out in the XIB; this adds gradient,
/// soft lime shadow and the shimmer sweep.
final class DSPrimaryButton: DSPressableControl {

    private let gradient = CAGradientLayer()
    private let shimmer = CAGradientLayer()
    private let shimmerHost = CALayer()

    /// Disabled look (grey) — e.g. Next before a photo is chosen.
    @IBInspectable var inactive: Bool = false { didSet { updateGradient() } }

    override func awakeFromNib() {
        super.awakeFromNib()
        pill = true
        clipsToBounds = false
        gradient.cornerCurve = .continuous
        layer.insertSublayer(gradient, at: 0)
        shimmerHost.masksToBounds = true
        layer.insertSublayer(shimmerHost, at: 1)
        shimmer.colors = [UIColor.white.withAlphaComponent(0).cgColor,
                          UIColor.white.withAlphaComponent(0.55).cgColor,
                          UIColor.white.withAlphaComponent(0).cgColor]
        shimmer.startPoint = CGPoint(x: 0, y: 0.5)
        shimmer.endPoint = CGPoint(x: 1, y: 0.5)
        shimmerHost.addSublayer(shimmer)
        shadowColor = UIColor(red: 123 / 255, green: 196 / 255, blue: 26 / 255, alpha: 1)
        shadowOpacity = 0.22
        shadowRadius = 9
        shadowOffsetY = 6
        updateGradient()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        gradient.cornerRadius = bounds.height / 2
        shimmerHost.frame = bounds
        shimmerHost.cornerRadius = bounds.height / 2
        shimmer.bounds = CGRect(x: 0, y: 0, width: 70, height: bounds.height * 2)
        shimmer.position = CGPoint(x: -70, y: bounds.midY)
        shimmer.setAffineTransform(CGAffineTransform(rotationAngle: .pi / 9))
        CATransaction.commit()
    }

    override var isEnabled: Bool {
        didSet { updateGradient() }
    }

    /// Inactive = same lime pill at 40 % opacity (Button/Primary · Next, disabled).
    private func updateGradient() {
        let off = inactive || !isEnabled
        gradient.colors = [DS.Color.limeTop.cgColor, DS.Color.limeBottom.cgColor]
        gradient.opacity = off ? 0.4 : 1
        subviews.forEach { $0.alpha = off ? 0.4 : 1 }
        layer.shadowOpacity = off ? 0 : shadowOpacity
        accessibilityTraits = off ? [.button, .notEnabled] : .button
    }

    /// One shimmer sweep (0.9 s, ease-in-out). Skipped with Reduce Motion.
    func runShimmer(delay: TimeInterval = 0) {
        guard !DS.Motion.reduceMotion, bounds.width > 0 else { return }
        let anim = CABasicAnimation(keyPath: "position.x")
        anim.fromValue = -70
        anim.toValue = bounds.width + 70
        anim.duration = 0.9
        anim.beginTime = CACurrentMediaTime() + delay
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        anim.fillMode = .backwards
        shimmer.add(anim, forKey: "shimmer")
    }

    /// Gentle attention pulse 1 → 1.03 → 1.
    func pulse(delay: TimeInterval = 0) {
        guard !DS.Motion.reduceMotion else { return }
        UIView.animate(withDuration: 0.25, delay: delay, options: [.curveEaseOut, .allowUserInteraction]) {
            self.transform = CGAffineTransform(scaleX: 1.03, y: 1.03)
        } completion: { _ in
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0,
                           options: [.allowUserInteraction]) { self.transform = .identity }
        }
    }
}
