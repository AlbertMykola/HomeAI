import UIKit

/// Storyboard roots opt into height-based metrics while retaining their authored Auto Layout hierarchy.
/// Controllers with an explicit reference layout keep that layout instead of applying two scales.
class DSAdaptiveRootView: UIView {
    private var metrics: DSReferenceLayout?

    /// Set by a presentation that sizes this root as an iPhone screen of its own (sheets in a Duo pane).
    var referenceSizeOverride: CGSize?

    var referenceSize: CGSize {
        referenceSizeOverride ?? CGSize(width: dsLayoutSize.width, height: window?.bounds.height ?? bounds.height)
    }

    func prepareMetrics() {
        if metrics == nil { metrics = DSReferenceLayout(root: self) }
    }

    func applyMetrics(size: CGSize? = nil) {
        prepareMetrics()
        metrics?.apply(size: size ?? referenceSize)
    }

    override func layoutSubviews() {
        applyMetrics()
        super.layoutSubviews()
    }
}

/// Measures after its own final bounds arrive, including fonts scaled by a parent root.
/// The minimum-height constraint stays authored in the storyboard.
final class DSMeasuredLabel: DSLabel {
    override func layoutSubviews() {
        super.layoutSubviews()
        guard numberOfLines == 0, bounds.width > 0, let font,
              let minimum = constraints.first(where: { $0.identifier == "ds.textHeight" }) else { return }
        let width = max(1, floor(bounds.width) - 1)
        let string = (text ?? "") as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let measured = string.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                                            attributes: attributes, context: nil).height
        let lines = ceil(string.size(withAttributes: attributes).width / width)
        let fitted = sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        let height = ceil(max(measured, lines * font.lineHeight, fitted))
        if abs(minimum.constant - height) > 0.1 { minimum.constant = height }
    }
}

class DSAdaptiveCollectionViewCell: UICollectionViewCell {
    private var metrics: DSReferenceLayout?

    override func awakeFromNib() {
        super.awakeFromNib()
        metrics = DSReferenceLayout(root: contentView)
    }

    override func layoutSubviews() {
        metrics?.apply(size: dsAdaptiveReferenceSize, refreshContent: true)
        super.layoutSubviews()
    }
}

class DSAdaptiveTableViewCell: UITableViewCell {
    private var metrics: DSReferenceLayout?

    override func awakeFromNib() {
        super.awakeFromNib()
        metrics = DSReferenceLayout(root: contentView)
    }

    override func layoutSubviews() {
        metrics?.apply(size: dsAdaptiveReferenceSize, refreshContent: true)
        updateAdaptiveContent(using: OnboardingLayout(size: dsAdaptiveReferenceSize))
        super.layoutSubviews()
    }

    func updateAdaptiveContent(using metrics: OnboardingLayout) {}

    override func systemLayoutSizeFitting(_ targetSize: CGSize,
                                         withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
                                         verticalFittingPriority: UILayoutPriority) -> CGSize {
        metrics?.apply(size: dsAdaptiveReferenceSize, refreshContent: true)
        updateAdaptiveContent(using: OnboardingLayout(size: dsAdaptiveReferenceSize))
        return super.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: horizontalFittingPriority,
                                             verticalFittingPriority: verticalFittingPriority)
    }
}

extension UIView {
    var dsAdaptiveReferenceSize: CGSize {
        if let root = self as? DSAdaptiveRootView { return root.referenceSize }
        var ancestor = superview
        while let view = ancestor {
            if let root = view as? DSAdaptiveRootView { return root.referenceSize }
            ancestor = view.superview
        }
        return window?.dsLayoutSize ?? UIScreen.main.bounds.size
    }
}
