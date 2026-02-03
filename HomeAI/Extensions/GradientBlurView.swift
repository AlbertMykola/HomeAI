import UIKit

@IBDesignable
class GradientBlurView: UIView {

    // MARK: - Gradient
    @IBInspectable var startColor: UIColor = .white { didSet { setNeedsLayout() } }
    @IBInspectable var endColor: UIColor = .black { didSet { setNeedsLayout() } }
    @IBInspectable var horizontal: Bool = false { didSet { setNeedsLayout() } }
    @IBInspectable var gradientEnabled: Bool = true { didSet { setNeedsLayout() } }
    /// Figma-like stops in percent (0...100)
    @IBInspectable var startLocationPercent: CGFloat = 0 { didSet { setNeedsLayout() } }
    @IBInspectable var endLocationPercent: CGFloat = 100 { didSet { setNeedsLayout() } }
    
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
            
            let start = max(0, min(100, startLocationPercent)) / 100.0
            let end = max(0, min(100, endLocationPercent)) / 100.0
            let from = min(start, end)
            let to = max(start, end)
            gradient.locations = [NSNumber(value: Double(from)), NSNumber(value: Double(to))]
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
