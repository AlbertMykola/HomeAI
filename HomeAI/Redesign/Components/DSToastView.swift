import UIKit

/// Top toast (e.g. "Saved to Photos", "You're offline"). Layout: DSToastView.xib.
final class DSToastView: DSNibView {

    @IBOutlet private weak var cardView: DSView!
    @IBOutlet private weak var iconView: UIImageView!
    @IBOutlet private weak var messageLabel: UILabel!

    enum Style {
        case success, info, warning

        var symbol: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .info: return "info.circle.fill"
            case .warning: return "wifi.slash"
            }
        }

        var tint: UIColor {
            switch self {
            case .success: return DS.Color.lime
            case .info, .warning: return .white
            }
        }
    }

    private static weak var current: DSToastView?

    /// Slides in from the top (−40 pt, spring), stays `duration`, slides out.
    static func show(_ message: String, style: Style = .info, symbol: String? = nil,
                     in host: UIView? = nil, duration: TimeInterval = 2.5) {
        guard let host = host ?? UIApplication.getKeyWindow() else { return }
        current?.removeFromSuperview()
        let toast = DSToastView()
        toast.messageLabel.text = message
        toast.iconView.image = UIImage(systemName: symbol ?? style.symbol)
        toast.iconView.tintColor = style.tint
        toast.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.topAnchor.constraint(equalTo: host.safeAreaLayoutGuide.topAnchor, constant: 8),
            toast.leadingAnchor.constraint(equalTo: host.leadingAnchor, constant: 20),
            toast.trailingAnchor.constraint(equalTo: host.trailingAnchor, constant: -20)
        ])
        current = toast
        UIAccessibility.post(notification: .announcement, argument: message)
        host.layoutIfNeeded()
        toast.alpha = 0
        toast.transform = CGAffineTransform(translationX: 0, y: -40)
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0,
                       options: [.allowUserInteraction]) {
            toast.alpha = 1
            toast.transform = .identity
        }
        UIView.animate(withDuration: 0.3, delay: duration, options: [.curveEaseIn]) {
            toast.alpha = 0
            toast.transform = CGAffineTransform(translationX: 0, y: -24)
        } completion: { _ in
            toast.removeFromSuperview()
        }
    }
}
