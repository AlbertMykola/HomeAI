import XCTest
import UIKit
@testable import HomeAI

@MainActor
final class StoryboardLayoutTests: XCTestCase {
    func testProjectThumbnailHasEnoughPixelsForItsRenderedCard() async throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        AppQA.seed(); AppQA.snapshot = true
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene), host = QASnapshotHost()
        window.rootViewController = host; window.makeKeyAndVisible()
        defer { window.isHidden = true; AppQA.snapshot = false }
        let controller = AppStoryboard.instantiate(ProjectsViewController.self)
        host.show(controller); window.layoutIfNeeded()
        let collection = try XCTUnwrap(controller.value(forKey: "collectionView") as? UICollectionView)
        collection.layoutIfNeeded()
        let cell = try XCTUnwrap(collection.visibleCells.compactMap { $0 as? ProjectCell }.first)
        let project = try XCTUnwrap(ProjectStore.shared.project(containing: AppQA.fixtureDocID))
        cell.prepareForReuse()
        cell.configure(project: project.project, versions: project.versions, selecting: false, selected: false)
        let deadline = CACurrentMediaTime() + 5
        while cell.coverImageView.image == nil && CACurrentMediaTime() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        window.layoutIfNeeded()
        let rendered = try XCTUnwrap(cell.coverImageView.image?.cgImage)
        let document = try XCTUnwrap(project.versions.last)
        let source = try XCTUnwrap(UIImage(contentsOfFile: document.storagePath)?.cgImage)
        XCTAssertGreaterThanOrEqual(CGFloat(rendered.width) + 1,
                                    min(CGFloat(source.width), ceil(cell.coverImageView.bounds.width * window.screen.scale)))
        XCTAssertGreaterThanOrEqual(CGFloat(rendered.height) + 1,
                                    min(CGFloat(source.height), ceil(cell.coverImageView.bounds.height * window.screen.scale)))
    }

    func testRichTextKeepsItsReferenceMetricsAfterStreamingAndResize() throws {
        let root = UIView()
        let label = UILabel(); label.numberOfLines = 0; root.addSubview(label)
        let paragraph = NSMutableParagraphStyle(); paragraph.lineSpacing = 4
        label.attributedText = NSAttributedString(string: "A streamed design reply", attributes: [
            .font: DS.Font.geologica(.medium, 15), .paragraphStyle: paragraph
        ])
        let layout = DSReferenceLayout(root: root)
        let large = CGSize(width: 1032, height: 1376)
        let scale = OnboardingLayout(size: large).scale
        layout.apply(size: large)
        let streamed = NSMutableAttributedString(attributedString: try XCTUnwrap(label.attributedText))
        streamed.addAttribute(.foregroundColor, value: UIColor.clear, range: NSRange(location: 5, length: 4))
        label.attributedText = streamed
        layout.apply(size: large, refreshContent: true)
        let font = try XCTUnwrap(label.attributedText?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        XCTAssertEqual(font.pointSize, 15 * scale, accuracy: 0.01)
        layout.apply(size: CGSize(width: 393, height: 852))
        let original = try XCTUnwrap(label.attributedText?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        let spacing = try XCTUnwrap(label.attributedText?.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle)
        XCTAssertEqual(original.pointSize, 15, accuracy: 0.01)
        XCTAssertEqual(spacing.lineSpacing, 4, accuracy: 0.01)
    }

    func testHomeMetricsScaleOnLargeIPadAndReturnToTheirOriginalValues() throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        AppQA.seed(); AppQA.snapshot = true
        defer { AppQA.snapshot = false }
        let home = AppStoryboard.instantiate(HomeViewController.self)
        home.loadViewIfNeeded()
        let hero = try XCTUnwrap(home.value(forKey: "heroView") as? UIView)
        let title = try XCTUnwrap(home.value(forKey: "heroTitleLabel") as? UILabel)
        let tiles = try XCTUnwrap(home.value(forKey: "toolTiles") as? [UIView])
        var original: (hero: CGFloat, tile: CGFloat, font: CGFloat)?
        for size in [CGSize(width: 393, height: 852), CGSize(width: 1032, height: 1376),
                     CGSize(width: 1376, height: 1032), CGSize(width: 375, height: 667), CGSize(width: 393, height: 852)] {
            home.view.frame = CGRect(origin: .zero, size: size)
            for _ in 0..<5 { home.view.setNeedsLayout(); home.view.layoutIfNeeded() }
            if original == nil { original = (hero.bounds.height, tiles[0].bounds.height, title.font.pointSize) }
            let base = try XCTUnwrap(original), scale = OnboardingLayout(size: size).scale
            XCTAssertEqual(hero.bounds.height, base.hero * scale, accuracy: 1)
            XCTAssertEqual(tiles[0].bounds.height, base.tile * scale, accuracy: 1)
            XCTAssertEqual(title.font.pointSize, base.font * scale, accuracy: 0.01)
        }
        XCTAssertGreaterThan(OnboardingLayout(size: CGSize(width: 1032, height: 1376)).scale, 1.35)
    }

    func testTipsUseToolContentAndAllBundledSamplePlansDecode() throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        let previous = AppQA.language
        defer { AppQA.language = previous }
        for language in ["cs", "da", "de", "en", "es", "fr", "it", "ja", "ko", "nb", "nl", "pl", "pt-BR", "ru", "uk"] {
            AppQA.language = language
            var firstTips: [DesignOption: String] = [:]
            for option in DesignOption.allCases {
                let tips = AppStoryboard.instantiate(PhotoTipsSheetViewController.self)
                tips.option = option; tips.loadViewIfNeeded()
                let labels = try XCTUnwrap(tips.value(forKey: "tipLabels") as? [UILabel]).sorted { $0.tag < $1.tag }
                XCTAssertEqual(labels.count, 4)
                XCTAssertTrue(labels.allSatisfy { !($0.text ?? "").isEmpty }, "\(language)/\(option)")
                firstTips[option] = labels[0].text
                let examples = try XCTUnwrap(tips.value(forKey: "exampleImageViews") as? [UIImageView])
                XCTAssertTrue(examples.allSatisfy { $0.image != nil }, "\(option)")
            }
            XCTAssertEqual(Set(firstTips.values).count, DesignOption.allCases.count, "Each tool needs its own guidance: \(language)")
        }
        for name in ["floorplan_demo_one", "floorplan_demo_two", "floorplan_demo_three"] {
            let plan = try XCTUnwrap(UIImage(named: name))
            XCTAssertGreaterThanOrEqual(plan.size.width, 600)
            XCTAssertGreaterThanOrEqual(plan.size.height, 450)
        }
    }

    func testProProfileCollapsesTheRestorePurchasesGroup() throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        AppQA.seed()
        defer { AppQA.premium = false }
        for pro in [false, true, false] {
            AppQA.premium = pro
            let profile = AppStoryboard.instantiate(ProfileTabViewController.self)
            profile.loadViewIfNeeded(); profile.beginAppearanceTransition(true, animated: false)
            profile.view.frame = CGRect(x: 0, y: 0, width: 1032, height: 1376)
            for _ in 0..<4 { profile.view.setNeedsLayout(); profile.view.layoutIfNeeded() }
            let group = try XCTUnwrap(profile.value(forKey: "restorePurchasesGroup") as? UIView)
            XCTAssertEqual(group.isHidden, pro)
            if pro { XCTAssertLessThanOrEqual(group.bounds.height, 1) }
            else { XCTAssertGreaterThan(group.bounds.height, 44) }
            profile.endAppearanceTransition()
        }
    }

    func testPaywallContentFillsTheViewportOnLargeIPad() throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        AppQA.seed()
        let paywall = ProPaywallViewController.make(placement: "qa", source: "qa", onPurchase: nil)
        paywall.loadViewIfNeeded()
        for size in [CGSize(width: 1032, height: 1376), CGSize(width: 1376, height: 1032), CGSize(width: 393, height: 852)] {
            paywall.view.frame = CGRect(origin: .zero, size: size)
            for _ in 0..<5 { paywall.view.setNeedsLayout(); paywall.view.layoutIfNeeded() }
            let scroll = try XCTUnwrap(paywall.value(forKey: "contentScrollView") as? UIScrollView)
            let stack = try XCTUnwrap(paywall.value(forKey: "contentStack") as? UIStackView)
            let stage = try XCTUnwrap(paywall.value(forKey: "stageView") as? UIView)
            XCTAssertGreaterThanOrEqual(stack.bounds.height, scroll.bounds.height - 1)
            XCTAssertEqual(stack.bounds.width, scroll.bounds.width, accuracy: 1)
            XCTAssertGreaterThan(stage.bounds.height, 100)
            let cta = try XCTUnwrap(paywall.value(forKey: "ctaButton") as? UIView)
            XCTAssertLessThanOrEqual(cta.frame.maxY, paywall.view.bounds.height)
            let timeline = try XCTUnwrap(paywall.value(forKey: "timelineView") as? UIView)
            let today = try XCTUnwrap(paywall.value(forKey: "dueTodayLabel") as? UILabel)
            let charge = try XCTUnwrap(paywall.value(forKey: "chargeRow") as? UIView)
            let todayFrame = today.convert(today.bounds, to: timeline)
            XCTAssertGreaterThanOrEqual(charge.frame.minY, todayFrame.maxY)
            XCTAssertLessThanOrEqual(charge.frame.maxY, timeline.bounds.height + 1)
        }
    }

    func testNativeTabItemsAreLocalizedAndEveryTabCanBeSelected() throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        AppQA.seed()
        let previousLanguage = AppQA.language, previousSnapshot = AppQA.snapshot
        AppQA.snapshot = true
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        defer { window.isHidden = true; AppQA.language = previousLanguage; AppQA.snapshot = previousSnapshot }
        for language in ["cs", "da", "de", "en", "es", "fr", "it", "ja", "ko", "nb", "nl", "pl", "pt-BR", "ru", "uk"] {
            AppQA.language = language
            let tabs = try XCTUnwrap(AppQA.makeTabs() as? TabBarController)
            window.rootViewController = tabs
            window.makeKeyAndVisible(); window.layoutIfNeeded()
            let controllers = try XCTUnwrap(tabs.viewControllers)
            let items = try XCTUnwrap(tabs.tabBar.items)
            XCTAssertEqual(controllers.count, 4, language)
            XCTAssertEqual(items.map(\.title), ["Create", "Inspiration", "Projects", "Profile"].map { Optional($0.localized) }, language)
            XCTAssertTrue(items.allSatisfy { $0.image != nil && $0.selectedImage != nil }, language)
            XCTAssertFalse(descendants(tabs.view).compactMap { $0 as? DSPressableControl }.contains { $0.actionName == "didTapItem:" },
                           "Tabs must be UIKit items, not custom controls: \(language)")
            for index in controllers.indices {
                tabs.selectedIndex = index
                window.setNeedsLayout(); window.layoutIfNeeded()
                XCTAssertTrue(tabs.selectedViewController === controllers[index], language)
                XCTAssertTrue(tabs.tabBar.selectedItem === items[index], language)
                XCTAssertTrue(isNativeTabBarVisible(tabs, in: window), language)
                let navigation = try XCTUnwrap(controllers[index] as? UINavigationController)
                let root = try XCTUnwrap(navigation.viewControllers.first)
                XCTAssertEqual(root.additionalSafeAreaInsets.bottom, 0, accuracy: 0.01,
                               "UIKit must reserve the tab bar's space without an application inset: \(language)/\(index)")
            }
        }
    }

    func testNativeTabBarRespectsSafeAreaWithoutInjectingCustomInsets() async throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        AppQA.seed()
        let previousSnapshot = AppQA.snapshot
        AppQA.snapshot = true
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try XCTUnwrap(scenes.first { $0.activationState == .foregroundActive } ?? scenes.first)
        let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        let tabs = try XCTUnwrap(AppQA.makeTabs() as? TabBarController)
        window.rootViewController = tabs; window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            if let previousKeyWindow, !previousKeyWindow.isHidden { previousKeyWindow.makeKey() }
            AppQA.snapshot = previousSnapshot
        }
        func waitForSelectedRootLayout(_ navigation: UINavigationController, root: UIViewController,
                                       extra: UIEdgeInsets) async throws {
            root.loadViewIfNeeded()
            let deadline = CACurrentMediaTime() + 4
            var previousSafe: CGRect?
            var previousInsets: UIEdgeInsets?
            var stablePasses = 0
            repeat {
                // UIKit attaches a newly selected native tab on a later main run-loop
                // pass. A layoutIfNeeded call or Task.yield alone cannot complete it.
                window.setNeedsLayout(); window.layoutIfNeeded()
                root.view.setNeedsLayout(); root.view.layoutIfNeeded()
                let safe = root.view.convert(root.view.safeAreaLayoutGuide.layoutFrame, to: window)
                let windowSafe = window.safeAreaLayoutGuide.layoutFrame
                var ready = window.isKeyWindow && tabs.selectedViewController === navigation
                    && tabs.view.window === window && navigation.view.window === window && root.view.window === window
                    && root.view.bounds.width > 0 && root.view.bounds.height > 0 && safe.width > 0 && safe.height > 0
                    && safe.minX >= windowSafe.minX + extra.left - 1
                    && safe.maxX <= windowSafe.maxX - extra.right + 1
                if #available(iOS 26.0, *) {
                    let guide = tabs.contentLayoutGuide
                    if let owner = guide.owningView {
                        let content = owner.convert(guide.layoutFrame, to: window)
                        ready = ready && content.width > 0 && content.height > 0
                            && safe.minY >= content.minY - 1 && safe.maxY <= content.maxY + 1
                        if extra == .zero { ready = ready && content.insetBy(dx: -1, dy: -1).contains(safe) }
                    } else { ready = false }
                }
                if ready, previousSafe == safe, previousInsets == root.view.safeAreaInsets { stablePasses += 1 }
                else { stablePasses = 0 }
                previousSafe = safe; previousInsets = root.view.safeAreaInsets
                if stablePasses >= 2 { return }
                try await Task.sleep(nanoseconds: 30_000_000)
            } while CACurrentMediaTime() < deadline
            XCTFail("Native selected root did not attach and settle: index=\(tabs.selectedIndex), extra=\(extra), "
                    + "key=\(window.isKeyWindow), rootWindow=\(String(describing: root.view.window)), "
                    + "bounds=\(root.view.bounds), safe=\(String(describing: previousSafe)), insets=\(root.view.safeAreaInsets)")
        }
        let initialNavigation = try XCTUnwrap(tabs.selectedViewController as? UINavigationController)
        let initialRoot = try XCTUnwrap(initialNavigation.viewControllers.first)
        try await waitForSelectedRootLayout(initialNavigation, root: initialRoot, extra: .zero)
        for extra in [UIEdgeInsets.zero, UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 84),
                      UIEdgeInsets(top: 0, left: 42, bottom: 0, right: 0)] {
            tabs.additionalSafeAreaInsets = extra
            for index in 0..<4 {
                tabs.selectedIndex = index
                let navigation = try XCTUnwrap(tabs.selectedViewController as? UINavigationController)
                let root = try XCTUnwrap(navigation.viewControllers.first)
                try await waitForSelectedRootLayout(navigation, root: root, extra: extra)
                let safe = root.view.convert(root.view.safeAreaLayoutGuide.layoutFrame, to: window)
                XCTAssertTrue(isNativeTabBarVisible(tabs, in: window))
                XCTAssertGreaterThan(safe.width, 0); XCTAssertGreaterThan(safe.height, 0)
                XCTAssertGreaterThanOrEqual(safe.minX, window.safeAreaLayoutGuide.layoutFrame.minX + extra.left - 1)
                XCTAssertLessThanOrEqual(safe.maxX, window.safeAreaLayoutGuide.layoutFrame.maxX - extra.right + 1)
                XCTAssertEqual(root.additionalSafeAreaInsets.bottom, 0, accuracy: 0.01)
                if #available(iOS 26.0, *) {
                    // The active iPad bar may be hosted above the content while tabBar
                    // still describes a legacy view. Use UIKit's unobscured region.
                    let guide = tabs.contentLayoutGuide
                    let owner = try XCTUnwrap(guide.owningView)
                    let content = owner.convert(guide.layoutFrame, to: window)
                    XCTAssertGreaterThan(content.width, 0); XCTAssertGreaterThan(content.height, 0)
                    // Check the full native region for the real device viewport,
                    // including a system side rail. During synthetic left/right inset
                    // mutations UIKit's guide X frame can update on a later pass;
                    // the root's physical horizontal safe area is checked above.
                    if extra == .zero {
                        XCTAssertTrue(content.insetBy(dx: -1, dy: -1).contains(safe),
                                      "Root safe area \(safe) must fit native content region \(content)")
                    }
                    XCTAssertGreaterThanOrEqual(safe.minY, content.minY - 1,
                                                "Content must clear UIKit's native top tabs")
                    XCTAssertLessThanOrEqual(safe.maxY, content.maxY + 1,
                                             "Content must clear UIKit's native bottom tabs")
                } else if isVisible(tabs.tabBar, in: window) {
                    let bar = tabs.tabBar.convert(tabs.tabBar.bounds, to: window)
                    if bar.midY > window.bounds.midY { XCTAssertLessThanOrEqual(safe.maxY, bar.minY + 1) }
                    else { XCTAssertGreaterThanOrEqual(safe.minY, bar.maxY - 1) }
                }
            }
        }
    }

    func testNativeTabBarHidesOnPushAndReturnsOnPop() async throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        AppQA.seed()
        let previousSnapshot = AppQA.snapshot
        AppQA.snapshot = true
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let tabs = try XCTUnwrap(AppQA.makeTabs(index: 2) as? TabBarController)
        window.rootViewController = tabs; window.makeKeyAndVisible(); window.layoutIfNeeded()
        defer { window.isHidden = true; AppQA.snapshot = previousSnapshot }
        let navigation = try XCTUnwrap(tabs.selectedViewController as? UINavigationController)
        let root = try XCTUnwrap(navigation.topViewController)
        XCTAssertTrue(isNativeTabBarVisible(tabs, in: window))
        let detail = AppQA.makeScreen("project-detail")
        detail.hidesBottomBarWhenPushed = true
        navigation.pushViewController(detail, animated: false)
        await Task.yield(); window.layoutIfNeeded()
        XCTAssertFalse(isNativeTabBarVisible(tabs, in: window), "UIKit must hide its tab bar for a pushed detail")
        XCTAssertEqual(root.additionalSafeAreaInsets.bottom, 0, accuracy: 0.01)
        navigation.popViewController(animated: false)
        await Task.yield(); window.layoutIfNeeded()
        XCTAssertTrue(navigation.topViewController === root)
        XCTAssertTrue(isNativeTabBarVisible(tabs, in: window), "Popping must restore the same native tab bar")
        XCTAssertTrue(tabs.tabBar.selectedItem === tabs.tabBar.items?[2])
    }

    func testProjectsSelectionAndCancelUseTheNativeBarWithoutResettingScroll() async throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        AppQA.seed()
        let previousSnapshot = AppQA.snapshot, previousEmpty = AppQA.emptyProjects
        AppQA.snapshot = true; AppQA.emptyProjects = false
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let tabs = try XCTUnwrap(AppQA.makeTabs(index: 2) as? TabBarController)
        window.rootViewController = tabs; window.makeKeyAndVisible(); window.layoutIfNeeded()
        let navigation = try XCTUnwrap(tabs.selectedViewController as? UINavigationController)
        let projects = try XCTUnwrap(navigation.topViewController as? ProjectsViewController)
        let collection = try XCTUnwrap(projects.value(forKey: "collectionView") as? UICollectionView)
        let select = try XCTUnwrap(projects.value(forKey: "selectButton") as? UIControl)
        let actions = try XCTUnwrap(projects.value(forKey: "actionBarView") as? UIView)
        let originalSource = collection.dataSource
        let fixture = try XCTUnwrap(ProjectStore.shared.project(containing: AppQA.fixtureDocID))
        // Enough real storyboard cards to scroll on every device, without creating
        // or persisting additional user projects merely to exercise layout.
        let repeatedSource = RepeatedProjectDataSource(fixture: fixture)
        collection.dataSource = repeatedSource
        collection.reloadData(); window.layoutIfNeeded()
        defer {
            collection.dataSource = originalSource
            withExtendedLifetime(repeatedSource) {}
            window.isHidden = true; AppQA.snapshot = previousSnapshot; AppQA.emptyProjects = previousEmpty
        }
        let minimumY = -collection.contentInset.top
        let maximumY = collection.contentSize.height - collection.bounds.height + collection.contentInset.bottom
        XCTAssertGreaterThan(maximumY - minimumY, 100, "The fixture must allow a nontrivial scroll position")
        let scrolled = CGPoint(x: 0, y: minimumY + min(150, (maximumY - minimumY) / 3))
        collection.setContentOffset(scrolled, animated: false); window.layoutIfNeeded()
        XCTAssertTrue(isNativeTabBarVisible(tabs, in: window))
        let initialBottom = collection.contentInset.bottom, initialSafeBottom = projects.view.safeAreaInsets.bottom
        let initialOffset = collection.contentOffset
        for selecting in [true, false] {
            repeatedSource.selecting = selecting
            select.sendActions(for: .touchUpInside)
            try await Task.sleep(nanoseconds: 750_000_000)
            for _ in 0..<4 { window.setNeedsLayout(); window.layoutIfNeeded() }
            XCTAssertEqual(isNativeTabBarVisible(tabs, in: window), !selecting)
            XCTAssertEqual(actions.isHidden, !selecting)
            XCTAssertEqual(collection.contentOffset.y, initialOffset.y, accuracy: 1,
                           "Selecting and cancelling must preserve the current project scroll position")
            let expectedBottom = projects.view.safeAreaInsets.bottom + OnboardingLayout(size: projects.view.dsAdaptiveReferenceSize).value(24)
            XCTAssertEqual(collection.contentInset.bottom, expectedBottom, accuracy: 1)
            XCTAssertEqual(collection.verticalScrollIndicatorInsets.bottom, expectedBottom, accuracy: 1)
            if selecting, abs(projects.view.safeAreaInsets.bottom - initialSafeBottom) > 1 {
                XCTAssertNotEqual(collection.contentInset.bottom, initialBottom,
                                  "A native bar safe-area change must recompute the collection's bottom inset")
            }
        }
        XCTAssertTrue(tabs.tabBar.selectedItem === tabs.tabBar.items?[2])
    }

    @MainActor private final class RepeatedProjectDataSource: NSObject, UICollectionViewDataSource {
        let fixture: (project: DesignProject, versions: [ImageDoc])
        var selecting = false
        init(fixture: (project: DesignProject, versions: [ImageDoc])) { self.fixture = fixture }
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { 24 }
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ProjectCell.reuseID, for: indexPath)
            (cell as? ProjectCell)?.configure(project: fixture.project, versions: fixture.versions, selecting: selecting, selected: false)
            return cell
        }
    }

    private func isNativeTabBarVisible(_ tabs: UITabBarController, in window: UIWindow) -> Bool {
        guard tabs.view.window === window else { return false }
        if #available(iOS 18.0, *) { return !tabs.isTabBarHidden }
        return isVisible(tabs.tabBar, in: window)
    }

    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }

    private func isVisible(_ view: UIView, in window: UIWindow) -> Bool {
        var ancestor: UIView? = view
        while let current = ancestor {
            if current.isHidden || current.alpha < 0.01 { return false }
            ancestor = current.superview
        }
        let visible = view.convert(view.bounds, to: window).intersection(window.bounds)
        return view.window === window && !visible.isNull && visible.width > 1 && visible.height > 1
    }
}
