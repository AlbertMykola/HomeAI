import XCTest
@testable import HomeAI

/// Catalog images must load from the app bundle with no network, so the catalog survives an image host outage
/// (Supabase 402 restriction, HOMEAI-R).
final class CatalogBundleImageTests: XCTestCase {
    func testCatalogPathsLoadFromBundle() {
        let paths = [
            "walls_image/wall_matte_paint_image.webp",       // Figma original (.jpg in CatalogFallback)
            "floor_images/flooring_natural_oak_image.webp",
            "inspiration_bathroom_image.png",
            "template_suggestions/kitchen_suggest_template.webp", // recovered .webp
            "modern-bedroom-design-interior_optimized.webp"
        ]
        let service = ImageStorageService()
        for path in paths {
            let loaded = expectation(description: path)
            service.fetchImage(path: path) { image in
                XCTAssertNotNil(image, path)
                XCTAssertNil(service.lastRemoteError(for: path), path)
                loaded.fulfill()
            }
            wait(for: [loaded], timeout: 5)
        }
    }
}
