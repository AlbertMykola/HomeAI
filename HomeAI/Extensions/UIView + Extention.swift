import UIKit
import QuartzCore
import ObjectiveC

// MARK: - UIView Extensions
public extension UIView {
    
    // MARK: - Rounding
    
    func roundCorners(_ corners: UIRectCorner, radius: CGFloat) {
        let path = UIBezierPath(roundedRect: bounds, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        let mask = CAShapeLayer()
        mask.path = path.cgPath
        layer.mask = mask
    }
    
    @IBInspectable var cornerRadius: CGFloat {
        get { return layer.cornerRadius }
        set { layer.cornerRadius = newValue }
    }
    
    // MARK: - Border
    
    @IBInspectable var borderWidth: CGFloat {
        get { return layer.borderWidth }
        set { layer.borderWidth = newValue }
    }
    
    @IBInspectable var borderColor: UIColor? {
        get { return UIColor(cgColor: layer.borderColor ?? UIColor.clear.cgColor) }
        set { layer.borderColor = newValue?.cgColor }
    }
    
    // MARK: - Safe Area
    var safeAreaHeight: CGFloat {
        if #available(iOS 11, *) {
            return safeAreaLayoutGuide.layoutFrame.size.height
        }
        return bounds.height
    }
    
    // MARK: - Gradient
    func applyHorizontalGradient(colors: [UIColor], locations: [NSNumber]? = nil) {
        applyGradient(colors: colors, locations: locations, startPoint: CGPoint(x: 0.0, y: 0.5), endPoint: CGPoint(x: 1.0, y: 0.5))
    }
    
    func applyVerticalGradient(colors: [UIColor], locations: [NSNumber]? = nil) {
        applyGradient(colors: colors, locations: locations, startPoint: CGPoint(x: 0.5, y: 0.0), endPoint: CGPoint(x: 0.5, y: 1.0))
    }
    
    private func applyGradient(colors: [UIColor], locations: [NSNumber]? = nil, startPoint: CGPoint, endPoint: CGPoint) {
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = colors.map { $0.cgColor }
        gradientLayer.locations = locations
        gradientLayer.startPoint = startPoint
        gradientLayer.endPoint = endPoint
        gradientLayer.frame = self.bounds
        
        self.layer.sublayers?
            .filter { $0 is CAGradientLayer }
            .forEach { $0.removeFromSuperlayer() }
        self.layer.insertSublayer(gradientLayer, at: 0)
    }
    
    func removeGradientLayer() {
        for layer in self.layer.sublayers ?? [] {
            if let gradientLayer = layer as? CAGradientLayer {
                gradientLayer.removeFromSuperlayer()
                break
            }
        }
    }
    
    func applyFigmaShadow(x: CGFloat, y: CGFloat, blur: CGFloat, spread: CGFloat, color: UIColor, opacityPercent: CGFloat, cornerRadius overrideCornerRadius: CGFloat? = nil) {
        layer.shadowColor = color.withAlphaComponent(1).cgColor
        layer.shadowOpacity = Float(max(0, min(1, opacityPercent / 100)))
        layer.shadowOffset = CGSize(width: x, height: y)
        layer.shadowRadius = max(0, blur * 0.5)                // Figma: blur ≈ 2 * shadowRadius
        layer.masksToBounds = false
        layer.shouldRasterize = false                           // важливо, поки розмір може змінюватись

        // 2) Функція, що рахує path (залежить від поточних bounds)
        func setPath(for view: UIView) {
            let r = (overrideCornerRadius ?? view.layer.cornerRadius)
            let inset = -spread                                  // негативний inset збільшує прямокутник
            let shadowRect = view.bounds.insetBy(dx: inset, dy: inset)
            let shadowCornerRadius = max(0, r + spread)
            view.layer.shadowPath = UIBezierPath(
                roundedRect: shadowRect,
                cornerRadius: shadowCornerRadius
            ).cgPath
        }
        if bounds.width > 1, bounds.height > 1 {
            setPath(for: self)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.bounds.width > 1, self.bounds.height > 1 else { return }
                setPath(for: self)
            }
        }
    }
    
    func addDashedBorder(color: UIColor, lineWidth: CGFloat, dashPattern: [NSNumber], cornerRadius: CGFloat) {
        // Видаляємо попередні пунктирні рамки, щоб не перекривались
        layer.sublayers?.removeAll(where: { $0.name == "DashedBorder" })

        let shapeLayer = CAShapeLayer()
        shapeLayer.name = "DashedBorder"
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.strokeColor = color.cgColor
        shapeLayer.lineWidth = lineWidth
        shapeLayer.lineDashPattern = dashPattern
        shapeLayer.path = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath
        layer.addSublayer(shapeLayer)
    }

}

