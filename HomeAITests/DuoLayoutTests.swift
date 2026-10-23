import XCTest
import UIKit
@testable import HomeAI

/// iPhone Duo layouts without folding the simulator: renders screens in windows sized like the outer display, the
/// unfolded display (portrait / landscape with the system bars on the right edge) and a Split View half.
/// Run on the "iPhone Duo" simulator with the HomeAIFullQA scheme:
///   TEST_RUNNER_DUO_OUT=/path TEST_RUNNER_DUO_SCREENS=home,result xcodebuild test -only-testing:HomeAITests/DuoLayoutTests
@MainActor @available(iOS 17.0, *)
final class DuoLayoutTests: XCTestCase {
    struct Variant {
        let name: String
        let size: CGSize?
        let regular: Bool
        let extraInsets: UIEdgeInsets
    }

    static let variants = [
        Variant(name: "outer", size: nil, regular: false, extraInsets: .zero),
        Variant(name: "inner-portrait", size: CGSize(width: 669, height: 951), regular: true, extraInsets: .zero),
        Variant(name: "inner-landscape", size: CGSize(width: 951, height: 669), regular: true,
                extraInsets: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 62)),
        Variant(name: "split-half", size: CGSize(width: 472, height: 669), regular: false,
                extraInsets: UIEdgeInsets(top: 24, left: 0, bottom: 20, right: 0))
    ]

    func testRenderDuoVariants() async throws {
        guard AppQA.enabled else { throw XCTSkip("Use the HomeAIFullQA scheme") }
        let env = ProcessInfo.processInfo.environment
        guard let out = env["DUO_OUT"] else { throw XCTSkip("Set TEST_RUNNER_DUO_OUT") }
        let screens = env["DUO_SCREENS"]?.split(separator: ",").map(String.init) ?? ["home", "inspiration", "projects"]
        let variants = env["DUO_VARIANTS"].map { names in Self.variants.filter { names.split(separator: ",").contains(Substring($0.name)) } }
            ?? Self.variants
        let folder = URL(fileURLWithPath: out, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        AppQA.seed()
        AppQA.snapshot = true
        AppQA.language = env["DUO_LANGUAGE"] ?? "en"
        AppQA.homeFocus = .interior
        UIView.setAnimationsEnabled(false)
        defer {
            AppQA.snapshot = false
            AppQA.language = nil
            AppQA.homeFocus = nil
            UIView.setAnimationsEnabled(true)
        }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)

        var report: [String] = ["screen bounds: \(scene.screen.bounds.size) scale \(scene.screen.scale)"]
        for variant in variants {
            let window = UIWindow(windowScene: scene)
            if let size = variant.size { window.frame = CGRect(origin: .zero, size: size) }
            window.traitOverrides.horizontalSizeClass = variant.regular ? .regular : .compact
            window.overrideUserInterfaceStyle = .light
            let host = QASnapshotHost()
            host.additionalSafeAreaInsets = variant.extraInsets
            window.rootViewController = host
            window.makeKeyAndVisible()
            for screen in screens {
                autoreleasepool {
                    let root = AppQA.container(for: AppQA.makeScreen(screen))
                    host.show(root)
                    window.layoutIfNeeded()
                }
                try await Task.sleep(nanoseconds: screen == "inspiration" ? 450_000_000 : 120_000_000)
                window.layoutIfNeeded()
                let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
                let image = renderer.image { _ in window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) }
                try image.pngData()?.write(to: folder.appendingPathComponent("\(variant.name)-\(screen).png"))
                report.append("\(variant.name) \(screen) window=\(window.bounds.size) safe=\(host.view.safeAreaInsets) "
                              + "hsc=\(host.traitCollection.horizontalSizeClass.rawValue)")
                await host.closePresentation()
            }
            host.clear()
            window.isHidden = true
        }
        try report.joined(separator: "\n").write(to: folder.appendingPathComponent("report.txt"), atomically: true,
                                                 encoding: .utf8)
    }
}
