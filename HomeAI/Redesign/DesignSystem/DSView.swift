import UIKit

/// Base view for redesign storyboards. Corner radius / border come from the shared UIView inspectables
/// (`cornerRadius`, `borderWidth`, `borderColor`); this adds continuous corners, pills and shadow.
class DSView: UIView {

    /// Radius = height / 2 (pills, circles).
    @IBInspectable var pill: Bool = false { didSet { setNeedsLayout() } }
    @IBInspectable var shadowColor: UIColor = .black { didSet { applyShadow() } }
    @IBInspectable var shadowOpacity: Float = 0 { didSet { applyShadow() } }
    @IBInspectable var shadowRadius: CGFloat = 0 { didSet { applyShadow() } }
    @IBInspectable var shadowOffsetY: CGFloat = 0 { didSet { applyShadow() } }
    /// Border colour that follows light / dark (layer.borderColor is a fixed CGColor).
    @IBInspectable var dsBorderColor: UIColor? { didSet { layer.borderColor = dsBorderColor?.resolvedColor(with: traitCollection).cgColor } }

    override func awakeFromNib() {
        super.awakeFromNib()
        layer.cornerCurve = .continuous
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if let dsBorderColor { layer.borderColor = dsBorderColor.resolvedColor(with: traitCollection).cgColor }
        applyShadow()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if pill { layer.cornerRadius = bounds.height / 2 }
        if shadowOpacity > 0 {
            layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
        }
    }


    private func applyShadow() {
        layer.shadowColor = shadowColor.resolvedColor(with: traitCollection).cgColor
        layer.shadowOpacity = shadowOpacity
        layer.shadowRadius = shadowRadius
        layer.shadowOffset = CGSize(width: 0, height: shadowOffsetY)
    }
}

/// Linear gradient background. `angle` follows CSS: 180 = top → bottom, 90 = left → right.
class DSGradientView: DSView {

    @IBInspectable var startColor: UIColor = .white { didSet { update() } }
    @IBInspectable var endColor: UIColor = .white { didSet { update() } }
    @IBInspectable var midColor: UIColor? { didSet { update() } }
    /// Position of `midColor` (0…1).
    @IBInspectable var midLocation: CGFloat = 0.5 { didSet { update() } }
    @IBInspectable var angle: CGFloat = 180 { didSet { update() } }

    override class var layerClass: AnyClass { CAGradientLayer.self }
    private var gradient: CAGradientLayer { layer as! CAGradientLayer }

    override func awakeFromNib() {
        super.awakeFromNib()
        update()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        update()
    }

    private func update() {
        var colors = [startColor.cgColor]
        if let midColor { colors.append(midColor.cgColor) }
        colors.append(endColor.cgColor)
        gradient.colors = colors
        gradient.locations = midColor == nil ? nil : [0, NSNumber(value: Double(midLocation)), 1]
        let rad = (angle - 90) * .pi / 180
        let dx = cos(rad) / 2, dy = sin(rad) / 2
        gradient.startPoint = CGPoint(x: 0.5 - dx, y: 0.5 - dy)
        gradient.endPoint = CGPoint(x: 0.5 + dx, y: 0.5 + dy)
    }
}

/// UILabel with letter spacing / line height editable in Interface Builder.
class DSLabel: UILabel {

    @IBInspectable var letterSpacing: CGFloat = 0 { didSet { restyle() } }
    @IBInspectable var lineHeightMultiple: CGFloat = 0 { didSet { restyle() } }

    override var text: String? {
        didSet { restyle() }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        restyle()
    }

    private func restyle() {
        guard let text, letterSpacing != 0 || lineHeightMultiple > 0 else { return }
        var attrs: [NSAttributedString.Key: Any] = [.kern: letterSpacing]
        if lineHeightMultiple > 0 {
            let p = NSMutableParagraphStyle()
            p.lineHeightMultiple = lineHeightMultiple
            p.alignment = textAlignment
            p.lineBreakMode = lineBreakMode
            attrs[.paragraphStyle] = p
        }
        super.attributedText = NSAttributedString(string: text, attributes: attrs)
    }
}

/// Image view with continuous corners (radius via the shared `cornerRadius` inspectable).
class DSImageView: UIImageView {
    override func awakeFromNib() {
        super.awakeFromNib()
        layer.cornerCurve = .continuous
        clipsToBounds = true
    }
}
