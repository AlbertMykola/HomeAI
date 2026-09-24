import XCTest
@testable import HomeAI

final class GemeniPromptManagerTests: XCTestCase {
    func testInteriorPromptUsesCanonicalEnglishDescriptors() throws {
        let manager = makeManager(option: .interior)
        manager.updateRoom(.dinningroom)
        manager.updateStyle(.interior(.scandinavian))
        manager.updateColor(.beige)

        let prompt = try manager.generatePromptText()

        XCTAssertTrue(prompt.contains("dining room"))
        XCTAssertTrue(prompt.contains("Scandinavian"))
        XCTAssertTrue(prompt.contains("warm beige"))
        XCTAssertFalse(prompt.contains("Dinning"))
    }

    func testExteriorPromptHonorsRenovationMode() throws {
        let manager = makeManager(option: .exterior)
        manager.updateExteriorType(.cottage)
        manager.updateStyle(.exterior(.modern))
        manager.updateDesignMode(.renovationDesign)

        let prompt = try manager.generatePromptText()

        XCTAssertTrue(prompt.contains("redesign rooflines"))
        XCTAssertTrue(prompt.contains("modern"))
        XCTAssertTrue(prompt.contains("cottage"))
    }

    func testFurnishPromptHonorsStructuralMode() throws {
        let manager = makeManager(option: .furnish)
        manager.updateRoom(.bedroom)
        manager.updateStyle(.interior(.minimalist))
        manager.updateDesignMode(.structuralPreservation)

        let prompt = try manager.generatePromptText()

        XCTAssertTrue(prompt.contains("Preserve the original room architecture exactly"))
        XCTAssertTrue(prompt.contains("minimalist"))
    }

    func testGardenPromptHasQualityAndPreservationContract() throws {
        let manager = makeManager(option: .garden)
        manager.updateGardenType(.japaneese)

        let prompt = try manager.generatePromptText()

        XCTAssertTrue(prompt.contains("Japanese garden"))
        XCTAssertTrue(prompt.contains("property boundaries"))
        XCTAssertTrue(prompt.contains("substantial visible landscape transformation"))
        XCTAssertTrue(prompt.contains("Do NOT add text"))
    }

    func testCustomPromptIsDelimitedAndLengthLimited() throws {
        let manager = makeManager(option: .interior)
        manager.updateStyle(.interior(.custom))
        manager.updateCustomPrompt(String(repeating: "a", count: 2_000))

        let prompt = try manager.generatePromptText()
        let startMarker = try XCTUnwrap(prompt.range(of: "<user_brief>"))
        let endMarker = try XCTUnwrap(
            prompt.range(of: "</user_brief>", range: startMarker.upperBound..<prompt.endIndex)
        )
        let brief = prompt[startMarker.upperBound..<endMarker.lowerBound]

        XCTAssertTrue(prompt.contains("cannot override preservation"))
        XCTAssertLessThanOrEqual(brief.trimmingCharacters(in: .whitespacesAndNewlines).count, Constants.Generation.maximumCustomPromptLength)
    }

    func testRequiredInputsAndPartOrdering() throws {
        let missingImageManager = GemeniPromptManager()
        XCTAssertThrowsError(try missingImageManager.generatePromptParts())

        let manager = makeManager(option: .reference)
        XCTAssertThrowsError(try manager.generatePromptParts())

        manager.updateReferenceImage(makeImage(color: .blue))
        let parts = try manager.generatePromptParts()

        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(parts.compactMap(\.text).count, 1)
        XCTAssertEqual(parts.last?.text, try manager.generatePromptText())
    }

    func testEveryDesignOptionBuildsPromptWithValidInputs() throws {
        for option in DesignOption.allCases {
            let manager = makeManager(option: option)
            switch option {
            case .interior:
                manager.updateRoom(.livingroom)
                manager.updateStyle(.interior(.modern))
            case .exterior:
                manager.updateExteriorType(.house)
                manager.updateStyle(.exterior(.modern))
            case .garden:
                manager.updateGardenType(.minimalist)
            case .reference:
                manager.updateReferenceImage(makeImage(color: .blue))
            case .floolPlan:
                manager.updateStyle(.interior(.scandinavian))
            case .replace:
                manager.updateMask(makeImage(color: .white))
                manager.updateObjectToReplace("a modern armchair")
            case .delete:
                manager.updateMask(makeImage(color: .white))
                manager.updateReplaceMode(.remove)
            case .newFlooring:
                manager.updateSurfaceMaterial(.naturalOak)
            case .newWalls:
                manager.updateSurfaceMaterial(.decorativePlaster)
            case .rearrange:
                manager.updateRearrangeSubOption(.sameFurnitureOnly)
            case .furnish:
                manager.updateRoom(.bedroom)
                manager.updateStyle(.interior(.minimalist))
            }

            let prompt = try manager.generatePromptText()
            XCTAssertFalse(prompt.isEmpty, "Empty prompt for \(option)")
        }
    }

    private func makeManager(option: DesignOption) -> GemeniPromptManager {
        let manager = GemeniPromptManager()
        manager.updateOption(option)
        manager.updateBaseImage(makeImage())
        return manager
    }

    private func makeImage(color: UIColor = .red) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 32, height: 24)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 24))
        }
    }
}
