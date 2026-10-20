import XCTest

final class LocalGenerationFlowUITests: XCTestCase {
    private let app = XCUIApplication()

    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ screen: String, extra: [String] = []) {
        app.launchArguments = ["--app-qa", "--qa-screen", screen, "--qa-language", "en", "--qa-premium",
                               "--qa-dark", "--qa-generation-delay", "2", "-AppleLanguages", "(en)", "-AppleLocale", "en"] + extra
        app.launch()
    }

    private func tap(_ identifier: String, at offset: CGVector? = nil) {
        let matches = app.descendants(matching: .any).matching(identifier: identifier)
        let ready = NSPredicate { _, _ in matches.allElementsBoundByIndex.contains(where: \.isHittable) }
        expectation(for: ready, evaluatedWith: app); waitForExpectations(timeout: 12)
        let element = matches.allElementsBoundByIndex.first(where: \.isHittable)!
        if let offset { element.coordinate(withNormalizedOffset: offset).tap() }
        else { element.tap() }
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func assertVersion(_ number: Int) {
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Version \(number) ·")).firstMatch.waitForExistence(timeout: 20))
    }

    func testGenerateCompareEditShareAndReopenPersistedProject() {
        launch("wizard-final")
        tap("didTapGenerate:0")
        XCTAssertTrue(app.staticTexts["Creating your design"].waitForExistence(timeout: 8))
        capture("Local-generation-scanning")
        XCTAssertTrue(app.buttons["didTapShare:0"].waitForExistence(timeout: 20))
        assertVersion(1)
        capture("Local-generation-result-v1")

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.28)).tap()
        XCTAssertTrue(app.buttons["didTapFit:0"].waitForExistence(timeout: 10))
        for segment in [0, 2, 1] { tap("didTapSegment:\(segment)") }
        let center = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        center.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.4)))
        capture("Local-generation-compare-drag")
        // Duo's simulator PointerUI time/Wi-Fi panel covers the centre of Fit.
        // Tap its visible upper edge so SpringBoard does not open Control Center.
        tap("didTapFit:0")
        XCTAssertTrue(app.buttons["didTapClose:0"].exists)
        capture("Local-compare-after-fit")
        tap("didTapClose:0")
        capture("Local-result-after-compare-close")

        tap("didTapTool:1")
        XCTAssertTrue(app.staticTexts["Paint walls"].waitForExistence(timeout: 10))
        tap("didTapSwatch:2"); tap("didTapApply:0")
        assertVersion(2)
        capture("Local-generation-painted-v2")
        tap("didTapShare:0")
        XCTAssertTrue(app.staticTexts["Share your redesign"].waitForExistence(timeout: 10))
        for format in [0, 1, 2] {
            tap("didTapFormat:\(format)")
            capture("Local-export-format-\(format)")
        }
        let exportScroll = app.scrollViews.containing(.button, identifier: "didTapQuickAction:1").firstMatch
        exportScroll.swipeUp()
        let share = exportScroll.buttons["didTapShare:0"]
        XCTAssertTrue(share.isHittable)
        XCTAssertLessThanOrEqual(share.frame.maxY, app.frame.maxY)
        capture("Local-export-actions-reachable")
        tap("didTapQuickAction:1") // Real local clipboard export; no external sharing.
        // Dismiss through the native grabber: Duo's PointerUI also obscures this sheet's close control.
        let close = app.buttons["didTapClose:0"]
        let origin = app.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: app.frame.width / 2, dy: close.frame.minY - 8))
            .press(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: app.frame.width / 2, dy: app.frame.height - 20)))
        tap("didTapBack:0")
        // A new process must read the just-created files and project membership.
        launch("projects")
        let project = app.collectionViews.cells.matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "Modern", "2 versions")).firstMatch
        XCTAssertTrue(project.waitForExistence(timeout: 12))
        project.tap()
        XCTAssertTrue(app.buttons["didTapContinue:0"].waitForExistence(timeout: 10))
        capture("Local-project-reopened-versions")
        tap("didTapContinue:0")
        assertVersion(2)
        capture("Local-result-reopened-from-disk")
    }

    func testFailureRetryAndCollapsedGenerationReachSavedResults() {
        launch("wizard-final", extra: ["--qa-generation-failure", "server", "--qa-generation-fail-once"])
        tap("didTapGenerate:0")
        XCTAssertTrue(app.staticTexts["Something went wrong"].waitForExistence(timeout: 15))
        capture("Local-generation-error")
        tap("didTapFailurePrimary:0")
        XCTAssertTrue(app.buttons["didTapShare:0"].waitForExistence(timeout: 20))
        assertVersion(1)
        capture("Local-generation-retry-success")

        // XCTest waits for continuous UIKit scan animations before synthesizing taps.
        // The normal animation is exercised above; Reduce Motion lets this test tap while G1 runs.
        launch("wizard-final", extra: ["--qa-generation-delay", "12", "--qa-reduce-motion"])
        tap("didTapGenerate:0")
        tap("didTapCollapse:0")
        XCTAssertTrue(app.buttons["didTapGenerate:0"].waitForExistence(timeout: 10))
        // Completion updates Projects even though G1 has been dismissed.
        XCTAssertTrue(app.staticTexts["Your design is ready"].waitForExistence(timeout: 15))
        capture("Local-generation-collapsed-ready")
        let open = app.staticTexts["Open"]
        XCTAssertTrue(open.waitForExistence(timeout: 5)); open.tap()
        XCTAssertTrue(app.buttons["didTapShare:0"].waitForExistence(timeout: 10))
        assertVersion(1)
        capture("Local-generation-collapsed-opened")
    }
}
