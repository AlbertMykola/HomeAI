import UIKit

/// Simulator-only fixtures and diagnostics. Release builds never enable this path.
enum AppQA {
    static var enabled: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--app-qa")
            || ProcessInfo.processInfo.environment["REHOMELY_FULL_QA"] == "1"
        #else
        return false
        #endif
    }

    #if DEBUG
    static var language: String?
    static var premium = false
    static var freeCount = 0
    static var dailyCount = 0
    static var reduceMotion: Bool?
    static var snapshot = false
    static var emptyProjects = false
    static var homeFocus: HomeFocus?
    static var generationService: any ImageGenerationService = QAGenerationService()
    static var localizationBundle: Bundle? {
        guard enabled, let language, let path = Bundle.main.path(forResource: language, ofType: "lproj") else { return nil }
        return Bundle(path: path)
    }
    static let storageURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("FullAppQA", isDirectory: true)
    static var photo: UIImage { UIImage(named: "ob_room_after")! }
    static var original: UIImage { UIImage(named: "ob_room_before")! }
    static let fixtureDocID = "qa-room-v1"
    private static let eventLock = NSLock()
    private static var eventStorage: [[String: Any]] = []

    static var events: [[String: Any]] {
        eventLock.lock(); defer { eventLock.unlock() }
        return eventStorage
    }

    static func clearEvents() {
        eventLock.lock(); defer { eventLock.unlock() }
        eventStorage.removeAll()
    }

    static func record(_ name: String, properties: [String: Any] = [:]) {
        guard enabled else { return }
        eventLock.lock(); defer { eventLock.unlock() }
        let entry: [String: Any] = ["name": name, "properties": properties, "time": Date().timeIntervalSince1970]
        eventStorage.append(entry)
        guard JSONSerialization.isValidJSONObject(entry),
              let data = try? JSONSerialization.data(withJSONObject: entry, options: [.sortedKeys]) else { return }
        try? FileManager.default.createDirectory(at: storageURL, withIntermediateDirectories: true)
        let url = storageURL.appendingPathComponent("analytics.jsonl")
        if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: nil) }
        if let file = try? FileHandle(forWritingTo: url) {
            defer { try? file.close() }
            _ = try? file.seekToEnd()
            try? file.write(contentsOf: data + Data([10]))
        }
    }

    static func seed() {
        guard enabled else { return }
        if ProcessInfo.processInfo.arguments.contains("--qa-reset-review") {
            UserDefaults.standard.removePersistentDomain(forName: "com.albert.apps.design.ai.qa.review")
        }
        let fm = FileManager.default
        try? fm.createDirectory(at: storageURL, withIntermediateDirectories: true)
        let history = storageURL.appendingPathComponent("ImageHistory", isDirectory: true)
        let date = ISO8601DateFormatter().string(from: Date())
        for id in [fixtureDocID, "qa-room-v2", "qa-garden-v1"] {
            let folder = history.appendingPathComponent(id, isDirectory: true)
            try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
            let imageURL = folder.appendingPathComponent("generated.jpg")
            let originalURL = folder.appendingPathComponent("original.jpg")
            if !fm.fileExists(atPath: imageURL.path) { try? photo.jpegData(compressionQuality: 0.85)?.write(to: imageURL) }
            if !fm.fileExists(atPath: originalURL.path) { try? original.jpegData(compressionQuality: 0.85)?.write(to: originalURL) }
            let doc: [String: Any] = ["id": id, "prompt": "QA fixture", "provider": "qa", "model": "local-fixture",
                                      "storagePath": imageURL.path, "originalPath": originalURL.path,
                                      "option": DesignOption.interior.rawValue, "interiorRoomType": "livingroom",
                                      "interiorStyle": "japanese", "style": "Japandi", "createdAt": date,
                                      "customPrompt": "", "designMode": "interiorDesign"]
            if !fm.fileExists(atPath: folder.appendingPathComponent("metadata.json").path),
               let data = try? JSONSerialization.data(withJSONObject: doc, options: .sortedKeys) {
                try? data.write(to: folder.appendingPathComponent("metadata.json"), options: .atomic)
            }
        }
        if ProjectStore.shared.project(containing: fixtureDocID)?.versions.count == 1 {
            ProjectStore.shared.addVersion(docID: "qa-room-v2", toProjectContaining: fixtureDocID)
        }
        #if DEBUG
        seedFloorPlanResult(in: history, date: date)
        #endif
    }

    #if DEBUG
    static let floorPlanDocID = "qa-plan-v1"

    /// Floor plan → 3D result (plan as the original, the clay render as the result) for the Duo split check.
    private static func seedFloorPlanResult(in history: URL, date: String) {
        let fm = FileManager.default
        let folder = history.appendingPathComponent(floorPlanDocID, isDirectory: true)
        guard !fm.fileExists(atPath: folder.appendingPathComponent("metadata.json").path),
              let plan = UIImage(named: "floorplan_demo_one"), let model = UIImage(named: "clay_floorplan") else { return }
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let imageURL = folder.appendingPathComponent("generated.jpg")
        let originalURL = folder.appendingPathComponent("original.jpg")
        try? model.jpegData(compressionQuality: 0.85)?.write(to: imageURL)
        try? plan.jpegData(compressionQuality: 0.85)?.write(to: originalURL)
        let doc: [String: Any] = ["id": floorPlanDocID, "prompt": "QA fixture", "provider": "qa", "model": "local-fixture",
                                  "storagePath": imageURL.path, "originalPath": originalURL.path,
                                  "option": DesignOption.floolPlan.rawValue, "style": "Japandi", "createdAt": date,
                                  "customPrompt": "", "designMode": "interiorDesign"]
        if let data = try? JSONSerialization.data(withJSONObject: doc, options: .sortedKeys) {
            try? data.write(to: folder.appendingPathComponent("metadata.json"), options: .atomic)
        }
    }
    #endif

    static func makeTabs(index: Int = 0) -> UIViewController {
        let tab = AppStoryboard.instantiate(TabBarController.self)
        tab.setViewControllers([
            AppStoryboard.instantiate(HomeViewController.self),
            AppStoryboard.instantiate(InspirationFeedViewController.self),
            AppStoryboard.instantiate(ProjectsViewController.self),
            AppStoryboard.instantiate(ProfileTabViewController.self)
        ].map { PortraitNavigationController(rootViewController: $0) }, animated: false)
        tab.selectedIndex = index
        return tab
    }

    static let screens = ["splash", "onboarding-room", "onboarding-tools", "onboarding-words", "onboarding-goal",
                          "home", "inspiration", "projects", "profile", "profile-pro", "language",
                          "wizard-photo", "wizard-photo-selected", "wizard-room", "wizard-style", "wizard-final",
                          "tool-exterior", "tool-garden", "tool-reference", "tool-walls", "tool-floor",
                          "tool-furnish", "tool-floorplan", "tool-rearrange", "result", "result-ask", "result-ask-pro", "compare", "paint", "replace", "remove",
                          "assistant", "assistant-typing", "assistant-reply", "assistant-failed", "idea", "paywall", "welcome-pro", "offline", "blocked", "camera-off", "force-update",
                          "projects-empty", "project-detail", "generation", "generation-failed", "generation-bad-photo",
                          "photo-tips", "custom-style", "out-of-credits", "notify", "change-style", "dislike", "share",
                          "assistant-attach", "assistant-history", "assistant-projects", "pro-watermark", "pro-hd", "pro-edits", "generic-error", "discard"] + toolTipScreens

    private static let toolTipScreens = DesignOption.allCases.filter { $0 != .interior }.map { "photo-tips-" + $0.rawValue }

    static let sheetScreens = Set(["photo-tips", "custom-style", "out-of-credits", "notify", "change-style", "dislike", "share", "assistant-attach", "assistant-history", "assistant-projects", "pro-watermark", "pro-hd", "pro-edits", "generic-error", "discard"] + toolTipScreens)

    static func makeScreen(_ name: String) -> UIViewController {
        premium = name == "profile-pro" || name == "result-ask-pro"
        emptyProjects = name == "projects-empty"
        switch name {
        case "onboarding": return AppStoryboard.instantiate(OBPageViewController.self)
        case "home": return makeTabs()
        case "inspiration": return makeTabs(index: 1)
        case "projects", "projects-empty": return makeTabs(index: 2)
        case "inspiration-open":
            let tabs = makeTabs(index: 1)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                let nav = (tabs as? UITabBarController)?.selectedViewController as? UINavigationController
                (nav?.viewControllers.first as? InspirationFeedViewController)?.qaOpenFirstIdea()
            }
            return tabs
        case "projects-open":
            // Wide windows: first project in the detail pane; phones: pushed.
            let tabs = makeTabs(index: 2)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                let nav = (tabs as? UITabBarController)?.selectedViewController as? UINavigationController
                (nav?.viewControllers.first as? ProjectsViewController)?.qaOpenFirstProject()
            }
            return tabs
        case "project-detail":
            let project = ProjectStore.shared.project(containing: fixtureDocID)!
            return ProjectDetailViewController.make(projectID: project.project.id, lastDocID: project.versions.last?.id)
        case "profile", "profile-pro": return makeTabs(index: 3)
        case "splash": return AppStoryboard.instantiate(LaunchViewController.self)
        case "onboarding-room": return OnboardingPageViewController.make(page: .room)
        case "onboarding-tools": return OnboardingPageViewController.make(page: .tools)
        case "onboarding-words": return OnboardingPageViewController.make(page: .words)
        case "onboarding-goal": return AppStoryboard.instantiate(OnboardingGoalViewController.self)
        case "language": return AppStoryboard.instantiate(LanguageViewController.self)
        case "wizard-photo", "wizard-photo-selected", "wizard-room", "wizard-style", "wizard-final":
            let session = WizardSession(option: .interior)
            if name != "wizard-photo" { session.photo = original; session.isDemoPhoto = true }
            session.place = .room(.livingroom)
            session.style = .interior(.modern)
            switch name {
            case "wizard-room": return WizardRoomViewController.make(session: session)
            case "wizard-style": return WizardStyleViewController.make(session: session)
            case "wizard-final": return WizardFinalViewController.make(session: session)
            default: return WizardPhotoViewController.make(session: session)
            }
        case "tool-exterior", "tool-garden", "tool-reference", "tool-walls", "tool-floor", "tool-furnish", "tool-floorplan", "tool-rearrange":
            let options: [String: DesignOption] = ["tool-exterior": .exterior, "tool-garden": .garden,
                                                  "tool-reference": .reference, "tool-walls": .newWalls,
                                                  "tool-floor": .newFlooring, "tool-furnish": .furnish,
                                                  "tool-floorplan": .floolPlan, "tool-rearrange": .rearrange]
            let session = WizardSession(option: options[name]!)
            session.photo = photo; session.isDemoPhoto = true
            return ToolStepFactory.make(session: session)
        case "result-plan":
            let vc = AppStoryboard.instantiate(ResultViewController.self)
            vc.docID = floorPlanDocID
            vc.initialImage = UIImage(named: "clay_floorplan")
            return vc
        case "result", "result-ask", "result-ask-pro":
            let vc = AppStoryboard.instantiate(ResultViewController.self)
            vc.docID = ProjectStore.shared.project(containing: fixtureDocID)?.versions.last?.id ?? fixtureDocID
            vc.initialImage = photo
            if name.hasPrefix("result-ask") { vc.previewAskForQA() }
            return vc
        case "compare":
            let vc = AppStoryboard.instantiate(CompareViewController.self)
            vc.beforeImage = original; vc.afterImage = photo
            return vc
        case "paint": return PaintEditorViewController.make(image: photo, original: original) { _, _ in }
        case "replace": return ReplaceEditorViewController.make(image: photo, original: original) { _, _ in }
        case "remove": return RemoveEditorViewController.make(image: photo, original: original) { _, _ in }
        case "assistant": return AssistantViewController.make()
        case "assistant-typing", "assistant-reply", "assistant-failed":
            var user = AssistantMessage(role: .user, text: "Ideas for a cozy bedroom".localized)
            if name == "assistant-failed" {
                // The production failure removes its typing reply and marks the user message.
                user.state = .failed
                return AssistantViewController.make(conversation: AssistantConversation(messages: [user]))
            }
            let reply = AssistantMessage(role: .assistant,
                                         text: name == "assistant-reply" ? "Warm minimal with travertine, linen curtains and soft evening light".localized : "",
                                         ideas: name == "assistant-reply" ? [AssistantIdea(title: "Cozy cabin".localized, subtitle: "Same room, new look".localized, style: "Modern", prompt: "QA fixture")] : [],
                                         state: name == "assistant-typing" ? .typing : .done)
            return AssistantViewController.make(conversation: AssistantConversation(messages: [user, reply]))
        case "generation", "generation-failed", "generation-bad-photo":
            let manager = GemeniPromptManager()
            manager.updateBaseImage(photo)
            let runner = GenerationRunner(promptManager: manager)
            runner.setQAState(name == "generation" ? .running(.generating) : .failed(name == "generation-failed" ? .failed(code: "502", message: "QA") : .photoNotSuitable))
            let vc = AppStoryboard.instantiate(GenerationViewController.self)
            vc.runner = runner; vc.sourcePhoto = photo; vc.styleTitle = "Modern".localized
            return vc
        case "idea": return IdeaDetailViewController.make(idea: InspirationFeed.load().first!, image: photo)
        case "paywall": return ProPaywallViewController.make(placement: Constants.Keys.obPlacement, source: "qa", onPurchase: nil)
        // Focused billing-policy fixtures, using the real storyboard controllers.
        case "paywall-legacy": return AppStoryboard.instantiate(PaywallViewController.self)
        case "paywall-no-trial":
            let paywall = ProPaywallViewController.make(placement: Constants.Keys.obPlacement, source: "qa", onPurchase: nil)
            paywall.loadViewIfNeeded()
            _ = paywall.perform(NSSelectorFromString("didTapTrial:"), with: paywall)
            return paywall
        case "paywall-single-weekly":
            let paywall = ProPaywallViewController.make(placement: Constants.Keys.obPlacement, source: "qa", onPurchase: nil)
            paywall.loadViewIfNeeded()
            (paywall.value(forKey: "trialToggle") as? UIView)?.isHidden = true
            return paywall
        case "welcome-pro": return WelcomeProViewController.make {}
        case "offline": return StateScreenViewController.make(.offline)
        case "blocked": return StateScreenViewController.make(.contentBlocked(photo: photo, policyID: "QA"))
        case "camera-off": return StateScreenViewController.make(.cameraOff)
        case "camera": return AppStoryboard.instantiate(CameraViewController.self)   // --qa-tabletop: half-folded Duo
        case "force-update": return StateScreenViewController.make(.forceUpdate)
        case "photo-tips": return QAPresentationHost { PhotoTipsSheetViewController.present(from: $0) }
        case let tool where tool.hasPrefix("photo-tips-"):
            let option = DesignOption(rawValue: String(tool.dropFirst("photo-tips-".count)))!
            return QAPresentationHost { PhotoTipsSheetViewController.present(from: $0, option: option) }
        case "custom-style": return QAPresentationHost { CustomStyleSheetViewController.present(from: $0, initialText: nil) { _ in } }
        case "out-of-credits": return QAPresentationHost { OutOfCreditsSheetViewController.present(from: $0, photo: photo) {} }
        case "notify": return QAPresentationHost { NotifySheetViewController.present(from: $0, photo: photo, styleTitle: "Modern".localized) {} }
        case "change-style": return QAPresentationHost { ChangeStyleSheetViewController.present(from: $0, option: .interior, current: "Modern") { _, _, _ in } }
        case "dislike": return QAPresentationHost { DislikeSheetViewController.present(from: $0) { _, _, _, _ in } }
        case "share": return QAPresentationHost { ShareSheetViewController.present(from: $0, before: original, after: photo) }
        case "assistant-attach": return QAPresentationHost { AssistantAttachSheetViewController.present(from: $0) { _ in } }
        case "assistant-history": return QAPresentationHost { AssistantHistoryViewController.present(from: $0) { _ in } }
        case "assistant-projects": return QAPresentationHost { AssistantProjectPickerViewController.present(from: $0) { _ in } }
        case "pro-watermark", "pro-hd", "pro-edits":
            return QAPresentationHost { ProFeatureSheetViewController.present(name == "pro-watermark" ? .watermark : name == "pro-hd" ? .hdExport : .unlimitedEdits, from: $0) }
        case "generic-error": return QAPresentationHost { DSAlertViewController.showGenericError(from: $0, code: "QA") {} }
        case "discard": return QAPresentationHost { DSAlertViewController.show(from: $0, title: "Discard changes?".localized, message: nil, actions: [.init(title: "Keep editing".localized, style: .cancel), .init(title: "Discard".localized, style: .destructive)]) }
        default: preconditionFailure("Unknown QA screen: \(name)")
        }
    }

    static func root() -> UIViewController {
        seed()
        let args = ProcessInfo.processInfo.arguments
        func argument(_ key: String) -> String? {
            guard let i = args.lastIndex(of: key), args.indices.contains(i + 1) else { return nil }
            return args[i + 1]
        }
        let delay = Double(argument("--qa-generation-delay") ?? "0.7") ?? 0.7
        generationService = QAGenerationService(delay: UInt64(min(max(delay, 0), 120) * 1_000_000_000),
                                                failure: argument("--qa-generation-failure"),
                                                failFirst: args.contains("--qa-generation-fail-once"))
        if let i = args.firstIndex(of: "--qa-home-focus"), args.indices.contains(i + 1) { homeFocus = HomeFocus(rawValue: args[i + 1]) }
        if let i = args.firstIndex(of: "--qa-language"), args.indices.contains(i + 1) { language = args[i + 1] }
        if let used = argument("--qa-used-free").flatMap(Int.init) { freeCount = max(0, min(2, used)) }
        if args.contains("--qa-reduce-motion") { reduceMotion = true }
        if args.contains("--qa-launch-flow") {
            // Exercise the production completion gate and root builders across real process launches.
            // A Pro fixture keeps this test independent of ATT, SDK startup and the onboarding upsell.
            premium = true
            homeFocus = nil
            if args.contains("--qa-reset-onboarding") {
                [Constants.Keys.didShowOnboarding, Constants.Keys.onboardingGoal, HomeFocus.defaultsKey].forEach {
                    UserDefaults.standard.removeObject(forKey: $0)
                }
            }
            DispatchQueue.main.async { NavigationManager.shared.proceedToApp() }
            return UIViewController()
        }
        let screen: String
        if let i = args.firstIndex(of: "--qa-screen"), args.indices.contains(i + 1) { screen = args[i + 1] } else { screen = "home" }
        let vc = makeScreen(screen)
        if args.contains("--qa-premium") { premium = true }
        if screen != "onboarding" { vc.view.accessibilityIdentifier = "qa.screen.\(screen)" }
        return container(for: vc)
    }

    static func container(for vc: UIViewController) -> UIViewController {
        // Match the actual route: editors, comparison, generation and paywalls are full-screen modals.
        if vc is WizardStepViewController || vc is ResultViewController || vc is AssistantViewController
            || vc is LanguageViewController || vc is ProjectDetailViewController {
            return PortraitNavigationController(rootViewController: vc)
        }
        return vc
    }
    #endif
}

#if DEBUG
/// Presents the production sheet with its real detent and safe area over a photo.
private final class QAPresentationHost: UIViewController {
    private var action: ((UIViewController) -> Void)?
    init(_ action: @escaping (UIViewController) -> Void) { self.action = action; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:)") }
    override func loadView() {
        let image = UIImageView(image: AppQA.photo)
        image.contentMode = .scaleAspectFill
        image.clipsToBounds = true
        image.isUserInteractionEnabled = true
        view = image
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let action = self.action
        self.action = nil
        action?(self)
    }
}
#endif
