import XCTest
import UIKit
@testable import HomeAI

/// Manual quality/cost check: the same photos and styles through the current image model and a candidate.
/// Real (billed) generations, so it only runs when asked:
///   TEST_RUNNER_MODEL_TEST_OUT=/path xcodebuild test -only-testing:HomeAITests/GeminiModelQualityTests
final class GeminiModelQualityTests: XCTestCase {
    private let models = ["gemini-3.1-flash-image-preview", "gemini-nano-banana-2.1"]
    private let cases: [(photo: String, room: InteriorType, style: StyleInteriorType)] = [
        ("wizard_demo_living", .livingroom, .japanese),
        ("wizard_demo_kitchen", .kitchen, .modern),
        ("wizard_demo_study", .study, .scandinavian)
    ]

    func testCompareModels() async throws {
        guard let out = ProcessInfo.processInfo.environment["MODEL_TEST_OUT"] else {
            throw XCTSkip("Set TEST_RUNNER_MODEL_TEST_OUT to run real generations")
        }
        let folder = URL(fileURLWithPath: out, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var report: [String] = []
        for (index, item) in cases.enumerated() {
            let photo = try XCTUnwrap(UIImage(named: item.photo)).normalizedForGeneration()
            try photo.jpegData(compressionQuality: 0.9)?.write(to: folder.appendingPathComponent("\(index)-original.jpg"))
            let manager = GemeniPromptManager()
            manager.updateOption(.interior)
            manager.updateBaseImage(photo)
            manager.updateRoom(item.room)
            manager.updateStyle(.interior(item.style))
            let input = try manager.makeGenerationInput()
            for model in models {
                let service = GeminiRESTService(
                    proxyURL: Constants.API.workerProxyBase + "/gemini/v1beta/models/\(model):generateContent",
                    modelResolver: { _ in model })
                let started = Date()
                do {
                    let result = try await service.generateImage(from: input)
                    try result.image.jpegData(compressionQuality: 0.9)?
                        .write(to: folder.appendingPathComponent("\(index)-\(model).jpg"))
                    report.append("\(index) \(item.style) \(model): ok \(Int(result.image.size.width))x\(Int(result.image.size.height)) "
                                  + "\(String(format: "%.1f", Date().timeIntervalSince(started))) s")
                } catch {
                    report.append("\(index) \(item.style) \(model): \(error)")
                }
            }
        }
        try report.joined(separator: "\n").write(to: folder.appendingPathComponent("report.txt"), atomically: true, encoding: .utf8)
    }
}
