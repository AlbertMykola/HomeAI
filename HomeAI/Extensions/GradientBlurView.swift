import UIKit

@IBDesignable
class GradientBlurView: UIView {

    // MARK: - Gradient
    @IBInspectable var startColor: UIColor = .white { didSet { setNeedsLayout() } }
    @IBInspectable var endColor: UIColor = .black { didSet { setNeedsLayout() } }
    @IBInspectable var horizontal: Bool = false { didSet { setNeedsLayout() } }
    @IBInspectable var gradientEnabled: Bool = true { didSet { setNeedsLayout() } }
    
    // MARK: - Blur
    @IBInspectable var blurEnabled: Bool = false { didSet { setNeedsLayout() } }
    @IBInspectable var blurStyle: Int = 0 { didSet { setNeedsLayout() } } // 0: light, 1: extraLight, 2: dark (підтримайте через switch)
    
    private var gradientLayer: CAGradientLayer?
    private var blurView: UIVisualEffectView?

    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Градієнт
        gradientLayer?.removeFromSuperlayer()
        if gradientEnabled {
            let gradient = CAGradientLayer()
            gradient.colors = [startColor.cgColor, endColor.cgColor]
            gradient.frame = bounds
            gradient.startPoint = horizontal ? CGPoint(x: 0, y: 0.5) : CGPoint(x: 0.5, y: 0)
            gradient.endPoint = horizontal ? CGPoint(x: 1, y: 0.5) : CGPoint(x: 0.5, y: 1)
            layer.insertSublayer(gradient, at: 0)
            gradientLayer = gradient
        }
        
        // Blur
        blurView?.removeFromSuperview()
        if blurEnabled {
            let styleArray: [UIBlurEffect.Style] = [.light, .extraLight, .dark]
            let style = styleArray[blurStyle]
            let effect = UIBlurEffect(style: style)
            let blur = UIVisualEffectView(effect: effect)
            blur.frame = bounds
            blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(blur)
            blurView = blur
        }
    }
}
