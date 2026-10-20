import XCTest
import UIKit
@testable import HomeAI

@MainActor
final class FullAppMotionTests: XCTestCase {
    func testEntrancesFinishAndScreensCanBeReenteredWithAndWithoutReduceMotion() async throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let host = QASnapshotHost()
        window.rootViewController = host
        window.overrideUserInterfaceStyle = .light
        window.makeKeyAndVisible()
        AppQA.language = "uk"
        AppQA.seed()
        defer { window.isHidden = true; AppQA.reduceMotion = nil; AppQA.language = nil }
        let names = ProcessInfo.processInfo.environment["REHOMELY_QA_MOTION_SCREENS"]?.split(separator: ",").map(String.init) ?? AppQA.screens
        for reduced in [false, true] {
            AppQA.reduceMotion = reduced
            for name in names {
                let content = AppQA.makeScreen(name)
                host.show(AppQA.container(for: content))
                window.layoutIfNeeded()
                if let onboarding = content as? OBPageChild { onboarding.obStartHeroAnimation() }
                let hasLongLoop = name.hasPrefix("onboarding-") || name == "paywall" || name == "splash"
                try await Task.sleep(nanoseconds: hasLongLoop ? 8_000_000_000 : 2_000_000_000)
                if AppQA.sheetScreens.contains(name) {
                    XCTAssertNotNil(host.presentedViewController, "Missing animated sheet: \(name)")
                }
                let visible = host.presentedViewController ?? content
                assertControls(visible.view, in: window, screen: name)
                // A modal, tab switch or backgrounding can cause the same instance to appear again.
                visible.beginAppearanceTransition(false, animated: false); visible.endAppearanceTransition()
                visible.beginAppearanceTransition(true, animated: false); visible.endAppearanceTransition()
                try await Task.sleep(nanoseconds: 550_000_000)
                assertControls(visible.view, in: window, screen: name + "-reentry")
                if let onboarding = content as? OBPageChild { onboarding.obPauseHeroAnimation() }
                await host.closePresentation()
                host.clear()
                try await Task.sleep(nanoseconds: 50_000_000)
            }
        }
    }

    private func assertControls(_ root: UIView, in window: UIWindow, screen: String, file: StaticString = #filePath, line: UInt = #line) {
        func walk(_ view: UIView, hidden: Bool, inheritedOpacity: Float) {
            let hidden = hidden || view.isHidden
            guard !hidden else { return }
            let layer = view.layer.presentation() ?? view.layer
            let opacity = inheritedOpacity * layer.opacity
            if let control = view as? DSPressableControl, control.isUserInteractionEnabled,
               control.bounds.width > 20, control.bounds.height > 20,
               control.convert(control.bounds, to: window).intersects(window.bounds) {
                XCTAssertGreaterThan(opacity, 0.05, "Invisible control after entrance: \(screen)/\(control.actionName ?? "")", file: file, line: line)
                XCTAssertGreaterThan(layer.transform.m11, 0.8, "Control stayed scaled down: \(screen)", file: file, line: line)
            }
            view.subviews.forEach { walk($0, hidden: hidden, inheritedOpacity: opacity) }
        }
        walk(root, hidden: false, inheritedOpacity: 1)
    }
}
