import XCTest

/// Opt-in smoke test for the normal SDK startup and the real onboarding completion route.
/// The default UI suite stays offline. Enable REHOMELY_LIVE_SDK_QA in the test runner environment.
final class LiveOnboardingSDKTests: XCTestCase {
    func testCompleteOnboardingWithLiveSDKs() throws {
        guard ProcessInfo.processInfo.environment["REHOMELY_LIVE_SDK_QA"] == "1" else {
            throw XCTSkip("Requires an explicit live SDK QA run")
        }
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["REHOMELY_FULL_QA"] = "0"
        app.resetAuthorizationStatus(for: .userTracking)
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-skipLaunchPaywall", "-showOnboarding"]
        app.launch()

        // System permission prompts belong to SpringBoard, not the app's accessibility tree.
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        XCTAssertFalse(alert.waitForExistence(timeout: 8), "ATT must wait until O4 completes")
        for index in 1...3 {
            let next = app.buttons.matching(identifier: "onboarding.continue").allElementsBoundByIndex.first(where: \.isHittable)
            XCTAssertNotNil(next)
            next?.tap()
            XCTAssertTrue(app.otherElements["onboarding.page.\(index)"].waitForExistence(timeout: 8))
        }
        app.buttons["onboarding.goal.interior"].tap()
        if alert.waitForExistence(timeout: 8) {
            let prompt = XCTAttachment(screenshot: app.screenshot())
            prompt.name = "Live-SDK-ATT-after-O4"
            prompt.lifetime = .keepAlways
            add(prompt)
            let decline = alert.buttons.element(boundBy: 0)
            decline.tap()
            // Duo can still be animating the system alert when its button enters the AX tree.
            if !alert.waitForNonExistence(timeout: 3) { decline.tap() }
            XCTAssertTrue(alert.waitForNonExistence(timeout: 5))
        }

        let finished = NSPredicate { _, _ in !app.buttons["onboarding.goal.interior"].exists }
        expectation(for: finished, evaluatedWith: app)
        waitForExpectations(timeout: 30)
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(app.staticTexts["Ready to go PRO?"].waitForExistence(timeout: 15))
        let price = app.staticTexts["paywall.price"]
        let loadedPrice = NSPredicate { _, _ in
            price.exists && price.label.range(of: "[0-9][.,][0-9]{2}", options: .regularExpression) != nil
        }
        expectation(for: loadedPrice, evaluatedWith: app)
        waitForExpectations(timeout: 30)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Live-SDK-onboarding-completed"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
