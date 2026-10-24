import XCTest
@testable import HomeAI

final class GenerationImageNormalizationTests: XCTestCase {
    func testNormalizationCapsLongEdgeAndUsesScaleOne() {
        let image = makeImage(size: CGSize(width: 4_000, height: 2_000))

        let normalized = image.normalizedForGeneration()

        XCTAssertEqual(normalized.imageOrientation, .up)
        XCTAssertEqual(normalized.scale, 1)
        XCTAssertEqual(normalized.generationPixelSize, CGSize(width: 1_536, height: 768))
    }

    func testNormalizationAppliesImageOrientation() throws {
        let original = makeImage(size: CGSize(width: 40, height: 20))
        let cgImage = try XCTUnwrap(original.cgImage)
        let rotated = UIImage(cgImage: cgImage, scale: 1, orientation: .right)

        let normalized = rotated.normalizedForGeneration()

        XCTAssertEqual(normalized.imageOrientation, .up)
        XCTAssertEqual(normalized.generationPixelSize, CGSize(width: 20, height: 40))
    }

    func testPromptManagerRejectsMismatchedMaskPixels() {
        let manager = GemeniPromptManager()
        manager.updateOption(.replace)
        manager.updateBaseImage(makeImage(size: CGSize(width: 100, height: 80)))
        manager.updateMask(makeImage(size: CGSize(width: 50, height: 40)))

        XCTAssertThrowsError(try manager.generatePromptParts()) { error in
            guard case PromptError.maskDimensionMismatch = error else {
                return XCTFail("Expected maskDimensionMismatch, got \(error)")
            }
        }
    }

    func testPromptManagerAcceptsMatchingMaskPixels() throws {
        let manager = GemeniPromptManager()
        manager.updateOption(.delete)
        manager.updateBaseImage(makeImage(size: CGSize(width: 100, height: 80)))
        manager.updateMask(makeImage(size: CGSize(width: 100, height: 80)))

        XCTAssertEqual(try manager.generatePromptParts().count, 3)
    }

    private func makeImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