// MARK: - Animations
public extension UIView {
    
    func pulseView(duration: TimeInterval = 1.0, delay: TimeInterval = 0) {
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.duration = duration
        pulse.fromValue = 1.0
        pulse.toValue = 1.05
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.layer.add(pulse, forKey: "pulse")
        }
    }

    func stopPulseView() {
        layer.removeAnimation(forKey: "pulse")
    }

    private static let shimmerLayerName = "PaywallShimmerLayer"
    private static let highlightLayerName = "PaywallHighlightShimmerLayer"
    private static var shimmerBackgroundColorKey: UInt8 = 0
    private static var shimmerHighlightColorKey: UInt8 = 0
    private static var shimmerOverlayKey: UInt8 = 0

    private var paywallShimmerOverlay: UIView? {
        get { objc_getAssociatedObject(self, &Self.shimmerOverlayKey) as? UIView }
        set { objc_setAssociatedObject(self, &Self.shimmerOverlayKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var isPaywallShimmering: Bool { paywallShimmerOverlay != nil }

    /// Кольори skeleton для paywall (темний / світлий фон).
    static func paywallSkeletonShimmerColors(for traitCollection: UITraitCollection) -> (
        background: UIColor,
        highlight: UIColor
    ) {
        if traitCollection.userInterfaceStyle == .dark {
            return (
                UIColor(white: 1, alpha: 0.14),
                UIColor(white: 1, alpha: 0.38)
            )
        }
        return (
            UIColor(white: 0.82, alpha: 1),
            UIColor(white: 1, alpha: 0.75)
        )
    }

    /// Skeleton shimmer (поки підвантажуються продукти).
    func startShimmer(
        highlightColor: UIColor = UIColor.white.withAlphaComponent(0.45),
        backgroundColor: UIColor = UIColor(white: 0.88, alpha: 1)
    ) {
        stopShimmer()

        let overlay = UIView()
        overlay.isUserInteractionEnabled = false
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.clipsToBounds = true
        overlay.backgroundColor = backgroundColor
        overlay.layer.cornerRadius = layer.cornerRadius
        overlay.layer.cornerCurve = .continuous
        addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlay.topAnchor.constraint(equalTo: topAnchor),
            overlay.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        paywallShimmerOverlay = overlay
        objc_setAssociatedObject(self, &Self.shimmerBackgroundColorKey, backgroundColor, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, &Self.shimmerHighlightColorKey, highlightColor, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        layoutIfNeeded()
        addSweepGradient(
            to: overlay,
            named: Self.shimmerLayerName,
            highlightColor: highlightColor,
            duration: 1.15
        )
    }

    func stopShimmer() {
        paywallShimmerOverlay?.removeFromSuperview()
        paywallShimmerOverlay = nil
        objc_setAssociatedObject(self, &Self.shimmerBackgroundColorKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(self, &Self.shimmerHighlightColorKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    func updateShimmerFrame() {
        guard let overlay = paywallShimmerOverlay else { return }
        overlay.layer.cornerRadius = layer.cornerRadius
        overlay.layoutIfNeeded()
        let highlightColor = (objc_getAssociatedObject(self, &Self.shimmerHighlightColorKey) as? UIColor)
            ?? UIColor.white.withAlphaComponent(0.38)
        addSweepGradient(
            to: overlay,
            named: Self.shimmerLayerName,
            highlightColor: highlightColor,
            duration: 1.15
        )
    }

    /// М’який shine поверх кнопки: не ховає текст і крутиться постійно.
    func startHighlightShimmer(highlightColor: UIColor = UIColor.white.withAlphaComponent(0.55)) {
        stopHighlightShimmer()
        clipsToBounds = true
        addSweepGradient(
            to: self,
            named: Self.highlightLayerName,
            highlightColor: highlightColor,
            duration: 2.1,
            insertAtZero: true,
            diagonal: true
        )
    }

    func stopHighlightShimmer() {
        layer.sublayers?
            .filter { $0.name == Self.highlightLayerName }
            .forEach { $0.removeFromSuperlayer() }
    }

    func updateHighlightShimmerFrame() {
        guard bounds.width > 1, bounds.height > 1 else { return }
        addSweepGradient(
            to: self,
            named: Self.highlightLayerName,
            highlightColor: UIColor.white.withAlphaComponent(0.55),
            duration: 2.1,
            insertAtZero: true,
            diagonal: true
        )
    }

    private func addSweepGradient(
        to host: UIView,
        named name: String,
        highlightColor: UIColor,
        duration: TimeInterval,
        insertAtZero: Bool = false,
        diagonal: Bool = false
    ) {
        let bounds = host.bounds
        guard bounds.width > 1, bounds.height > 1 else { return }

        if UIAccessibility.isReduceMotionEnabled {
            host.layer.sublayers?.filter { $0.name == name }.forEach { $0.removeFromSuperlayer() }
            return
        }

        let existing = host.layer.sublayers?.first(where: { $0.name == name }) as? CAGradientLayer
        let gradient = existing ?? CAGradientLayer()
        gradient.name = name
        let newFrame = CGRect(x: -bounds.width, y: 0, width: bounds.width * 3, height: bounds.height)
        let needsLayout = existing == nil
            || abs(gradient.frame.width - newFrame.width) > 1
            || abs(gradient.frame.height - newFrame.height) > 1
        guard needsLayout else { return }

        gradient.frame = newFrame
        gradient.colors = [
            UIColor.clear.cgColor,
            highlightColor.withAlphaComponent(0.12).cgColor,
            highlightColor.cgColor,
            highlightColor.withAlphaComponent(0.12).cgColor,
            UIColor.clear.cgColor
        ]
        gradient.locations = [0.25, 0.44, 0.5, 0.56, 0.75]
        if diagonal {
            gradient.startPoint = CGPoint(x: 0, y: 0.15)
            gradient.endPoint = CGPoint(x: 1, y: 0.85)
        } else {
            gradient.startPoint = CGPoint(x: 0, y: 0.5)
            gradient.endPoint = CGPoint(x: 1, y: 0.5)
        }
        gradient.removeAnimation(forKey: "shimmer")
        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = -bounds.width
        animation.toValue = bounds.width
        animation.duration = duration
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        gradient.add(animation, forKey: "shimmer")

        if gradient.superlayer == nil {
            if insertAtZero {
                host.layer.insertSublayer(gradient, at: 0)
            } else {
                host.layer.addSublayer(gradient)
            }
        }
    }
}

public extension UIView {

    struct GradientStop {
        public var percent: CGFloat   // 0…100
        public var color: UIColor
        public init(percent: CGFloat, color: UIColor) {
            self.percent = percent
            self.color = color
        }
    }

    enum GradientDirection {
        case vertical
        case horizontal
        case angle(CGFloat) // у градусах: 0 -> вправо, 90 -> вгору
    }

    private struct AssocKeys {
        static var gradientLayer = "ppx.gradientLayer"
    }

    private var ppxGradientLayer: CAGradientLayer? {
        get { objc_getAssociatedObject(self, &AssocKeys.gradientLayer) as? CAGradientLayer }
        set { objc_setAssociatedObject(self, &AssocKeys.gradientLayer, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // Головний метод: як у Figma — масив стопів (відсоток + колір) і напрям
    func setGradient(stops: [GradientStop], direction: GradientDirection = .vertical) {
        let layer = ppxGradientLayer ?? CAGradientLayer()
        layer.frame = bounds
        layer.colors = stops.map { $0.color.cgColor }
        layer.locations = stops.map { NSNumber(value: Double(max(0, min(100, $0.percent)) / 100.0)) }

        switch direction {
        case .vertical:
            layer.startPoint = CGPoint(x: 0.5, y: 0.0)
            layer.endPoint   = CGPoint(x: 0.5, y: 1.0)
        case .horizontal:
            layer.startPoint = CGPoint(x: 0.0, y: 0.5)
            layer.endPoint   = CGPoint(x: 1.0, y: 0.5)
        case .angle(let degrees):
            let (start, end) = Self.gradientPoints(for: degrees)
            layer.startPoint = start
            layer.endPoint   = end
        }

        if ppxGradientLayer == nil {
            self.layer.insertSublayer(layer, at: 0) // під контент
            ppxGradientLayer = layer
        }
    }

    /// Оновити розмір градієнта під поточні `bounds` (після layout).
    /// Якщо задано `cornerRadius`, шар підганяється під заокруглення батька (капсула картки тощо).
    func updateGradientFrame(cornerRadius: CGFloat? = nil) {
        guard let g = ppxGradientLayer else { return }
        g.frame = bounds
        if let r = cornerRadius {
            g.cornerRadius = r
            g.masksToBounds = true
        }
    }

    // Перетворення кута у start/end у unit‑просторі
    private static func gradientPoints(for angle: CGFloat) -> (CGPoint, CGPoint) {
        let radians = angle * .pi / 180.0
        var x = cos(radians), y = sin(radians)

        if abs(x) > abs(y) {
            x = x >= 0 ? 1 : -1
            y = x * tan(radians)
        } else {
            y = y >= 0 ? 1 : -1
            x = y / tan(radians)
        }

        let endSigned = CGPoint(x: x, y: y)
        let startSigned = CGPoint(x: -endSigned.x, y: -endSigned.y)

        func toGradientSpace(_ p: CGPoint) -> CGPoint {
            CGPoint(x: (p.x + 1) * 0.5, y: 1.0 - (p.y + 1) * 0.5)
        }
        return (toGradientSpace(startSigned), toGradientSpace(endSigned))
    }
    
    func maskTopWithCircularDome(sagitta: CGFloat) {
            layoutIfNeeded()

            let w = bounds.width
            let h = bounds.height
            guard w > 0, h > 0, sagitta > 0 else { layer.mask = nil; return }

            // Формула радіуса кола через довжину хорди w та сагіту s:
            // r = (s^2 + (w/2)^2) / (2s)
            let s = sagitta
            let r = (s*s + (w*w)/4.0) / (2.0*s) // точна кругова дуга, без апроксимацій [web:184]

            // Центр кола лежить над верхнім ребром на відстані (r - s)
            let cx = w / 2.0
            let cy = -(r - s)

            // Кути до лівої та правої вершин хорди з урахуванням системи координат iOS
            let leftAngle  = atan2(0 - cy,    0 - cx)
            let rightAngle = atan2(0 - cy, w - cx)

            let path = UIBezierPath()
            // вниз лівий
            path.move(to: CGPoint(x: 0, y: h))
            path.addLine(to: CGPoint(x: 0, y: 0))
            // верхня кругова дуга зліва направо
            path.addArc(withCenter: CGPoint(x: cx, y: cy),
                        radius: r,
                        startAngle: leftAngle,
                        endAngle: rightAngle,
                        clockwise: true) // побудова дуги за документацією UIBezierPath [web:197]
            // правий край і низ
            path.addLine(to: CGPoint(x: w, y: h))
            path.close()

            let mask = CAShapeLayer()
            mask.path = path.cgPath
            layer.mask = mask // застосувати як маску шару, щоб обрізати контент під арку [web:200][web:188]
        }
}

extension UIView {
    class func fromNib<T: UIView>() -> T {
        let generic = String(describing: T.self)
        let base = generic.components(separatedBy: "<").first ?? generic
        let bundle = Bundle(for: T.self)
        guard let view = bundle.loadNibNamed(base, owner: nil, options: nil)?.first as? T else {
            assertionFailure("Missing nib \(base)")
            return T(frame: .zero)
        }
        return view
    }
}
