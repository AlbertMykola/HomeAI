import XCTest
import UIKit

final class ControlInteractionUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws { continueAfterFailure = false }

    private func tap(_ identifier: String) {
        let control = app.buttons[identifier].firstMatch
        XCTAssertTrue(control.waitForExistence(timeout: 12))
        let ready = NSPredicate { _, _ in control.isHittable }
        expectation(for: ready, evaluatedWith: control); waitForExpectations(timeout: 12)
        control.tap()
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
        case "Projects", "Проєкти", "tab.projects": identifiers = ["didTapSegment:0"]
        case "Profile", "Профіль", "tab.profile": identifiers = ["profile.appearance.menu"]
        default:
            XCTFail("Unknown native tab: \(title)"); return
        }
        let markers = identifiers.map { identifier in
            identifier == "home.hero.title"
                ? app.staticTexts.matching(identifier: identifier).firstMatch
                : app.buttons.matching(identifier: identifier).firstMatch
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
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func reveal(_ element: XCUIElement, in scroll: XCUIElement) {
        for _ in 0..<6 {
            if element.isHittable, element.frame.minY >= scroll.frame.minY - 1,
               element.frame.maxY <= scroll.frame.maxY + 1 { return }
            scroll.swipeUp()
        }
        XCTAssertTrue(element.isHittable, app.debugDescription)
        XCTAssertLessThanOrEqual(element.frame.maxY, scroll.frame.maxY + 1)
    }

    private func waitForKeyboardViewport(in scroll: XCUIElement) {
        let keyboard = app.keyboards.firstMatch
        // Hardware keyboards need no inset. With software input, wait for the
        // keyboard layout guide before deciding whether the action needs a swipe.
        guard keyboard.waitForExistence(timeout: 5) else { return }
        let aligned = NSPredicate { _, _ in scroll.frame.maxY <= keyboard.frame.minY + 1 }
        expectation(for: aligned, evaluatedWith: scroll); waitForExpectations(timeout: 12)
    }

    func testStyleLongPressPreviewDismissesBackToTheSameStep() {
        app.launchArguments = ["--app-qa", "--qa-screen", "wizard-style", "--qa-language", "uk",
                               "--qa-premium", "--qa-dark", "-AppleLanguages", "(uk)", "-AppleLocale", "uk_UA"]
        app.launch()
        let styles = app.collectionViews.firstMatch
        let tile = styles.cells.element(boundBy: 1)
        XCTAssertTrue(tile.waitForExistence(timeout: 12))
        let count = styles.cells.count
        tile.press(forDuration: 1)
        let preview = app.images["style.preview.image"]
        XCTAssertTrue(preview.waitForExistence(timeout: 8))
        XCTAssertGreaterThan(preview.frame.height, preview.frame.width)
        capture("Storyboard-style-preview")
        preview.tap()
        let dismissed = NSPredicate { _, _ in !preview.exists }
        expectation(for: dismissed, evaluatedWith: app); waitForExpectations(timeout: 8)
        XCTAssertTrue(tile.isHittable)
        XCTAssertEqual(styles.cells.count, count)
    }

    func testCompareButtonOpensComparisonWithOneTapAndCanReopen() {
        for language in ["en", "uk"] {
            app.launchArguments = ["--app-qa", "--qa-screen", "result", "--qa-language", language,
                                   "--qa-dark", "-AppleLanguages", "(\(language))", "-AppleLocale", language]
            app.launch()
            for _ in 0..<2 {
                tap("result.compare")
                XCTAssertTrue(app.buttons["didTapFit:0"].waitForExistence(timeout: 5))
                tap("didTapClose:0")
                XCTAssertTrue(app.buttons["result.compare"].waitForExistence(timeout: 5))
            }
        }
    }

    func testFirstGenerationShowsSystemRatingRequest() {
        app.launchArguments = ["--app-qa", "--qa-screen", "wizard-final", "--qa-language", "en",
                               "--qa-premium", "--qa-system-review", "--qa-reset-review",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        tap("didTapGenerate:0")
        XCTAssertTrue(app.buttons["didTapShare:0"].waitForExistence(timeout: 20))
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let dismiss = app.buttons.matching(NSPredicate(format: "label IN %@", ["Not Now", "Not now", "Не зараз"])).firstMatch
        let systemDismiss = system.buttons.matching(NSPredicate(format: "label IN %@", ["Not Now", "Not now", "Не зараз"])).firstMatch
        let shown = NSPredicate { _, _ in dismiss.exists || systemDismiss.exists }
        expectation(for: shown, evaluatedWith: app); waitForExpectations(timeout: 12)
        let ready = NSPredicate { _, _ in
            (dismiss.exists && dismiss.isHittable && dismiss.isEnabled)
                || (systemDismiss.exists && systemDismiss.isHittable && systemDismiss.isEnabled)
        }
        expectation(for: ready, evaluatedWith: app); waitForExpectations(timeout: 12)
        capture("First-generation-system-rating")
        XCTAssertTrue(dismiss.exists || systemDismiss.exists, app.debugDescription)
        (dismiss.exists ? dismiss : systemDismiss).tap()
        let resumed = NSPredicate { _, _ in self.app.buttons["result.compare"].isHittable }
        expectation(for: resumed, evaluatedWith: app); waitForExpectations(timeout: 8)
    }

    func testProProfileHidesRestoreWhileFreeProfileKeepsIt() {
        for pro in [false, true] {
            app.launchArguments = ["--app-qa", "--qa-screen", "home", "--qa-home-focus", "interior", "--qa-language", "en",
                                   "-AppleLanguages", "(en)", "-AppleLocale", "en"]
            if pro { app.launchArguments.append("--qa-premium") }
            app.launch(); tapTab("Profile")
            XCTAssertTrue(app.staticTexts["Profile"].firstMatch.waitForExistence(timeout: 8))
            if pro { XCTAssertFalse(app.buttons["didTapRow:3"].exists) }
            else { XCTAssertTrue(app.buttons["didTapRow:3"].exists) }
        }
    }

    func testToolTipsAndBundledFloorPlanCanReachAGeneratedResult() {
        for (route, firstTip) in [("home.more.exterior", "Photograph the building in daylight."),
                                   ("home.more.garden", "Use natural daylight and avoid harsh sunlight or deep shadows.")] {
            app.launchArguments = ["--app-qa", "--qa-screen", "home", "--qa-home-focus", "interior", "--qa-language", "en",
                                   "--qa-premium", "-AppleLanguages", "(en)", "-AppleLocale", "en"]
            app.launch()
            let card = app.buttons[route]
            reveal(card, in: app.scrollViews.firstMatch); tap(route); tap("didTapTips:0")
            XCTAssertTrue(app.staticTexts[firstTip].waitForExistence(timeout: 8))
            tap("didTapClose:0")
        }
        app.launchArguments = ["--app-qa", "--qa-screen", "home", "--qa-home-focus", "interior", "--qa-language", "en",
                               "--qa-premium", "-AppleLanguages", "(en)", "-AppleLocale", "en"]
        app.launch()
        reveal(app.buttons["didTapFloorPlan:0"], in: app.scrollViews.firstMatch)
        tap("didTapFloorPlan:0")
        XCTAssertTrue(app.staticTexts["Add your floor plan"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["didTapDemo:0"].exists)
        XCTAssertTrue(app.buttons["didTapDemo:1"].exists)
        XCTAssertTrue(app.buttons["didTapDemo:2"].exists)
        tap("didTapTips:0")
        XCTAssertTrue(app.staticTexts["Full 2D floor plan with every room clearly visible."].waitForExistence(timeout: 8))
        tap("didTapClose:0")
        tap("didTapDemo:1"); tap("didTapNext:0")
        XCTAssertTrue(app.staticTexts["Floor plan to 3D"].waitForExistence(timeout: 10))
        tap("didTapGenerate:0")
        XCTAssertTrue(app.buttons["result.compare"].waitForExistence(timeout: 20))
    }

    func testHomeAssistantAndProjectsRoutesRemainUsableAfterEntrance() {
        app.launchArguments = ["--app-qa", "--qa-screen", "home", "--qa-home-focus", "interior", "--qa-language", "en",
                               "--qa-premium", "-AppleLanguages", "(en)", "-AppleLocale", "en"]
        app.launch()
        reveal(app.buttons["didTapAssistant:1"], in: app.scrollViews.firstMatch)
        tap("didTapAssistant:1")
        XCTAssertTrue(app.staticTexts["Hi! I'm your AI designer"].waitForExistence(timeout: 8))
        tap("didTapBack:0")
        tapTab("Projects")
        XCTAssertTrue(app.staticTexts["Projects"].firstMatch.waitForExistence(timeout: 8))
        tapTab("Create"); tapTab("Projects")
        XCTAssertTrue(app.staticTexts["Projects"].firstMatch.isHittable)
    }

    func testLargeTabletHomeTipsAndPaywallUseTheAvailableHeight() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("Large tablet layout") }
        XCUIDevice.shared.orientation = .portrait
        app.launchArguments = ["--app-qa", "--qa-screen", "home", "--qa-home-focus", "interior", "--qa-language", "uk",
                               "-AppleLanguages", "(uk)", "-AppleLocale", "uk_UA"]
        app.launch()
        XCTAssertTrue(app.buttons["didTapUpload:0"].waitForExistence(timeout: 10))
        capture("Adaptive-tablet-home")
        tap("didTapGetPro:0")
        let cta = app.buttons["didTapCTA:0"]
        XCTAssertTrue(cta.waitForExistence(timeout: 10)); XCTAssertTrue(cta.isHittable)
        XCTAssertLessThanOrEqual(cta.frame.maxY, app.frame.maxY)
        XCTAssertGreaterThan(cta.frame.minY, app.frame.height * 0.65)
        capture("Adaptive-tablet-paywall")
        tap("didTapClose:0")
        tap("didTapUpload:0"); tap("didTapTips:0")
        let gotIt = app.buttons.matching(NSPredicate(format: "identifier == %@ AND label == %@", "didTapClose:0", "Зрозуміло")).firstMatch
        XCTAssertTrue(gotIt.waitForExistence(timeout: 8)); XCTAssertTrue(gotIt.isHittable)
        capture("Adaptive-tablet-tips")
        gotIt.tap(); tap("didTapWizardBack:0")
        XCTAssertTrue(app.buttons["didTapUpload:0"].isHittable)
    }

    func testAppearanceMenuChangesThemeAndRestoresSystemMode() {
        app.launchArguments = ["--app-qa", "--qa-screen", "profile", "--qa-language", "en",
                               "--qa-dark", "-AppleLanguages", "(en)", "-AppleLocale", "en"]
        app.launch()
        tap("profile.appearance.menu")
        let light = app.buttons["Light"].firstMatch
        XCTAssertTrue(light.waitForExistence(timeout: 8))
        capture("Storyboard-appearance-menu")
        light.tap()
        let menuButton = app.buttons["profile.appearance.menu"]
        expectation(for: NSPredicate(format: "value == %@", "Light"), evaluatedWith: menuButton)
        waitForExpectations(timeout: 8)
        tap("profile.appearance.menu")
        let system = app.buttons["System"].firstMatch
        XCTAssertTrue(system.waitForExistence(timeout: 8))
        system.tap()
        expectation(for: NSPredicate(format: "value == %@", "System"), evaluatedWith: menuButton)
        waitForExpectations(timeout: 8)
        capture("Storyboard-appearance-system-restored")
    }

    func testAskKeyboardCanExpandDismissAndReopen() {
        app.launchArguments = ["--app-qa", "--qa-screen", "result", "--qa-language", "en", "--qa-premium",
                               "--qa-dark", "-AppleLanguages", "(en)", "-AppleLocale", "en"]
        app.launch()
        for attempt in 0..<2 {
            tap("didTapAsk:0")
            let field = app.textViews.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 10)); XCTAssertTrue(field.isHittable)
            field.tap()
            field.typeText("Keep the windows and doors. Use warm neutral colours. Add a reading corner and soft lighting. Keep the original layout and replace the rug with a soft beige wool rug. ")
            let send = app.buttons["didTapSend:0"]
            capture("Ask-after-typing-\(attempt)")
            if !send.isHittable { print(app.debugDescription) }
            XCTAssertTrue(send.isHittable)
            XCTAssertLessThanOrEqual(field.frame.maxY, app.frame.maxY)
            let keyboard = app.keyboards.firstMatch
            if keyboard.exists {
                XCTAssertLessThanOrEqual(send.frame.maxY, keyboard.frame.minY + 2)
                XCTAssertLessThanOrEqual(field.frame.maxY, keyboard.frame.minY + 2)
            }
            capture("Ask-expanded-\(attempt)")
            let heading = app.staticTexts["Ask for a change"]
            XCTAssertTrue(heading.isHittable)
            // The software keyboard can arrive after typeText on a freshly booted simulator.
            // Freeze both drag endpoints from one settled geometry instead of resolving
            // the heading lazily after an already captured Send coordinate.
            var frames: [CGRect] = []
            var stableSince = ProcessInfo.processInfo.systemUptime
            let stable = NSPredicate { _, _ in
                let current = [self.app.frame, heading.frame, field.frame, send.frame,
                               keyboard.exists ? keyboard.frame : .zero]
                if current != frames {
                    frames = current
                    stableSince = ProcessInfo.processInfo.systemUptime
                    return false
                }
                return ProcessInfo.processInfo.systemUptime - stableSince >= 1
                    && heading.isHittable && send.isHittable
            }
            expectation(for: stable, evaluatedWith: app); waitForExpectations(timeout: 10)
            if frames[4].intersects(frames[0]) {
                XCTAssertLessThanOrEqual(frames[3].maxY, frames[4].minY + 2)
                XCTAssertLessThanOrEqual(frames[2].maxY, frames[4].minY + 2)
            }
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: frames[1].midX - frames[0].minX,
                                                   dy: frames[1].midY - frames[0].minY))
            let end = origin.withOffset(CGVector(dx: frames[1].midX - frames[0].minX,
                                                 dy: frames[3].maxY - 1 - frames[0].minY))
            print("ASK_GESTURE settledFrames=\(frames)")
            start.press(forDuration: 0.1, thenDragTo: end)
            let hidden = NSPredicate { _, _ in !heading.isHittable }
            expectation(for: hidden, evaluatedWith: app); waitForExpectations(timeout: 10)
            XCTAssertTrue(app.buttons["didTapShare:0"].isHittable)
            capture("Ask-dismissed-\(attempt)")
        }
        tap("didTapShare:0")
        XCTAssertTrue(app.staticTexts["Share your redesign"].waitForExistence(timeout: 10))
        capture("Share-after-keyboard-reentry")
    }

    func testLongCopySheetsCanScrollAboveTheKeyboardAndSubmit() {
        app.launchArguments = ["--app-qa", "--qa-screen", "custom-style", "--qa-language", "uk", "--qa-dark",
                               "-AppleLanguages", "(uk)", "-AppleLocale", "uk"]
        app.launch()
        let field = app.textViews.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap(); field.typeText("Warm oak, soft linen and warm evening light")
        let customScroll = app.scrollViews.containing(.button, identifier: "didTapUse:0").firstMatch
        waitForKeyboardViewport(in: customScroll)
        reveal(app.buttons["didTapUse:0"], in: customScroll)
        capture("Custom-style-keyboard-scroll")
        tap("didTapUse:0")
        let gone = NSPredicate { _, _ in !field.exists }
        expectation(for: gone, evaluatedWith: app); waitForExpectations(timeout: 10)
        capture("Custom-style-submitted")

        app.launchArguments = ["--app-qa", "--qa-screen", "result", "--qa-language", "uk", "--qa-dark",
                               "-AppleLanguages", "(uk)", "-AppleLocale", "uk"]
        app.launch()
        tap("didTapDislike:0")
        let feedbackScroll = app.scrollViews.containing(.button, identifier: "didTapReason:5").firstMatch
        XCTAssertTrue(feedbackScroll.waitForExistence(timeout: 10))
        reveal(app.buttons["didTapReason:5"], in: feedbackScroll)
        tap("didTapReason:5")
        reveal(app.buttons["Лише надіслати відгук"], in: feedbackScroll)
        capture("Feedback-last-reason-and-actions")
        tap("Лише надіслати відгук")
        XCTAssertTrue(app.buttons["didTapShare:0"].waitForExistence(timeout: 10))
    }

    func testLastFreeBannerClosesWithoutOpeningThePaywallAndStaysDismissed() {
        app.launchArguments = ["--app-qa", "--qa-screen", "home", "--qa-home-focus", "interior", "--qa-language", "uk", "--qa-dark",
                               "--qa-used-free", "1", "-AppleLanguages", "(uk)", "-AppleLocale", "uk"]
        app.launch()
        let banner = app.buttons["didTapFreeBanner:0"]
        XCTAssertTrue(banner.waitForExistence(timeout: 10))
        capture("Last-free-banner-wrapped")
        tap("home.freeBanner.close")
        let hidden = NSPredicate { _, _ in !banner.isHittable }
        expectation(for: hidden, evaluatedWith: app); waitForExpectations(timeout: 10)
        XCTAssertTrue(app.buttons["didTapUpload:0"].isHittable)
        tapTab("Профіль"); tapTab("Створити")
        XCTAssertFalse(banner.isHittable)
        capture("Last-free-banner-dismissed")
    }

    func testLongFailureExplanationsScrollWhileRetryStaysReachable() {
        for (screen, language, prefix) in [("generation-failed", "de", "Unsere Server"),
                                           ("generation-bad-photo", "uk", "Спробуйте ширше фото")] {
            app.launchArguments = ["--app-qa", "--qa-screen", screen, "--qa-language", language,
                                   "-AppleLanguages", "(\(language))", "-AppleLocale", language]
            app.launch()
            let retry = app.buttons["didTapFailurePrimary:0"]
            XCTAssertTrue(retry.waitForExistence(timeout: 10))
            let footer = retry.frame
            let body = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
            XCTAssertTrue(body.waitForExistence(timeout: 10))
            let scroll = app.scrollViews.firstMatch
            scroll.swipeUp()
            if app.frame.width < 500 { XCTAssertGreaterThan(body.frame.height, 30) }
            XCTAssertGreaterThanOrEqual(body.frame.minY, scroll.frame.minY - 1)
            XCTAssertLessThanOrEqual(body.frame.maxY, scroll.frame.maxY + 1)
            XCTAssertEqual(retry.frame.minY, footer.minY, accuracy: 1)
            XCTAssertTrue(retry.isHittable)
            capture("Failure-explanation-scrolled-\(screen)")
        }
    }

    func testCompactProFeatureCanScrollToBothActions() {
        for language in ["es", "pl", "pt-BR"] {
            app.launchArguments = ["--app-qa", "--qa-screen", "pro-watermark", "--qa-language", language,
                                   "--qa-dark", "-AppleLanguages", "(\(language))", "-AppleLocale", language]
            app.launch()
            let scroll = app.scrollViews["proFeature.content"]
            XCTAssertTrue(scroll.waitForExistence(timeout: 10))
            let see = app.buttons["didTapSee:0"]
            let notNow = app.buttons["proFeature.notNow"]
            reveal(notNow, in: scroll)
            XCTAssertTrue(see.isHittable)
            XCTAssertTrue(notNow.isHittable)
            XCTAssertLessThanOrEqual(notNow.frame.maxY, scroll.frame.maxY + 1)
            capture("Pro-feature-actions-\(language)")
            notNow.tap()
            let dismissed = NSPredicate { _, _ in !scroll.exists }
            expectation(for: dismissed, evaluatedWith: app); waitForExpectations(timeout: 10)
        }
    }

    func testAssistantFailedMessageShowsRetryAndCanRetryLocally() {
        app.launchArguments = ["--app-qa", "--qa-screen", "assistant-failed", "--qa-language", "en",
                               "--qa-dark", "--qa-premium", "-AppleLanguages", "(en)", "-AppleLocale", "en"]
        app.launch()
        let retry = app.buttons["didTapRetry:0"]
        XCTAssertTrue(retry.waitForExistence(timeout: 10))
        XCTAssertTrue(retry.isHittable)
        XCTAssertEqual(app.tables.firstMatch.cells.count, 1)
        retry.tap()
        // The app's QA URLProtocol rejects the request locally. A failed retry
        // returns to one user message, without retaining an orphan typing bubble.
        let recovered = NSPredicate { _, _ in retry.isHittable && self.app.tables.firstMatch.cells.count == 1 }
        expectation(for: recovered, evaluatedWith: app); waitForExpectations(timeout: 12)
        capture("Assistant-failure-retry-local")
    }
}
