import UIKit

/// Top toast (e.g. "Saved to Photos", "You're offline"). Layout: DSToastView.xib.
final class DSToastView: DSNibView {

    @IBOutlet private weak var cardView: DSView!
    @IBOutlet private weak var iconView: UIImageView!
    @IBOutlet private weak var messageLabel: UILabel!
    @IBOutlet private weak var actionLabel: UILabel!

    enum Style {
        case success, info, warning, error

        var symbol: String {
            switch self {
            case .success: return "checkmark.circle"
            case .info: return "info.circle"
            case .warning: return "wifi.slash"
            case .error: return "exclamationmark.triangle"
            }
        }

        func tint(light: Bool) -> UIColor {
            switch self {
            case .success, .info: return light ? .black : DS.Color.lime
            case .warning: return light ? .black : .white
            case .error: return UIColor(hex: "FF5A52")
            }
        }
    }

    private static weak var current: DSToastView?
    private var onTap: (() -> Void)?
    private var hideWork: DispatchWorkItem?

    /// A/12 Toasts & banners: one at a time (a new one replaces the old), drops from the top (−60 pt, spring
    /// response 0.4 / damping 0.8) with an icon pop, stays 2.5 s (4 s with an action), leaves ease-in 0.3 s.
    /// Swipe up to dismiss. Dark glass by default; `light` for dark / photo screens.
    static func show(_ message: String, style: Style = .info, symbol: String? = nil, action: String? = nil,
                     in host: UIView? = nil, topOffset: CGFloat = 52, duration: TimeInterval? = nil,
                     light: Bool = false, onTap: (() -> Void)? = nil) {
        guard let host = host ?? UIApplication.getKeyWindow() else { return }
        let light = light || isPhotoScreenOnTop(host.window ?? (host as? UIWindow))
        current?.removeFromSuperview()
        let toast = DSToastView()
        toast.messageLabel.text = message
        toast.actionLabel.text = action
        toast.actionLabel.isHidden = action == nil
        toast.iconView.image = UIImage(systemName: symbol ?? style.symbol)
        toast.iconView.tintColor = style.tint(light: light)
        if light {
            toast.cardView.backgroundColor = UIColor.white.withAlphaComponent(0.96)
            toast.messageLabel.textColor = .black
            toast.actionLabel.textColor = UIColor(hex: "3E7A00")
        }
        toast.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.topAnchor.constraint(equalTo: host.safeAreaLayoutGuide.topAnchor, constant: topOffset),
            toast.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 20),
            toast.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -20)
        ])
        current = toast
        if let onTap {
            toast.onTap = onTap
            toast.addGestureRecognizer(UITapGestureRecognizer(target: toast, action: #selector(didTapToast)))
            toast.accessibilityTraits = .button
        }
        toast.addGestureRecognizer(UIPanGestureRecognizer(target: toast, action: #selector(didPan(_:))))
        switch style {
        case .success: DS.Haptic.success()
        case .error: DS.Haptic.error()
        default: break
        }
        UIAccessibility.post(notification: .announcement, argument: message)
        host.layoutIfNeeded()
        toast.alpha = 0
        toast.transform = CGAffineTransform(translationX: 0, y: -60)
        UIViewPropertyAnimator(duration: 0.4, dampingRatio: 0.8) {
            toast.alpha = 1
            toast.transform = .identity
        }.startAnimation()
        if !DS.Motion.reduceMotion {
            toast.iconView.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
            DS.Motion.animate(0.4, delay: 0.1, timing: DS.Motion.easeOutBack) { toast.iconView.transform = .identity }
        }
        let work = DispatchWorkItem { [weak toast] in toast?.hide() }
        toast.hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (duration ?? (action == nil ? 2.5 : 4)), execute: work)
    }

    private func hide() {
        hideWork?.cancel()
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseIn]) {
            self.alpha = 0
            self.transform = CGAffineTransform(translationX: 0, y: -24)
        } completion: { _ in
            self.removeFromSuperview()
        }
    }

    @objc private func didPan(_ pan: UIPanGestureRecognizer) {
        let dy = min(0, pan.translation(in: self).y)
        switch pan.state {
        case .changed:
            transform = CGAffineTransform(translationX: 0, y: dy)
        case .ended, .cancelled:
            if dy < -20 || pan.velocity(in: self).y < -300 {
                hide()
            } else {
                UIView.animate(withDuration: 0.25) { self.transform = .identity }
            }
        default: break
        }
    }

    @objc private func didTapToast() {
        let action = onTap
        onTap = nil
        hideWork?.cancel()
        UIView.animate(withDuration: 0.2, animations: { self.alpha = 0 }) { _ in self.removeFromSuperview() }
        action?()
    }

    /// Dark photo screens (result, editors, camera, idea detail) get the light toast variant.
    private static func isPhotoScreenOnTop(_ window: UIWindow?) -> Bool {
        var top = window?.rootViewController
        while true {
            if let presented = top?.presentedViewController, !presented.isBeingDismissed { top = presented; continue }
            if let nav = top as? UINavigationController { top = nav.visibleViewController; continue }
            if let tabs = top as? UITabBarController { top = tabs.selectedViewController; continue }
            break
        }
        return top is ResultViewController || top is MaskEditorViewController || top is CameraViewController
            || top is IdeaDetailViewController || top is CompareViewController
    }
}
