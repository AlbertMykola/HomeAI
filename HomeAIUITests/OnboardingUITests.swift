import XCTest

final class OnboardingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch(page: Int = 0, language: String = "en", animated: Bool = false) {
        app.launchEnvironment["REHOMELY_FULL_QA"] = "0"
        app.launchArguments = ["--onboarding-preview", "--onboarding-page", String(page),
                               "-AppleLanguages", "(\(language))", "-AppleLocale", language.replacingOccurrences(of: "-", with: "_")]
        if !animated { app.launchArguments.append("--onboarding-still") }
        app.launch()
    }

    private func tap(_ identifier: String) {
        let candidates = app.descendants(matching: .any).matching(identifier: identifier)
        let ready = NSPredicate { _, _ in candidates.allElementsBoundByIndex.contains(where: \.isHittable) }
        expectation(for: ready, evaluatedWith: app)
        waitForExpectations(timeout: 8)
        candidates.allElementsBoundByIndex.first(where: \.isHittable)!.tap()
    }

    private func capture(_ name: String) {
        // UIScrollView's contentOffset animation can still be moving when a label becomes hittable.
        // Capture only after its delegate has settled the pager.
        let pager = app.otherElements.matching(NSPredicate(format: "identifier BEGINSWITH 'onboarding.page.' OR identifier == 'onboarding.completed'")).firstMatch
        XCTAssertTrue(pager.waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertCompleted() {
        XCTAssertTrue(app.otherElements["onboarding.completed"].waitForExistence(timeout: 5))
    }

    private func waitForPage(_ index: Int) {
        XCTAssertTrue(app.otherElements["onboarding.page.\(index)"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["onboarding.skip"].exists)
        XCTAssertFalse(app.buttons["onboarding.goal.skip"].exists)
    }

    private func assertHeroFillsPager(_ page: String) -> XCUIElement {
        let hero = app.otherElements["onboarding.hero.\(page)"]
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        let pager = app.scrollViews.firstMatch
        XCTAssertTrue(pager.exists)
        XCTAssertEqual(hero.frame.width, pager.frame.width, accuracy: 1, "Embedded hero must use the entire safe viewport")
        XCTAssertEqual(hero.frame.minX, pager.frame.minX, accuracy: 1)
        XCTAssertEqual(hero.frame.height, pager.frame.height, accuracy: 1)
        XCTAssertEqual(hero.frame.minY, pager.frame.minY, accuracy: 1)
        print("ONBOARDING_GEOMETRY page=\(page) pager=\(pager.frame) hero=\(hero.frame)")
        return hero
    }

    func testContinueThroughFourSteps() {
        launch()
        _ = assertHeroFillsPager("room")
        capture("O1-room")
        tap("onboarding.continue")
        waitForPage(1)
        XCTAssertTrue(app.staticTexts["One app, 11 AI tools"].isHittable)
        capture("O2-tools")
        // The app's centre can fall on the pager's text panel on compact screens.
        // Exercise the carousel in the visible hero, then verify that it really moved.
        let hero = assertHeroFillsPager("tools")
        let walls = app.staticTexts["Paint walls"].firstMatch
        XCTAssertTrue(walls.waitForExistence(timeout: 5))
        let originalX = walls.frame.midX
        hero.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.28))
            .press(forDuration: 0.01,
                   thenDragTo: hero.coordinate(withNormalizedOffset: CGVector(dx: 0.28, dy: 0.28)),
                   withVelocity: .fast, thenHoldForDuration: 0)
        waitForPage(1)
        let floor = app.staticTexts["New floor"].firstMatch
        let moved = NSPredicate { _, _ in
            floor.exists && hero.frame.contains(floor.frame)
                && (!walls.exists || walls.frame.midX < originalX - 20)
        }
        expectation(for: moved, evaluatedWith: app); waitForExpectations(timeout: 8)
        capture("O2-tools-carousel-swiped")
        tap("onboarding.continue")
        waitForPage(2)
        _ = assertHeroFillsPager("words")
        waitForPage(2)
        capture("O3-words")
        tap("onboarding.continue")
        waitForPage(3)
        XCTAssertTrue(app.staticTexts["What are we redesigning?"].isHittable)
        capture("O4-goal")
        tap("onboarding.goal.exterior")
        capture("O4-selected")
        assertCompleted()
    }

    func testEveryGoalChoice() {
        for goal in ["interior", "exterior", "garden", "surfaces"] {
            launch(page: 3)
            waitForPage(3)
            tap("onboarding.goal.\(goal)")
            assertCompleted()
        }
    }

    func testNoSkipOnAnyStepAndGoalSelectionCompletesOnboarding() {
        launch()
        waitForPage(0)
        for index in 1...3 {
            tap("onboarding.continue")
            waitForPage(index)
        }
        XCTAssertFalse(app.otherElements["onboarding.completed"].exists)
        tap("onboarding.goal.interior")
        assertCompleted()
    }

    func testUkrainianLayoutAndFlow() {
        launch(language: "uk")
        capture("uk-O1")
        tap("onboarding.continue")
        capture("uk-O2")
        tap("onboarding.continue")
        capture("uk-O3")
        tap("onboarding.continue")
        capture("uk-O4")
        tap("onboarding.goal.surfaces")
        assertCompleted()
    }

    func testAnimatedComparisonAndBackSwipe() {
        launch(animated: true)
        let hero = app.otherElements["onboarding.hero.room"]
        XCTAssertTrue(hero.waitForExistence(timeout: 5))
        let handle = app.otherElements["onboarding.comparison.handle"]
        let ready = NSPredicate { _, _ in handle.isHittable }
        expectation(for: ready, evaluatedWith: app)
        waitForExpectations(timeout: 8)
        handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: hero.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.35)))
        capture("O1-dragged")
        tap("onboarding.continue")
        capture("O2-animated")
        tap("onboarding.continue")
        capture("O3-animated")
        app.swipeRight()
        waitForPage(1)
        XCTAssertTrue(app.staticTexts["One app, 11 AI tools"].isHittable)
        tap("onboarding.continue")
        waitForPage(2)
        tap("onboarding.continue")
        waitForPage(3)
        tap("onboarding.goal.interior")
        assertCompleted()
    }

    func testEveryShippedLanguageCanCompleteOnboarding() {
        for language in ["cs", "da", "de", "en", "es", "fr", "it", "ja", "ko", "nb", "nl", "pl", "pt-BR", "ru", "uk"] {
            launch(language: language)
            waitForPage(0)
            capture("\(language)-native-bundle-O1")
            for index in 1...3 {
                tap("onboarding.continue")
                waitForPage(index)
            }
            capture("\(language)-native-bundle-O4")
            tap("onboarding.goal.interior")
            assertCompleted()
        }
    }
}
