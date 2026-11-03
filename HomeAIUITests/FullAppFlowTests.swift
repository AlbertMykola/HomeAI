import XCTest

final class FullAppFlowTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ screen: String = "home", language: String = "en", focus: String = "interior", extra: [String] = []) {
        app.launchArguments = ["--app-qa", "--qa-screen", screen, "--qa-language", language,
                               "--qa-home-focus", focus, "-AppleLanguages", "(\(language))", "-AppleLocale", language] + extra
        app.launch()
    }

    private func tap(_ identifier: String) {
        let elements = app.descendants(matching: .any).matching(identifier: identifier)
        let ready = NSPredicate { _, _ in elements.allElementsBoundByIndex.contains(where: \.isHittable) }
        expectation(for: ready, evaluatedWith: app)
        waitForExpectations(timeout: 10)
        elements.allElementsBoundByIndex.first(where: \.isHittable)!.tap()
    }

    private func nativeTabItem(_ title: String) -> XCUIElement {
        let identifiers = ["Create": "tab.create", "Створити": "tab.create",
                           "Inspiration": "tab.inspiration", "Натхнення": "tab.inspiration",
                           "Projects": "tab.projects", "Проєкти": "tab.projects",
                           "Profile": "tab.profile", "Профіль": "tab.profile"]
        let identifier = identifiers[title] ?? title
        // Both top tabs on iPad and the phone bar/rail expose native Buttons.
        // A lazy firstMatch avoids scanning UIKit's duplicate nested AX records.
        return app.buttons.matching(identifier: identifier).firstMatch
    }

    private func tapTab(_ title: String) {
        let item = nativeTabItem(title)
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            item.exists && item.isHittable
        }, object: app)
        let result = XCTWaiter.wait(for: [ready], timeout: 30)
        guard result == .completed else {
            XCTFail("Native tab \(title) must be tappable: \(app.debugDescription)"); return
        }
        XCTAssertEqual(item.label, title)
        item.tap()
        assertNativeTabContentSelected(title)
    }

    private func assertNativeTabContentSelected(_ title: String) {
        let identifiers: [String]
        switch title {
        case "Create", "Створити", "tab.create":
            // Home retains its scroll position when switching tabs. Its plan cards
            // remain valid selection evidence when the hero is above the viewport.
            identifiers = ["home.hero.title", "didTapUpload:0", "didTapFloorPlan:0", "didTapAssistant:1"]
        case "Inspiration", "Натхнення", "tab.inspiration": identifiers = ["didTapSearch:0"]
        case "Projects", "Проєкти", "tab.projects": identifiers = ["projects.segment"]
        case "Profile", "Профіль", "tab.profile": identifiers = ["profile.appearance.menu"]
        default:
            XCTFail("Unknown native tab: \(title)"); return
        }
        let markers = identifiers.map { identifier in
            identifier == "home.hero.title"
                ? app.staticTexts.matching(identifier: identifier).firstMatch
                : app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        }
        let viewport = app.frame
        let visibleContent = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            markers.contains { marker in
                guard marker.exists else { return false }
                let frame = marker.frame
                return frame.minX.isFinite && frame.minY.isFinite && frame.width.isFinite && frame.height.isFinite
                    && frame.width > 0 && frame.height > 0 && frame.intersects(viewport)
            }
        }, object: app)
        if XCTWaiter.wait(for: [visibleContent], timeout: 30) != .completed {
            XCTFail("Native tab \(title) must show its actual content: \(app.debugDescription)")
        }
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testExteriorHomeHeroAndAlternativeCardsOpenMatchingWizards() {
        launch(focus: "exterior", extra: ["--qa-dark"])
        XCTAssertEqual(app.staticTexts["home.hero.title"].label, "Redesign your exterior")
        XCTAssertFalse(app.buttons["home.more.exterior"].exists)
        tap("didTapUpload:0")
        XCTAssertTrue(app.staticTexts["Add a photo of your home"].waitForExistence(timeout: 8))
        capture("Exterior-home-hero-route")
        launch(focus: "exterior")
        tap("home.more.interior")
        XCTAssertTrue(app.staticTexts["Add a photo of your room"].waitForExistence(timeout: 8))
        launch(focus: "exterior")
        tap("home.more.garden")
        XCTAssertTrue(app.staticTexts["Add a photo of your garden"].waitForExistence(timeout: 8))
    }

    func testWizardGeneratesResultThenPaintAndShare() {
        launch()
        tap("didTapUpload:0")
        tap("didTapDemo:0")
        tap("didTapNext:0")
        XCTAssertTrue(app.staticTexts["Which room is it?"].waitForExistence(timeout: 8))
        app.collectionViews.cells.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Pick a style"].waitForExistence(timeout: 8))
        app.collectionViews.cells.element(boundBy: 1).tap()
        tap("didTapGenerate:0")
        XCTAssertTrue(app.buttons["didTapShare:0"].waitForExistence(timeout: 15))
        capture("Flow-generated-result")
        tap("didTapTool:1") // Paint
        XCTAssertTrue(app.staticTexts["Paint walls"].waitForExistence(timeout: 8))
        capture("Flow-paint-editor")
        tap("didTapSwatch:0")
        tap("didTapApply:0")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Version 2'")).firstMatch.waitForExistence(timeout: 15))
        capture("Flow-painted-new-version")
        tap("didTapShare:0")
        XCTAssertTrue(app.staticTexts["Share your redesign"].waitForExistence(timeout: 8))
        capture("Flow-share-real-sheet")
    }

    func testNativeTabBarHasFourLocalizedItemsAndHidesForPushedDetails() {
        let environment = ProcessInfo.processInfo.environment
        // Hosted snapshots cover all locales and themes. Native invocations run one
        // complete route to limit repeated AX launches; opt into the four-case matrix.
        let matrix = environment["REHOMELY_QA_NATIVE_MATRIX"] == "1"
        let languages = matrix ? ["en", "uk"] : [environment["REHOMELY_QA_NATIVE_LANGUAGE"] ?? "en"]
        let appearances = matrix ? [false, true] : [environment["REHOMELY_QA_NATIVE_DARK"] == "1"]
        for language in languages {
            let titles = language == "uk"
                ? ["Створити", "Натхнення", "Проєкти", "Профіль"]
                : ["Create", "Inspiration", "Projects", "Profile"]
            for dark in appearances {
                launch(language: language, extra: dark ? ["--qa-dark"] : [])
                for title in titles { tapTab(title) }
                let nativeIDs = ["tab.create", "tab.inspiration", "tab.projects", "tab.profile"]
                let nativeItems = app.buttons.matching(NSPredicate(format: "identifier IN %@", nativeIDs))
                XCTAssertEqual(Set(nativeItems.allElementsBoundByIndex.map(\.identifier)), Set(nativeIDs), app.debugDescription)
                XCTAssertFalse(app.buttons["didTapItem:0"].exists, "The custom floating tab controls must be removed")
                tapTab(titles[2])
                tap("didTapSelect:0")
                let selectionHidesTabs = NSPredicate { _, _ in
                    let item = self.nativeTabItem(titles[2])
                    return !item.exists || !item.isHittable
                }
                expectation(for: selectionHidesTabs, evaluatedWith: app); waitForExpectations(timeout: 30)
                tap("didTapSelect:0") // Cancel selection with Done.
                let cancelled = NSPredicate { _, _ in
                    let item = self.nativeTabItem(titles[2])
                    return item.exists && item.isHittable
                }
                expectation(for: cancelled, evaluatedWith: app); waitForExpectations(timeout: 30)
                assertNativeTabContentSelected(titles[2])
                for title in titles {
                    let item = nativeTabItem(title)
                    XCTAssertTrue(item.exists && item.isHittable, app.debugDescription)
                }
                let project = app.collectionViews.cells.firstMatch
                XCTAssertTrue(project.waitForExistence(timeout: 30)); project.tap()
                XCTAssertTrue(app.buttons["didTapContinue:0"].waitForExistence(timeout: 30))
                let hidden = NSPredicate { _, _ in
                    let item = self.nativeTabItem(titles[2])
                    return !item.exists || !item.isHittable
                }
                expectation(for: hidden, evaluatedWith: app); waitForExpectations(timeout: 30)
                tap("didTapBack:0")
                let returned = NSPredicate { _, _ in
                    let item = self.nativeTabItem(titles[2])
                    return item.exists && item.isHittable
                }
                expectation(for: returned, evaluatedWith: app); waitForExpectations(timeout: 30)
                assertNativeTabContentSelected(titles[2])
                capture("Native-tabs-\(language)-\(dark ? "dark" : "light")")
                tapTab(titles[0])
                XCTAssertTrue(app.buttons["didTapUpload:0"].waitForExistence(timeout: 30))
            }
        }
    }

    func testTabsProjectDetailAndLanguage() {
        launch()
        tapTab("Inspiration")
        XCTAssertTrue(app.staticTexts["Inspiration"].firstMatch.waitForExistence(timeout: 8))
        app.swipeUp()
        tapTab("Projects")
        app.collectionViews.cells.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["didTapContinue:0"].waitForExistence(timeout: 8))
        capture("Flow-project-versions")
        tap("didTapBack:0")
        tapTab("Profile")
        tap("didTapRow:0") // Language
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Українська")).firstMatch.waitForExistence(timeout: 8))
        capture("Flow-language-list")
        for dark in [false, true] {
            launch("projects-empty", extra: dark ? ["--qa-dark"] : [])
            XCTAssertTrue(app.staticTexts["Your redesigns will live here"].waitForExistence(timeout: 8))
            capture("Empty-designs-\(dark ? "dark" : "light")")
            app.segmentedControls["projects.segment"].buttons.element(boundBy: 1).tap()
            XCTAssertTrue(app.staticTexts["Save ideas from Inspiration"].waitForExistence(timeout: 8))
            capture("Empty-ideas-\(dark ? "dark" : "light")")
            tapTab("Inspiration")
            app.swipeUp()
            capture("Inspiration-scrolled-header-\(dark ? "dark" : "light")")
        }
    }

    func testInspirationDetailCanBeOpenedClosedAndTried() {
        for reduced in [false, true] {
            launch("inspiration", language: "uk", extra: reduced ? ["--qa-reduce-motion"] : ["--qa-dark"])
            for attempt in 0..<2 {
                let card = app.collectionViews.cells.firstMatch
                XCTAssertTrue(card.waitForExistence(timeout: 8))
                card.tap()
                let cta = app.buttons["didTapTry:0"]
                XCTAssertTrue(cta.waitForExistence(timeout: 8))
                XCTAssertTrue(cta.isHittable)
                XCTAssertLessThanOrEqual(cta.frame.maxY, app.frame.maxY)
                capture("Inspiration-detail-\(reduced ? "reduced-light" : "normal-dark")-\(attempt)")
                tap("didTapClose:0")
                XCTAssertTrue(app.collectionViews.cells.firstMatch.waitForExistence(timeout: 8))
            }
            app.collectionViews.cells.element(boundBy: 0).tap()
            tap("didTapTry:0")
            XCTAssertTrue(app.buttons["didTapDemo:0"].waitForExistence(timeout: 8))
        }
    }

    func testProfileTipsAndDurationCorrections() {
        launch("profile", language: "uk", extra: ["--qa-dark"])
        XCTAssertTrue(app.staticTexts["Безкоштовний план"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["didTapRow:4"].exists)
        XCTAssertTrue(app.buttons["didTapRow:3"].exists)
        capture("Profile-free-wrapped")
        tapTab("Створити")
        tapTab("Профіль")
        capture("Profile-returned-once")
        launch("wizard-photo", language: "uk", extra: ["--qa-dark"])
        let tipsTitle = app.staticTexts["Як отримати найкращий результат"]
        if !tipsTitle.waitForExistence(timeout: 3) {
            app.scrollViews.firstMatch.swipeUp()
            tap("didTapTips:0")
        }
        XCTAssertTrue(tipsTitle.waitForExistence(timeout: 8))
        capture("Photo-tips-wrapped-top")
        let gotIt = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Зрозуміло")).firstMatch
        if !gotIt.isHittable { app.swipeUp() }
        XCTAssertTrue(gotIt.isHittable)
        capture("Photo-tips-wrapped-bottom")
        gotIt.tap()
        XCTAssertTrue(app.buttons["didTapTips:0"].waitForExistence(timeout: 8))
        launch("tool-reference", language: "uk", extra: ["--qa-dark"])
        let generate = app.buttons["didTapGenerate:0"]
        XCTAssertTrue(generate.waitForExistence(timeout: 8))
        XCTAssertTrue(generate.label.contains("Близько 30 с"))
        capture("Reference-duration-only")
    }

    func testFailureRetryAndCreditsRemainUsable() {
        launch("wizard-final", extra: ["--qa-generation-fail"])
        tap("didTapGenerate:0")
        XCTAssertTrue(app.staticTexts["Something went wrong"].waitForExistence(timeout: 15))
        capture("Flow-generation-failed")
        tap("didTapFailurePrimary:0")
        XCTAssertTrue(app.buttons["Contact support"].waitForExistence(timeout: 15))
        tap("didTapFailureBack:0")
        XCTAssertTrue(app.buttons["didTapGenerate:0"].waitForExistence(timeout: 8))
    }

    func testCompareGesturesAndBackgroundResume() {
        launch("compare")
        let center = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        center.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.45)))
        capture("Compare-dragged")
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["didTapFit:0"].waitForExistence(timeout: 8))
        app.buttons["didTapFit:0"].tap()
        XCTAssertTrue(app.buttons["didTapClose:0"].isHittable)
        capture("Compare-resumed")
    }

    func testPaywallToggleAndCloseReturnsHome() {
        launch()
        tap("didTapGetPro:0")
        let toggle = app.buttons["didTapTrial:0"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 8))
        // ✕ only appears 5 s after the paywall is on screen.
        XCTAssertFalse(app.buttons["didTapClose:0"].exists && app.buttons["didTapClose:0"].isHittable)
        if !toggle.isHittable { app.swipeUp() }
        tap("didTapTrial:0")
        XCTAssertEqual(toggle.label, "Enable Free Trial")
        XCTAssertEqual(app.buttons["didTapCTA:0"].label, "Continue")
        tap("didTapTrial:0")
        XCTAssertEqual(toggle.label, "Free Trial Enabled")
        tap("didTapClose:0")
        XCTAssertTrue(app.buttons["didTapUpload:0"].waitForExistence(timeout: 8))
        capture("Paywall-closed-home-resumed")
    }
}
