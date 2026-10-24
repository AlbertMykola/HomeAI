import UIKit

extension UIView {
    /// Use the native horizontal viewport while retaining the reference's full-height scale.
    var dsLayoutSize: CGSize {
        CGSize(width: max(0, bounds.width - safeAreaInsets.left - safeAreaInsets.right), height: bounds.height)
    }
}

/// Scales authored Figma metrics once per window size; UIKit's generated constraints stay untouched.
final class DSReferenceLayout {
    private static let sourceFont = NSAttributedString.Key("RehomelyReferenceFont")
    private static let sourceParagraph = NSAttributedString.Key("RehomelyReferenceParagraph")
    private static let sourceKern = NSAttributedString.Key("RehomelyReferenceKern")
    private final class LabelMetrics {
        let label: UILabel
        let points: CGFloat
        var attributedBase: NSAttributedString?
        var lastAttributed: NSAttributedString?
        init(_ label: UILabel) { self.label = label; points = label.font.pointSize }
    }
    private var fonts: [LabelMetrics] = []
    private var textInputs: [(UIView, CGFloat)] = []
    private var textContainers: [(UITextView, UIEdgeInsets, CGFloat)] = []
    private var constants: [(NSLayoutConstraint, CGFloat)] = []
    private var stacks: [(UIStackView, CGFloat, UIEdgeInsets)] = []
    private var customSpacings: [(UIStackView, UIView, CGFloat)] = []
    private var corners: [(UIView, CGFloat)] = []
    private var flows: [(UICollectionViewFlowLayout, CGSize, CGFloat, CGFloat, UIEdgeInsets)] = []
    private var tables: [(UITableView, CGFloat)] = []
    private(set) var scale: CGFloat = -1

    /// `excluding`: subtrees scaled by a layout of their own.
    init(root: UIView, prefix: String? = nil, excluding: [UIView] = []) {
        func capture(_ view: UIView) {
            if excluding.contains(where: { $0 === view }) { return }
            // Reusable cells own their metrics, independently of their parent's first layout.
            if view !== root && (view is UICollectionViewCell || view is UITableViewCell || view is DSAdaptiveRootView || view is DSToastView) { return }
            // System switches draw themselves; scaling their private layers' corners distorts the pill on iPad.
            if view is UISwitch { return }
            if let label = view as? UILabel { fonts.append(LabelMetrics(label)) }
            if let field = view as? UITextField, let font = field.font { textInputs.append((field, font.pointSize)) }
            if let field = view as? UITextView, let font = field.font { textInputs.append((field, font.pointSize)) }
            if let field = view as? UITextView {
                textContainers.append((field, field.textContainerInset, field.textContainer.lineFragmentPadding))
            }
            constants += view.constraints.filter { constraint in
                if let prefix { return constraint.identifier?.hasPrefix(prefix) == true }
                let identifier = constraint.identifier ?? ""
                // UIKit also creates plain NSLayoutConstraints for safe-area guides.
                // Only explicit storyboard metrics may change with our design scale.
                return identifier.hasPrefix("ds.reference.") || identifier.hasPrefix("storyboardGeometry.")
            }.map { ($0, $0.constant) }
            if prefix == nil, let collection = view as? UICollectionView,
               let flow = collection.collectionViewLayout as? UICollectionViewFlowLayout {
                flows.append((flow, flow.itemSize, flow.minimumLineSpacing, flow.minimumInteritemSpacing, flow.sectionInset))
            }
            if prefix == nil, let table = view as? UITableView, table.rowHeight > 0 {
                tables.append((table, table.rowHeight))
            }
            if let stack = view as? UIStackView {
                stack.insetsLayoutMarginsFromSafeArea = false
                stacks.append((stack, stack.spacing, stack.layoutMargins))
                for child in stack.arrangedSubviews {
                    let spacing = stack.customSpacing(after: child)
                    if spacing >= 0 && spacing < 1_000 { customSpacings.append((stack, child, spacing)) }
                }
            }
            if view.layer.cornerRadius > 0 && !(view === root && view is DSAdaptiveRootView) {
                corners.append((view, view.layer.cornerRadius))
            }
            view.subviews.forEach(capture)
        }
        capture(root)
    }

    @discardableResult func apply(size: CGSize, refreshContent: Bool = false) -> Bool {
        apply(scale: OnboardingLayout(size: size).scale, refreshContent: refreshContent)
    }

