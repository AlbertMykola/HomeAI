import XCTest
import UIKit
@testable import HomeAI

@MainActor
final class OnboardingLayoutTests: XCTestCase {
    func testPagerConsumesHorizontalSafeAreaOnlyOnceDuringTransitions() async throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        AppQA.seed()
        let previousLanguage = AppQA.language, previousSnapshot = AppQA.snapshot
        AppQA.language = "en"; AppQA.snapshot = true
        defer { AppQA.language = previousLanguage; AppQA.snapshot = previousSnapshot }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        var reports: [[String: Any]] = []
        for extra in [UIEdgeInsets.zero, UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 84),
                      UIEdgeInsets(top: 0, left: 42, bottom: 0, right: 0)] {
            let window = UIWindow(windowScene: scene), controller = AppStoryboard.instantiate(OBPageViewController.self)
            controller.additionalSafeAreaInsets = extra
            window.rootViewController = controller; window.makeKeyAndVisible()
            defer { window.isHidden = true }
            try await Task.sleep(nanoseconds: 80_000_000); window.layoutIfNeeded()
            let scroll = try XCTUnwrap(controller.view.subviews.first as? UIScrollView)
            var samples = 0, heroWidths: [CGFloat] = []
            func checkVisiblePages() {
                window.layoutIfNeeded()
                let visible = controller.view.safeAreaLayoutGuide.layoutFrame
                for page in controller.children {
                    let index = (page as? OnboardingPageViewController)?.page.rawValue ?? 3
                    XCTAssertEqual(page.view.frame.minX, scroll.bounds.width * CGFloat(index), accuracy: 1)
                    XCTAssertEqual(page.view.frame.minY, 0, accuracy: 1)
                    XCTAssertEqual(page.view.bounds.height, scroll.bounds.height, accuracy: 1,
                                   "Pages must not stretch when the decoded scroll view receives its first size")
                    let frame = page.view.convert(page.view.bounds, to: controller.view)
                    guard frame.intersection(visible).width > 1 else { continue }
                    XCTAssertEqual(page.view.bounds.width, scroll.bounds.width, accuracy: 1)
                    let guide = page.value(forKey: "horizontalViewportGuide") as? UILayoutGuide
                    XCTAssertNotNil(guide)
                    XCTAssertEqual(guide?.layoutFrame.width ?? 0, scroll.bounds.width, accuracy: 1, "Content must fill the pager's horizontal viewport")
                    XCTAssertEqual(guide?.layoutFrame.minX ?? -1, 0, accuracy: 1)
                    if let onboarding = page as? OnboardingPageViewController {
                        XCTAssertEqual(onboarding.heroView.bounds.width, scroll.bounds.width, accuracy: 1, "Hero must fill the usable pager width")
                        heroWidths.append(onboarding.heroView.bounds.width)
                    }
                    samples += 1
                }
            }
            for index in 0..<4 {
                XCTAssertEqual(controller.currentIndex, index)
                checkVisiblePages()
                guard index < 3 else { break }
                let page = try XCTUnwrap(controller.children.first { ($0 as? OnboardingPageViewController)?.page.rawValue == index })
                controller.obChildRequestsNext(page)
                let deadline = CACurrentMediaTime() + 3
                repeat {
                    try await Task.sleep(nanoseconds: 16_000_000)
                    checkVisiblePages()
                } while !controller.view.isUserInteractionEnabled && CACurrentMediaTime() < deadline
                XCTAssertTrue(controller.view.isUserInteractionEnabled)
                XCTAssertEqual(controller.view.accessibilityIdentifier, "onboarding.page.\(index + 1)")
            }
            XCTAssertGreaterThan(samples, 4)
            reports.append(["extraInsets": "\(extra)", "parentInsets": "\(controller.view.safeAreaInsets)",
                            "viewportWidth": scroll.bounds.width, "samples": samples,
                            "heroWidths": Array(Set(heroWidths)).sorted()])
        }
        try JSONSerialization.data(withJSONObject: ["device": UIDevice.current.name, "pages": reports.count * 4,
                                                   "scenarios": reports], options: [.prettyPrinted])
            .write(to: AppQA.storageURL.appendingPathComponent("onboarding-pager-safe-area.json"))
    }

    func testStoryboardToolAndGoalCaptionsRemainTransparent() throws {
        func labels(in view: UIView) -> [UILabel] {
            (view as? UILabel).map { [$0] } ?? view.subviews.flatMap { labels(in: $0) }
        }
        let tools = OnboardingPageViewController.make(page: .tools)
        tools.loadViewIfNeeded()
        let canvas = try XCTUnwrap(tools.heroView.subviews.first { $0.subviews.contains { $0 is OnboardingToolCard } })
        let captions = canvas.subviews.compactMap { $0 as? OnboardingToolCard }.flatMap { labels(in: $0) }
        XCTAssertEqual(captions.count, 5)
        let goals = AppStoryboard.instantiate(OnboardingGoalViewController.self)
        goals.loadViewIfNeeded()
        func goalTiles(in view: UIView) -> [OnboardingGoalControl] {
            (view as? OnboardingGoalControl).map { [$0] } ?? view.subviews.flatMap { goalTiles(in: $0) }
        }
        let goalCaptions = goalTiles(in: goals.view).flatMap { labels(in: $0) }
        XCTAssertEqual(goalCaptions.count, 8)
        for label in captions + goalCaptions {
            XCTAssertFalse(label.isOpaque, "Caption must not draw an opaque black rectangle")
            XCTAssertTrue(label.backgroundColor == nil || label.backgroundColor == .clear)
            XCTAssertFalse((label.text ?? "").isEmpty)
        }
    }

    func testLocalizedSubtitlesFitAfterPixelRounding() {
        let previous = AppQA.language
        defer { AppQA.language = previous }
        for language in ["cs", "da", "de", "en", "es", "fr", "it", "ja", "ko", "nb", "nl", "pl", "pt-BR", "ru", "uk"] {
            AppQA.language = language
            for page in [OnboardingPageViewController.Page.room, .tools, .words] {
                let controller = OnboardingPageViewController.make(page: page)
                controller.loadViewIfNeeded()
                for width in [375.0, 393, 402, 414, 430, 440, 466, 669, 744, 820, 1024] {
                    controller.view.frame = CGRect(x: 0, y: 0, width: width, height: 874)
                    for _ in 0..<3 { controller.view.setNeedsLayout(); controller.view.layoutIfNeeded() }
                    let label = controller.subtitleLabel!
                    XCTAssertGreaterThanOrEqual(label.bounds.height + 1, label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height, "\(language)/\(page)/\(width)")
                }
            }
        }
    }

    func testPagerResumesWhenDuoResizesDuringContinue() throws {
        let controller = AppStoryboard.instantiate(OBPageViewController.self)
        controller.loadViewIfNeeded()
        let sizes = [CGSize(width: 466, height: 678), CGSize(width: 669, height: 951)]
        // A scroll view completes animated offsets synchronously when it has no visible window.
        let window = UIWindow(frame: CGRect(origin: .zero, size: sizes[1]))
        let host = UIViewController()
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        host.addChild(controller)
        host.view.addSubview(controller.view)
        controller.didMove(toParent: host)
        controller.view.autoresizingMask = []
        controller.view.frame = CGRect(origin: .zero, size: sizes[0])
        controller.view.layoutIfNeeded()
        let firstPage = try XCTUnwrap(controller.children.first as? OnboardingPageViewController)

        for size in [sizes[1], sizes[0]] {
            controller.obChildRequestsNext(firstPage)
            XCTAssertEqual(controller.view.accessibilityIdentifier, "onboarding.transitioning")
            controller.view.frame = CGRect(origin: .zero, size: size)
            controller.view.setNeedsLayout()
            controller.view.layoutIfNeeded()
            XCTAssertTrue(controller.view.isUserInteractionEnabled)
            XCTAssertEqual(controller.view.accessibilityIdentifier, "onboarding.page.0")
            let scroll = try XCTUnwrap(controller.view.subviews.first as? UIScrollView)
            XCTAssertEqual(scroll.contentOffset.x, 0, accuracy: 0.1)
            XCTAssertEqual(firstPage.view.bounds.size, scroll.bounds.size)
            XCTAssertEqual(scroll.bounds.width, controller.view.dsLayoutSize.width, accuracy: 0.5)
        }
    }

    func testPanelsRemainReadableWhenTheSameWindowResizes() {
        let sizes: [CGSize] = [
            CGSize(width: 393, height: 852), CGSize(width: 375, height: 667),
            CGSize(width: 466, height: 678), CGSize(width: 669, height: 951),
            CGSize(width: 951, height: 669),
            CGSize(width: 768, height: 1024), CGSize(width: 1024, height: 768)
        ]
        for page in [OnboardingPageViewController.Page.room, .tools, .words] {
            let controller = OnboardingPageViewController.make(page: page)
            controller.loadViewIfNeeded()
            for size in sizes + sizes.reversed() {
                controller.view.frame = CGRect(origin: .zero, size: size)
                for _ in 0..<3 { controller.view.setNeedsLayout(); controller.view.layoutIfNeeded() }
                for label in [controller.titleLabel!, controller.subtitleLabel!] {
                    XCTAssertFalse(label.hasAmbiguousLayout)
                    XCTAssertGreaterThanOrEqual(label.bounds.height + 1, label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height, "\(page) \(size)")
                    XCTAssertEqual(label.backgroundColor, .clear)
                }
                let button = controller.view.convert(controller.nextButton.bounds, from: controller.nextButton)
                let subtitle = controller.view.convert(controller.subtitleLabel.bounds, from: controller.subtitleLabel)
                XCTAssertGreaterThan(button.minY, subtitle.maxY)
                XCTAssertLessThanOrEqual(button.maxY, size.height)
                let fontSize = controller.titleLabel.font.pointSize
                controller.view.setNeedsLayout()
                controller.view.layoutIfNeeded()
                XCTAssertEqual(controller.titleLabel.font.pointSize, fontSize, accuracy: 0.001)
            }
        }
    }

    func testGoalPersistsAndSelectsTheMatchingWizard() {
        let keys = [Constants.Keys.onboardingGoal, HomeFocus.defaultsKey]
        let original = keys.map { UserDefaults.standard.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, original) { UserDefaults.standard.set(value, forKey: key) }
        }
        let expected: [DesignOption] = [.interior, .exterior, .garden, .newWalls]
        for (goal, option) in zip(OnboardingGoal.allCases, expected) {
            goal.save()
            XCTAssertEqual(UserDefaults.standard.string(forKey: Constants.Keys.onboardingGoal), goal.rawValue)
            XCTAssertEqual(HomeFocus.current.option, option)
        }
    }
}
