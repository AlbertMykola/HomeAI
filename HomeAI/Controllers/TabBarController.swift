import UIKit

final class TabBarController: UITabBarController {

    private var fallbackBackgroundView: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        applyFallbackTabBarBackgroundIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateFallbackBackgroundFrame()
    }

    private func applyFallbackTabBarBackgroundIfNeeded() {
        if #available(iOS 26.0, *) { return }

        // Приберемо стандартну прозорість
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = nil
        appearance.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.22)
            : UIColor.white.withAlphaComponent(0.22)
        }
        let normalColor = UIColor.secondaryLabel
        let selectedColor = UIColor.label
        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        appearance.inlineLayoutAppearance = appearance.stackedLayoutAppearance
        appearance.compactInlineLayoutAppearance = appearance.stackedLayoutAppearance
        tabBar.standardAppearance = appearance
        
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        tabBar.tintColor = selectedColor
        tabBar.unselectedItemTintColor = normalColor

        // Створюємо кастомний blur + tint
        let blur = UIBlurEffect(style: .systemMaterial)
        let blurView = UIVisualEffectView(effect: blur)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.isUserInteractionEnabled = false

        let tintView = UIView()
        tintView.translatesAutoresizingMaskIntoConstraints = false
        let tint = UIColor { trait in
            trait.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.22)
            : UIColor.white.withAlphaComponent(0.22)
        }
        tintView.backgroundColor = tint
        tintView.isUserInteractionEnabled = false
        blurView.contentView.addSubview(tintView)

        blurView.contentView.addSubview(tintView)
        NSLayoutConstraint.activate([
            tintView.topAnchor.constraint(equalTo: blurView.contentView.topAnchor),
            tintView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor),
            tintView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor)
        ])

        tabBar.insertSubview(blurView, at: 0)
        fallbackBackgroundView = blurView
        updateFallbackBackgroundFrame()

        tabBar.layer.masksToBounds = false
        tabBar.layer.shadowColor = UIColor.black.cgColor
        tabBar.layer.shadowOpacity = 0.08
        tabBar.layer.shadowRadius = 10
        tabBar.layer.shadowOffset = CGSize(width: 0, height: -2)
    }

    private func updateFallbackBackgroundFrame() {
        guard let bg = fallbackBackgroundView else { return }
        let barFrame = tabBar.frame
        bg.frame = CGRect(x: barFrame.minX,
                          y: barFrame.minY - 6,
                          width: barFrame.width,
                          height: barFrame.height + 12)
    }
}
