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

    /// Якщо користувач пішов у редагування з детальки (delete object тощо), після `pop` назад на Processing знову показати цю детальку.
    private(set) var pendingInspirationDetailReopen: (model: ImageDetailModel, promptManager: GemeniPromptManager?)?

    func setPendingInspirationDetailReopen(model: ImageDetailModel, promptManager: GemeniPromptManager?) {
        pendingInspirationDetailReopen = (model, promptManager)
    }

    func consumePendingInspirationDetailReopen() -> (model: ImageDetailModel, promptManager: GemeniPromptManager?)? {
        let value = pendingInspirationDetailReopen
        pendingInspirationDetailReopen = nil
        return value
    }

    func clearPendingInspirationDetailReopen() {
        pendingInspirationDetailReopen = nil
    }

    // MARK: - Storyboards
    private let mainStoryboard = UIStoryboard(name: "Main", bundle: .main)

    // MARK: - Bootstrap
    func setupWindow(with windowScene: UIWindowScene) {
        window = UIWindow(windowScene: windowScene)
        configureNavigationBarAppearance()
        
        // ЗМІНА: Завжди починаємо з LaunchViewController
        guard let launchVC = mainStoryboard.instantiateViewController(withIdentifier: "LaunchViewController") as? LaunchViewController else {
            assertionFailure("LaunchViewController not found in Main.storyboard. Did you set Storyboard ID?")
            // Аварійний варіант, якщо щось пішло не так
            proceedToApp()
            return
        }
        
        window?.rootViewController = launchVC
        window?.makeKeyAndVisible()
    }

    // НОВИЙ ПУБЛІЧНИЙ МЕТОД (раніше був setRootViewController)
    // Цей метод викликається з LaunchViewController, коли він завершить роботу
    func proceedToApp() {
        guard let window else { return }
        let didShowOB: Bool? = UserDefaultsManager.shared.getValue(forKey: Constants.Keys.didShowOnboarding)

        if didShowOB == nil {
            // ЗМІНА: анімація ввімкнена для плавного переходу
            setOnboardingAsRoot(in: window, animated: true)
        } else {
            // ЗМІНА: анімація ввімкнена для плавного переходу
            setTabBarAsRoot(in: window, animated: true)
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

    @discardableResult
    func showInspirationDetail(model: ImageDetailModel,
                               promptManager: GemeniPromptManager?,
                               showsRegenerateButton: Bool = true,
                               showsLimitedEditorActions: Bool = false) -> InspirationDetailViewController? {
        let sb = UIStoryboard(name: "Main", bundle: .main)
        guard let vc = sb.instantiateViewController(withIdentifier: "InspirationDetailViewController") as? InspirationDetailViewController else { return nil }

        vc.data = model
        vc.promptManager = promptManager
        vc.showsRegenerateButton = showsRegenerateButton
        vc.showsLimitedEditorActions = showsLimitedEditorActions

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
        return vc
    }

    func settings() {
        let sb = UIStoryboard(name: "Main", bundle: .main)
        guard let vc = sb.instantiateViewController(withIdentifier: "SettingsViewController") as? SettingsViewController else { return }
        push(vc)
    }

    func presentStyle(promptManager: GemeniPromptManager,
                      option: DesignOption,
                      onSelect: @escaping (UnifiedStyle) -> Void,
                      onGenerate: (() -> Void)? = nil) {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "StyleListViewController") as? StyleListViewController else { return }
        vc.promptManager = promptManager
        vc.selectedOption = option
        vc.isPresentedModall = true
        vc.onSelectStyle = onSelect
        vc.onGenerate = onGenerate

        present(vc, mode: .sheet(detents: [.medium(), .large()], grabber: true))
    }

    func presentColor(promptManager: GemeniPromptManager,
                      onSelect: @escaping (ColorType) -> Void,
                      onGenerate: (() -> Void)? = nil) {
        let sb = UIStoryboard(name: "Main", bundle: .main)
        guard let vc = sb.instantiateViewController(withIdentifier: "ColorListViewController") as? ColorListViewController else { return }
        vc.promptManager = promptManager
        vc.isPresentedModall = true
        vc.onSelectColor = onSelect
        vc.onGenerate = onGenerate

        vc.modalPresentationStyle = .pageSheet
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        (UIApplication.getTopViewController() ?? currentNavigationController)?.present(vc, animated: true)
    }

    // MARK: - Photo Tips
    func showPhotoTips(designOption: DesignOption = .interior, presentingViewController: UIViewController? = nil) {
        let sb = UIStoryboard(name: "Main", bundle: .main)
        guard let vc = sb.instantiateViewController(withIdentifier: "PhotoTipsViewController") as? PhotoTipsViewController else { return }
        vc.designOption = designOption
        vc.modalPresentationStyle = .pageSheet
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        let presenter = presentingViewController ?? UIApplication.getTopViewController() ?? currentNavigationController
        presenter?.present(vc, animated: true)
    }
    
    func showPrompt(promptManager: GemeniPromptManager, showSuggestions: Bool = true, initialPrompt: String? = nil, onSelect: @escaping (String) -> Void) {
        let sb = UIStoryboard(name: "Main", bundle: .main)
        guard let vc = sb.instantiateViewController(withIdentifier: "PromptViewController") as? PromptViewController else { return }
        vc.promptManager = promptManager
        vc.showSuggestions = showSuggestions
        vc.initialPrompt = initialPrompt
        vc.onSelectPrompt = onSelect
        present(vc, mode: .sheet(detents: [.medium(), .large()], grabber: true))
    }

    func showPageViewController(option: DesignOption) {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        let vc = storyboard.instantiateViewController(withIdentifier: "PageViewController") as! PageViewController
        vc.selectedOption = option
        push(vc)
    }

    func showProcessing(manager: GemeniPromptManager) {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        guard let processingVC = storyboard.instantiateViewController(withIdentifier: "ProcessingViewController") as? ProcessingViewController else {
            return
        }
        processingVC.promptManager = manager
        NavigationManager.shared.push(processingVC)
    }

    func showAddPhoto(type: ReferenceScreenType = .currentRoom, designOption: DesignOption? = nil) {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "AddPhotoViewController") as? AddPhotoViewController else {
            return
        }
        vc.referenceType = type
        if let option = designOption {
            let manager = GemeniPromptManager()
            manager.updateOption(option)
            vc.promptManager = manager
        }
        push(vc)
    }
    
    func showReplaceObjectPage(initialImage: UIImage? = nil,
                               promptManager: GemeniPromptManager? = nil,
                               flowMode: ReplaceObjectPageViewController.FlowMode = .replace) {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "ReplaceObjectPageViewController") as? ReplaceObjectPageViewController else {
            return
        }
        vc.flowMode = flowMode
        
        // Якщо передано initialImage, встановлюємо його в promptManager
        if let image = initialImage, let manager = promptManager {
                manager.updateBaseImage(image)
            vc.promptManager = manager
        } else if let manager = promptManager {
            vc.promptManager = manager
        }
        
        push(vc)
    }
    
    func showObjectSelection(promptManager: GemeniPromptManager? = nil,
                             showsGenerateButton: Bool = true,
                             requiresPromptInput: Bool = true,
                             replacementDescription: String? = nil) {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "ObjectSelectionViewController") as? ObjectSelectionViewController else {
            return
        }
        
        if let promptManager {
            vc.promptManager = promptManager
        }
        vc.showsGenerateButton = showsGenerateButton
        vc.requiresPromptInput = requiresPromptInput
        vc.replacementDescription = replacementDescription
        push(vc)
    }

    func showSurfaceMaterialPicker(promptManager: GemeniPromptManager) {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "SurfaceMaterialPickerViewController") as? SurfaceMaterialPickerViewController else {
            return
        }
        vc.promptManager = promptManager
        push(vc)
    }
    
    // Створює тестове зображення, якщо немає в Assets
    private func createTestImage() -> UIImage? {
        let size = CGSize(width: 800, height: 600)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let cgContext = context.cgContext
            
            // Фон (інтер'єр)
            UIColor.systemBrown.withAlphaComponent(0.5).setFill()
            cgContext.fill(CGRect(origin: .zero, size: size))
            
            // Стіна
            UIColor.systemGray5.setFill()
            cgContext.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.7))
            
            // Підлога
            UIColor.systemGray3.setFill()
            cgContext.fill(CGRect(x: 0, y: size.height * 0.7, width: size.width, height: size.height * 0.3))
            
            // Об'єкт 1: Стіл (прямокутник)
            UIColor.systemBrown.setFill()
            let tableRect = CGRect(x: 150, y: 300, width: 300, height: 150)
            cgContext.fill(tableRect)
            
            // Об'єкт 2: Ваза (овал)
            UIColor.systemBlue.setFill()
            let vaseRect = CGRect(x: 500, y: 250, width: 100, height: 200)
            cgContext.fillEllipse(in: vaseRect)
            
            // Об'єкт 3: Картина на стіні (прямокутник)
            UIColor.systemPurple.setFill()
            let pictureRect = CGRect(x: 300, y: 100, width: 200, height: 150)
            cgContext.fill(pictureRect)
            
            // Об'єкт 4: Крісло (прямокутник)
            UIColor.systemOrange.setFill()
            let chairRect = CGRect(x: 50, y: 400, width: 120, height: 150)
            cgContext.fill(chairRect)
        }
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
