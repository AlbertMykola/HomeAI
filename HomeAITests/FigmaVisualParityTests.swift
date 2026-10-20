import XCTest
import UIKit
@testable import HomeAI

@MainActor
final class FigmaVisualParityTests: XCTestCase {
    func testProfileAllowanceStaysInsideItsTrack() async throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        AppQA.seed(); AppQA.snapshot = true; AppQA.premium = false
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene), host = QASnapshotHost()
        window.rootViewController = host; window.makeKeyAndVisible()
        defer { window.isHidden = true; AppQA.snapshot = false; AppQA.freeCount = 0 }
        var rows: [[String: Any]] = []
        for used in 0...2 {
            AppQA.freeCount = used
            let profile = AppStoryboard.instantiate(ProfileTabViewController.self)
            host.show(AppQA.container(for: profile)); window.layoutIfNeeded()
            try await Task.sleep(nanoseconds: 60_000_000); window.layoutIfNeeded()
            let track = try XCTUnwrap(profile.value(forKey: "progressTrackView") as? UIView)
            let fill = try XCTUnwrap(profile.value(forKey: "progressFillView") as? UIView)
            XCTAssertLessThanOrEqual(fill.frame.maxX, track.bounds.maxX + 0.5)
            XCTAssertEqual(fill.bounds.width, track.bounds.width * CGFloat(2 - used) / 2, accuracy: 0.5)
            rows.append(["used": used, "trackWidth": track.bounds.width, "fillWidth": fill.bounds.width])
        }
        let folder = AppQA.storageURL.appendingPathComponent("figma-visual", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent("profile-allowance.json"))
    }

    func testFloatingShareKeepsRoundedGeometryThroughoutItsTransition() async throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        AppQA.seed(); AppQA.snapshot = false; AppQA.language = "en"
        UIView.setAnimationsEnabled(true)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene), host = QASnapshotHost()
        window.rootViewController = host; window.makeKeyAndVisible()
        // Settle the hosted window before measuring a presentation. On a freshly booted
        // Duo, presenting during the first window activation can produce no visible frames.
        host.loadViewIfNeeded()
        window.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 80_000_000)
        window.layoutIfNeeded()
        XCTAssertTrue(window.isKeyWindow)
        XCTAssertTrue(host.view.window === window)
        defer { window.isHidden = true; AppQA.language = nil; AppQA.reduceMotion = nil }
        let scale = OnboardingLayout(size: window.bounds.size).scale
        let folder = AppQA.storageURL.appendingPathComponent("figma-visual", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var runs: [[String: Any]] = []
        for reduced in [false, true] {
            AppQA.reduceMotion = reduced
            ShareSheetViewController.present(from: host, before: AppQA.original, after: AppQA.photo)
            let sheet = try XCTUnwrap(host.presentedViewController as? ShareSheetViewController)
            let start = CACurrentMediaTime()
            var samples: [[String: Double]] = []
            var completedAt: Double?
            while CACurrentMediaTime() - start < 3 {
                let elapsed = CACurrentMediaTime() - start
                let layer = sheet.view.layer.presentation() ?? sheet.view.layer
                if sheet.view.window != nil && elapsed > 0.05 {
                    samples.append(["time": elapsed, "width": Double(layer.bounds.width),
                                    "height": Double(layer.bounds.height), "top": Double(layer.frame.minY),
                                    "radius": Double(layer.cornerRadius)])
                    XCTAssertEqual(layer.cornerRadius, 38 * scale, accuracy: 0.1)
                    XCTAssertTrue(sheet.view.clipsToBounds)
                }
                if sheet.view.window != nil && !sheet.isBeingPresented && completedAt == nil { completedAt = elapsed }
                if let completedAt, elapsed > completedAt + 0.2 { break }
                try await Task.sleep(nanoseconds: 16_000_000)
            }
            XCTAssertNotNil(completedAt)
            XCTAssertGreaterThan(samples.count, 3)
            for sample in samples {
                XCTAssertEqual(sample["width"]!, Double(sheet.view.bounds.width), accuracy: 1)
                XCTAssertEqual(sample["height"]!, Double(sheet.view.bounds.height), accuracy: 1)
            }
            // Continue dismissal from a partial downward drag; its final position must clear the screen.
            if !reduced { sheet.view.transform = CGAffineTransform(translationX: 0, y: 60 * scale) }
            sheet.dismiss(animated: true)
            try await Task.sleep(nanoseconds: 50_000_000)
            if !reduced { XCTAssertGreaterThanOrEqual(sheet.view.frame.minY, window.bounds.height - 1) }
            try await Task.sleep(nanoseconds: 350_000_000)
            XCTAssertNil(host.presentedViewController)
            runs.append(["reduceMotion": reduced, "samples": samples])
        }
        try JSONSerialization.data(withJSONObject: runs, options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent("share-motion.json"))
    }

    func testResultCompareAndShareMatchReferenceGeometry() async throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        AppQA.seed(); AppQA.snapshot = true; AppQA.language = "en"; AppQA.premium = false
        UIView.setAnimationsEnabled(false)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene), host = QASnapshotHost()
        window.rootViewController = host; window.overrideUserInterfaceStyle = .light; window.makeKeyAndVisible()
        defer { window.isHidden = true; AppQA.snapshot = false; AppQA.language = nil; UIView.setAnimationsEnabled(true) }
        let folder = AppQA.storageURL.appendingPathComponent("figma-visual", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let exactReferenceSize = window.bounds.size == CGSize(width: 393, height: 852)
        var metrics: [String: Any] = ["size": "\(window.bounds.size)"]
        func frame(_ vc: UIViewController, _ key: String) throws -> CGRect {
            let view = try XCTUnwrap(vc.value(forKey: key) as? UIView)
            return view.convert(view.bounds, to: window)
        }
        func check(_ actual: CGRect, _ expected: CGRect, _ name: String) {
            metrics[name] = "\(actual)"
            if exactReferenceSize {
                XCTAssertEqual(actual.minX, expected.minX, accuracy: 2, name)
                XCTAssertEqual(actual.minY, expected.minY, accuracy: 2, name)
                XCTAssertEqual(actual.width, expected.width, accuracy: 2, name)
                XCTAssertEqual(actual.height, expected.height, accuracy: 2, name)
            }
        }
        func capture(_ name: String) throws {
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
            try image.pngData()?.write(to: folder.appendingPathComponent(name + ".png"))
        }

        let result = AppQA.makeScreen("result")
        host.show(AppQA.container(for: result)); window.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 150_000_000); window.layoutIfNeeded()
        check(try frame(result, "panelView"), CGRect(x: 0, y: 528, width: 393, height: 324), "result.panel")
        check(try frame(result, "askBarView"), CGRect(x: 20, y: 775, width: 353, height: 50), "result.ask")
        let versions = try XCTUnwrap(result.value(forKey: "versionsCollectionView") as? UICollectionView)
        XCTAssertFalse(versions.visibleCells.isEmpty, "Version thumbnails must survive pixel rounding at every scale")
        let stripHeight = try XCTUnwrap(versions.constraints.first { $0.firstAttribute == .height })
        let originalHeight = stripHeight.constant
        // Reproduce the half-point height loss caused by Auto Layout pixel rounding.
        for height in [originalHeight - 0.5, originalHeight] {
            stripHeight.constant = height
            result.view.setNeedsLayout(); result.view.layoutIfNeeded(); versions.layoutIfNeeded()
            XCTAssertEqual(versions.visibleCells.count, versions.numberOfItems(inSection: 0),
                           "Version cells must survive a fractional viewport-height change")
            for cell in versions.visibleCells {
                XCTAssertLessThanOrEqual(cell.frame.maxY, versions.bounds.height + 0.5)
                XCTAssertGreaterThanOrEqual(cell.frame.minY, -0.5)
            }
        }
        try capture("result")

        let compare = AppQA.makeScreen("compare")
        host.show(compare); window.layoutIfNeeded()
        check(try frame(compare, "stageView"), CGRect(x: 0, y: 76, width: 393, height: 700), "compare.stage")
        check(try frame(compare, "segmentedView"), CGRect(x: 46, y: 790, width: 300, height: 40), "compare.segmented")
        let after = try XCTUnwrap(compare.value(forKey: "afterImageView") as? UIImageView)
        XCTAssertEqual(after.contentMode, .scaleAspectFill)
        try capture("compare")

        host.show(AppQA.container(for: result)); window.layoutIfNeeded()
        ShareSheetViewController.present(from: host, before: AppQA.original, after: AppQA.photo)
        let share = try XCTUnwrap(host.presentedViewController as? ShareSheetViewController)
        window.layoutIfNeeded()
        try await Task.sleep(nanoseconds: 100_000_000); window.layoutIfNeeded()
        check(share.view.convert(share.view.bounds, to: window), CGRect(x: 8, y: 185, width: 377, height: 659), "share.sheet")
        check(try frame(share, "previewView"), CGRect(x: 28, y: 258, width: 337, height: 210), "share.preview")
        let before = try XCTUnwrap(share.value(forKey: "beforeLabel") as? UILabel)
        let afterLabel = try XCTUnwrap(share.value(forKey: "afterLabel") as? UILabel)
        let watermark = try XCTUnwrap(share.value(forKey: "previewWatermarkView") as? UIView)
        XCTAssertEqual(before.text, "Before"); XCTAssertEqual(afterLabel.text, "After"); XCTAssertFalse(watermark.isHidden)
        let badge = try XCTUnwrap(share.value(forKey: "hdProBadge") as? UIView)
        let proLabel = try XCTUnwrap((badge.subviews.first as? UIStackView)?.arrangedSubviews.compactMap { $0 as? UILabel }.first)
        XCTAssertLessThanOrEqual(proLabel.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)).width * proLabel.minimumScaleFactor,
                                 proLabel.bounds.width + 0.5, "The full PRO badge must fit")
        let toggle = try XCTUnwrap(share.value(forKey: "watermarkSwitch") as? UISwitch)
        toggle.isOn = false; toggle.sendActions(for: .valueChanged); XCTAssertTrue(watermark.isHidden)
        toggle.isOn = true; toggle.sendActions(for: .valueChanged)
        try capture("share")
        await host.closePresentation()

        let icons = ["back", "download20", "share20", "more20", "compare", "like", "dislike", "again", "style", "paint", "replace", "remove", "floor", "furnish", "layout", "ask", "mic", "compare_left", "compare_right", "close20", "fit", "close16", "watermark", "mark", "hd", "crown", "download22", "copy", "message", "more22", "export"]
        for icon in icons { XCTAssertGreaterThan(try XCTUnwrap(UIImage(named: "figma_" + icon)).size.width, 0, icon) }
        metrics["compiledFigmaIcons"] = icons.count
        try JSONSerialization.data(withJSONObject: metrics, options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent("geometry.json"))
    }
}
