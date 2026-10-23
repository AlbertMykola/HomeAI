import UIKit

/// Native UIKit tabs: Create · Inspiration · Projects · Profile.
/// The tab controller and each tab item are authored in storyboards.
final class TabBarController: UITabBarController {

    enum Tab: Int, CaseIterable {
        case create, inspiration, projects, profile

        var title: String {
            switch self {
            case .create: return "Create".localized
            case .inspiration: return "Inspiration".localized
            case .projects: return "Projects".localized
            case .profile: return "Profile".localized
            }
        }
    }

    private var isSelectingProjects = false

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.portraitLockedInterfaceOrientations
    }

    override var shouldAutorotate: Bool {
        !UIDevice.isPortraitLocked
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.tintColor = DS.Color.link
        delegate = self
        configureTabItems(viewControllers)
    }

    override var selectedIndex: Int {
        didSet {
            if isViewLoaded { updateTabBarVisibility(animated: false) }
        }
    }

    override func setViewControllers(_ viewControllers: [UIViewController]?, animated: Bool) {
        configureTabItems(viewControllers)
        super.setViewControllers(viewControllers, animated: animated)
    }

    private func configureTabItems(_ controllers: [UIViewController]?) {
        for (index, controller) in (controllers ?? []).enumerated() {
            guard let tab = Tab(rawValue: index) else { continue }
            let navigation = controller as? UINavigationController
            navigation?.delegate = self
            let root = navigation?.viewControllers.first ?? controller
            let item = root.tabBarItem!
            item.title = tab.title
            item.accessibilityIdentifier = "tab.\(tab)"
            controller.tabBarItem = item
        }
    }

    func select(_ tab: Tab) {
        guard let controllers = viewControllers, controllers.indices.contains(tab.rawValue) else { return }
        (controllers[tab.rawValue] as? UINavigationController)?.popToRootViewController(animated: false)
        selectedIndex = tab.rawValue
    }

    /// Projects temporarily replaces navigation with its selection actions.
    func setTabBarHiddenForSelection(_ hidden: Bool, animated: Bool) {
        isSelectingProjects = hidden
        updateTabBarVisibility(animated: animated)
    }

    private func updateTabBarVisibility(animated: Bool) {
        let navigation = selectedViewController as? UINavigationController
        let pushed = (navigation?.viewControllers.count ?? 1) > 1
        setNativeTabBarHidden(isSelectingProjects || pushed, animated: animated)
    }

    private func setNativeTabBarHidden(_ hidden: Bool, animated: Bool) {
        if #available(iOS 18.0, *) {
            guard isTabBarHidden != hidden else { return }
            setTabBarHidden(hidden, animated: animated)
        } else {
            guard tabBar.isHidden != hidden else { return }
            tabBar.isHidden = hidden
            view.setNeedsLayout()
        }
    }
}

extension TabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        updateTabBarVisibility(animated: false)
    }
}

extension TabBarController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        guard navigationController === selectedViewController else { return }
        let isRoot = navigationController.viewControllers.first === viewController
        setNativeTabBarHidden(isSelectingProjects || !isRoot, animated: animated)
        navigationController.transitionCoordinator?.notifyWhenInteractionChanges { [weak self] context in
            if context.isCancelled { self?.updateTabBarVisibility(animated: animated) }
        }
    }
}
