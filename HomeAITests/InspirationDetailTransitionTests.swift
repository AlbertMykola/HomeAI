import XCTest
import UIKit
@testable import HomeAI

@MainActor
final class InspirationDetailTransitionTests: XCTestCase {
    func testDetailCTAIsFullyVisibleInEveryLanguageAndTheme() async throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        AppQA.seed()
        AppQA.snapshot = true
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let host = QASnapshotHost()
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; AppQA.language = nil; AppQA.snapshot = false }
        for dark in [false, true] {
            window.overrideUserInterfaceStyle = dark ? .dark : .light
            for language in ["cs", "da", "de", "en", "es", "fr", "it", "ja", "ko", "nb", "nl", "pl", "pt-BR", "ru", "uk"] {
                AppQA.language = language
                let detail = AppQA.makeScreen("idea") as! IdeaDetailViewController
                host.show(detail)
                window.layoutIfNeeded()
                let button = try XCTUnwrap(descendants(detail.view).compactMap { $0 as? DSPressableControl }.first { $0.actionName == "didTapTry:" })
                let label = try XCTUnwrap(descendants(button).compactMap { $0 as? UILabel }.first)
                let available = label.bounds.size
                let fullText = UILabel()
                fullText.font = label.font
                fullText.text = label.text
                fullText.numberOfLines = 0
                let required = fullText.sizeThatFits(CGSize(width: available.width, height: CGFloat.greatestFiniteMagnitude))
                XCTAssertLessThanOrEqual(required.height, available.height + 1, "CTA height: \(language)")
                let fullWidth = label.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)).width
                if label.numberOfLines == 1 { XCTAssertLessThanOrEqual(fullWidth, available.width + 1, "Truncated CTA: \(language)") }
                let frame = button.convert(button.bounds, to: detail.view)
                XCTAssertLessThanOrEqual(frame.maxY, detail.view.safeAreaLayoutGuide.layoutFrame.maxY + 0.5, language)
                let bottomPadding = OnboardingLayout(size: detail.view.dsLayoutSize).value(16)
                XCTAssertLessThanOrEqual(frame.maxY, detail.view.bounds.maxY - bottomPadding + 0.5, "Bottom padding: \(language)")
                XCTAssertGreaterThanOrEqual(frame.minY, detail.panelView.frame.minY, language)
                XCTAssertLessThanOrEqual(required.height, button.bounds.height - 8, language)
                if ["uk", "de"].contains(language) {
                    let attachment = XCTAttachment(image: windowScreenshot(window))
                    attachment.name = "Detail-\(language)-\(dark ? "dark" : "light")"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
                host.clear()
            }
        }
    }

    func testCardPresentationKeepsThePanelInItsFinalLayout() async throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        AppQA.seed()
        AppQA.language = "uk"
        AppQA.snapshot = false
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let tabs = AppQA.makeTabs(index: 1) as! UITabBarController
        window.rootViewController = tabs
        window.overrideUserInterfaceStyle = .dark
        window.makeKeyAndVisible()
        defer { window.isHidden = true; AppQA.language = nil; AppQA.reduceMotion = nil }
        try await Task.sleep(nanoseconds: 1_000_000_000)
        let feed = try XCTUnwrap((tabs.selectedViewController as? UINavigationController)?.topViewController as? InspirationFeedViewController)
        let collection = try XCTUnwrap(descendants(feed.view).compactMap { $0 as? UICollectionView }.first)
        var runs: [[String: Any]] = []
        for reduced in [false, true] {
            AppQA.reduceMotion = reduced
            collection.delegate?.collectionView?(collection, didSelectItemAt: IndexPath(item: 0, section: 0))
            let detail = try XCTUnwrap(feed.presentedViewController as? IdeaDetailViewController)
            let start = CACurrentMediaTime()
            let startedAt = Date().timeIntervalSince1970
            var samples: [[String: Double]] = []
            var finishedAt: TimeInterval?
            while CACurrentMediaTime() - start < 4 {
                let panel = detail.panelView!
                let layer = panel.layer.presentation() ?? panel.layer
                let elapsed = CACurrentMediaTime() - start
                let finished = detail.view.window != nil && !detail.isBeingPresented
                if finished, finishedAt == nil { finishedAt = elapsed }
                samples.append(["time": CACurrentMediaTime() - start,
                                "top": Double(layer.frame.minY), "height": Double(layer.bounds.height),
                                "layoutTop": Double(panel.center.y - panel.bounds.height / 2),
                                "opacity": Double(layer.opacity),
                                "cornerRadius": Double(layer.cornerRadius),
                                "maskedCorners": Double(layer.maskedCorners.rawValue),
                                "photoOverPanel": photoOverlapsPanel(detail) ? 1 : 0,
                                "inWindow": detail.view.window != nil ? 1 : 0,
                                "transitionComplete": detail.view.window != nil && !detail.isBeingPresented ? 1 : 0,
                                "safeBottom": Double(detail.view.safeAreaInsets.bottom)])
                if let finishedAt, elapsed > max(1.35, finishedAt + 0.25) { break }
                try await Task.sleep(nanoseconds: 16_000_000)
            }
            let finalTop = Double(detail.panelView.frame.minY)
            let visible = samples.filter { $0["inWindow"] == 1 && $0["time"]! > 0.05 && $0["opacity"]! > 0.1 }
            let layoutTops = visible.compactMap { $0["layoutTop"] }
            for sample in visible {
                let radius = OnboardingLayout(size: detail.view.dsLayoutSize).value(34)
                XCTAssertEqual(sample["cornerRadius"]!, radius, accuracy: 0.1, "Corners changed while visible")
                XCTAssertEqual(sample["maskedCorners"]!, 3)
                XCTAssertEqual(sample["photoOverPanel"]!, 0, "A transition photo covers the panel's rounded overlap")
            }
            XCTAssertLessThanOrEqual((layoutTops.max() ?? 0) - (layoutTops.min() ?? 0), 1,
                                     "Panel layout changed during presentation (reduce motion: \(reduced))")
            if !reduced {
                XCTAssertLessThanOrEqual((visible.compactMap { $0["top"] }.max() ?? 0) - finalTop, 14,
                                         "The visible panel should enter from Figma's 12 pt offset")
            }
            // UIKit can defer starting presentation on a busy simulator. Check settlement
            // after actual transition completion, rather than a deadline from the tap.
            let completedAt = samples.first { $0["transitionComplete"] == 1 }?["time"]
            XCTAssertNotNil(completedAt, "Presentation never completed")
            let settled = samples.filter { $0["time"]! > (completedAt ?? 0) + 0.1 }
            XCTAssertFalse(settled.isEmpty)
            for sample in settled {
                XCTAssertEqual(sample["top"]!, finalTop, accuracy: 1, "Panel jumped after transition completion")
                XCTAssertEqual(sample["opacity"]!, 1, accuracy: 0.01)
            }
            let button = try XCTUnwrap(descendants(detail.view).compactMap { $0 as? DSPressableControl }.first { $0.actionName == "didTapTry:" })
            let frame = button.convert(button.bounds, to: detail.view)
            XCTAssertLessThanOrEqual(frame.maxY, detail.view.safeAreaLayoutGuide.layoutFrame.maxY + 0.5)
            let bottomPadding = OnboardingLayout(size: detail.view.dsLayoutSize).value(16)
            XCTAssertLessThanOrEqual(frame.maxY, detail.view.bounds.maxY - bottomPadding + 0.5)
            XCTAssertGreaterThanOrEqual(frame.minY, detail.panelView.frame.minY)
            let attachment = XCTAttachment(image: windowScreenshot(window))
            attachment.name = "Detail-settled-\(reduced ? "reduced" : "normal")"
            attachment.lifetime = .keepAlways
            add(attachment)
            runs.append(["reducedMotion": reduced, "startedAt": startedAt, "finalTop": finalTop, "samples": samples])
            await withCheckedContinuation { continuation in detail.dismiss(animated: true) { continuation.resume() } }
            XCTAssertNil(feed.presentedViewController)
            XCTAssertTrue(collection.visibleCells.allSatisfy { cell in
                descendants(cell).compactMap { $0 as? UIImageView }.allSatisfy { $0.alpha > 0.99 }
            }, "Dismiss must restore the source card")
        }
        let report = AppQA.storageURL.appendingPathComponent("inspiration-detail-motion.json")
        try JSONSerialization.data(withJSONObject: ["device": UIDevice.current.name, "size": "\(window.bounds.size)", "runs": runs], options: [.prettyPrinted, .sortedKeys]).write(to: report)
        let attachment = XCTAttachment(contentsOfFile: report)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func descendants(_ view: UIView) -> [UIView] { [view] + view.subviews.flatMap(descendants) }
    private func photoOverlapsPanel(_ detail: IdeaDetailViewController) -> Bool {
        let panel = detail.panelView!
        var current: UIView = panel
        while let parent = current.superview {
            let region = panel.convert(CGRect(x: 34, y: 0, width: max(1, panel.bounds.width - 68), height: 32), to: parent)
            if let index = parent.subviews.firstIndex(of: current) {
                for sibling in parent.subviews.dropFirst(index + 1) where sibling is UIImageView && sibling.alpha > 0.05 {
                    if sibling.frame.intersects(region) { return true }
                }
            }
            current = parent
        }
        return false
    }
    private func windowScreenshot(_ window: UIWindow) -> UIImage {
        UIGraphicsImageRenderer(bounds: window.bounds).image { window.layer.render(in: $0.cgContext) }
    }
}
