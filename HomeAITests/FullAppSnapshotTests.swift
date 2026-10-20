import XCTest
import UIKit
@testable import HomeAI

@MainActor
final class FullAppSnapshotTests: XCTestCase {
    struct Issue: Codable {
        let language: String
        let screen: String
        let kind: String
        let text: String
        let frame: String
        let required: String
        var appearance: String?
    }

    func testAllScreensAcrossLocalizations() async throws {
        guard AppQA.enabled else { throw XCTSkip("Use the HomeAIFullQA scheme") }
        let env = ProcessInfo.processInfo.environment
        let previousUsedFree = AppQA.freeCount
        if let raw = env["REHOMELY_QA_USED_FREE"], let used = Int(raw) { AppQA.freeCount = max(0, min(2, used)) }
        let languages = (env["REHOMELY_QA_LANGUAGES"] ?? "cs,da,de,en,es,fr,it,ja,ko,nb,nl,pl,pt-BR,ru,uk").split(separator: ",").map(String.init)
        let screenNames = env["REHOMELY_QA_SCREENS"]?.split(separator: ",").map(String.init) ?? AppQA.screens
        let takeScreenshots = env["REHOMELY_QA_SNAPSHOTS"] == "1"
        let auditScrollContent = env["REHOMELY_QA_SCROLL_CONTENT"] == "1"
        let appearances = (env["REHOMELY_QA_APPEARANCES"] ?? "light").split(separator: ",").map(String.init)
        let screenshotLanguages = env["REHOMELY_QA_SNAPSHOT_LANGUAGES"].map { Set($0.split(separator: ",").map(String.init)) }
        AppQA.seed()
        if takeScreenshots { try? FileManager.default.removeItem(at: AppQA.storageURL.appendingPathComponent("screenshots")) }
        AppQA.snapshot = true
        AppQA.homeFocus = .interior
        UIView.setAnimationsEnabled(false)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let host = QASnapshotHost()
        window.rootViewController = host
        window.overrideUserInterfaceStyle = .light
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            AppQA.language = nil
            AppQA.snapshot = false
            AppQA.homeFocus = nil
            AppQA.freeCount = previousUsedFree
            UIView.setAnimationsEnabled(true)
        }
        var issues: [Issue] = []
        var visited: [[String: String]] = []
        var scrollPositions = 0
        let reportURL = AppQA.storageURL.appendingPathComponent("layout-report.json")
        for appearance in appearances {
        window.overrideUserInterfaceStyle = appearance == "dark" ? .dark : .light
        for language in languages {
            AppQA.language = language
            for screen in screenNames {
                autoreleasepool {
                    let content = AppQA.makeScreen(screen)
                    let root = AppQA.container(for: content)
                    host.show(root)
                    root.view.setNeedsLayout()
                    window.layoutIfNeeded()
                }
                // Feed intentionally keeps its loading skeleton for at least 300 ms.
                // Capture its settled cards rather than treating that transition as the design.
                try await Task.sleep(nanoseconds: screen == "inspiration" ? 400_000_000 : 60_000_000)
                window.layoutIfNeeded()
                if AppQA.sheetScreens.contains(screen) {
                    XCTAssertNotNil(host.presentedViewController, "Missing real sheet: \(language)/\(screen)")
                }
                let inspected: UIView
                if let presented = host.presentedViewController {
                    inspected = presented.view
                } else if let tabs = host.children.first as? UITabBarController,
                          let selected = tabs.selectedViewController {
                    // Audit authored content against the safe area UIKit assigns it.
                    // Native top/side tabs may be siblings outside that content area.
                    inspected = (selected as? UINavigationController)?.topViewController?.view ?? selected.view
                } else {
                    inspected = window
                }
                if screen.hasPrefix("result-ask") {
                    func views(in root: UIView) -> [UIView] { [root] + root.subviews.flatMap { views(in: $0) } }
                    let elements = views(in: inspected)
                    let send = try XCTUnwrap(elements.first { $0.accessibilityIdentifier == "didTapSend:0" })
                    let field = try XCTUnwrap(elements.first { $0 is UITextView })
                    let safe = window.safeAreaLayoutGuide.layoutFrame
                    let panel = try XCTUnwrap(elements.first { $0.accessibilityIdentifier == "result.ask.panel" })
                    let background = panel.convert(panel.bounds, to: window)
                    XCTAssertGreaterThanOrEqual(background.maxY, window.bounds.maxY - 1,
                                                "Ask background must cover the bottom safe area: \(language)/\(screen)")
                    for element in [send, field] {
                        let frame = element.convert(element.bounds, to: window)
                        XCTAssertGreaterThanOrEqual(frame.minY, safe.minY - 1, "Ask input above safe viewport: \(language)/\(screen)")
                        XCTAssertLessThanOrEqual(frame.maxY, safe.maxY + 1, "Ask input under home/shelf area: \(language)/\(screen)")
                        XCTAssertGreaterThanOrEqual(frame.minX, safe.minX - 1)
                        XCTAssertLessThanOrEqual(frame.maxX, safe.maxX + 1)
                    }
                }
                if screen == "assistant-failed" {
                    func retryControl(in view: UIView) -> DSPressableControl? {
                        if let control = view as? DSPressableControl, control.actionName == "didTapRetry:" { return control }
                        return view.subviews.lazy.compactMap { retryControl(in: $0) }.first
                    }
                    let retry = try XCTUnwrap(retryControl(in: inspected), "Failed assistant fixture must expose the real user-message retry")
                    XCTAssertFalse(retry.isHidden)
                    XCTAssertTrue(retry.isUserInteractionEnabled)
                    XCTAssertTrue(inspected.bounds.contains(retry.convert(retry.bounds, to: inspected)), "Retry must be fully visible")
                }
                var found = inspect(inspected, language: language, screen: screen)
                let selectedCapture = takeScreenshots && (screenshotLanguages?.contains(language) ?? true)
                func capture(_ name: String) throws {
                    let subfolder = appearances.count > 1 ? "\(language)/\(appearance)" : language
                    let folder = AppQA.storageURL.appendingPathComponent("screenshots/\(subfolder)", isDirectory: true)
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: UIGraphicsImageRendererFormat.preferred())
                    let image = renderer.image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
                    try image.pngData()?.write(to: folder.appendingPathComponent(name + ".png"))
                }
                if !found.isEmpty || selectedCapture { try capture(screen) }
                if auditScrollContent {
                    for scroll in verticalContent(in: inspected) {
                        let original = scroll.contentOffset
                        let maximum = max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
                        let step = max(100, scroll.bounds.height * 0.75)
                        var offset = min(step, maximum)
                        while offset > original.y + 1 {
                            scroll.setContentOffset(CGPoint(x: original.x, y: offset), animated: false)
                            window.layoutIfNeeded()
                            try await Task.sleep(nanoseconds: 16_000_000)
                            window.layoutIfNeeded()
                            let current = inspect(inspected, language: language, screen: screen).map {
                                Issue(language: $0.language, screen: $0.screen, kind: "scrolled-" + $0.kind,
                                      text: $0.text, frame: "offset \(offset): \($0.frame)", required: $0.required)
                            }
                            found += current
                            scrollPositions += 1
                            if !current.isEmpty || selectedCapture { try capture(screen + "-scroll-\(scrollPositions)") }
                            if offset >= maximum - 1 { break }
                            offset = min(maximum, offset + step)
                        }
                        scroll.setContentOffset(original, animated: false)
                        window.layoutIfNeeded()
                    }
                }
                for index in found.indices { found[index].appearance = appearance }
                issues += found
                visited.append(["language": language, "screen": screen, "appearance": appearance])
                // Persist after each screen so a crash identifies the last completed combination.
                let data: [String: Any] = ["device": UIDevice.current.name, "size": "\(window.bounds.size)",
                                           "safeAreaInsets": "\(window.safeAreaInsets)",
                                           "visited": visited, "scrollPositions": scrollPositions,
                                           "issues": try JSONSerialization.jsonObject(with: JSONEncoder().encode(issues))]
                try JSONSerialization.data(withJSONObject: data, options: [.prettyPrinted, .sortedKeys]).write(to: reportURL, options: .atomic)
                await host.closePresentation()
                host.clear()
            }
        }
        }
        let attachment = XCTAttachment(contentsOfFile: reportURL)
        attachment.name = "Full-app-layout-report"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertTrue(issues.isEmpty, "\(issues.count) layout issues; first: \(issues.prefix(8)); report: \(reportURL.path)")
    }

    private func inspect(_ root: UIView, language: String, screen: String) -> [Issue] {
        var issues: [Issue] = []
        func walk(_ view: UIView, visible: Bool, clip: CGRect) {
            // UIKit owns native tab fonts, fitting and safe-area placement. Native
            // item accessibility and hit targets are covered by dedicated tab tests.
            guard !(view is UITabBar), view.accessibilityIdentifier?.hasPrefix("tab.") != true else { return }
            let visible = visible && !view.isHidden && view.alpha > 0.01
            guard visible else { return }
            // UIKit owns a text field's fitted placeholder label and may shrink it internally.
            guard !(view is UITextField) else { return }
            let bounds = view.convert(view.bounds, to: root)
            let inheritedClip = clip
            let clip = view.clipsToBounds ? clip.intersection(bounds) : clip
            if ProcessInfo.processInfo.environment["REHOMELY_QA_SCROLL_CONTENT"] == "1",
               let control = view as? UIControl,
               control.bounds.width > 1, control.bounds.height > 1, !hasScrollAncestor(control),
               !root.bounds.insetBy(dx: -1.5, dy: -1.5).contains(bounds) {
                issues.append(Issue(language: language, screen: screen, kind: "control-outside-viewport",
                                    text: control.accessibilityLabel ?? "\(type(of: control))", frame: "\(bounds)",
                                    required: "inside \(root.bounds) or reachable by scrolling"))
            }
            if ProcessInfo.processInfo.environment["REHOMELY_QA_SCROLL_CONTENT"] == "1",
               view is UIControl, view.bounds.width > 1, !hasScrollAncestor(view),
               bounds.intersects(root.bounds) {
                let safe = root.safeAreaLayoutGuide.layoutFrame
                if bounds.minX < safe.minX - 1.5 || bounds.maxX > safe.maxX + 1.5 {
                    issues.append(Issue(language: language, screen: screen, kind: "control-overlaps-side-safe-area",
                                        text: view.accessibilityLabel ?? "\(type(of: view))", frame: "\(bounds)",
                                        required: "horizontal safe area \(safe)"))
                }
            }
            guard !clip.isNull, !clip.isEmpty else { return }
            if let label = view as? UILabel, let text = label.text, !text.isEmpty, label.bounds.width > 0 {
                let need = label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude))
                if screen == "paywall", text == "No payment now".localized,
                   !clip.contains(bounds.insetBy(dx: 0.5, dy: 0.5)) {
                    issues.append(Issue(language: language, screen: screen, kind: "payment-note-outside-viewport", text: text,
                                        frame: "\(bounds)", required: "inside \(clip)"))
                }
                guard CGRect(origin: bounds.origin, size: CGSize(width: bounds.width, height: max(bounds.height, need.height))).intersects(clip) else { return }
                if need.height > label.bounds.height + 1.5 {
                    issues.append(Issue(language: language, screen: screen, kind: "label-height", text: text,
                                        frame: "\(label.frame)", required: "\(need)"))
                }
                if ProcessInfo.processInfo.environment["REHOMELY_QA_SCROLL_CONTENT"] == "1",
                   label.numberOfLines > 1, !isInCell(label) {
                    let probe = UILabel(); probe.text = text; probe.numberOfLines = 0
                    probe.font = label.font.withSize(label.font.pointSize * (label.adjustsFontSizeToFitWidth ? label.minimumScaleFactor : 1))
                    let full = probe.sizeThatFits(CGSize(width: label.bounds.width, height: CGFloat.greatestFiniteMagnitude))
                    if full.height > label.bounds.height + 1.5 {
                        issues.append(Issue(language: language, screen: screen, kind: "bounded-lines-truncated", text: text,
                                            frame: "\(bounds)", required: "\(full)"))
                    }
                }
                if label.numberOfLines == 1, label.lineBreakMode != .byTruncatingTail,
                   label.lineBreakMode != .byTruncatingMiddle, label.lineBreakMode != .byTruncatingHead {
                    let full = label.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
                    if full.width > label.bounds.width + 2 {
                        issues.append(Issue(language: language, screen: screen, kind: "label-width", text: text,
                                            frame: "\(label.frame)", required: "\(full)"))
                    }
                }
                if label.accessibilityIdentifier?.hasPrefix("home.") == true, label.numberOfLines == 1 {
                    let full = label.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
                    let minimum = label.adjustsFontSizeToFitWidth ? label.minimumScaleFactor : 1
                    if full.width * minimum > label.bounds.width + 1 {
                        issues.append(Issue(language: language, screen: screen, kind: "header-truncation", text: text,
                                            frame: "\(label.frame)", required: "\(full) at scale \(minimum)"))
                    }
                }
                if screen == "paywall", label.numberOfLines == 1 {
                    let full = label.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
                    let minimum = label.adjustsFontSizeToFitWidth ? label.minimumScaleFactor : 1
                    if full.width * minimum > label.bounds.width + 1.5 {
                        issues.append(Issue(language: language, screen: screen, kind: "paywall-truncated-copy", text: text,
                                            frame: "\(label.frame)", required: "\(full) at scale \(minimum)"))
                    }
                }
                if ProcessInfo.processInfo.environment["REHOMELY_QA_STRICT_LABELS"] == "1",
                   let control = enclosingControl(label), control.bounds.width > 0 {
                    // Partly visible cards in a horizontal carousel are deliberate; inspect their fully visible peers.
                    let controlFrame = control.convert(control.bounds, to: root)
                    let fullyVisible = inheritedClip.insetBy(dx: -1, dy: -1).contains(controlFrame)
                    if fullyVisible, label.numberOfLines == 1 {
                        let full = label.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
                        let minimum = label.adjustsFontSizeToFitWidth ? label.minimumScaleFactor : 1
                        if full.width * minimum > label.bounds.width + 1.5 {
                            issues.append(Issue(language: language, screen: screen, kind: "control-label-truncated", text: text,
                                                frame: "\(bounds)", required: "\(full) at minScale \(minimum); action=\(control.actionName ?? "")"))
                        }
                    }
                    let local = label.convert(label.bounds, to: control)
                    if fullyVisible, !control.bounds.insetBy(dx: -1.5, dy: -1.5).contains(local) {
                        issues.append(Issue(language: language, screen: screen, kind: "label-outside-control", text: text,
                                            frame: "\(local)", required: "inside \(control.bounds); action=\(control.actionName ?? "")"))
                    }
                }
                if ProcessInfo.processInfo.environment["REHOMELY_QA_STRICT_LABELS"] == "1",
                   label.numberOfLines == 1, enclosingControl(label) == nil, !isInCell(label),
                   inheritedClip.insetBy(dx: -1, dy: -1).contains(bounds) {
                    let full = label.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
                    let minimum = label.adjustsFontSizeToFitWidth ? label.minimumScaleFactor : 1
                    if full.width * minimum > label.bounds.width + 1.5 {
                        issues.append(Issue(language: language, screen: screen, kind: "static-label-truncated", text: text,
                                            frame: "\(bounds)", required: "\(full) at minScale \(minimum)"))
                    }
                }
            }
            view.subviews.forEach { walk($0, visible: visible, clip: clip) }
        }
        walk(root, visible: true, clip: root.bounds)
        return issues
    }

    private func enclosingControl(_ view: UIView) -> DSPressableControl? {
        var ancestor = view.superview
        while let current = ancestor {
            if let control = current as? DSPressableControl { return control }
            // Collection cells contain dynamic titles with explicit truncation in the design.
            if current is UICollectionViewCell { return nil }
            ancestor = current.superview
        }
        return nil
    }

    private func isInCell(_ view: UIView) -> Bool {
        var ancestor = view.superview
        while let current = ancestor {
            if current is UICollectionViewCell || current is UITableViewCell { return true }
            ancestor = current.superview
        }
        return false
    }

    private func hasScrollAncestor(_ view: UIView) -> Bool {
        var parent = view.superview
        while let current = parent {
            if current is UIScrollView { return true }
            parent = current.superview
        }
        return false
    }

    private func verticalContent(in root: UIView) -> [UIScrollView] {
        func collect(_ view: UIView) -> [UIScrollView] {
            guard !view.isHidden, view.alpha > 0.01 else { return [] }
            var result: [UIScrollView] = []
            if let scroll = view as? UIScrollView, !(scroll is UICollectionView), !(scroll is UITableView),
               !(scroll is UITextView), scroll.maximumZoomScale <= 1.01,
               scroll.contentSize.height > scroll.bounds.height + 8 { result.append(scroll) }
            return result + view.subviews.flatMap(collect)
        }
        return collect(root)
    }
}

/// Delivers appearance synchronously; UIKit may otherwise defer a new window root's appearance
/// until after the next snapshot has already started.
@MainActor
final class QASnapshotHost: UIViewController {
    override var shouldAutomaticallyForwardAppearanceMethods: Bool { false }
    func closePresentation() async {
        guard presentedViewController != nil else { return }
        await withCheckedContinuation { continuation in
            dismiss(animated: false) { continuation.resume() }
        }
    }
    func show(_ child: UIViewController) {
        clear()
        addChild(child)
        child.view.frame = view.bounds
        child.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(child.view)
        child.didMove(toParent: self)
        child.beginAppearanceTransition(true, animated: false)
        child.endAppearanceTransition()
    }
    func clear() {
        dismiss(animated: false)
        for child in children {
            child.dismiss(animated: false)
            child.beginAppearanceTransition(false, animated: false)
            child.willMove(toParent: nil)
            child.view.removeFromSuperview()
            child.removeFromParent()
            child.endAppearanceTransition()
        }
    }
}
