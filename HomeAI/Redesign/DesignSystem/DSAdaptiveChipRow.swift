import UIKit

/// Finite chip pairs keep their natural size; long translations stack at compact widths.
final class DSAdaptiveChipRow: UIStackView {
    override func awakeFromNib() {
        super.awakeFromNib()
        insetsLayoutMarginsFromSafeArea = false
        for chip in arrangedSubviews.compactMap({ $0 as? DSChipControl }) {
            (chip.subviews.first as? UIStackView)?.insetsLayoutMarginsFromSafeArea = false
        }
    }

    func fit(in availableWidth: CGFloat) {
        let chips = arrangedSubviews.filter { $0 is DSChipControl }
        if availableWidth > 0, !chips.isEmpty {
            let naturalWidth = chips.reduce(CGFloat.zero) { result, chip in
                guard let row = chip.subviews.first as? UIStackView else { return result }
                let contentWidth = row.arrangedSubviews.reduce(CGFloat.zero) { total, view in
                    if let label = view as? UILabel {
                        return total + label.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                               height: CGFloat.greatestFiniteMagnitude)).width
                    }
                    return total + (view.constraints.first { $0.firstAttribute == .width && $0.secondItem == nil }?.constant ?? view.bounds.width)
                }
                return result + contentWidth + row.layoutMargins.left + row.layoutMargins.right
                    + row.spacing * CGFloat(max(0, row.arrangedSubviews.count - 1))
            } + spacing * CGFloat(arrangedSubviews.count - 1)
            let nextAxis: NSLayoutConstraint.Axis = naturalWidth > availableWidth + 0.5 ? .vertical : .horizontal
            if axis != nextAxis {
                axis = nextAxis
                alignment = nextAxis == .vertical ? .leading : .center
            }
            for spacer in arrangedSubviews where !(spacer is DSChipControl) {
                let hide = nextAxis == .vertical
                if spacer.isHidden != hide { spacer.isHidden = hide }
            }
        }
    }
}
