import UIKit

/// iPhone Duo unfolded / wide windows: phone-designed screens keep a readable column instead of stretching.
/// Implemented as extra horizontal safe-area insets, so every storyboard layout that pins to the safe area
/// (all of them) centres itself; backgrounds stay full-bleed and `dsLayoutSize` scales to the column.
enum DSWideLayout {
    /// Windows at least this wide get a centred column.
    static let wideWidth: CGFloat = 600
    static let columnWidth: CGFloat = 560

    static func isWide(_ width: CGFloat) -> Bool { width >= wideWidth }

    /// Horizontal inset that centres a reading column in `controller`'s window area (0 on phones).
    /// Unfolded landscape: 560 pt for screens without their own two-pane layout. Unfolded portrait follows
    /// Figma (Duo/P): full width, except screens that ask for a `portraitColumn` (paywall 420 pt).
    static func columnInset(for controller: UIViewController, portraitColumn: CGFloat? = nil) -> CGFloat {
        guard let window = controller.view.window else { return 0 }
        let outer = window.safeAreaInsets
        let available = controller.view.bounds.width - outer.left - outer.right
        guard isWide(available) else { return 0 }
        let portrait = controller.view.bounds.height > controller.view.bounds.width
        guard let column = portrait ? portraitColumn : columnWidth else { return 0 }
        return max(0, floor((available - column) / 2))
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
    func dsApplyWideColumn(fullWidth: Bool = false, portraitColumn: CGFloat? = nil) {
        let inset = fullWidth ? 0 : DSWideLayout.columnInset(for: self, portraitColumn: portraitColumn)
        let target = UIEdgeInsets(top: additionalSafeAreaInsets.top, left: inset,
                                  bottom: additionalSafeAreaInsets.bottom, right: inset)
        if additionalSafeAreaInsets != target { additionalSafeAreaInsets = target }
    }
}

/// Card grids: 2 columns on phones, more when the window is wide.
enum DSGrid {
    static func columns(for width: CGFloat) -> Int {
        // iPhone Duo (Figma: list pane, portrait column and closed screen all show 2 columns at iPhone size).
        if UIDevice.isFoldablePhone { return 2 }
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
    /// Folding presents the open detail full screen instead of pushing it (for details that are modals on phones).
    var collapseByPresenting = false

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
        // Unfolded Duo portrait (Figma Duo/P/08, 10, 11): one full-width column, details push like on iPhone.
        let duoPortrait = UIDevice.isFoldablePhone && host.view.bounds.height > host.view.bounds.width
        let wide = DSWideLayout.isWide(width) && !duoPortrait
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
            let present = collapseByPresenting
            DispatchQueue.main.async { [weak host] in
                if present {
                    detail.modalPresentationStyle = .fullScreen
                    host?.present(detail, animated: false)
                } else {
                    host?.navigationController?.pushViewController(detail, animated: false)
                }
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

extension UIViewController {
    /// iPhone Duo unfolded in landscape: a wide window that is wider than tall (uses the container's window,
    /// which exists before the child gets one).
    var dsWantsWideLandscape: Bool {
        guard let window = navigationController?.view.window ?? view.window else { return false }
        let size = (navigationController?.view ?? view).bounds.size
        return DSWideLayout.isWide(size.width - window.safeAreaInsets.left - window.safeAreaInsets.right)
            && size.width > size.height
    }
}

/// Two storyboard-authored constraint sets (phone 999 / unfolded 1) and the priority swap between them.
final class DSLayoutSwitch {
    private let phone: [NSLayoutConstraint]
    private let unfolded: [NSLayoutConstraint]
    private(set) var isUnfolded = false

    init(phone: [NSLayoutConstraint], unfolded: [NSLayoutConstraint]) {
        self.phone = phone
        self.unfolded = unfolded
    }

    /// Returns true when the arrangement changed.
    @discardableResult
    func set(unfolded on: Bool) -> Bool {
        guard on != isUnfolded else { return false }
        isUnfolded = on
        phone.forEach { $0.priority = UILayoutPriority(on ? 1 : 999) }
        unfolded.forEach { $0.priority = UILayoutPriority(on ? 999 : 1) }
        return true
    }
}

/// Which half of the unfolded Duo a view sits in (the panes split at the hinge, the window's centre).
enum DSPane {
    case left, right

    /// A view narrower than ~¾ of its window belongs to the half holding its centre; a full-width one gets `default`.
    static func of(_ view: UIView?, default fallback: DSPane) -> DSPane {
        guard let view, let window = view.window else { return fallback }
        let frame = view.convert(view.bounds, to: window)
        guard frame.width < window.bounds.width * 0.75 else { return fallback }
        return frame.midX < window.bounds.midX ? .left : .right
    }
}
