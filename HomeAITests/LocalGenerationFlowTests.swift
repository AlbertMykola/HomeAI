import XCTest
import UIKit
@testable import HomeAI

@MainActor
final class LocalGenerationFlowTests: XCTestCase {
    private var generatedIDs: [String] = []

    override func setUpWithError() throws {
        guard AppQA.enabled else { throw XCTSkip("Use HomeAIFullQA") }
        AppQA.language = "en"; AppQA.premium = true; AppQA.freeCount = 0; AppQA.dailyCount = 0
        AppQA.generationService = QAGenerationService(delay: 1_000_000)
        AppQA.clearEvents()
    }

    override func tearDown() async throws {
        for id in generatedIDs { try await ProjectStore.shared.deleteProject(containing: id) }
        AppQA.language = nil; AppQA.premium = false; AppQA.snapshot = false
        AppQA.generationService = QAGenerationService()
    }

    func testEveryToolSavesRealFilesAndRestoresItsResultWithoutNetworking() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene), host = QASnapshotHost()
        window.rootViewController = host; window.makeKeyAndVisible()
        AppQA.snapshot = true
        defer { window.isHidden = true }
        let folder = AppQA.storageURL.appendingPathComponent("local-generations", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var rows: [[String: Any]] = []
        for option in DesignOption.allCases {
            let manager = manager(for: option)
            let outcome = try await generate(manager)
            generatedIDs.append(outcome.docID)
            let project = try XCTUnwrap(ProjectStore.shared.project(containing: outcome.docID))
            let doc = try XCTUnwrap(project.versions.first)
            XCTAssertEqual(doc.designOption, option)
            XCTAssertEqual(doc.model, "qa-local-\(option.rawValue)")
            XCTAssertTrue(doc.hasLocalOriginal)
            XCTAssertNotNil(doc.previewPath)
            XCTAssertTrue(doc.storagePath.hasPrefix(AppQA.storageURL.path))
            let loaded = try await ImageHistoryService().loadImage(at: doc.storagePath)
            XCTAssertEqual(loaded.generationPixelSize, outcome.model.image.generationPixelSize)
            XCTAssertNotEqual(loaded.jpegData(compressionQuality: 0.7), manager.baseImage?.jpegData(compressionQuality: 0.7))
            let vc = AppStoryboard.instantiate(ResultViewController.self)
            vc.docID = doc.id // Deliberately no initial image: must load actual history files.
            host.show(AppQA.container(for: vc)); window.layoutIfNeeded()
            try await Task.sleep(nanoseconds: 100_000_000)
            let result = try XCTUnwrap(vc.value(forKey: "resultImageView") as? UIImageView)
            XCTAssertNotNil(result.image)
            let original = try XCTUnwrap(vc.value(forKey: "originalImageView") as? UIImageView)
            XCTAssertNotNil(original.image)
            let compare = AppStoryboard.instantiate(CompareViewController.self)
            compare.beforeImage = original.image; compare.afterImage = result.image
            host.show(compare); window.layoutIfNeeded()
            let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
            try renderer.image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
                .pngData()?.write(to: folder.appendingPathComponent(option.rawValue + "-compare.png"))
            let restored = HistoryDocOpener.restoredManager(for: doc, baseImage: try XCTUnwrap(manager.baseImage))
            XCTAssertNoThrow(try restored.makeGenerationInput(), "Cannot regenerate saved \(option)")
            if [.reference, .replace, .delete].contains(option) {
                let regenerated = try await generate(restored, baseDocID: doc.id)
                XCTAssertEqual(ProjectStore.shared.project(containing: regenerated.docID)?.versions.count, 2)
                if option == .reference { XCTAssertNotNil(restored.referenceImage) }
                else { XCTAssertEqual(restored.maskImage?.generationPixelSize, restored.baseImage?.generationPixelSize) }
            }
            rows.append(["option": option.rawValue, "docID": doc.id,
                         "width": loaded.generationPixelSize.width, "height": loaded.generationPixelSize.height,
                         "preview": doc.previewPath != nil, "original": doc.hasLocalOriginal])
            host.clear()
        }
        let blocked = AppQA.events.filter { $0["name"] as? String == "qa_network_blocked" }
        XCTAssertTrue(blocked.isEmpty, "Unexpected network attempt: \(blocked)")
        XCTAssertEqual(AppQA.events.filter { $0["name"] as? String == "generation_succeeded" }.count, DesignOption.allCases.count + 3)
        try JSONSerialization.data(withJSONObject: ["device": UIDevice.current.name, "results": rows,
                                                    "blockedNetworkAttempts": blocked.count], options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent("pipeline.json"))
    }

    func testEditsVersionsExportsAndDeletionKeepOriginalAndSurvivingFiles() async throws {
        let first = try await generate(manager(for: .interior))
        generatedIDs.append(first.docID)
        let base = try XCTUnwrap(ProjectStore.shared.project(containing: first.docID))
        let firstDoc = try XCTUnwrap(base.versions.first)
        let originalData = try Data(contentsOf: URL(fileURLWithPath: try XCTUnwrap(firstDoc.originalPath)))
        for option in [DesignOption.newWalls, .newFlooring, .replace, .delete, .rearrange] {
            let edit = manager(for: option)
            edit.updateBaseImage(first.model.image)
            if option == .replace || option == .delete { edit.updateMask(mask(for: try XCTUnwrap(edit.baseImage))) }
            let outcome = try await generate(edit, baseDocID: first.docID)
            XCTAssertEqual(ProjectStore.shared.project(containing: outcome.docID)?.project.id, base.project.id)
            ProjectStore.shared.setNote("Local \(option.rawValue)", for: outcome.docID)
            XCTAssertEqual(ProjectStore.shared.note(for: outcome.docID), "Local \(option.rawValue)")
        }
        var project = try XCTUnwrap(ProjectStore.shared.project(containing: first.docID))
        XCTAssertEqual(project.versions.count, 6)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: try XCTUnwrap(firstDoc.originalPath))), originalData)
        ProjectStore.shared.rename(projectContaining: first.docID, to: "Local QA project")
        project = try XCTUnwrap(ProjectStore.shared.project(containing: first.docID))
        XCTAssertEqual(project.project.title, "Local QA project")
        let image = first.model.image
        for pro in [false, true] {
            let exported = PhotoSaver.exportImage(image, pro: pro, watermark: !pro)
            XCTAssertLessThanOrEqual(max(exported.generationPixelSize.width, exported.generationPixelSize.height), pro ? 4096 : 1080)
            XCTAssertEqual(exported.size.width / exported.size.height, image.size.width / image.size.height, accuracy: 0.002)
        }
        let deleted = try XCTUnwrap(project.versions.last)
        try await ProjectStore.shared.deleteVersion(docID: deleted.id)
        XCTAssertFalse(FileManager.default.fileExists(atPath: deleted.storagePath))
        XCTAssertEqual(ProjectStore.shared.project(containing: first.docID)?.versions.count, 5)
        XCTAssertTrue(FileManager.default.fileExists(atPath: firstDoc.storagePath))

        // The optional fields must keep pre-existing history decodable.
        AppQA.seed()
        let legacy = try XCTUnwrap(ImageHistoryService().allDocs().first { $0.id == AppQA.fixtureDocID })
        XCTAssertNil(legacy.referencePath); XCTAssertNil(legacy.maskPath)

        // A saved mask must reopen against the edit input even if the caller supplies a different photo.
        let maskedDoc = try XCTUnwrap(project.versions.first { $0.designOption == .replace })
        let restored = HistoryDocOpener.restoredManager(for: maskedDoc, baseImage: UIImage(named: "home_card_exterior")!)
        XCTAssertEqual(restored.baseImage?.generationPixelSize, first.model.image.generationPixelSize)
        XCTAssertNoThrow(try restored.makeGenerationInput())
    }

    func testPortraitLandscapeSquareAndSmallResponsesAcrossLanguages() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene), host = QASnapshotHost()
        window.rootViewController = host; window.makeKeyAndVisible()
        AppQA.snapshot = true
        defer { window.isHidden = true }
        let languages = (ProcessInfo.processInfo.environment["REHOMELY_QA_LANGUAGES"] ?? "cs,da,de,en,es,fr,it,ja,ko,nb,nl,pl,pt-BR,ru,uk").split(separator: ",").map(String.init)
        let folder = AppQA.storageURL.appendingPathComponent("local-generations", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var cases = 0
        for size in [CGSize(width: 1024, height: 1536), CGSize(width: 1536, height: 1024), CGSize(width: 1024, height: 1024), CGSize(width: 200, height: 300)] {
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in AppQA.photo.draw(in: CGRect(origin: .zero, size: size)) }
            AppQA.generationService = QAGenerationService(delay: 1_000_000, image: image)
            let outcome = try await generate(manager(for: .interior)); generatedIDs.append(outcome.docID)
            for language in languages {
                AppQA.language = language
                for theme in [UIUserInterfaceStyle.light, .dark] {
                    window.overrideUserInterfaceStyle = theme
                    let vc = AppStoryboard.instantiate(ResultViewController.self)
                    vc.docID = outcome.docID; vc.initialImage = outcome.model.image
                    host.show(AppQA.container(for: vc)); window.layoutIfNeeded()
                    let panel = try XCTUnwrap(vc.value(forKey: "panelView") as? UIView)
                    XCTAssertGreaterThan(panel.bounds.height, 150)
                    XCTAssertLessThanOrEqual(panel.convert(panel.bounds, to: window).maxY, window.bounds.maxY + 1)
                    let ask = try XCTUnwrap(vc.value(forKey: "askControl") as? UIControl)
                    XCTAssertGreaterThan(ask.bounds.height, 30)
                    XCTAssertLessThanOrEqual(ask.convert(ask.bounds, to: window).maxY, window.bounds.maxY + 1)
                    let result = try XCTUnwrap(vc.value(forKey: "resultImageView") as? UIImageView)
                    XCTAssertEqual(result.image?.generationPixelSize, size)
                    if language == "uk" && theme == .dark {
                        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
                        try renderer.image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
                            .pngData()?.write(to: folder.appendingPathComponent("result-\(Int(size.width))x\(Int(size.height)).png"))
                    }
                    cases += 1
                    host.clear()
                }
            }
        }
        try JSONSerialization.data(withJSONObject: ["device": UIDevice.current.name, "resultStates": cases], options: [.prettyPrinted])
            .write(to: folder.appendingPathComponent("result-layout.json"))
    }

    func testTransientFailureCanRetryAndCancellationDoesNotCreateAProject() async throws {
        AppQA.premium = false
        AppQA.generationService = QAGenerationService(delay: 1_000_000, failure: "server", failFirst: true)
        let runner = GenerationRunner(promptManager: manager(for: .interior))
        let failed = expectation(description: "local failure")
        runner.onStateChange = { if case .failed = $0 { failed.fulfill() } }
        runner.start(); await fulfillment(of: [failed], timeout: 8)
        XCTAssertEqual(AppQA.freeCount, 0)
        let saved = expectation(description: "retry saved")
        runner.onStateChange = { if case .succeeded(let outcome) = $0 { self.generatedIDs.append(outcome.docID); saved.fulfill() } }
        runner.retry(); await fulfillment(of: [saved], timeout: 8)
        XCTAssertEqual(AppQA.freeCount, 1)
        for category in ["no_image", "content_blocked"] {
            AppQA.generationService = QAGenerationService(delay: 1_000_000, failure: category)
            let failure = GenerationRunner(promptManager: manager(for: .interior))
            let done = expectation(description: category)
            failure.onStateChange = { state in
                if case .failed(let reason) = state {
                    switch (category, reason) {
                    case ("no_image", .photoNotSuitable), ("content_blocked", .contentBlocked): break
                    default: XCTFail("Wrong local error mapping")
                    }
                    done.fulfill()
                }
            }
            failure.start(); await fulfillment(of: [done], timeout: 8)
            XCTAssertEqual(AppQA.freeCount, 1)
        }
        let count = ImageHistoryService().allDocs().count
        AppQA.generationService = QAGenerationService(delay: 3_000_000_000)
        let cancelled = GenerationRunner(promptManager: manager(for: .interior))
        let done = expectation(description: "cancelled")
        cancelled.onStateChange = { if case .idle = $0 { done.fulfill() } }
        cancelled.start(); cancelled.cancel(); await fulfillment(of: [done], timeout: 8)
        XCTAssertEqual(ImageHistoryService().allDocs().count, count)
        XCTAssertEqual(AppQA.freeCount, 1)
        XCTAssertFalse(AppQA.events.contains { $0["name"] as? String == "qa_network_blocked" })
    }

    func testHTTPGuardInterceptsDefaultAndEphemeralSessions() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        QANetworkBlocker.protect(configuration)
        for session in [URLSession.shared, URLSession(configuration: configuration)] {
            do {
                _ = try await session.data(from: URL(string: "https://local-generation-qa.invalid/probe")!)
                XCTFail("QA HTTP guard must fail closed")
            } catch { XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet) }
        }
        XCTAssertEqual(AppQA.events.filter { $0["name"] as? String == "qa_network_blocked" }.count, 2)
    }

    func testShareFormatsPreviewAndHDExportMatchTheSelectedOptions() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene), host = QASnapshotHost()
        window.rootViewController = host; window.makeKeyAndVisible(); AppQA.snapshot = true
        defer { window.isHidden = true }
        let folder = AppQA.storageURL.appendingPathComponent("local-generations", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var rows: [[String: Any]] = []
        for premium in [false, true] {
            AppQA.premium = premium
            ShareSheetViewController.present(from: host, before: AppQA.original, after: AppQA.photo)
            let sheet = try XCTUnwrap(host.presentedViewController as? ShareSheetViewController)
            sheet.loadViewIfNeeded(); window.layoutIfNeeded()
            try await Task.sleep(nanoseconds: 60_000_000)
            window.layoutIfNeeded()
            let formats = try XCTUnwrap(sheet.value(forKey: "formatControls") as? [DSPressableControl])
            let actions = try XCTUnwrap(sheet.value(forKey: "actionControls") as? [DSPressableControl])
            let hd = try XCTUnwrap(sheet.value(forKey: "hdSwitch") as? UISwitch)
            let single = try XCTUnwrap(sheet.value(forKey: "singleImageView") as? UIImageView)
            let split = try XCTUnwrap((sheet.value(forKey: "beforeImageView") as? UIImageView)?.superview)
            for format in 0...2 {
                formats.first { $0.tag == format }?.sendActions(for: .touchUpInside)
                XCTAssertEqual(split.isHidden, format != 0, "Letterboxing must not reveal a second preview underneath Story")
                if format == 2 {
                    let preview = try XCTUnwrap(single.image)
                    XCTAssertEqual(preview.size.width / preview.size.height, 9 / 16.0, accuracy: 0.001)
                    XCTAssertEqual(single.contentMode, .scaleAspectFit)
                }
                for highDefinition in premium ? [false, true] : [false] {
                    hd.isOn = highDefinition
                    actions.first { $0.tag == 1 }?.sendActions(for: .touchUpInside)
                    XCTAssertTrue(AppQA.events.contains { $0["name"] as? String == "share_action" }, "Copy must reach the sheet's action handler")
                    try await Task.sleep(nanoseconds: 50_000_000)
                    let exported = try XCTUnwrap(UIPasteboard.general.image, "Copy types: \(UIPasteboard.general.types)")
                    let longest = max(exported.generationPixelSize.width, exported.generationPixelSize.height)
                    if highDefinition { XCTAssertGreaterThan(longest, 1080) }
                    else { XCTAssertLessThanOrEqual(longest, 1080) }
                    if format == 2 { XCTAssertEqual(exported.size.width / exported.size.height, 9 / 16.0, accuracy: 0.002) }
                    if premium && highDefinition {
                        try exported.pngData()?.write(to: folder.appendingPathComponent("export-format-\(format).png"))
                    }
                    rows.append(["premium": premium, "format": format, "HD": highDefinition,
                                 "width": exported.generationPixelSize.width, "height": exported.generationPixelSize.height])
                }
            }
            await host.closePresentation()
        }
        try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent("exports.json"))
    }

    func testShareSheetActionsRemainReachableAcrossLanguages() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene), host = QASnapshotHost()
        window.rootViewController = host; window.makeKeyAndVisible(); AppQA.snapshot = true
        defer { window.isHidden = true }
        var rows: [[String: Any]] = []
        for language in ["cs", "da", "de", "en", "es", "fr", "it", "ja", "ko", "nb", "nl", "pl", "pt-BR", "ru", "uk"] {
            AppQA.language = language
            for premium in [false, true] {
                AppQA.premium = premium
                ShareSheetViewController.present(from: host, before: AppQA.original, after: AppQA.photo)
                let sheet = try XCTUnwrap(host.presentedViewController as? ShareSheetViewController)
                sheet.loadViewIfNeeded(); window.layoutIfNeeded()
                // Nonanimated custom presentations still receive their container layout on the next run-loop turn.
                try await Task.sleep(nanoseconds: 60_000_000)
                window.layoutIfNeeded()
                let scroll = try XCTUnwrap(sheet.value(forKey: "contentScrollView") as? UIScrollView)
                let share = try XCTUnwrap(sheet.value(forKey: "shareButton") as? UIControl)
                let title = try XCTUnwrap(sheet.value(forKey: "titleLabel") as? UILabel)
                let close = try XCTUnwrap(sheet.value(forKey: "closeButton") as? UIControl)
                scroll.setContentOffset(CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height)), animated: false)
                window.layoutIfNeeded()
                XCTAssertFalse(title.convert(title.bounds, to: sheet.view).intersects(close.convert(close.bounds, to: sheet.view)),
                               "Share title overlaps Close: \(language); title=\(title.frame), close=\(close.frame)")
                let button = share.convert(share.bounds, to: scroll)
                XCTAssertGreaterThan(share.bounds.height, 40)
                XCTAssertGreaterThanOrEqual(button.minY, scroll.bounds.minY - 1, language)
                XCTAssertLessThanOrEqual(button.maxY, scroll.bounds.maxY + 1, language)
                for label in descendants(of: sheet.view).compactMap({ $0 as? UILabel }) where label.numberOfLines == 0 {
                    XCTAssertGreaterThan(label.bounds.width, 0)
                    XCTAssertLessThanOrEqual(label.sizeThatFits(CGSize(width: label.bounds.width, height: .greatestFiniteMagnitude)).height,
                                             label.bounds.height + 1, "Clipped share text: \(language) \(label.text ?? "")")
                }
                rows.append(["language": language, "premium": premium, "shareButtonVisibleAfterScroll": true,
                             "scrollable": scroll.contentSize.height > scroll.bounds.height])
                await host.closePresentation()
            }
        }
        let folder = AppQA.storageURL.appendingPathComponent("local-generations", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent("share-layout.json"))
    }

    func testCompareModesDragZoomAndFitExposeTheCorrectImageRegions() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene), host = QASnapshotHost()
        window.rootViewController = host; window.makeKeyAndVisible(); AppQA.snapshot = true
        defer { window.isHidden = true }
        let compare = AppStoryboard.instantiate(CompareViewController.self)
        compare.beforeImage = AppQA.original; compare.afterImage = AppQA.photo
        host.show(compare); window.layoutIfNeeded()
        let stage = try XCTUnwrap(compare.value(forKey: "stageView") as? UIView)
        let clip = try XCTUnwrap(compare.value(forKey: "beforeClipView") as? UIView)
        let before = try XCTUnwrap(compare.value(forKey: "beforeImageView") as? UIImageView)
        let after = try XCTUnwrap(compare.value(forKey: "afterImageView") as? UIImageView)
        let divider = try XCTUnwrap(compare.value(forKey: "dividerView") as? UIView)
        let controls = try XCTUnwrap(compare.value(forKey: "segmentControls") as? [DSPressableControl])
        var rows: [[String: Any]] = []
        for (mode, fraction) in [(0, 1.0), (1, 0.5), (2, 0.0), (1, 0.5)] {
            controls.first { $0.tag == mode }?.sendActions(for: .touchUpInside)
            window.layoutIfNeeded()
            XCTAssertEqual(clip.bounds.width / stage.bounds.width, fraction, accuracy: 0.002)
            XCTAssertEqual(before.bounds.size, stage.bounds.size, "Clipping must not resize the original photo")
            XCTAssertEqual(divider.alpha, mode == 1 ? 1 : 0)
            rows.append(["mode": mode, "visibleOriginalFraction": clip.bounds.width / stage.bounds.width])
        }
        let pan = LocalComparePan()
        for fraction in [0.25, 0.75] {
            pan.point = CGPoint(x: stage.bounds.width * fraction, y: stage.bounds.midY)
            compare.perform(NSSelectorFromString("handleDrag:"), with: pan)
            window.layoutIfNeeded()
            XCTAssertEqual(clip.bounds.width / stage.bounds.width, fraction, accuracy: 0.002)
            XCTAssertEqual(divider.frame.midX, clip.frame.maxX, accuracy: 0.5)
        }
        let pinch = UIPinchGestureRecognizer(); pinch.scale = 2
        compare.perform(NSSelectorFromString("handlePinch:"), with: pinch)
        XCTAssertEqual(before.transform, after.transform)
        XCTAssertEqual(after.transform.a, 2, accuracy: 0.001)
        let fit = try XCTUnwrap(compare.value(forKey: "fitButton") as? UIControl)
        fit.sendActions(for: .touchUpInside)
        XCTAssertEqual(before.transform, .identity); XCTAssertEqual(after.transform, .identity)
        let folder = AppQA.storageURL.appendingPathComponent("local-generations", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
            .write(to: folder.appendingPathComponent("compare-layout.json"))
    }

    private func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }

    private func generate(_ manager: GemeniPromptManager, baseDocID: String? = nil) async throws -> GenerationRunner.Outcome {
        let runner = GenerationRunner(promptManager: manager, baseDocID: baseDocID)
        let done = expectation(description: "local \(manager.designOption)")
        var output: GenerationRunner.Outcome?
        runner.onStateChange = { state in
            if case .succeeded(let outcome) = state { output = outcome; done.fulfill() }
            if case .failed(let failure) = state { XCTFail("Local generation failed: \(failure)"); done.fulfill() }
        }
        runner.start(); runner.start() // Rapid duplicate taps must still save just one result.
        await fulfillment(of: [done], timeout: 12)
        return try XCTUnwrap(output)
    }

    private func manager(for option: DesignOption) -> GemeniPromptManager {
        let manager = GemeniPromptManager()
        manager.updateOption(option); manager.updateBaseImage(AppQA.original)
        manager.updateRoom(.livingroom); manager.updateExteriorType(.house)
        manager.updateStyle(.interior(.modern)); manager.updateStyle(.exterior(.modern))
        manager.updateRearrangeSubOption(.sameFurnitureOnly)
        if option == .newWalls { manager.updateSurfaceMaterial(.mattePaint) }
        if option == .newFlooring { manager.updateSurfaceMaterial(.naturalOak) }
        if option == .reference { manager.updateReferenceImage(AppQA.photo) }
        if option == .replace || option == .delete {
            manager.updateMask(mask(for: manager.baseImage!))
            manager.updateObjectToReplace("Green armchair")
            manager.updateReplaceMode(option == .delete ? .remove : .replace)
        }
        return manager
    }

    private func mask(for image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: image.generationPixelSize, format: format).image { context in
            UIColor.black.setFill(); context.fill(CGRect(origin: .zero, size: image.generationPixelSize))
            UIColor.white.setFill(); context.fill(CGRect(x: 100, y: 100, width: 150, height: 200))
        }
    }
}

private final class LocalComparePan: UIPanGestureRecognizer {
    var point: CGPoint = .zero
    override func location(in view: UIView?) -> CGPoint { point }
}
