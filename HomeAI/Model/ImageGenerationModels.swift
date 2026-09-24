import UIKit

enum ImageGenerationProvider: String, Codable {
    case gemini
    case openAI = "openai"
}

struct ImageGenerationInput {
    let prompt: String
    let baseImage: UIImage
    let referenceImage: UIImage?
    let maskImage: UIImage?
    let designOption: DesignOption

    func prompt(for provider: ImageGenerationProvider) -> String {
        guard maskImage != nil else { return prompt }
        switch provider {
        case .gemini:
            return prompt + " MASK INPUT: The last supplied image is a grayscale mask aligned to the first image (the original photo). White marks the editable region; black marks protected content. The mask is selection data, not a style reference or part of the output."
        case .openAI:
            return prompt + " MASK INPUT: Use the separately supplied edit mask aligned to the original photo. Transparent areas are editable; opaque areas are protected. The mask is selection data and must not appear in the output."
        }
    }
}

struct ImageGenerationResult {
    let image: UIImage
    let prompt: String
    let provider: ImageGenerationProvider
    let model: String
}

protocol ImageGenerationFailure: LocalizedError {
    var category: String { get }
    var statusCode: Int? { get }
}

protocol ImageGenerationService {
    var provider: ImageGenerationProvider { get }
    func model(for option: DesignOption) -> String
    func generateImage(from input: ImageGenerationInput) async throws -> ImageGenerationResult
}
