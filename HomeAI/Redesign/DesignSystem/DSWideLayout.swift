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

/// Screens that use the full width themselves (multi-column grids, side-by-side layouts).
protocol DSWideLayoutFullWidth: UIViewController {
    var dsUsesFullWidth: Bool { get }
}

extension DSWideLayoutFullWidth {
    var dsUsesFullWidth: Bool { true }
}

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

/// List + detail on wide windows (iPhone Duo unfolded). The host's storyboard scene owns both layouts:
/// `listOnly` constraints (priority 999) pin the list to the safe area, `split` constraints (priority 1) put it
/// next to `pane`. On wide windows the priorities swap and the selected item opens in the pane; when the window
/// narrows again (folding) the open detail moves onto the navigation stack, so nothing is lost.
final class DSSplitPane {
    private weak var host: UIViewController?
    private let pane: UIView
    private let listOnly: [NSLayoutConstraint]
    private let split: [NSLayoutConstraint]
    private(set) var detail: UIViewController?
    private(set) var isSplit = false
    /// Called before a pane detail moves onto the navigation stack (folding), e.g. to show its back button.
    var willCollapse: ((UIViewController) -> Void)?

    init(host: UIViewController, pane: UIView, listOnly: [NSLayoutConstraint], split: [NSLayoutConstraint]) {
        self.host = host
        self.pane = pane
        self.listOnly = listOnly
        self.split = split
    }

    /// Call from the host's `viewWillLayoutSubviews`.
    func update() {
        guard let host, let window = host.view.window else { return }
        let width = host.view.bounds.width - window.safeAreaInsets.left - window.safeAreaInsets.right
        let wide = DSWideLayout.isWide(width)
        guard wide != isSplit else { return }
        isSplit = wide
        let low = UILayoutPriority(1), high = UILayoutPriority(999)
        listOnly.forEach { $0.priority = wide ? low : high }
        split.forEach { $0.priority = wide ? high : low }
        pane.isHidden = !wide
        if !wide, let detail {
            remove(detail)
            self.detail = nil
            willCollapse?(detail)
            DispatchQueue.main.async { [weak host] in
                host?.navigationController?.pushViewController(detail, animated: false)
            }
        }
    }

    /// Shows `controller` in the pane. Returns false on narrow windows (the caller pushes instead).
    @discardableResult
    func show(_ controller: UIViewController) -> Bool {
        guard isSplit, let host else { return false }
        let previous = detail
        host.addChild(controller)
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        controller.view.alpha = 0
        pane.addSubview(controller.view)
        NSLayoutConstraint.activate([
            controller.view.leadingAnchor.constraint(equalTo: pane.leadingAnchor),
            controller.view.trailingAnchor.constraint(equalTo: pane.trailingAnchor),
            controller.view.topAnchor.constraint(equalTo: pane.topAnchor),
            controller.view.bottomAnchor.constraint(equalTo: pane.bottomAnchor)
        ])
        controller.didMove(toParent: host)
        detail = controller
        UIView.animate(withDuration: DS.Motion.reduceMotion ? 0 : 0.25, animations: {
            controller.view.alpha = 1
            previous?.view.alpha = 0
        }, completion: { [weak self] _ in
            if let previous { self?.remove(previous) }
        })
        return true
    }

    func clear() {
        guard let detail else { return }
        remove(detail)
        self.detail = nil
    }

    private func remove(_ controller: UIViewController) {
        controller.willMove(toParent: nil)
        controller.view.removeFromSuperview()
        controller.removeFromParent()
        controller.view.alpha = 1
        controller.view.translatesAutoresizingMaskIntoConstraints = true
    }
}
