import UIKit

/// iPhone Duo unfolded / wide windows: phone-designed screens keep a readable column instead of stretching.
/// Implemented as extra horizontal safe-area insets, so every storyboard layout that pins to the safe area
/// (all of them) centres itself; backgrounds stay full-bleed and `dsLayoutSize` scales to the column.
enum DSWideLayout {
    /// Windows at least this wide get a centred column.
    static let wideWidth: CGFloat = 600
    static let columnWidth: CGFloat = 560

    static func isWide(_ width: CGFloat) -> Bool { width >= wideWidth }

    /// Horizontal inset that centres a `columnWidth` column in `controller`'s window area (0 on phones).
    static func columnInset(for controller: UIViewController) -> CGFloat {
        guard let window = controller.view.window else { return 0 }
        let outer = window.safeAreaInsets
        let available = controller.view.bounds.width - outer.left - outer.right
        guard isWide(available) else { return 0 }
        return floor((available - columnWidth) / 2)
    }
}

/// Screens that use the full width themselves (multi-column grids).
protocol DSWideLayoutFullWidth: UIViewController {}

extension UIViewController {
    /// Call from `viewWillLayoutSubviews` of a container or full-screen controller.
    func dsApplyWideColumn(fullWidth: Bool = false) {
        let inset = fullWidth ? 0 : DSWideLayout.columnInset(for: self)
        let target = UIEdgeInsets(top: additionalSafeAreaInsets.top, left: inset,
                                  bottom: additionalSafeAreaInsets.bottom, right: inset)
        if additionalSafeAreaInsets != target { additionalSafeAreaInsets = target }
    }
}

/// Card grids: 2 columns on phones, more when the window is wide.
enum DSGrid {
    static func columns(for width: CGFloat) -> Int {
        if width >= 900 { return 4 }
        if width >= 560 { return 3 }
        return 2
    }
}
