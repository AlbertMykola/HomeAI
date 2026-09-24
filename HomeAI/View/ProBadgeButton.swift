import UIKit

enum ProBadgeButton {

    private struct Defaults {
        struct Images {
            static let sparkles = "pw_stars_icon"
        }

        struct Layout {
            static let height: CGFloat = 33
            static let minWidth: CGFloat = 55
        }

        struct Colors {
            static let title = UIColor.black
            static let fallbackBackground = UIColor(red: 204 / 255, green: 204 / 255, blue: 204 / 255, alpha: 0.67)
        }
    }

    static func makeBarButtonItem(target: Any?, action: Selector) -> UIBarButtonItem {
        let button = makeButton(remaining: FreeGenerationManager.shared.remainingFreeGenerations)
        button.addTarget(target, action: action, for: .touchUpInside)

        let item = UIBarButtonItem(customView: button)
        if #available(iOS 26.0, *) {
            item.hidesSharedBackground = true
        }
        return item
    }

    static func refreshBarButtonItem(_ item: UIBarButtonItem?) {
        guard let button = button(from: item) else { return }
        updateRemainingGenerations(on: button, remaining: FreeGenerationManager.shared.remainingFreeGenerations)
    }

    static func button(from item: UIBarButtonItem?) -> LiquidGlassButton? {
        item?.customView as? LiquidGlassButton
    }

    private static func makeButton(remaining: Int) -> LiquidGlassButton {
        let button = LiquidGlassButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: Defaults.Layout.height.scaledByHeight()),
            button.widthAnchor.constraint(greaterThanOrEqualToConstant: Defaults.Layout.minWidth.scaledByWidth())
        ])
        updateRemainingGenerations(on: button, remaining: remaining)
        return button
    }

    private static func updateRemainingGenerations(on button: LiquidGlassButton, remaining: Int) {
        button.applyLiquidGlass(
            LiquidGlassConfig(
                style: .glass,
                mode: .light,
                title: "\(remaining)",
                foregroundColor: Defaults.Colors.title,
                backgroundColor: Defaults.Colors.fallbackBackground,
                contentInsets: NSDirectionalEdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 10),
                font: UIFont.systemFont(ofSize: 15, weight: .regular),
                image: UIImage(named: Defaults.Images.sparkles),
                imagePlacement: .leading,
                imagePadding: 4,
                cornerStyle: .capsule
            )
        )
        button.alpha = 0.8
    }
}

extension UIViewController {

    func configureProGenerationsBarButton() {
        guard !AdaptyService.shared.hasActiveSubscription else {
            navigationItem.rightBarButtonItem = nil
            return
        }
        navigationItem.rightBarButtonItem = ProBadgeButton.makeBarButtonItem(
            target: self,
            action: #selector(handleProGenerationsBarButtonTap)
        )
    }

    func refreshProGenerationsBarButton() {
        guard !AdaptyService.shared.hasActiveSubscription else {
            navigationItem.rightBarButtonItem = nil
            return
        }

        if ProBadgeButton.button(from: navigationItem.rightBarButtonItem) != nil {
            ProBadgeButton.refreshBarButtonItem(navigationItem.rightBarButtonItem)
        } else {
            configureProGenerationsBarButton()
        }
    }

    @objc func handleProGenerationsBarButtonTap() {
        AmplitudeService.shared.logEvent(.pressPro)
        GenerationsLeftAlertView.present(from: self)
    }
}
