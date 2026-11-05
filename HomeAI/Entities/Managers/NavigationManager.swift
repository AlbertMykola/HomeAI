import UIKit

final class PortraitNavigationController: UINavigationController {

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        UIDevice.portraitLockedInterfaceOrientations
    }

    override var shouldAutorotate: Bool {
        !UIDevice.isPortraitLocked
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        dsApplyWideColumn(fullWidth: (topViewController as? DSWideLayoutFullWidth)?.dsUsesFullWidth == true)
    }
}

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

    /// Onboarding is done and the tab bar is the root (App Intents wait for this).
    var isMainUIReady: Bool { window?.rootViewController is TabBarController }
    private var pendingPremiumPurchaseCompletion: (() -> Void)?
    private var pendingLocalPushOpen = false

    var isShowingMainApp: Bool {
        window?.rootViewController is UITabBarController
    }

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
        #if DEBUG
        if AppQA.enabled {
            window?.overrideUserInterfaceStyle = ProcessInfo.processInfo.arguments.contains("--qa-dark") ? .dark : .light
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
                window?.rootViewController = UIViewController()
            } else {
                window?.rootViewController = AppQA.root()
            }
            window?.makeKeyAndVisible()
            return
        }
        #endif
        // Redesign A is light-only.
        AppearanceMode.apply(to: window, animated: false)
        NetworkMonitor.shared.start()
        configureNavigationBarAppearance()
        
        let launchVC = AppStoryboard.instantiate(LaunchViewController.self)
        
        window?.rootViewController = launchVC
        window?.makeKeyAndVisible()
    }

    // НОВИЙ ПУБЛІЧНИЙ МЕТОД (раніше був setRootViewController)
    // Цей метод викликається з LaunchViewController, коли він завершить роботу
    func proceedToApp() {
        guard let window else { return }
        let didShowOB: Bool? = UserDefaultsManager.shared.getValue(forKey: Constants.Keys.didShowOnboarding)
        let openedFromLocalPush = pendingLocalPushOpen
        pendingLocalPushOpen = false

        if didShowOB != true || Constants.Debug.alwaysShowOnboarding {
            showFirstLaunchOnboarding(in: window)
        } else {
            // O4 personalizes its first Home session; subsequent cold launches start with Interior.
            UserDefaults.standard.set(HomeFocus.interior.rawValue, forKey: HomeFocus.defaultsKey)
            setTabBarAsRoot(
                in: window,
                animated: true,
                showsLaunchPaywall: false,
                selectOptionsTab: openedFromLocalPush
            )
            showOpenOffer()
        }
    }

    /// Every app open (launch, back from the background) for non-subscribers past onboarding: the Adapty offer, over
    /// whatever is on top unless something is already presented there.
    func showOpenOffer() {
        #if DEBUG
        if AppQA.enabled { return }
        #endif
        let didShowOB: Bool? = UserDefaultsManager.shared.getValue(forKey: Constants.Keys.didShowOnboarding)
        guard didShowOB == true, let tabBar = window?.rootViewController as? UITabBarController else { return }
        Task { @MainActor in
            // A launch: Adapty's first profile decides whether this user is a subscriber.
            guard !(await AdaptyService.shared.hasActiveSubscriptionWhenReady(timeoutSeconds: 6)) else { return }
            // Let the root cross-dissolve finish so the tab bar is in the window.
            try? await Task.sleep(nanoseconds: 600_000_000)
            await PaywallProvider.shared.showOffer(over: tabBar, source: "app_open")
        }
    }

    // MARK: - Root builders
    private func setTabBarAsRoot(
        in window: UIWindow,
        animated: Bool,
        showsLaunchPaywall: Bool = false,
        selectOptionsTab: Bool = false,
        coveredBy cover: UIViewController? = nil
    ) {
        let tabBarController = AppStoryboard.instantiate(TabBarController.self)
        tabBarController.setViewControllers(makeTabControllers(), animated: false)
        if selectOptionsTab {
            tabBarController.selectedIndex = 0
        }
        let applyRoot = {
            window.rootViewController = tabBarController
            // Already on screen in the same cross-dissolve: Home never shows on its own before the cover.
            if let cover {
                cover.modalPresentationStyle = .overFullScreen
                tabBarController.present(cover, animated: false)
            }
        }
        if animated {
            UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve, animations: applyRoot)
        } else {
            applyRoot()
        }
        window.makeKeyAndVisible()
        MainActor.assumeIsolated { AppIntentRouter.shared.runPendingIfReady() }
        #if DEBUG
        if AppQA.enabled { return }
        #endif
        LocalNotificationService.shared.sync(requestPermissionIfNeeded: false)
        Task { @MainActor [weak tabBarController] in
            let config = await WorkerConfigService.shared.refreshIfNeeded()
            ForceUpdate.presentIfNeeded(config, over: tabBarController)
        }
        #if DEBUG
        // Simulator QA: -openLatestResult jumps straight to the newest project's result screen.
        if ProcessInfo.processInfo.arguments.contains("-openLatestResult"),
           let doc = ProjectStore.shared.allProjects().first?.versions.last {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.showResult(docID: doc.id, image: nil, reveal: false)
            }
        }
        if let i = ProcessInfo.processInfo.arguments.firstIndex(of: "-showState"),
           ProcessInfo.processInfo.arguments.indices.contains(i + 1) {
            let kind: StateScreenViewController.Kind
            switch ProcessInfo.processInfo.arguments[i + 1] {
            case "blocked": kind = .contentBlocked(photo: UIImage(named: "home_hero_before"), policyID: "2C91")
            case "camera": kind = .cameraOff
            default: kind = .offline
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                tabBarController.present(StateScreenViewController.make(kind), animated: true)
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-showProFeature") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                ProFeatureSheetViewController.present(.watermark, from: tabBarController)
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-showWelcomePro") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                tabBarController.present(WelcomeProViewController.make {}, animated: true)
            }
        }
        if ProcessInfo.processInfo.arguments.contains("-openAssistant") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.showAssistant() }
        }
        #endif
        if showsLaunchPaywall {
            scheduleLaunchPaywallIfNeeded()
        }
        scheduleForcedPaywallIfNeeded()
    }

    /// Create · Inspiration · Projects · Profile.
    private func makeTabControllers() -> [UIViewController] {
        let home = AppStoryboard.instantiate(HomeViewController.self)
        let inspiration = AppStoryboard.instantiate(InspirationFeedViewController.self)
        let projects = AppStoryboard.instantiate(ProjectsViewController.self)
        let profile = AppStoryboard.instantiate(ProfileTabViewController.self)
        return [home, inspiration, projects, profile].map { PortraitNavigationController(rootViewController: $0) }
    }

    /// The onboarding set up in Adapty (`AdaptyOnboardingProvider`) if there is one, otherwise ours. The launch
    /// screen stays up while Adapty answers (at most a few seconds).
    private func showFirstLaunchOnboarding(in window: UIWindow) {
        Task { @MainActor [weak self] in
            let provider = AdaptyOnboardingProvider.shared
            let remote = await provider.makeOnboarding(onFinish: { [weak self] showPaywall in
                Task { @MainActor in
                    await OBPageViewController.requestTrackingIfNeeded()
                    if showPaywall {
                        self?.completeOnboardingWithPaywall(placement: Constants.Keys.obPlacement)
                    } else {
                        // The flow ended (its paywall closed or bought): the offer for those who didn't buy.
                        self?.completeOnboarding()
                        self?.showOpenOffer()
                    }
                }
            }, onFallback: { [weak self] in
                self?.setOnboardingAsRoot(in: window, animated: true)
            })
            guard let self else { return }
            guard let remote else { return self.setOnboardingAsRoot(in: window, animated: true) }
            let applyRoot = { window.rootViewController = remote }
            UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve, animations: applyRoot)
            window.makeKeyAndVisible()
        }
    }

    private func setOnboardingAsRoot(in window: UIWindow, animated: Bool) {
        let ob = AppStoryboard.instantiate(OBPageViewController.self)
        // Not redesigned yet → keep it light even when the app follows a dark system appearance.
        ob.overrideUserInterfaceStyle = .light
        let applyRoot = { window.rootViewController = ob }
        if animated {
            UIView.transition(with: window, duration: 0.35, options: .transitionCrossDissolve, animations: applyRoot)
        } else {
            applyRoot()
        }
        window.makeKeyAndVisible()
    }

    func handleLocalPushOpen() {
        if isShowingMainApp {
            selectOptionsTab()
            return
        }
        pendingLocalPushOpen = true
    }

    func completeOnboarding() {
        UserDefaultsManager.shared.saveValue(true, forKey: Constants.Keys.didShowOnboarding)
        if let window { setTabBarAsRoot(in: window, animated: true) }
    }

    /// Onboarding → paywall straight away (it loads its products itself); Home is set up underneath it.
    /// Returns the paywall, or nil when the cached profile already has Pro.
    @discardableResult
    func completeOnboardingWithPaywall(placement: String) -> UIViewController? {
        UserDefaultsManager.shared.saveValue(true, forKey: Constants.Keys.didShowOnboarding)
        guard let window else { return nil }
        guard !AdaptyService.shared.hasActiveSubscription else {
            setTabBarAsRoot(in: window, animated: true)
            return nil
        }
        let paywall = MainActor.assumeIsolated {
            PaywallProvider.shared.makePaywall(placement: placement, source: placement, onPurchase: nil)
        }
        setTabBarAsRoot(in: window, animated: true, coveredBy: paywall)
        return paywall
    }

    private func selectOptionsTab() {
        guard let tab = window?.rootViewController as? UITabBarController else { return }
        tab.selectedIndex = 0
        (tab.selectedViewController as? UINavigationController)?.popToRootViewController(animated: false)
    }

    private func configureNavigationBarAppearance() {
        let titleAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.label]
        let largeTitleAttributes: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.label]

        // Різні appearance: один і той самий об'єкт на standard + scrollEdge ламає collapse large title.
        let standard = UINavigationBarAppearance()
        standard.configureWithTransparentBackground()
        standard.shadowColor = .clear
        standard.titleTextAttributes = titleAttributes

        let scrollEdge = UINavigationBarAppearance()
        scrollEdge.configureWithTransparentBackground()
        scrollEdge.shadowColor = .clear
        scrollEdge.titleTextAttributes = titleAttributes
        scrollEdge.largeTitleTextAttributes = largeTitleAttributes

        let navProxy = UINavigationBar.appearance()
        navProxy.standardAppearance = standard
        navProxy.scrollEdgeAppearance = scrollEdge
        navProxy.compactAppearance = standard
        if #available(iOS 15.0, *) {
            navProxy.compactScrollEdgeAppearance = scrollEdge
        }
        navProxy.tintColor = .label
        navProxy.isTranslucent = true
    }

    /// Debug: paywall після TabBar лише без підписки.
    private func scheduleForcedPaywallIfNeeded() {
        guard Constants.Debug.alwaysShowPaywallOnLaunch else { return }
        guard !AdaptyService.shared.hasActiveSubscription else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.showPremium(placement: Constants.Keys.optionPlacememt, origin: .inApp)
        }
    }

    /// Returning users: після launch screen відкриваємо TabBar і одразу показуємо окремий paywall.
    private func scheduleLaunchPaywallIfNeeded() {
        guard !AdaptyService.shared.hasActiveSubscription, !Constants.Debug.skipLaunchPaywall else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.showPremium(placement: Constants.Keys.appLaunchPlacement, origin: .inApp)
        }
    }

    // MARK: - Premium (Paywall)

    func showPremium(placement: String, origin: PaywallOrigin, onPurchase: (() -> Void)? = nil) {
        guard !AdaptyService.shared.hasActiveSubscription else { return }
        // A/02: everything in the app uses the redesigned paywall; onboarding keeps the old one for now.
        if origin == .inApp {
            let paywall = MainActor.assumeIsolated {
                PaywallProvider.shared.makePaywall(placement: placement, source: placement, onPurchase: onPurchase)
            }
            present(paywall, mode: .overFull)
            return
        }
        let vc = AppStoryboard.instantiate(PaywallViewController.self)
        pendingPremiumPurchaseCompletion = onPurchase
        vc.onSuccessfulPurchase = { [weak self] in
            guard let self else { return }
            let completion = self.pendingPremiumPurchaseCompletion
            self.pendingPremiumPurchaseCompletion = nil
            completion?()
        }
        vc.placement = placement
        vc.origin = origin
        // Old paywall isn't redesigned yet → always light.
        vc.overrideUserInterfaceStyle = .light
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
    
    func showPrompt(
        promptManager: GemeniPromptManager,
        showSuggestions: Bool = true,
        initialPrompt: String? = nil,
        onSelect: @escaping (String) -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        let sb = UIStoryboard(name: "Main", bundle: .main)
        guard let vc = sb.instantiateViewController(withIdentifier: "PromptViewController") as? PromptViewController else { return }
        vc.promptManager = promptManager
        vc.showSuggestions = showSuggestions
        vc.initialPrompt = initialPrompt
        vc.onSelectPrompt = onSelect
        vc.onCancelPrompt = onCancel
        present(vc, mode: .sheet(detents: [.medium(), .large()], grabber: true))
    }

    func showPageViewController(option: DesignOption) {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "PageViewController") as? PageViewController else {
            return
        }
        vc.selectedOption = option
        push(vc)
    }

    /// Starts a design flow for an option (Home, Projects, etc.).
    func startDesign(option: DesignOption, configure: ((WizardSession) -> Void)? = nil) {
        let session = WizardSession(option: option)
        configure?(session)
        push(WizardPhotoViewController.make(session: session))
    }

    /// A/09 AI designer (Home → "Ask AI designer").
    /// Pro-only: non-Pro users get the paywall; its close button leaves them where they were.
    func showAssistant() {
        guard !AssistantStore.requiresProForChat || AdaptyService.shared.hasActiveSubscription else {
            AmplitudeService.shared.logRedesignEvent("assistant_paywall", properties: [:])
            showPremium(placement: Constants.Keys.optionPlacememt, origin: .inApp) { [weak self] in
                self?.push(AssistantViewController.make())
            }
            return
        }
        push(AssistantViewController.make())
    }

    /// Switches the root tab (e.g. "View" in the Saved to Ideas toast).
    func selectTab(_ tab: TabBarController.Tab) {
        (window?.rootViewController as? TabBarController)?.select(tab)
    }

    func pushWizardStep(_ vc: UIViewController) {
        push(vc)
    }

    /// A/05 Generation (full screen, can be collapsed while it keeps running).
    func showGeneration(manager: GemeniPromptManager, sourcePhoto: UIImage?, styleTitle: String? = nil,
                        onChangePhoto: (() -> Void)? = nil, onEditRequest: (() -> Void)? = nil) {
        let runner = GenerationRunner(promptManager: manager)
        let vc = AppStoryboard.instantiate(GenerationViewController.self)
        vc.runner = runner
        vc.sourcePhoto = sourcePhoto ?? manager.baseImage
        vc.styleTitle = styleTitle
        vc.onChangePhoto = onChangePhoto
        vc.onEditRequest = onEditRequest
        present(vc, mode: .full) { runner.start() }
    }

    /// A/06 · R1 Result for a saved version (doc id).
    func showResult(docID: String, image: UIImage?, reveal: Bool) {
        let vc = AppStoryboard.instantiate(ResultViewController.self)
        vc.docID = docID
        vc.initialImage = image
        vc.reveal = reveal
        push(vc)
    }

    func showFeaturesViewController() {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "FeaturesViewController") as? FeaturesViewController else { return }
        push(vc)
    }

    /// Legacy entry (Options) → the new A/09 AI designer, same Pro gate.
    func showAssistantList() {
        showAssistant()
    }

    func showChat(assistantType: AssistantType, initialMessage: String? = nil) {
        let storyboard = UIStoryboard(name: "Main", bundle: .main)
        guard let vc = storyboard.instantiateViewController(withIdentifier: "ChatViewController") as? ChatViewController else { return }
        vc.assistantType    = assistantType
        vc.initialMessage   = initialMessage
        push(vc)
    }

    func showProcessing(manager: GemeniPromptManager) {
        // App Review 5.1.2(i): explicit consent before the photo goes to the third-party AI (legacy flows too).
        if !AIPhotoConsent.hasConsent, let anchor = presentationAnchor() {
            AIPhotoConsent.run(from: anchor) { [weak self] in self?.showProcessing(manager: manager) }
            return
        }
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

        let nav = PortraitNavigationController(rootViewController: selected)
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

        guard let anchor = presentationAnchor() else {
            retryPresent(vc, mode: mode, animated: animated, completion: completion)
            return
        }
        if mode == .overContext {
            anchor.definesPresentationContext = true
        }
        anchor.presentSafely(vc, animated: animated, completion: completion)
    }

    private func retryPresent(_ vc: UIViewController, mode: ModalMode, animated: Bool, completion: (() -> Void)?, attempt: Int = 0) {
        guard attempt < 3 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            guard let anchor = self.presentationAnchor() else {
                self.retryPresent(vc, mode: mode, animated: animated, completion: completion, attempt: attempt + 1)
                return
            }
            if mode == .overContext {
                anchor.definesPresentationContext = true
            }
            anchor.presentSafely(vc, animated: animated, completion: completion)
        }
    }

    private func presentationAnchor() -> UIViewController? {
        if let top = UIApplication.getTopViewController(), top.canPresentModal {
            return top
        }

        if let root = getRootViewController() {
            if root.canPresentModal { return root }
            if let tab = root as? UITabBarController {
                if tab.canPresentModal { return tab }
                if let selected = tab.selectedViewController, selected.canPresentModal {
                    return selected
                }
            }
        }

        if let nav = currentNavigationController, nav.canPresentModal {
            return nav
        }

        return nil
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
            return getTopViewController(base: nav.topViewController ?? nav.visibleViewController)
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
