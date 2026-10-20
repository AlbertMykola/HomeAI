import UIKit

extension UIViewController {
    /// Moves the white knob of a XIB segmented control (knob + equal segments) and restyles the labels.
    func applySegment(index: Int, labels: [UILabel], knobLeading: NSLayoutConstraint, container: UIView,
                      count: Int, animated: Bool) {
        let inset = OnboardingLayout(size: view.dsAdaptiveReferenceSize).value(3)
        let width = (container.bounds.width - 2 * inset) / CGFloat(count)
        let changes = {
            let leading = inset + width * CGFloat(index)
            if abs(knobLeading.constant - leading) > 0.01 { knobLeading.constant = leading }
            for (i, l) in labels.sorted(by: { $0.tag < $1.tag }).enumerated() {
                let font = DS.Font.geologica(i == index ? .semiBold : .medium, l.font.pointSize)
                let color = i == index ? DS.Color.textPrimary : DS.Color.textSecondary
                if l.font != font { l.font = font }
                if l.textColor != color { l.textColor = color }
            }
            if animated { container.layoutIfNeeded() }
        }
        animated ? UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0,
                                  animations: changes) : changes()
    }
}

/// Grey rounded view with a dashed 1.5 pt border (empty photo slots).
final class DashedBorderView: DSView {
    private let dash = CAShapeLayer()

    override func awakeFromNib() {
        super.awakeFromNib()
        dash.strokeColor = UIColor(white: 0.75, alpha: 1).cgColor
        dash.fillColor = UIColor.clear.cgColor
        dash.lineWidth = 1.5
        dash.lineDashPattern = [6, 4]
        layer.addSublayer(dash)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        dash.frame = bounds
        dash.path = UIBezierPath(roundedRect: bounds.insetBy(dx: 0.75, dy: 0.75), cornerRadius: layer.cornerRadius).cgPath
    }
}
