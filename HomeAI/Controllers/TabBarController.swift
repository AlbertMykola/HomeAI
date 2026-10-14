import UIKit

/// Root tabs: Create · Inspiration · Projects · Profile.
/// The system tab bar is hidden; `DSTabBarView` (XIB) floats above content and hides on push.
final class TabBarController: UITabBarController {

    enum Tab: Int { case create, inspiration, projects, profile }

    private let floatingBar = DSTabBarView()
    private var barBottom: NSLayoutConstraint?
    private var isBarHidden = false
    private var didRunEntrance = false

    /// Height of the floating bar + gap; root controllers get it as extra bottom safe area.
    static let floatingInset: CGFloat = 64 + 8

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.portraitLockedInterfaceOrientations
    }

    override var shouldAutorotate: Bool {
        !UIDevice.isPadPortraitLocked
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tabBar.isHidden = true
        delegate = self
        installFloatingBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didRunEntrance else { return }
        didRunEntrance = true
        floatingBar.animateEntrance(delay: 0.25)
    }

    override var selectedIndex: Int {
        didSet { floatingBar.setSelected(selectedIndex, animated: false) }
    }

    override func setViewControllers(_ viewControllers: [UIViewController]?, animated: Bool) {
        super.setViewControllers(viewControllers, animated: animated)
        viewControllers?.forEach { vc in
            let nav = vc as? UINavigationController
            nav?.delegate = self
            (nav?.viewControllers.first ?? vc).additionalSafeAreaInsets.bottom = Self.floatingInset
        }
    }

    func select(_ tab: Tab) {
        selectedIndex = tab.rawValue
        (selectedViewController as? UINavigationController)?.popToRootViewController(animated: false)
    }

    private func installFloatingBar() {
        floatingBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(floatingBar)
        let bottom = floatingBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 0)
        NSLayoutConstraint.activate([
            floatingBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            floatingBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            floatingBar.heightAnchor.constraint(equalToConstant: 64),
            bottom
        ])
        barBottom = bottom
        floatingBar.onSelect = { [weak self] index in
            guard let self else { return }
            if index == self.selectedIndex {
                (self.selectedViewController as? UINavigationController)?.popToRootViewController(animated: true)
                return
            }
            self.selectFromBar(index)
        }
    }

    private func selectFromBar(_ index: Int) {
        super.selectedIndex = index
    }

    func setFloatingBarHidden(_ hidden: Bool, animated: Bool) {
        guard hidden != isBarHidden else { return }
        isBarHidden = hidden
        let changes = {
            self.floatingBar.alpha = hidden ? 0 : 1
            self.floatingBar.transform = hidden ? CGAffineTransform(translationX: 0, y: 40) : .identity
        }
        floatingBar.isUserInteractionEnabled = !hidden
        guard animated else { changes(); return }
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0,
                       options: [.beginFromCurrentState, .allowUserInteraction], animations: changes)
    }
}

extension TabBarController: UITabBarControllerDelegate {}

extension TabBarController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        let isRoot = navigationController.viewControllers.first === viewController
        guard let coordinator = navigationController.transitionCoordinator, animated else {
            setFloatingBarHidden(!isRoot, animated: false)
            return
        }
        coordinator.animate(alongsideTransition: { _ in
            self.setFloatingBarHidden(!isRoot, animated: false)
        }, completion: { context in
            if context.isCancelled {
                let wasRoot = navigationController.viewControllers.count == 1
                self.setFloatingBarHidden(!wasRoot, animated: true)
            }
        })
    }
}
