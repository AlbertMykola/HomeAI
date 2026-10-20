import XCTest
import UIKit
@testable import HomeAI

@MainActor
final class PresentationCopyRegressionTests: XCTestCase {
    private let languages = ["cs", "da", "de", "en", "es", "fr", "it", "ja", "ko", "nb", "nl", "pl", "pt-BR", "ru", "uk"]

    func testAssistantAndProjectsAreHiddenBeforeTheirFirstEntranceAndDoNotReplay() async throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        AppQA.seed(); AppQA.snapshot = false
        defer { AppQA.reduceMotion = nil; AppQA.emptyProjects = false }
        for reduced in [false, true] {
            AppQA.reduceMotion = reduced
            for screen in ["assistant", "projects", "projects-empty", "inspiration", "project-detail"] {
                AppQA.emptyProjects = screen == "projects-empty"
                let window = try makeWindow(), host = QASnapshotHost()
                window.rootViewController = host; window.makeKeyAndVisible()
                let controller: UIViewController
                switch screen {
                case "assistant": controller = AssistantViewController.make()
                case "inspiration": controller = AppStoryboard.instantiate(InspirationFeedViewController.self)
                case "project-detail": controller = AppQA.makeScreen(screen)
                default: controller = AppStoryboard.instantiate(ProjectsViewController.self)
                }
                host.addChild(controller); controller.loadViewIfNeeded()
                controller.beginAppearanceTransition(true, animated: true)
                controller.view.frame = host.view.bounds; host.view.addSubview(controller.view); controller.didMove(toParent: host)
                window.layoutIfNeeded()
                let keys: [String]
                switch screen {
                case "assistant": keys = ["navView", "composerView", "greetingTitleLabel"]
                case "project-detail": keys = ["tableView", "continueButton"]
                case "inspiration": keys = ["largeTitleLabel", "searchButton"]
                default: keys = ["largeTitleLabel", "collectionView"]
                }
                let views = try keys.map { try XCTUnwrap(controller.value(forKey: $0) as? UIView) }
                for view in views { XCTAssertEqual(view.alpha, 0, "\(screen) must be prepared before the first visible frame") }
                controller.endAppearanceTransition()
                try await Task.sleep(nanoseconds: 1_500_000_000)
                for view in views { XCTAssertEqual(view.alpha, 1) }
                controller.beginAppearanceTransition(false, animated: false); controller.endAppearanceTransition()
                controller.beginAppearanceTransition(true, animated: false)
                for view in views { XCTAssertEqual(view.alpha, 1, "\(screen) must not replay its entrance") }
                controller.endAppearanceTransition(); window.isHidden = true
            }
        }
    }

    func testProfileIsPreparedBeforeItsFirstVisibleFrameAndDoesNotReplay() async throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        AppQA.seed(); AppQA.language = "uk"; AppQA.snapshot = false; AppQA.premium = false; AppQA.freeCount = 1
        let window = try makeWindow()
        defer { window.isHidden = true; AppQA.language = nil; AppQA.freeCount = 0; AppQA.premium = false }
        let host = QASnapshotHost()
        window.rootViewController = host
        window.makeKeyAndVisible()
        await Task.yield()
        let profile = AppStoryboard.instantiate(ProfileTabViewController.self)
        host.addChild(profile)
        profile.loadViewIfNeeded()
        profile.beginAppearanceTransition(true, animated: true)
        profile.view.frame = host.view.bounds
        host.view.addSubview(profile.view)
        profile.didMove(toParent: host)
        window.layoutIfNeeded()
        let scroll = try XCTUnwrap(walk(profile.view).compactMap { $0 as? UIScrollView }.first)
        scroll.delegate?.scrollViewDidScroll?(scroll)
        let heading = try XCTUnwrap(walk(profile.view).compactMap { $0 as? UILabel }.first { $0.text == "Profile".localized })
        XCTAssertEqual(heading.alpha, 0, "Initial scroll layout must not reveal the heading before entrance")
        let title = try XCTUnwrap(walk(profile.view).compactMap { $0 as? UILabel }.first { $0.text == "Free plan".localized })
        let card = try XCTUnwrap(ancestors(title).first { $0 is DSView })
        XCTAssertEqual(card.alpha, 0, "The screen must not appear once before its entrance starts")
        profile.endAppearanceTransition()
        try await Task.sleep(nanoseconds: 1_500_000_000)
        XCTAssertEqual(card.alpha, 1)
        profile.beginAppearanceTransition(false, animated: false); profile.endAppearanceTransition()
        profile.beginAppearanceTransition(true, animated: false)
        XCTAssertEqual(card.alpha, 1, "Returning to Profile must not hide it again")
        profile.endAppearanceTransition()
        XCTAssertFalse(walk(profile.view).compactMap { $0 as? DSPressableControl }.contains { $0.actionName == "didTapRow:" && $0.tag == 4 })
    }

    func testTipsPlanCardsAndGenerationCopyAcrossLanguagesAndThemes() async throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        AppQA.seed(); AppQA.snapshot = true; AppQA.freeCount = FreeGenerationManager.shared.limit
        let window = try makeWindow()
        let host = QASnapshotHost()
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; AppQA.snapshot = false; AppQA.language = nil; AppQA.premium = false; AppQA.freeCount = 0 }
        var visited = 0
        var generationChecks = 0
        let generationModes: [Bool] = ProcessInfo.processInfo.environment["REHOMELY_QA_SKIP_GENERATION_COPY"] == "1" ? [] : [false, true]
        for dark in [false, true] {
            window.overrideUserInterfaceStyle = dark ? .dark : .light
            for language in languages {
                AppQA.language = language
                for screen in ["profile", "profile-pro", "photo-tips"] {
                    let vc = AppQA.makeScreen(screen)
                    host.show(AppQA.container(for: vc))
                    window.layoutIfNeeded()
                    try await Task.sleep(nanoseconds: 50_000_000)
                    window.layoutIfNeeded()
                    let root = host.presentedViewController?.view ?? vc.view!
                    let texts = screen == "photo-tips"
                        ? ["Get the best result", "Wide & bright", "Too close / dark", "Turn on the lights or shoot by day", "Step back, show the whole room", "Hold the phone level, at chest height", "Clutter is fine, we'll handle it"]
                        : (screen == "profile" ? ["Free plan", "No free designs left"] : ["Rehomely Pro", "Unlimited designs"])
                    for text in texts {
                        let label = try XCTUnwrap(walk(root).compactMap { $0 as? UILabel }.first { $0.text == text.localized }, "Missing \(screen)/\(language)/\(text)")
                        assertFullText(label, context: "\(screen)/\(language)/\(text)")
                    }
                    if screen == "profile" {
                        XCTAssertFalse(walk(root).compactMap { $0 as? DSPressableControl }.contains { $0.actionName == "didTapRow:" && $0.tag == 4 })
                        let cta = try XCTUnwrap(walk(root).compactMap { $0 as? DSPressableControl }.first { $0.actionName == "didTapGetPro:" })
                        for label in walk(cta).compactMap({ $0 as? UILabel }) {
                            label.text = String(format: "Get Pro · %@ / year".localized, "49,99 USD")
                            window.layoutIfNeeded()
                            assertFullText(label, context: "Profile price/\(language)")
                            XCTAssertLessThanOrEqual(label.bounds.height, cta.bounds.height - 8)
                        }
                    }
                    if screen == "profile-pro", let label = walk(root).compactMap({ $0 as? UILabel }).first(where: { $0.text == "Unlimited designs".localized }) {
                        label.text = String(format: "Unlimited designs · renews %@".localized, "31.12.2027")
                        window.layoutIfNeeded()
                        assertFullText(label, context: "Pro renewal/\(language)")
                    }
                    if screen == "photo-tips" {
                        let button = try XCTUnwrap(walk(root).compactMap { $0 as? DSPrimaryButton }.first)
                        let scroll = try XCTUnwrap(walk(root).compactMap { $0 as? UIScrollView }.first)
                        let bottom = max(0, scroll.contentSize.height - scroll.bounds.height)
                        scroll.setContentOffset(CGPoint(x: 0, y: bottom), animated: false)
                        XCTAssertTrue(root.bounds.contains(button.convert(button.bounds, to: root)), "Tips CTA must be reachable: \(language)")
                    }
                    if language == "uk" {
                        let attachment = XCTAttachment(image: UIGraphicsImageRenderer(bounds: window.bounds).image { window.layer.render(in: $0.cgContext) })
                        attachment.name = "Polish-\(screen)-\(dark ? "dark" : "light")"
                        attachment.lifetime = .keepAlways; add(attachment)
                    }
                    visited += 1
                    await host.closePresentation(); host.clear()
                }
                // Exercise every Generate screen's real localized subtitle, in both entitlement states.
                for premium in generationModes {
                    AppQA.premium = premium
                    for screen in ["tool-exterior", "tool-garden", "tool-reference", "tool-walls", "tool-floor", "tool-furnish", "tool-floorplan", "tool-rearrange", "wizard-final"] {
                        let vc = AppQA.makeScreen(screen)
                        AppQA.premium = premium
                        host.show(AppQA.container(for: vc))
                        window.layoutIfNeeded()
                        let seconds = screen == "tool-floorplan" ? 60 : 30
                        let expected = String(format: "About %d s".localized, seconds)
                        let labels = walk(vc.view).compactMap { $0 as? UILabel }
                        XCTAssertTrue(labels.contains { $0.text == expected }, "\(screen)/\(language)/Pro \(premium) must show duration only")
                        generationChecks += 1
                        host.clear()
                    }
                }
            }
        }
        let report = ["device": UIDevice.current.name, "window": "\(window.bounds.size)", "copyStates": visited, "generationStates": generationChecks] as [String: Any]
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted]).write(to: AppQA.storageURL.appendingPathComponent("presentation-copy.json"))
    }

    func testEditingActionsShowDurationForFreeAndPro() async throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        let retryKey = "redesign_free_retry_used_on"
        let previousRetry = UserDefaults.standard.object(forKey: retryKey)
        AppQA.seed(); AppQA.snapshot = true
        UIView.setAnimationsEnabled(false)
        let window = try makeWindow(), host = QASnapshotHost()
        window.rootViewController = host; window.makeKeyAndVisible()
        defer {
            window.isHidden = true; AppQA.snapshot = false; AppQA.language = nil; AppQA.premium = false
            if let previousRetry { UserDefaults.standard.set(previousRetry, forKey: retryKey) }
            else { UserDefaults.standard.removeObject(forKey: retryKey) }
            UIView.setAnimationsEnabled(true)
        }
        var states = 0
        let actions = [("paint", "applyLabel", "Apply"), ("replace", "applyLabel", "Replace"),
                       ("remove", "applyLabel", "Remove"), ("change-style", "restyleLabel", "Restyle"),
                       ("dislike", "sendRetryLabel", "Send & try again")]
        for dark in [false, true] {
            window.overrideUserInterfaceStyle = dark ? .dark : .light
            for language in languages {
                AppQA.language = language
                for premium in [false, true] {
                    for (screen, labelKey, title) in actions {
                        // Exercise both feedback branches without performing or charging a retry.
                        for freeRetry in (screen == "dislike" ? [false, true] : [false]) {
                            if freeRetry { UserDefaults.standard.removeObject(forKey: retryKey) }
                            else { UserDefaults.standard.set(Date(), forKey: retryKey) }
                            let content = AppQA.makeScreen(screen)
                            AppQA.premium = premium
                            host.show(AppQA.container(for: content)); window.layoutIfNeeded()
                            try await Task.sleep(nanoseconds: 40_000_000); window.layoutIfNeeded()
                            let visible = host.presentedViewController ?? content
                            let label = try XCTUnwrap(visible.value(forKey: labelKey) as? UILabel)
                            XCTAssertEqual(label.text, title.localized + " · " + String(format: "About %d s".localized, 30),
                                           "\(screen)/\(language)/Pro \(premium)/free retry \(freeRetry)")
                            if screen == "dislike" {
                                let note = try XCTUnwrap(visible.value(forKey: "freeRetryView") as? UIView)
                                XCTAssertEqual(note.isHidden, !freeRetry)
                            }
                            assertFullText(label, context: "\(screen)/\(language)")
                            states += 1
                            await host.closePresentation(); host.clear()
                        }
                    }
                }
            }
        }
        XCTAssertEqual(states, 360)
        try JSONSerialization.data(withJSONObject: ["device": UIDevice.current.name, "states": states], options: [.prettyPrinted])
            .write(to: AppQA.storageURL.appendingPathComponent("editing-duration.json"))
    }

    func testAssistantMessagesRemainReadableBelowTheHeaderAcrossLanguagesAndThemes() async throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        AppQA.seed(); AppQA.snapshot = true
        let window = try makeWindow(), host = QASnapshotHost()
        window.rootViewController = host; window.makeKeyAndVisible()
        defer { window.isHidden = true; AppQA.snapshot = false; AppQA.language = nil }
        var states = 0, minimumClearance = CGFloat.greatestFiniteMagnitude
        for dark in [false, true] {
            window.overrideUserInterfaceStyle = dark ? .dark : .light
            for language in languages {
                AppQA.language = language
                for screen in ["assistant-typing", "assistant-reply", "assistant-failed"] {
                    let content = AppQA.makeScreen(screen)
                    host.show(AppQA.container(for: content)); window.layoutIfNeeded()
                    try await Task.sleep(nanoseconds: 60_000_000); window.layoutIfNeeded()
                    let fade = try XCTUnwrap(content.value(forKey: "headerFadeView") as? UIView)
                    let cell = try XCTUnwrap(walk(content.view).compactMap { $0 as? AssistantUserCell }.first)
                    let label = try XCTUnwrap(cell.value(forKey: "messageLabel") as? UILabel)
                    XCTAssertEqual(label.text, "Ideas for a cozy bedroom".localized)
                    let clearance = label.convert(label.bounds, to: content.view).minY - fade.convert(fade.bounds, to: content.view).maxY
                    minimumClearance = min(minimumClearance, clearance)
                    XCTAssertGreaterThanOrEqual(clearance, -1, "Header fade covers user text: \(screen)/\(language)")
                    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                    XCTAssertTrue(label.textColor.resolvedColor(with: window.traitCollection).getRed(&red, green: &green, blue: &blue, alpha: &alpha))
                    XCTAssertEqual(red, 0, accuracy: 0.001); XCTAssertEqual(green, 0, accuracy: 0.001)
                    XCTAssertEqual(blue, 0, accuracy: 0.001); XCTAssertEqual(alpha, 1, accuracy: 0.001)
                    assertFullText(label, context: "Assistant user message/\(screen)/\(language)")
                    states += 1
                    host.clear()
                }
            }
        }
        XCTAssertEqual(states, 90)
        try JSONSerialization.data(withJSONObject: ["device": UIDevice.current.name, "states": states,
                                                   "minimumTextClearance": minimumClearance], options: [.prettyPrinted])
            .write(to: AppQA.storageURL.appendingPathComponent("assistant-readability.json"))
    }

    private func assertFullText(_ label: UILabel, context: String, file: StaticString = #filePath, line: UInt = #line) {
        let measure = UILabel(); measure.text = label.text; measure.font = label.font; measure.numberOfLines = 0
        let required = measure.sizeThatFits(CGSize(width: label.bounds.width, height: CGFloat.greatestFiniteMagnitude))
        XCTAssertGreaterThan(label.bounds.width, 0, context, file: file, line: line)
        XCTAssertLessThanOrEqual(required.height, label.bounds.height + 1, "Truncated: \(context)", file: file, line: line)
    }
    private func makeWindow() throws -> UIWindow {
        UIWindow(windowScene: try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first))
    }
    private func walk(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(walk) }
    private func ancestors(_ view: UIView) -> [UIView] { view.superview.map { [$0] + ancestors($0) } ?? [] }
}
