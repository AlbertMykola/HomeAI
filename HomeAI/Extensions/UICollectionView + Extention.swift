import UIKit

extension UICollectionView {

    enum PageFlowBottomInset {
        static let `default`: CGFloat = 20
        static let overlayButtonBottomOffset: CGFloat = 20
        static let overlayButtonHeight: CGFloat = 54
        static let spacingAboveOverlayButton: CGFloat = 10
    }

    func applyPageFlowBottomInset(in hostView: UIView, overlayButton: UIButton? = nil) {
        let bottomInset: CGFloat
        if let overlayButton, !overlayButton.isHidden {
            bottomInset = hostView.safeAreaInsets.bottom
                + PageFlowBottomInset.overlayButtonBottomOffset
                + PageFlowBottomInset.overlayButtonHeight
                + PageFlowBottomInset.spacingAboveOverlayButton
        } else {
            bottomInset = PageFlowBottomInset.default
        }

        guard abs(contentInset.bottom - bottomInset) > 0.5 else { return }
        var inset = contentInset
        inset.bottom = bottomInset
        contentInset = inset
        verticalScrollIndicatorInsets.bottom = bottomInset
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
