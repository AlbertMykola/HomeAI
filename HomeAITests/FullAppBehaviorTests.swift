import XCTest
import UIKit
@testable import HomeAI

@MainActor
final class FullAppBehaviorTests: XCTestCase {
    override func setUpWithError() throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        AppQA.clearEvents()
        AppQA.premium = false
        AppQA.freeCount = 0
        AppQA.language = "en"
        AppQA.generationService = QAGenerationService(delay: 1_000_000)
        UserDefaults.standard.removePersistentDomain(forName: "com.albert.apps.design.ai.qa.review")
    }

    override func tearDown() {
        AppQA.language = nil
        AppQA.reduceMotion = nil
        AppQA.generationService = QAGenerationService()
        super.tearDown()
    }

    func testOnboardingCountsOnlyVisiblePagesAndDoesNotRepeatOnReentry() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let pager = AppStoryboard.instantiate(OBPageViewController.self)
        let host = QASnapshotHost()
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.show(pager)
        window.layoutIfNeeded()
        defer { window.isHidden = true }
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(steps, [1], "Preloading O2 must not count as a view")
        pager.obChildRequestsNext(try XCTUnwrap(pager.children.first))
        try await Task.sleep(nanoseconds: 700_000_000)
        XCTAssertEqual(steps, [1, 2])
        for _ in 0..<2 {
            let page = try XCTUnwrap(pager.children.first { ($0 as? OnboardingPageViewController)?.page.rawValue == pager.currentIndex })
            pager.obChildRequestsNext(page)
            try await Task.sleep(nanoseconds: 700_000_000)
        }
        XCTAssertEqual(steps, [1, 2, 3, 4])
        pager.beginAppearanceTransition(false, animated: false); pager.endAppearanceTransition()
        pager.beginAppearanceTransition(true, animated: false); pager.endAppearanceTransition()
        XCTAssertEqual(steps, [1, 2, 3, 4])
    }

    func testFirstGeneratedResultRequestsRatingOnceAcrossRelaunch() async throws {
        XCTAssertFalse(RatePrompt.consumeRequest(for: AppQA.fixtureDocID), "Opening existing history must not ask for a rating")
        let runner = makeRunner()
        let saved = expectation(description: "first generated image saved")
        var docID: String?
        runner.onStateChange = { state in
            if case .succeeded(let outcome) = state { docID = outcome.docID; saved.fulfill() }
        }
        runner.start()
        await fulfillment(of: [saved], timeout: 10)
        let id = try XCTUnwrap(docID)
        let reopened = try XCTUnwrap(UserDefaults(suiteName: "com.albert.apps.design.ai.qa.review"))
        XCTAssertFalse(RatePrompt.consumeRequest(for: "another-result", defaults: reopened))
        XCTAssertTrue(RatePrompt.consumeRequest(for: id, defaults: reopened))
        XCTAssertFalse(RatePrompt.consumeRequest(for: id, defaults: reopened))
        RatePrompt.recordSuccessfulGeneration(docID: "second-result", defaults: reopened)
        XCTAssertFalse(RatePrompt.consumeRequest(for: "second-result", defaults: reopened))
        try await ProjectStore.shared.deleteProject(containing: id)
    }

    func testSuccessfulGenerationConsumesOneCreditAndHasOneCorrelatedOutcome() async throws {
        let runner = makeRunner()
        let done = expectation(description: "saved generation")
        var docID: String?
        runner.onStateChange = { state in
            if case .succeeded(let outcome) = state { docID = outcome.docID; done.fulfill() }
        }
        runner.start()
        runner.start() // A rapid second tap must not start another attempt.
        await fulfillment(of: [done], timeout: 10)
        XCTAssertEqual(AppQA.freeCount, 1)
        assertCorrelatedOutcome("generation_succeeded")
        XCTAssertNotNil(docID.flatMap { ProjectStore.shared.project(containing: $0) })
        if let docID { try await ProjectStore.shared.deleteProject(containing: docID) }
    }

    func testFailureKeepsCreditAndRetryUsesNewAttemptID() async throws {
        AppQA.generationService = QAGenerationService(delay: 1_000_000, failure: "server")
        let runner = makeRunner()
        let failed = expectation(description: "failed generation")
        runner.onStateChange = { if case .failed = $0 { failed.fulfill() } }
        runner.start()
        await fulfillment(of: [failed], timeout: 5)
        let failedID = runner.attemptID
        XCTAssertEqual(AppQA.freeCount, 0)
        assertCorrelatedOutcome("generation_failed")
        AppQA.generationService = QAGenerationService(delay: 1_000_000)
        let retried = expectation(description: "retry saved")
        var docID: String?
        runner.onStateChange = { if case .succeeded(let outcome) = $0 { docID = outcome.docID; retried.fulfill() } }
        runner.retry()
        await fulfillment(of: [retried], timeout: 10)
        XCTAssertNotEqual(runner.attemptID, failedID)
        XCTAssertEqual(AppQA.freeCount, 1)
        let retry = try XCTUnwrap(AppQA.events.first { $0["name"] as? String == "generation_retry" })
        XCTAssertEqual((retry["properties"] as? [String: Any])?["previous_attempt_id"] as? String, failedID)
        if let docID { try await ProjectStore.shared.deleteProject(containing: docID) }
    }

    func testCancellationHasNoSuccessOrCreditCharge() async throws {
        AppQA.generationService = QAGenerationService(delay: 5_000_000_000)
        let runner = makeRunner()
        let stopped = expectation(description: "cancelled attempt reached idle")
        runner.onStateChange = { if case .idle = $0 { stopped.fulfill() } }
        runner.start()
        try await Task.sleep(nanoseconds: 50_000_000)
        runner.cancel()
        await fulfillment(of: [stopped], timeout: 8)
        XCTAssertEqual(AppQA.freeCount, 0)
        assertCorrelatedOutcome("generation_cancelled")
        XCTAssertFalse(AppQA.events.contains { $0["name"] as? String == "generation_succeeded" })
    }

    func testCreditGateHasBlockedOutcomeAndNoCharge() {
        AppQA.freeCount = 2
        let runner = makeRunner()
        runner.start()
        guard case .blocked(.requiresSubscription) = runner.state else { return XCTFail("Expected credit gate") }
        assertCorrelatedOutcome("generation_blocked")
        XCTAssertEqual(AppQA.freeCount, 2)
    }

    func testReduceMotionClearsAnInterruptedEntranceTransform() async throws {
        AppQA.reduceMotion = true
        let view = UIView()
        view.transform = CGAffineTransform(translationX: 18, y: 24).scaledBy(x: 0.6, y: 0.6)
        DS.Motion.enter(view, delay: 0, dy: 12, scale: 0.8, spring: true)
        try await Task.sleep(nanoseconds: 350_000_000)
        XCTAssertEqual(view.transform, .identity)
        XCTAssertEqual(view.alpha, 1, accuracy: 0.01)
    }

    func testPaywallScalingIsStableAcrossWindowResizes() throws {
        let controller = ProPaywallViewController.make(placement: "qa", source: "qa", onPurchase: nil)
        controller.loadViewIfNeeded()
        func labels(_ view: UIView) -> [UILabel] {
            (view as? UILabel).map { [$0] } ?? view.subviews.flatMap(labels)
        }
        let title = try XCTUnwrap(labels(controller.view).first { $0.text == "Ready to go PRO?" })
        let restore = try XCTUnwrap(labels(controller.view).first { $0.text == "Restore" })
        let sizes = [CGSize(width: 393, height: 852), CGSize(width: 402, height: 874), CGSize(width: 466, height: 678), CGSize(width: 669, height: 951),
                     CGSize(width: 820, height: 1180), CGSize(width: 393, height: 852)]
        for size in sizes {
            controller.view.frame = CGRect(origin: .zero, size: size)
            for _ in 0..<3 { controller.view.setNeedsLayout(); controller.view.layoutIfNeeded() }
            XCTAssertEqual(title.font.pointSize, 31 * OnboardingLayout(size: size).scale, accuracy: 0.01)
            XCTAssertGreaterThan(title.bounds.width, 200)
            XCTAssertGreaterThanOrEqual(restore.bounds.height + 1, restore.sizeThatFits(CGSize(width: restore.bounds.width, height: .greatestFiniteMagnitude)).height)
        }
    }

    func testMaterialPickerAnalyticsUsesSerializablePlacement() throws {
        for (placement, name) in [(SurfaceMaterialOption.Placement.floor, "floor"), (.wall, "wall")] {
            let properties = try XCTUnwrap(AmpitudeEvent.showSurfaceMaterialPicker(type: placement).properties)
            XCTAssertTrue(JSONSerialization.isValidJSONObject(properties))
            XCTAssertEqual(properties["type"] as? String, name)
        }
    }

    func testReferenceCatalogDecodesTheSameIdeasAsTheFeed() throws {
        let categories = try InspirationDataProvider.shared.loadInspirationsFromBundle()
        let images = Set(categories.flatMap { $0.items.map(\.image) })
        XCTAssertGreaterThan(images.count, 40)
        XCTAssertEqual(images, Set(InspirationFeed.load().map(\.image)))
    }

    private var steps: [Int] {
        AppQA.events.filter { $0["name"] as? String == "onboarding_step" }
            .compactMap { ($0["properties"] as? [String: Any])?["step"] as? Int }
    }

    private func makeRunner() -> GenerationRunner {
        let manager = GemeniPromptManager()
        manager.updateOption(.interior)
        manager.updateBaseImage(AppQA.original)
        manager.updateRoom(.livingroom)
        manager.updateStyle(.interior(.modern))
        return GenerationRunner(promptManager: manager)
    }

    private func assertCorrelatedOutcome(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let starts = AppQA.events.filter { $0["name"] as? String == "generation_started" }
        let ends = AppQA.events.filter { $0["name"] as? String == name }
        XCTAssertEqual(starts.count, 1, file: file, line: line)
        XCTAssertEqual(ends.count, 1, file: file, line: line)
        let startID = (starts.first?["properties"] as? [String: Any])?["attempt_id"] as? String
        let endID = (ends.first?["properties"] as? [String: Any])?["attempt_id"] as? String
        XCTAssertNotNil(startID, file: file, line: line)
        XCTAssertEqual(startID, endID, file: file, line: line)
        let payloads = AppQA.events.compactMap { $0["properties"] as? [String: Any] }
        XCTAssertFalse(payloads.contains { $0["prompt"] != nil || $0["message"] != nil }, "QA must not put user content in funnel analytics", file: file, line: line)
    }
}
