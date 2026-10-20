import XCTest

final class OnboardingReturningLaunchTests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(reset: Bool = false) {
        app.launchArguments = ["--app-qa", "--qa-launch-flow", "--qa-language", "en",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        if reset { app.launchArguments.append("--qa-reset-onboarding") }
        app.launch()
    }

    private func tap(_ identifier: String) {
        let candidates = app.descendants(matching: .any).matching(identifier: identifier)
        let ready = NSPredicate { _, _ in candidates.allElementsBoundByIndex.contains(where: \.isHittable) }
        expectation(for: ready, evaluatedWith: app)
        waitForExpectations(timeout: 10)
        candidates.allElementsBoundByIndex.first(where: \.isHittable)!.tap()
    }

    func testEveryGoalPersonalizesOnlyTheFirstLaunch() {
        let goals = [("interior", "Redesign a room"), ("exterior", "Redesign your exterior"),
                     ("garden", "Redesign your garden"), ("surfaces", "Refresh your surfaces")]
        for (goal, firstTitle) in goals {
            launch(reset: true)
            XCTAssertTrue(app.otherElements["onboarding.page.0"].waitForExistence(timeout: 10))
            for index in 1...3 {
                tap("onboarding.continue")
                XCTAssertTrue(app.otherElements["onboarding.page.\(index)"].waitForExistence(timeout: 8))
            }
            tap("onboarding.goal.\(goal)")
            let hero = app.staticTexts["home.hero.title"]
            XCTAssertTrue(hero.waitForExistence(timeout: 10))
            XCTAssertEqual(hero.label, firstTitle, goal)
            XCTAssertFalse(app.otherElements["onboarding.page.0"].exists)
            if goal == "surfaces" {
                // Interior must be the first available alternative, with reference still reachable.
                XCTAssertTrue(app.buttons["home.more.interior"].isHittable)
                let shot = XCTAttachment(screenshot: app.screenshot())
                shot.name = "Surfaces-first-Home-with-Interior"
                shot.lifetime = .keepAlways
                add(shot)
                let carousel = app.scrollViews["home.more.carousel"]
                XCTAssertTrue(carousel.exists)
                carousel.swipeLeft()
                XCTAssertTrue(app.buttons["home.more.reference"].isHittable)
                carousel.swipeRight()
                tap("home.more.interior")
                XCTAssertTrue(app.staticTexts["Add a photo of your room"].waitForExistence(timeout: 8))
            }
            app.terminate()
            launch()
            XCTAssertTrue(hero.waitForExistence(timeout: 10))
            XCTAssertEqual(hero.label, "Redesign a room", "Returning launch after \(goal)")
            XCTAssertFalse(app.otherElements["onboarding.page.0"].exists)
            XCTAssertFalse(app.buttons["onboarding.skip"].exists)
            app.terminate()
        }
        // Completion persists beyond a single relaunch.
        launch()
        XCTAssertTrue(app.staticTexts["home.hero.title"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["home.hero.title"].label, "Redesign a room")
        XCTAssertFalse(app.otherElements["onboarding.page.0"].exists)
    }
}
