import XCTest
import UIKit
@testable import HomeAI

@MainActor
final class LiveBackendSmokeTests: XCTestCase {
    func testConfiguredProviderReturnsADecodableImage() async throws {
        guard ProcessInfo.processInfo.environment["REHOMELY_LIVE_BACKEND_QA"] == "1" else {
            throw XCTSkip("Opt-in: one real generation with a bundled room photo")
        }
        _ = await SupabaseAppConfigService.shared.refreshIfNeeded()
        // Explicit environment bypasses the local QA provider, retaining the production provider selection.
        let service = ImageGenerationServiceFactory.make(environment: [:])
        let manager = GemeniPromptManager()
        manager.updateOption(.interior)
        manager.updateBaseImage(try XCTUnwrap(UIImage(named: "home_hero_before")))
        manager.updateRoom(.livingroom)
        manager.updateStyle(.interior(.modern))
        let result = try await service.generateImage(from: manager.makeGenerationInput())
        XCTAssertGreaterThan(result.image.size.width, 100)
        XCTAssertGreaterThan(result.image.size.height, 100)
        XCTAssertEqual(result.provider, service.provider)
        XCTAssertFalse(result.model.isEmpty)
        let image = XCTAttachment(image: result.image)
        image.name = "Live-provider-\(result.provider.rawValue)-\(result.model)"
        image.lifetime = .keepAlways
        add(image)
    }
}
