import UIKit

@IBDesignable
class LiquidGlassView: UIView {
    
    private var glassEffectView: UIVisualEffectView?
    private var tintOverlay: UIView?
    private var gradientOverlay: CAGradientLayer?

    // MARK: - Inspectable Properties
    @IBInspectable var glassStyle: Int = 0 { didSet { applyLiquidGlass() } } // 0 = regular, 1 = clear
    @IBInspectable var glassTintColor: UIColor? { didSet { applyLiquidGlass() } }
    @IBInspectable var glassInteractive: Bool = true { didSet { applyLiquidGlass() } }
    @IBInspectable var glassBlurOpacity: CGFloat = 1.0 { didSet { glassEffectView?.alpha = glassBlurOpacity } }
    @IBInspectable var fallbackGradient: Bool = true { didSet { applyLiquidGlass() } }
    @IBInspectable var fallbackShadow: Bool = true { didSet { applyLiquidGlass() } }
    @IBInspectable var fallbackRadius: CGFloat = 14 { didSet { setNeedsLayout() } }
    // Налаштування "скляності" для iOS < 26
    // Ближче до прозорого вигляду iOS 26: менше тинту і blur
    @IBInspectable var fallbackTintOpacity: CGFloat = 0.14 { didSet { applyLiquidGlass() } }
    @IBInspectable var fallbackBlurAlpha: CGFloat = 0.82 { didSet { applyLiquidGlass() } }

    // Corner radius per corner
    @IBInspectable var cornerRadiusValue: CGFloat = 0 { didSet { applyCornerConfiguration() } }
    @IBInspectable var topLeftCorner: Bool = false { didSet { applyCornerConfiguration() } }
    @IBInspectable var topRightCorner: Bool = false { didSet { applyCornerConfiguration() } }
    @IBInspectable var bottomLeftCorner: Bool = false { didSet { applyCornerConfiguration() } }
    @IBInspectable var bottomRightCorner: Bool = false { didSet { applyCornerConfiguration() } }

    // MARK: - Lifecycle
    override func layoutSubviews() {
        super.layoutSubviews()
        glassEffectView?.frame = bounds
        tintOverlay?.frame = bounds
        gradientOverlay?.frame = bounds
        applyCornerConfiguration()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        applyLiquidGlass()
        applyCornerConfiguration()
    }

    // MARK: - Setup Methods
    private func applyLiquidGlass() {
        glassEffectView?.removeFromSuperview()
        tintOverlay?.removeFromSuperview()
        gradientOverlay?.removeFromSuperlayer()
        tintOverlay = nil
        gradientOverlay = nil

        if #available(iOS 26.0, *) {
            let style: UIGlassEffect.Style = (glassStyle == 1) ? .clear : .regular
            let effect = UIGlassEffect(style: style)
            effect.isInteractive = glassInteractive
            if let tint = glassTintColor {
                effect.tintColor = tint
            }

            let visualEffectView = UIVisualEffectView(effect: effect)
            visualEffectView.frame = bounds
            visualEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            visualEffectView.alpha = glassBlurOpacity
            addSubview(visualEffectView)
            sendSubviewToBack(visualEffectView)
            glassEffectView = visualEffectView
        } else {
                let blurStyle: UIBlurEffect.Style = (glassStyle == 1) ? .systemUltraThinMaterial : .systemMaterial
                let effect = UIBlurEffect(style: blurStyle)
                
                let visualEffectView = UIVisualEffectView(effect: effect)
                visualEffectView.frame = bounds
                visualEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                visualEffectView.alpha = fallbackBlurAlpha
                
                addSubview(visualEffectView)
                sendSubviewToBack(visualEffectView)
                glassEffectView = visualEffectView

                // Fallback tint overlay (для виразнішого glass на старих iOS)
                let tintView = UIView(frame: bounds)
                let baseTint = glassTintColor ?? UIColor { [self] trait in
                    trait.userInterfaceStyle == .dark
                    ? UIColor.black.withAlphaComponent(0.16)
                    : UIColor.white.withAlphaComponent(fallbackTintOpacity)
                }
                tintView.backgroundColor = baseTint
                tintView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                addSubview(tintView)
                sendSubviewToBack(tintView)
                tintOverlay = tintView

                // Fallback gradient для додаткової глибини
                if fallbackGradient {
                    let gradient = CAGradientLayer()
                    gradient.colors = [
                        UIColor.white.withAlphaComponent(0.08).cgColor,
                        UIColor.white.withAlphaComponent(0.02).cgColor,
                        UIColor.black.withAlphaComponent(0.10).cgColor
                    ]
                    gradient.locations = [0, 0.48, 1]
                    gradient.frame = bounds
                    layer.insertSublayer(gradient, above: tintView.layer)
                    gradientOverlay = gradient
                }

                // Легка тінь, щоб відійшло від фону
                if fallbackShadow {
                    layer.shadowColor = UIColor.black.cgColor
                    layer.shadowOpacity = 0.08
                    layer.shadowRadius = 12
                    layer.shadowOffset = CGSize(width: 0, height: 6)
                } else {
                    layer.shadowOpacity = 0
                }
            }
    }

    private func applyCornerConfiguration() {
        let radius = cornerRadiusValue > 0 ? cornerRadiusValue : fallbackRadius
        layer.cornerRadius = radius
        layer.maskedCorners = []

        if topLeftCorner { layer.maskedCorners.insert(.layerMinXMinYCorner) }
        if topRightCorner { layer.maskedCorners.insert(.layerMaxXMinYCorner) }
        if bottomLeftCorner { layer.maskedCorners.insert(.layerMinXMaxYCorner) }
        if bottomRightCorner { layer.maskedCorners.insert(.layerMaxXMaxYCorner) }

        layer.masksToBounds = false // дозволяємо тіні
        glassEffectView?.layer.cornerRadius = radius
        glassEffectView?.clipsToBounds = true
        tintOverlay?.layer.cornerRadius = radius
        tintOverlay?.clipsToBounds = true
        gradientOverlay?.cornerRadius = radius
    }
}
