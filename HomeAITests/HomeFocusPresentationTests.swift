import XCTest
import UIKit
@testable import HomeAI

@MainActor
final class HomeFocusPresentationTests: XCTestCase {
    private let languages = ["cs", "da", "de", "en", "es", "fr", "it", "ja", "ko", "nb", "nl", "pl", "pt-BR", "ru", "uk"]
    private let focuses: [HomeFocus] = [.interior, .exterior, .garden, .surfaces]

    func testHomeCopyAndAlternativesForEveryGoalLanguageAndAppearance() async throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        AppQA.seed()
        AppQA.snapshot = true
        UIView.setAnimationsEnabled(false)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let host = QASnapshotHost()
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            host.clear()
            window.isHidden = true
            AppQA.language = nil
            AppQA.homeFocus = nil
            AppQA.snapshot = false
            UIView.setAnimationsEnabled(true)
        }
        var issues: [String] = []
        var visited: [String] = []
        let folder = AppQA.storageURL.appendingPathComponent("home-focus", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for style in [UIUserInterfaceStyle.light, .dark] {
            window.overrideUserInterfaceStyle = style
            for language in languages {
                AppQA.language = language
                for focus in focuses {
                    AppQA.homeFocus = focus
                    let root = AppQA.makeTabs()
                    host.show(root)
                    window.layoutIfNeeded()
                    try await Task.sleep(nanoseconds: 30_000_000)
                    window.layoutIfNeeded()
                    let name = "\(language)-\(focus.rawValue)-\(style == .dark ? "dark" : "light")"
                    visited.append(name)
                    let all = descendants(root.view)
                    let labels = all.compactMap { $0 as? UILabel }
                    let title = labels.first { $0.accessibilityIdentifier == "home.hero.title" }
                    XCTAssertEqual(title?.text, focus.heroTitle, name)
                    XCTAssertEqual(labels.first { $0.accessibilityIdentifier == "home.hero.subtitle" }?.text, focus.heroSubtitle, name)
                    XCTAssertEqual(labels.first { $0.accessibilityIdentifier == "home.hero.tag" }?.text, focus.title, name)
                    if focus != .interior { XCTAssertNotEqual(title?.text, "Redesign a room".localized, name) }
                    let controls = all.compactMap { $0 as? DSPressableControl }.filter { $0.accessibilityIdentifier?.hasPrefix("home.more.") == true }
                    let expected = HomeViewController.More.options(for: focus)
                    XCTAssertEqual(Set(controls.compactMap(\.accessibilityIdentifier)), Set(expected.map { "home.more.\($0.option.rawValue)" }), name)
                    XCTAssertFalse(expected.contains { $0.option == focus.option }, name)
                    for alternative in expected {
                        let control = try XCTUnwrap(controls.first { $0.accessibilityIdentifier == "home.more.\(alternative.option.rawValue)" })
                        XCTAssertEqual(control.accessibilityLabel, alternative.title, name)
                    }
                    for label in labels where label.accessibilityIdentifier?.hasPrefix("home.") == true {
                        guard let text = label.text, !text.isEmpty else { continue }
                        if text.hasPrefix("home_hero_") { issues.append("\(name): untranslated \(text)") }
                        let probe = UILabel()
                        probe.numberOfLines = 0
                        probe.font = label.font.withSize(label.font.pointSize * (label.adjustsFontSizeToFitWidth ? label.minimumScaleFactor : 1))
                        probe.text = text
                        let required = probe.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
                        if required.height > label.bounds.height + 2 {
                            issues.append("\(name): clipped \(text), \(label.bounds.size), needs \(required)")
                        }
                    }
                    if ["uk", "de", "en"].contains(language) {
                        try save(window, to: folder.appendingPathComponent(name + "-top.png"))
                        if let scroll = all.compactMap({ $0 as? UIScrollView }).first(where: { $0.contentSize.height > $0.bounds.height + 100 }) {
                            let offset = min(max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom), 520)
                            scroll.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
                            window.layoutIfNeeded()
                            try save(window, to: folder.appendingPathComponent(name + "-tools.png"))
                        }
                    }
                    host.clear()
                }
            }
        }
        let report: [String: Any] = ["device": UIDevice.current.name, "size": "\(window.bounds.size)", "visited": visited, "issues": issues]
        let url = folder.appendingPathComponent("report.json")
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]).write(to: url)
        let attachment = XCTAttachment(contentsOfFile: url)
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertTrue(issues.isEmpty, "\(issues.count) issues: \(issues.prefix(12))")
    }

    func testPlanCardCopyFitsAfterScrollingAcrossLanguagesAndThemes() async throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        AppQA.seed(); AppQA.snapshot = true
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene), host = QASnapshotHost()
        window.rootViewController = host; window.makeKeyAndVisible()
        defer { host.clear(); window.isHidden = true; AppQA.snapshot = false; AppQA.language = nil }
        var states = 0
        for style in [UIUserInterfaceStyle.light, .dark] {
            window.overrideUserInterfaceStyle = style
            for language in languages {
                AppQA.language = language
                let root = AppQA.makeTabs()
                host.show(root); window.layoutIfNeeded()
                try await Task.sleep(nanoseconds: 30_000_000); window.layoutIfNeeded()
                let all = descendants(root.view)
                let tabs = try XCTUnwrap(root as? UITabBarController)
                let navigation = try XCTUnwrap(tabs.selectedViewController as? UINavigationController)
                let home = try XCTUnwrap(navigation.topViewController as? HomeViewController)
                let scroll = try XCTUnwrap(home.value(forKey: "scrollView") as? UIScrollView)
                let maximum = max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
                let labels = all.compactMap { $0 as? UILabel }.filter { $0.accessibilityIdentifier?.hasPrefix("home.plan.") == true }
                XCTAssertEqual(labels.count, 4)
                for offset in [CGFloat.zero, maximum * 0.75, maximum] {
                    scroll.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
                    window.layoutIfNeeded()
                    for label in labels {
                        let measure = UILabel(); measure.text = label.text; measure.font = label.font; measure.numberOfLines = 0
                        let need = measure.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
                        XCTAssertLessThanOrEqual(need.height, label.bounds.height + 1, "\(language)/\(style)/\(offset): \(label.text ?? "")")
                    }
                    if language == "pl", offset == maximum {
                        try save(window, to: AppQA.storageURL.appendingPathComponent("home-plan-pl-\(style == .dark ? "dark" : "light").png"))
                    }
                    states += 1
                }
                host.clear()
            }
        }
        XCTAssertEqual(states, 90)
        try JSONSerialization.data(withJSONObject: ["device": UIDevice.current.name, "states": states], options: [.prettyPrinted])
            .write(to: AppQA.storageURL.appendingPathComponent("home-plan-copy.json"))
    }

    func testHomeAccessibilityTextAttributesHaveStringValues() throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        AppQA.seed(); AppQA.snapshot = true; AppQA.freeCount = 1; AppQA.premium = false
        let root = AppQA.makeTabs()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene), host = QASnapshotHost()
        window.rootViewController = host; window.makeKeyAndVisible()
        host.show(root); window.layoutIfNeeded()
        defer { host.clear(); window.isHidden = true; AppQA.snapshot = false; AppQA.freeCount = 0 }
        var identifiers = Set<String>()
        for view in descendants(root.view) {
            for key in ["accessibilityIdentifier", "accessibilityLabel", "accessibilityHint", "accessibilityValue"] {
                if let value = view.value(forKey: key) {
                    XCTAssertTrue(value is String, "\(type(of: view)).\(key) must contain text, got \(type(of: value))")
                    if key == "accessibilityIdentifier", let text = value as? String { identifiers.insert(text) }
                }
            }
        }
        XCTAssertTrue(identifiers.contains("home.freeBanner.close"))
        XCTAssertTrue(identifiers.contains("home.more.carousel"))
    }

    func testOnboardingChoicePersistsTheHomeFocus() {
        let defaults = UserDefaults.standard
        let oldGoal = defaults.object(forKey: Constants.Keys.onboardingGoal)
        let oldFocus = defaults.object(forKey: HomeFocus.defaultsKey)
        defer {
            defaults.set(oldGoal, forKey: Constants.Keys.onboardingGoal)
            defaults.set(oldFocus, forKey: HomeFocus.defaultsKey)
            AppQA.homeFocus = nil
        }
        AppQA.homeFocus = nil
        for goal in OnboardingGoal.allCases {
            goal.save()
            XCTAssertEqual(HomeFocus.current.rawValue, goal.rawValue)
        }
    }

    func testSurfacesIncludesInteriorAndRetainsEveryOtherCategory() {
        XCTAssertEqual(HomeViewController.More.options(for: .surfaces).map(\.option), [.interior, .exterior, .garden, .reference])
    }

    func testRegeneratedHomeIllustrationsHaveEnoughPixelsAndAlpha() throws {
        for name in ["paint", "flooring", "replace", "remove", "furnish", "rearrange", "floorplan", "assistant", "interior", "reference", "exterior", "garden"] {
            let image = try XCTUnwrap(UIImage(named: "clay_\(name)")?.cgImage)
            XCTAssertGreaterThanOrEqual(image.width, 512, name)
            XCTAssertGreaterThanOrEqual(image.height, 512, name)
            XCTAssertTrue([CGImageAlphaInfo.first, .last, .premultipliedFirst, .premultipliedLast].contains(image.alphaInfo), name)
        }
    }

    private func descendants(_ view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap(descendants)
    }

    private func save(_ window: UIWindow, to url: URL) throws {
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try image.pngData()?.write(to: url)
    }
}
