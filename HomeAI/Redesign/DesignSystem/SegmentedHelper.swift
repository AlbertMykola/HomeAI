import UIKit

extension UIViewController {
    /// Moves the white knob of a XIB segmented control (knob + equal segments) and restyles the labels.
    func applySegment(index: Int, labels: [UILabel], knobLeading: NSLayoutConstraint, container: UIView,
                      count: Int, animated: Bool) {
        let width = (container.bounds.width - 6) / CGFloat(count)
        let changes = {
            knobLeading.constant = 3 + width * CGFloat(index)
            for (i, l) in labels.sorted(by: { $0.tag < $1.tag }).enumerated() {
                l.font = DS.Font.geologica(i == index ? .semiBold : .medium, 14)
                l.textColor = i == index ? DS.Color.textPrimary : DS.Color.textSecondary
            }
            container.layoutIfNeeded()
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
