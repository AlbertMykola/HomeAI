import UIKit

@IBDesignable
class LiquidGlassView: UIView {
    
    private var glassEffectView: UIVisualEffectView?

    // MARK: - Inspectable Properties
    @IBInspectable var glassStyle: Int = 0 { didSet { applyLiquidGlass() } } // 0 = regular, 1 = clear
    @IBInspectable var glassTintColor: UIColor? { didSet { applyLiquidGlass() } }
    @IBInspectable var glassInteractive: Bool = true { didSet { applyLiquidGlass() } }
    @IBInspectable var glassBlurOpacity: CGFloat = 1.0 { didSet { glassEffectView?.alpha = glassBlurOpacity } }

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
                let blurStyle: UIBlurEffect.Style = (glassStyle == 1) ? .systemUltraThinMaterial : .systemThinMaterial
                let effect = UIBlurEffect(style: blurStyle)
                
                let visualEffectView = UIVisualEffectView(effect: effect)
                visualEffectView.frame = bounds
                visualEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                visualEffectView.alpha = glassBlurOpacity
                
                if let tint = glassTintColor {
                    let tintView = UIView(frame: bounds)
                    tintView.backgroundColor = tint.withAlphaComponent(0.2)
                    tintView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    visualEffectView.contentView.addSubview(tintView)
                }
                
                addSubview(visualEffectView)
                sendSubviewToBack(visualEffectView)
                glassEffectView = visualEffectView
            }
    }

    private func applyCornerConfiguration() {
        layer.cornerRadius = cornerRadiusValue
        layer.maskedCorners = []

        if topLeftCorner { layer.maskedCorners.insert(.layerMinXMinYCorner) }
        if topRightCorner { layer.maskedCorners.insert(.layerMaxXMinYCorner) }
        if bottomLeftCorner { layer.maskedCorners.insert(.layerMinXMaxYCorner) }
        if bottomRightCorner { layer.maskedCorners.insert(.layerMaxXMaxYCorner) }

        layer.masksToBounds = cornerRadiusValue > 0
    }
}
