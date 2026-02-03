import UIKit
import GoogleGenerativeAI

/// Менеджер для формування промпту та даних для заміни об'єктів на зображенні
final class ObjectReplacementManager {
    
    // MARK: - Properties
    
    /// Базове зображення, на якому потрібно замінити об'єкт
    private(set) var baseImage: UIImage?
    
    /// Бінарна маска (чорне/біле), де білий = область для заміни
    private(set) var maskImage: UIImage?
    
    /// Дані маски в PNG форматі для API
    private(set) var maskData: Data?
    
    /// Опис об'єкта, який потрібно замінити (опціонально)
    private(set) var objectDescription: String?
    
    /// Додатковий опис того, на що замінити (опціонально)
    private(set) var replacementDescription: String?
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Data Setup Methods
    
    /// Встановлює базове зображення
    func setBaseImage(_ image: UIImage) {
        self.baseImage = image
    }
    
    /// Встановлює маску для заміни
    func setMask(_ mask: UIImage) {
        self.maskImage = mask
        self.maskData = mask.pngData()
    }
    
    /// Встановлює опис об'єкта для заміни
    func setObjectDescription(_ description: String?) {
        self.objectDescription = description?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Встановлює опис того, на що замінити
    func setReplacementDescription(_ description: String?) {
        self.replacementDescription = description?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Validation
    
    /// Перевіряє, чи всі необхідні дані наявні
    func validate() throws {
        guard baseImage != nil else {
            throw ObjectReplacementError.missingBaseImage
        }
        
        guard maskImage != nil || objectDescription != nil else {
            throw ObjectReplacementError.missingMaskOrDescription
        }
    }
    
    // MARK: - Prompt Generation
    
    /// Генерує промпт для заміни об'єкта
    func generatePrompt() -> String {
        var prompt = "You are an expert AI object replacement specialist."
        prompt += " You will receive an image where you need to replace specific objects while maintaining the overall scene integrity."
        
        // Додаємо інформацію про маску
        if maskImage != nil {
            prompt += "\n\n"
            prompt += "**MASK INFORMATION:**"
            prompt += " The user has drawn a precise mask on the image indicating the exact area that needs to be replaced."
            prompt += " The mask is a binary image where white pixels indicate the area to replace and black pixels indicate areas to preserve."
            prompt += " Focus ONLY on the masked (white) area - this is the region that must be replaced."
            prompt += " Everything outside the mask (black areas) must remain completely unchanged, pixel-perfect."
        }
        
        // Додаємо опис об'єкта, якщо є
        if let objectDesc = objectDescription, !objectDesc.isEmpty {
            prompt += "\n\n"
            prompt += "**OBJECT TO REPLACE:**"
            prompt += " The user wants to replace: '\(objectDesc)'"
        }
        
        // Додаємо опис заміни, якщо є
        if let replacementDesc = replacementDescription, !replacementDesc.isEmpty {
            prompt += "\n\n"
            prompt += "**REPLACEMENT SPECIFICATION:**"
            prompt += " Replace with: '\(replacementDesc)'"
            prompt += " The replacement must match this description while fitting seamlessly into the scene."
        }
        
        prompt += "\n\n"
        prompt += "**YOUR TASK:**"
        
        if maskImage != nil {
            prompt += "\n1. Identify the masked area in the image (the white region in the mask)."
            prompt += "\n2. Replace ONLY the content within the masked area with a high-quality, photorealistic alternative."
            prompt += "\n3. The replacement must fit seamlessly into the scene, matching the style, lighting, shadows, and perspective of the surrounding area."
        } else if let objectDesc = objectDescription {
            prompt += "\n1. Locate the '\(objectDesc)' in the image."
            prompt += "\n2. Replace it with a high-quality, photorealistic alternative that fits the room's style and context."
        } else {
            prompt += "\n1. Identify objects in the image that need replacement."
            prompt += "\n2. Replace them with high-quality, photorealistic alternatives."
        }
        
        prompt += "\n4. Maintain the original lighting, perspective, and camera angle."
        prompt += "\n5. Ensure the replaced area blends seamlessly with the surrounding environment."
        prompt += "\n6. Preserve all architectural elements, background, and non-targeted objects exactly as they appear."
        prompt += "\n7. Keep the same color temperature and lighting conditions."
        
        prompt += "\n\n"
        prompt += "**CRITICAL RULES - DO NOT VIOLATE:**"
        
        if maskImage != nil {
            prompt += "\n1. **RESPECT THE MASK:** Only modify the area indicated by the white pixels in the mask. Everything outside the mask (black pixels) must remain pixel-perfect unchanged. Do not modify even a single pixel outside the masked area."
        }
        
        prompt += "\n2. **PRESERVE STRUCTURE:** Keep all walls, floors, ceilings, windows, doors, and fixed architectural elements completely unchanged."
        prompt += "\n3. **MAINTAIN PERSPECTIVE:** Do not change the camera angle, field of view, or viewing position."
        prompt += "\n4. **SEAMLESS INTEGRATION:** The replaced area must look natural and belong in the scene, matching the lighting, shadows, reflections, and color temperature of the original image."
        prompt += "\n5. **NO GEOMETRIC DISTORTION:** Do not warp, stretch, or distort the image geometry."
        prompt += "\n6. **PHOTOREALISM:** The final output must be a high-quality, photorealistic image that looks like a real photograph."
        prompt += "\n7. **NO TEXT/LOGOS:** Do not add any text, watermarks, or logos."
        prompt += "\n8. **CONTEXT AWARENESS:** The replacement must make sense in the context of the room. For example, if replacing furniture, it should match the room's style and scale."
        
        prompt += "\n\n"
        prompt += "Generate the new image with the specified area replaced while maintaining the integrity of the original scene."
        
        return prompt
    }
    
    // MARK: - API Data Preparation
    
    /// Готує дані для відправки в API
    /// Повертає масив частин промпту: [baseImage, maskImage (optional), textPrompt]
    func prepareAPIData() throws -> [ModelContent.Part] {
        try validate()
        
        guard let baseImage = baseImage else {
            throw ObjectReplacementError.missingBaseImage
        }
        
        guard let baseImageData = baseImage.jpegData(compressionQuality: 0.8) else {
            throw ObjectReplacementError.imageConversionFailed
        }
        
        var parts: [ModelContent.Part] = []
        
        // 1. Додаємо базове зображення
        parts.append(.data(mimetype: "image/jpeg", baseImageData))
        
        // 2. Додаємо маску, якщо вона є
        // Примітка: Gemini API може не підтримувати маски напряму як окремий параметр,
        // тому маска може бути описана в текстовому промпті або додана як друге зображення
        if let maskData = maskData {
            // Додаємо маску як друге зображення з описом в промпті
            parts.append(.data(mimetype: "image/png", maskData))
        }
        
        // 3. Додаємо текстовий промпт
        let textPrompt = generatePrompt()
        parts.append(.text(textPrompt))
        
        return parts
    }
    
    // MARK: - Helper Methods
    
    /// Очищає всі дані
    func reset() {
        baseImage = nil
        maskImage = nil
        maskData = nil
        objectDescription = nil
        replacementDescription = nil
    }
    
    /// Перевіряє, чи готові дані для відправки
    var isReady: Bool {
        return baseImage != nil && (maskImage != nil || objectDescription != nil)
    }
}

// MARK: - Errors

enum ObjectReplacementError: LocalizedError {
    case missingBaseImage
    case missingMaskOrDescription
    case imageConversionFailed
    case invalidMaskFormat
    
    var errorDescription: String? {
        switch self {
        case .missingBaseImage:
            return "Base image is required for object replacement."
        case .missingMaskOrDescription:
            return "Either mask image or object description is required."
        case .imageConversionFailed:
            return "Failed to convert image to required format."
        case .invalidMaskFormat:
            return "Mask image must be in valid format."
        }
    }
}
