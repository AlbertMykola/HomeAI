import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

@IBDesignable
final class FigmaLayerBlurView: UIView {

    @IBInspectable var blur: CGFloat = 100 { didSet { setNeedsLayout() } }      // Figma px
    @IBInspectable var cornerRadiusIB: CGFloat = 18 { didSet { setNeedsLayout() } }
    @IBInspectable var continuousCorners: Bool = true { didSet { setNeedsLayout() } }
    @IBInspectable var fillColor: UIColor = UIColor(red: 0xA8/255, green: 0xA5/255, blue: 0xAE/255, alpha: 1) { didSet { setNeedsLayout() } }
    @IBInspectable var fillOpacity: CGFloat = 0.75 { didSet { setNeedsLayout() } }

    @IBInspectable var mode: Int = 0 { didSet { setNeedsLayout() } }            // 0=Uniform, 1=Progressive
    @IBInspectable var maskStart: CGFloat = 0.45 { didSet { setNeedsLayout() } }
    @IBInspectable var maskEnd: CGFloat   = 1.00 { didSet { setNeedsLayout() } }
    @IBInspectable var maskExponent: CGFloat = 1.0 { didSet { setNeedsLayout() } }
    @IBInspectable var maskOrientation: Int = 0 { didSet { setNeedsLayout() } } // 0=vertical, 1=horizontal

    private let imageView = UIImageView()

    // Явно задаємо колірні простори CI
    private lazy var ciContext: CIContext = {
        let ws = CGColorSpace(name: CGColorSpace.linearSRGB)!
        let os = CGColorSpace(name: CGColorSpace.sRGB)!
        return CIContext(options: [.workingColorSpace: ws, .outputColorSpace: os])
    }()

    override init(frame: CGRect) { super.init(frame: frame); commonInit() }
    required init?(coder: NSCoder) { super.init(coder: coder); commonInit() }

    private func commonInit() {
        isOpaque = false
        clipsToBounds = false
        addSubview(imageView)
        imageView.contentMode = .scaleToFill
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        layer.cornerRadius = cornerRadiusIB
        layer.cornerCurve = continuousCorners ? .continuous : .circular
        imageView.image = renderFigmaLayerBlur()
    }

    private func renderFigmaLayerBlur() -> UIImage? {
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        let scale = UIScreen.main.scale

        // Figma px -> Core Image pixels
        let radiusPx = max(0, blur) * scale

        // запас полотна в ПОІНТАХ
        let bleedPts = ceil(radiusPx / scale) * 1.5
        let canvasSize = CGSize(width: bounds.width + bleedPts*2,
                                height: bounds.height + bleedPts*2)
        let rect = CGRect(x: bleedPts, y: bleedPts, width: bounds.width, height: bounds.height)

        let fmt = UIGraphicsImageRendererFormat()
        fmt.opaque = false
        fmt.scale = scale

        // База (заливка + кут)
        let base = UIGraphicsImageRenderer(size: canvasSize, format: fmt).image { _ in
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadiusIB) // кругові; маскування continuous робитимемо шаром
            fillColor.withAlphaComponent(max(0, min(1, fillOpacity))).setFill()
            path.fill()
        }
        guard let cg = base.cgImage else { return base }
        let ciBase = CIImage(cgImage: cg)

        // Уніфікований пайплайн: premultiply -> clamp -> blur -> unpremultiply -> crop
        func blurCI(_ source: CIImage, radiusPx: CGFloat) -> CIImage? {
            let premult = source.premultiplyingAlpha()
            let clamped = premult.clampedToExtent()
            let g = CIFilter.gaussianBlur()
            g.inputImage = clamped
            g.radius = Float(radiusPx)
            guard let out = g.outputImage else { return nil }
            let unpremult = out.unpremultiplyingAlpha()
            return unpremult.cropped(to: source.extent)
        }

        if mode == 0 {
            guard let out = blurCI(ciBase, radiusPx: radiusPx) else { return base }
            guard let cgOut = ciContext.createCGImage(out, from: out.extent) else { return base }
            return UIImage(cgImage: cgOut, scale: scale, orientation: .up)
        }

        // Progressive: blurred + маска + змішування
        guard let blurred = blurCI(ciBase, radiusPx: radiusPx) else { return base }

        let maskImg = UIGraphicsImageRenderer(size: canvasSize, format: fmt).image { ctx in
            let grad = CAGradientLayer()
            grad.frame = CGRect(origin: .zero, size: canvasSize)
            let s = max(0, min(1, maskStart))
            let e = max(0, min(1, maskEnd))
            grad.locations = [NSNumber(value: Double(s)),
                              NSNumber(value: Double((s+e)/2)),
                              NSNumber(value: Double(e))]
            grad.colors = [UIColor.black.cgColor,
                           UIColor(white: 0.6, alpha: 1).cgColor,
                           UIColor.white.cgColor]
            if maskOrientation == 0 {
                grad.startPoint = CGPoint(x: 0.5, y: 0.0); grad.endPoint = CGPoint(x: 0.5, y: 1.0)
            } else {
                grad.startPoint = CGPoint(x: 0.0, y: 0.5); grad.endPoint = CGPoint(x: 1.0, y: 0.5)
            }
            grad.render(in: ctx.cgContext)
        }
        guard let cgMask = maskImg.cgImage else { return base }
        let ciMask = CIImage(cgImage: cgMask)

        let blend = CIFilter.blendWithAlphaMask()
        blend.inputImage = blurred
        blend.backgroundImage = ciBase
        blend.maskImage = ciMask
        guard let mixed = blend.outputImage else { return base }

        guard let cgOut = ciContext.createCGImage(mixed, from: ciBase.extent) else { return base }
        return UIImage(cgImage: cgOut, scale: scale, orientation: .up)
    }
}