    @discardableResult func apply(scale next: CGFloat, refreshContent: Bool = false) -> Bool {
        guard next > 0, refreshContent || abs(next - scale) > 0.001 else { return false }
        scale = next
        for metrics in fonts {
            let label = metrics.label
            if let current = label.attributedText {
                if metrics.lastAttributed?.isEqual(to: current) != true { metrics.attributedBase = current }
            } else {
                metrics.attributedBase = nil
                metrics.lastAttributed = nil
            }
            let points = metrics.points.scaledByHeight(height: 852 * next)
            if abs(label.font.pointSize - points) > 0.001 { label.font = label.font.withSize(points) }
            if let base = metrics.attributedBase {
                let attributed = NSMutableAttributedString(attributedString: base)
                base.enumerateAttributes(in: NSRange(location: 0, length: base.length)) { attributes, range, _ in
                    if let font = (attributes[Self.sourceFont] ?? attributes[.font]) as? UIFont {
                        attributed.addAttribute(Self.sourceFont, value: font, range: range)
                        attributed.addAttribute(.font, value: font.withSize(font.pointSize.scaledByHeight(height: 852 * next)), range: range)
                    }
                    if let paragraph = (attributes[Self.sourceParagraph] ?? attributes[.paragraphStyle]) as? NSParagraphStyle,
                       let scaled = paragraph.mutableCopy() as? NSMutableParagraphStyle {
                        attributed.addAttribute(Self.sourceParagraph, value: paragraph, range: range)
                        scaled.minimumLineHeight *= next; scaled.maximumLineHeight *= next
                        scaled.paragraphSpacing *= next; scaled.lineSpacing *= next
                        attributed.addAttribute(.paragraphStyle, value: scaled, range: range)
                    }
                    if let kern = (attributes[Self.sourceKern] ?? attributes[.kern]) as? NSNumber {
                        attributed.addAttribute(Self.sourceKern, value: kern, range: range)
                        attributed.addAttribute(.kern, value: kern.doubleValue * Double(next), range: range)
                    }
                }
                if label.attributedText?.isEqual(to: attributed) != true { label.attributedText = attributed }
                metrics.lastAttributed = attributed
            }
        }
        textInputs.forEach { view, points in
            let size = points.scaledByHeight(height: 852 * next)
            if let field = view as? UITextField, let font = field.font, abs(font.pointSize - size) > 0.001 { field.font = font.withSize(size) }
            if let field = view as? UITextView, let font = field.font, abs(font.pointSize - size) > 0.001 { field.font = font.withSize(size) }
        }
        textContainers.forEach { field, inset, padding in
            let target = UIEdgeInsets(top: inset.top * next, left: inset.left * next,
                                      bottom: inset.bottom * next, right: inset.right * next)
            if field.textContainerInset != target { field.textContainerInset = target }
            if field.textContainer.lineFragmentPadding != padding * next { field.textContainer.lineFragmentPadding = padding * next }
        }
        constants.forEach { constraint, points in
            let value = points.scaledByHeight(height: 852 * next)
            if abs(constraint.constant - value) > 0.001 { constraint.constant = value }
        }
        stacks.forEach { stack, spacing, margins in
            if abs(stack.spacing - spacing * next) > 0.001 { stack.spacing = spacing * next }
            let target = UIEdgeInsets(top: margins.top * next, left: margins.left * next,
                                      bottom: margins.bottom * next, right: margins.right * next)
            if stack.layoutMargins != target { stack.layoutMargins = target }
        }
        customSpacings.forEach { stack, child, spacing in
            if abs(stack.customSpacing(after: child) - spacing * next) > 0.001 { stack.setCustomSpacing(spacing * next, after: child) }
        }
        flows.forEach { flow, size, line, gap, inset in
            let target = CGSize(width: floor(size.width * next), height: floor(size.height * next))
            if flow.itemSize != target { flow.itemSize = target }
            if flow.minimumLineSpacing != line * next { flow.minimumLineSpacing = line * next }
            if flow.minimumInteritemSpacing != gap * next { flow.minimumInteritemSpacing = gap * next }
            let margins = UIEdgeInsets(top: inset.top * next, left: inset.left * next,
                                       bottom: inset.bottom * next, right: inset.right * next)
            if flow.sectionInset != margins { flow.sectionInset = margins }
        }
        tables.forEach { table, height in
            if table.rowHeight != height * next { table.rowHeight = height * next }
        }
        corners.forEach { view, radius in
            if abs(view.layer.cornerRadius - radius * next) > 0.001 { view.layer.cornerRadius = radius * next }
        }
        return true
    }
}
