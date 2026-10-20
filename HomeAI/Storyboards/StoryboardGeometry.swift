import UIKit

/// Geometry for animated illustrations. Every constraint is connected from Interface Builder.
final class StoryboardGeometry {
    private let constraints: [ObjectIdentifier: [String: NSLayoutConstraint]]

    init(constraints: [NSLayoutConstraint]) {
        var grouped: [ObjectIdentifier: [String: NSLayoutConstraint]] = [:]
        for constraint in constraints {
            guard let view = constraint.firstItem as? UIView,
                  let metric = constraint.identifier?.split(separator: ".").last else { continue }
            grouped[ObjectIdentifier(view), default: [:]][String(metric)] = constraint
        }
        self.constraints = grouped
    }

    func setFrame(_ view: UIView, _ frame: CGRect) {
        guard let metrics = constraints[ObjectIdentifier(view)] else {
            preconditionFailure("Missing storyboard geometry for \(view)")
        }
        for (key, value) in [("x", frame.minX), ("y", frame.minY), ("w", frame.width), ("h", frame.height)] {
            if let constraint = metrics[key], abs(constraint.constant - value) > 0.001 {
                constraint.constant = value
            }
        }
    }
}
