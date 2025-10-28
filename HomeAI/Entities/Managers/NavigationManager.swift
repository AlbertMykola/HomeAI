import UIKit

final class NavigationManager {

    enum ModalMode: Equatable {
        case sheet(detents: [UISheetPresentationController.Detent], grabber: Bool)
        case overContext
        case overFull
        case full // новий режим
    }

    static let shared = NavigationManager()
    private init() {}

    // MARK: - State
    private var window: UIWindow?

    // MARK: - Storyboards
    private let mainStoryboard = UIStoryboard(name: "Main", bundle: .main)

    // MARK: - Bootstrap
    func setupWindow(with windowScene: UIWindowScene) {
        window = UIWindow(windowScene: windowScene)
        configureNavigationBarAppearance()
        setRootViewController()
    }

    private func setRootViewController() {
        guard let window else { return }
        let didShowOB: Bool? = UserDefaultsManager.shared.getValue(forKey: Constants.Keys.didShowOnboarding)

        if didShowOB == nil {
            setOnboardingAsRoot(in: window, animated: false)
        } else {
            setTabBarAsRoot(in: window, animated: false)
        }
    }

    // MARK: - Root builders
    private func setTabBarAsRoot(in window: UIWindow, animated: Bool) {
        guard let tabBarController = mainStoryboard.instantiateViewController(withIdentifier: "TabBarController") as? UITabBarController else {
            assertionFailure("TabBarController not found in Main.storyboard")
            return
        }
        tabBarController.viewControllers = (tabBarController.viewControllers ?? []).map { vc in
            guard !(vc is UINavigationController) else { return vc }
            return UINavigationController(rootViewController: vc)
        }
        let applyRoot = { window.rootViewController = tabBarController }
        if animated {
            UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve, animations: applyRoot)
        } else {
            applyRoot()
        }
        window.makeKeyAndVisible()
    }

    private func setOnboardingAsRoot(in window: UIWindow, animated: Bool) {
        guard let ob = mainStoryboard.instantiateViewController(withIdentifier: "OBPageViewController") as? OBPageViewController else {
            assertionFailure("OBPageViewController not found")
            return
        }
        let applyRoot = { window.rootViewController = ob }
        if animated {
            UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve, animations: applyRoot)
        } else {
            applyRoot()
        }
        window.makeKeyAndVisible()
    }

    func completeOnboarding() {
        UserDefaultsManager.shared.saveValue(true, forKey: Constants.Keys.didShowOnboarding)
        if let window { setTabBarAsRoot(in: window, animated: true) }
    }

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]

        let navProxy = UINavigationBar.appearance()
        navProxy.standardAppearance = appearance
        navProxy.scrollEdgeAppearance = appearance
        navProxy.compactAppearance = appearance
        if #available(iOS 15.0, *) {
            navProxy.compactScrollEdgeAppearance = appearance
        }
        navProxy.tintColor = .label
        navProxy.isTranslucent = true
    }

    // MARK: - Premium (Paywall)

    func showPremium(placement: String, origin: PaywallOrigin) {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "PaywallViewController") as? PaywallViewController else { return }
        vc.placement = placement
        vc.origin = origin
        let mode: ModalMode = (origin == .onboarding) ? .full : .overFull
        present(vc, mode: mode)
    }

    // Зручний оверлоад для потоку з застосунку
    func showPremium(placement: String) {
        showPremium(placement: placement, origin: .inApp)
    }

    // MARK: - Derived controllers (інші маршрути лишаємо без змін)

    func showInspirationDetail(model: ImageDetailModel, promptManager: PromptManager?) {
        let sb = UIStoryboard(name: "Main", bundle: .main)
        guard let vc = sb.instantiateViewController(withIdentifier: "InspirationDetailViewController") as? InspirationDetailViewController else { return }

        vc.data = model
        vc.promptManager = promptManager

        vc.onRegenerate = { [weak self] pm in
            if let nav = self?.currentNavigationController,
               let processing = nav.viewControllers.last(where: { $0 is ProcessingViewController }) as? ProcessingViewController {
                processing.promptManager = pm
                processing.startGeneration()
            } else {
                self?.showProcessing(manager: pm)
            }
        }
        present(vc, mode: .overFull)
    }

    func settings() {
        let sb = UIStoryboard(name: "Main", bundle: .main)
        guard let vc = sb.instantiateViewController(withIdentifier: "SettingsViewController") as? SettingsViewController else { return }
        push(vc)
    }

    func presentStyle(promptManager: PromptManager,
                      option: DesignOption,
                      onSelect: @escaping (UnifiedStyle) -> Void) {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "StyleListViewController") as? StyleListViewController else { return }
        vc.promptManager = promptManager
        vc.selectedOption = option
        vc.isPresentedModall = true
        vc.onSelectStyle = onSelect

        present(vc, mode: .sheet(detents: [.medium(), .large()], grabber: true))
    }

    func presentColor(promptManager: PromptManager,
                      onSelect: @escaping (ColorType) -> Void) {
        let sb = UIStoryboard(name: "Main", bundle: .main)
        guard let vc = sb.instantiateViewController(withIdentifier: "ColorListViewController") as? ColorListViewController else { return }
        vc.promptManager = promptManager
        vc.isPresentedModall = true
        vc.onSelectColor = onSelect

        vc.modalPresentationStyle = .pageSheet
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        (UIApplication.getTopViewController() ?? currentNavigationController)?.present(vc, animated: true)
    }

    func showPageViewController(option: DesignOption) {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        let vc = storyboard.instantiateViewController(withIdentifier: "PageViewController") as! PageViewController
        vc.selectedOption = option
        push(vc)
    }

    func showProcessing(manager: PromptManager) {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        guard let processingVC = storyboard.instantiateViewController(withIdentifier: "ProcessingViewController") as? ProcessingViewController else {
            return
        }
        processingVC.promptManager = manager
        NavigationManager.shared.push(processingVC)
    }

    func showAddPhoto(type: ReferenceScreenType = .currentRoom) {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "AddPhotoViewController") as? AddPhotoViewController else {
            return
        }
        vc.referenceType = type
        push(vc)
    }

    // MARK: - Centralized transitions

    private var currentNavigationController: UINavigationController? {
        if let nav = window?.rootViewController as? UINavigationController { return nav }

        if let tab = window?.rootViewController as? UITabBarController {
            if let nav = tab.selectedViewController as? UINavigationController { return nav }
            if let selected = tab.selectedViewController, let nav = selected.navigationController { return nav }
        }

        if let top = UIApplication.getTopViewController() {
            if let nav = top as? UINavigationController { return nav }
            if let nav = top.navigationController { return nav }
        }
        return nil
    }

    @discardableResult
    private func ensureNavOnSelectedTab() -> UINavigationController? {
        guard let tab = window?.rootViewController as? UITabBarController else { return currentNavigationController }
        if let nav = tab.selectedViewController as? UINavigationController { return nav }
        guard let selected = tab.selectedViewController else { return currentNavigationController }

        let nav = UINavigationController(rootViewController: selected)
        var vcs = tab.viewControllers ?? []
        if let idx = vcs.firstIndex(of: selected) {
            vcs[idx] = nav
            tab.viewControllers = vcs
            tab.selectedIndex = idx
        }
        return nav
    }

    private func push(_ vc: UIViewController, animated: Bool = true, hidesTabBar: Bool = true) {
        if hidesTabBar { vc.hidesBottomBarWhenPushed = true }
        let nav = currentNavigationController ?? ensureNavOnSelectedTab()
        nav?.pushViewController(vc, animated: animated)
    }

    private func present(_ vc: UIViewController, mode: ModalMode, animated: Bool = true, completion: (() -> Void)? = nil) {
        switch mode {
        case .sheet(let detents, let grabber):
            vc.modalPresentationStyle = .pageSheet
            if let sheet = vc.sheetPresentationController {
                sheet.detents = detents
                sheet.prefersGrabberVisible = grabber
                sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            } else {
                vc.modalPresentationStyle = .overFullScreen
            }
        case .overContext:
            vc.modalPresentationStyle = .overCurrentContext
        case .overFull:
            vc.modalPresentationStyle = .overFullScreen
        case .full:
            vc.modalPresentationStyle = .fullScreen // для онбордингу
        }

        let anchor = UIApplication.getTopViewController() ?? currentNavigationController
        if mode == .overContext {
            (anchor)?.definesPresentationContext = true
        }
        (anchor)?.present(vc, animated: animated, completion: completion)
    }

    // MARK: - Back & Dismiss

    func navigateBack() {
        if let nav = currentNavigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        } else {
            UIApplication.getTopViewController()?.dismiss(animated: true)
        }
    }

    func dismissAllPresentedControllers() {
        guard let root = getRootViewController() else { return }
        root.dismiss(animated: true)
    }

    private func getRootViewController() -> UIViewController? {
        if let window { return window.rootViewController }
        return UIApplication.getKeyWindow()?.rootViewController
    }

    func popToRoot(animated: Bool = true) {
        guard let nav = currentNavigationController else { return }
        nav.popToRootViewController(animated: animated)
    }
}

// MARK: - UIApplication helpers

extension UIApplication {

    class func getTopViewController(base: UIViewController? = UIApplication.getKeyWindow()?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return getTopViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return getTopViewController(base: selected)
        }
        if let presented = base?.presentedViewController {
            return getTopViewController(base: presented)
        }
        return base
    }

    /// Key window for multi-scene setups
    class func getKeyWindow() -> UIWindow? {
        if #available(iOS 15, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            return UIApplication.shared.keyWindow
        }
    }
}
