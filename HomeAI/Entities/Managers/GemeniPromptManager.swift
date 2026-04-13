import UIKit
import GoogleGenerativeAI

// Визначаємо кастомні помилки
enum PromptError: Error {
    case missingData(String)
    case imageConversionFailed
}

// ----- НОВА НАЗВА КЛАСУ -----
class GemeniPromptManager {
    
    // MARK: - Дані, що збираються покроково
    
    private(set) var designOption: DesignOption = .interior
    
    // Крок 1: Фото
    private(set) var baseImage: UIImage?
    private(set) var referenceImage: UIImage? // Для режиму .reference
    
    // Крок 2: Тип
    private(set) var interiorRoomType: InteriorType?
    private(set) var exteriorBuildingType: ExteriorType?
    private(set) var gardenType: GardenType?
    
    // Дизайн-режим: структурне збереження або вільна реновація
    private(set) var designMode: DesignMode = .structuralPreservation
    
    // Крок 3: Стиль
    private(set) var interiorStyle: StyleInteriorType?
    private(set) var exteriorStyle: StyleExteriorType?
    
    // Крок 4: Колір
    private(set) var colorType: ColorType?
    
    // Кастомний промпт (для .custom стилю)
    private(set) var customPrompt: String?
    
    // For .newFlooring / .newWalls
    private(set) var surfaceMaterial: SurfaceMaterialOption?
    private(set) var surfaceCustomPrompt: String?
    
    // Для режиму .replace
    enum ReplaceMode {
        case replace
        case remove
    }
    private(set) var replaceMode: ReplaceMode = .replace
    private(set) var objectToReplace: String?
    private(set) var maskImage: UIImage?
    private(set) var maskData: Data? // PNG data для API
    
    // MARK: - Методи оновлення (для виклику з VC)
    
    // Викликається з PageViewController
    func updateOption(_ option: DesignOption) {
        self.designOption = option
    }
    
    // Викликається з AddPhotoViewController
    func updateBaseImage(_ image: UIImage) {
        self.baseImage = image
    }
    
    // Викликається з AddPhotoViewController
    func updateReferenceImage(_ image: UIImage) {
        self.referenceImage = image
    }
    
    // Викликається для очищення базового зображення
    func clearBaseImage() {
        self.baseImage = nil
    }
    
    // Викликається для очищення референсного зображення
    func clearReferenceImage() {
        self.referenceImage = nil
    }
    
    // Викликається з RoomListViewController
    func updateRoom(_ room: InteriorType) {
        self.interiorRoomType = room
    }
    
    // Потрібно викликати з вашого "TypeViewController"
    func updateExteriorType(_ type: ExteriorType) {
        self.exteriorBuildingType = type
    }
    
    // Потрібно викликати з вашого "TypeViewController"
    func updateGardenType(_ type: GardenType) {
        self.gardenType = type
    }
    
    func updateDesignMode(_ mode: DesignMode) {
        self.designMode = mode
    }
    
    // Викликається з StyleListViewController
    func updateStyle(_ style: UnifiedStyle) {
        switch style {
        case .interior(let interior):
            self.interiorStyle = interior
        case .exterior(let exterior):
            self.exteriorStyle = exterior
        case .garden(let name):
            if let match = GardenType.allCases.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                if match == .noStyle {
                    clearGardenType()
                } else {
                    updateGardenType(match)
                }
            }
        case .reference:
            break
        default: break
        }
    }
    
    // Викликається для встановлення стилю в nil (для .noStyle)
    func clearInteriorStyle() {
        self.interiorStyle = nil
    }
    
    // Викликається для встановлення exterior стилю в nil (для .noStyle)
    func clearExteriorStyle() {
        self.exteriorStyle = nil
    }
    
    // Викликається для встановлення garden типу в nil (для .noStyle)
    func clearGardenType() {
        self.gardenType = nil
    }
    
    // Викликається з PromptViewController для встановлення кастомного промпту
    func updateCustomPrompt(_ prompt: String) {
        self.customPrompt = prompt
        // Встановлюємо стиль/тип як .custom залежно від designOption
        switch designOption {
        case .exterior:
            self.exteriorStyle = .custom
        case .garden:
            self.gardenType = .custom
        case .newFlooring, .newWalls:
            // Do not touch style enums for these modes. Store the custom text separately.
            self.surfaceCustomPrompt = prompt
        default:
            self.interiorStyle = .custom
        }
    }
    
    func updateSurfaceMaterial(_ material: SurfaceMaterialOption?) {
        self.surfaceMaterial = material
    }
    
    func updateSurfaceCustomPrompt(_ prompt: String?) {
        self.surfaceCustomPrompt = prompt
        // Keep `customPrompt` in sync (used by PromptViewController / other flows)
        self.customPrompt = prompt
    }
    
    // Потрібно викликати з вашого "ColorListViewController"
    func updateColor(_ color: ColorType?) {
        self.colorType = color
    }
    
    // Викликається з ObjectSelectionViewController
    func updateObjectToReplace(_ objectName: String) {
        self.objectToReplace = objectName
    }

    // Викликається з ObjectSelectionViewController
    func updateReplaceMode(_ mode: ReplaceMode) {
        self.replaceMode = mode
    }
    
    // Викликається з ObjectSelectionViewController
    func updateMask(_ mask: UIImage) {
        self.maskImage = mask
        self.maskData = mask.pngData()
    }
    
    // MARK: - Фінальна Генерація Промпту
    
    /**
     Цей метод викликається на екрані "Processing",
     коли всі дані вже зібрано.
     */
    func generatePromptParts() throws -> [ModelContent.Part] {
        
        // --- КРОК 1: ЗБИРАЄМО ЗОБРАЖЕННЯ ---

        // 1. Перевірка базового зображення
        guard let baseImage = baseImage else {
            throw PromptError.missingData("Base image is missing.")
        }
        guard let imageData = baseImage.jpegData(compressionQuality: 0.8) else {
            throw PromptError.imageConversionFailed
        }
        
        // 2. Створюємо масив частин, ПОЧИНАЮЧИ З ЗОБРАЖЕННЯ
        var parts: [ModelContent.Part] = [
            .data(mimetype: "image/jpeg", imageData) // Базове зображення ЙДЕ ПЕРШИМ
        ]
        
        // 3. Якщо це режим "reference", додаємо друге зображення
        if designOption == .reference {
            guard let refImage = referenceImage,
                  let refData = refImage.jpegData(compressionQuality: 0.8) else {
                // Ми перевіряємо це тут, а не в `buildReferencePrompt`,
                // щоб гарантовано додати зображення до тексту
                throw PromptError.missingData("Reference image is missing for .reference mode.")
            }
            // Додаємо друге зображення
            parts.append(.data(mimetype: "image/jpeg", refData))
        }
        
        // 4. Якщо це режим "replace" і є маска, додаємо маску як друге зображення
        if designOption == .replace, let mask = maskImage, let maskData = maskData {
            // Додаємо маску як друге зображення (після базового зображення)
            parts.append(.data(mimetype: "image/png", maskData))
        }

        // --- КРОК 2: ЗБИРАЄМО ТЕКСТ ---
        
        // 4. Створення текстового промпту на основі designOption
        let textPrompt: String
        
        switch designOption {
        case .interior:
            textPrompt = try buildInteriorPrompt()
        case .exterior:
            textPrompt = try buildExteriorPrompt()
        case .garden:
            textPrompt = try buildGardenPrompt()
        case .reference:
            textPrompt = try buildReferencePrompt()
        case .replace:
                textPrompt = try buildReplacePrompt()
        case .newFlooring:
            textPrompt = try buildNewFlooringPrompt()
        case .newWalls:
            textPrompt = try buildNewWallsPrompt()
        case .delete:
            textPrompt = ""
        }
        
        // 5. Додаємо фінальний текст В КІНЦІ
        parts.append(.text(textPrompt))
        
        // 6. Повертаємо зібраний масив [Image1, Image2 (opt), Text1]
        return parts
    }
    
    // MARK: - Приватні "Будівельники" Промптів
    
    /**
     ✅  ОНОВЛЕНИЙ, БІЛЬШ ДЕТАЛЬНИЙ ПРОМПТ ДЛЯ ІНТЕР'ЄРУ
     */
    private func buildInteriorPrompt() throws -> String {
        // --- 1. Валідація даних ---
        // Detail/edit flows may not have explicit room type persisted.
        let roomName = interiorRoomType?.name ?? "interior space"
        // Style is optional for .noStyle case. Default to random when not set.
        let resolvedColorType = colorType ?? .random

        // --- Якщо є кастомний промпт, використовуємо його ---
        if let customPrompt = customPrompt, interiorStyle == .custom {
            var prompt = "You are a world-class AI interior designer."
            prompt += " Your task is to completely redesign the user-provided image of a \(roomName)."
            prompt += " \(customPrompt)"
            
            // Додаємо стандартні правила
            prompt += " IMPORTANT RULES:"
            prompt += " 1. Preserve the original room layout, camera perspective, and the location of all architectural elements (like windows, doors, and fireplaces)."
            prompt += " 2. Replace ALL existing furniture, lighting, and decor according to the custom design requirements."
            prompt += " 3. The final image must be photorealistic, clean, and high-resolution, like a photo from an architectural magazine."
            prompt += " 4. Do NOT add any text, logos, or watermarks to the image."
            prompt += " Generate the new image."
            
            return prompt
        }

        // --- 2. Персона та Завдання ---
        var prompt = "You are a world-class AI interior designer."
        prompt += " Your task is to completely redesign the user-provided image of a \(roomName)."

        // --- 2a. Режим дизайну ---
        switch designMode {
        case .structuralPreservation:
            prompt += " Follow the existing room layout closely while keeping walls, windows, and openings consistent."
        case .renovationDesign:
            prompt += " This is a full renovation design: you have COMPLETE FREEDOM to reimagine and redesign everything. You can move, resize, or modify windows, doors, and any architectural openings. You can rearrange walls, change room structure, relocate furniture, and completely transform the space. The only constraint is maintaining a realistic camera perspective."
        }

        // --- 3. Основні інструкції (Стиль) ---
        if let style = interiorStyle, style != .noStyle {
        prompt += " You must apply a stunning \(style.name) aesthetic to the entire room."
        } else {
            // For .noStyle - just create a beautiful design without specific style
            prompt += " You must create a beautiful, well-designed interior for the entire room."
        }

        // --- 4. Логіка кольору ---
        if let style = interiorStyle, style != .noStyle {
        if resolvedColorType == .random {
            let styleColorSuggestions = getColors(for: .interior(style))
            prompt += " Use a color palette that perfectly matches the \(style.name) style. Good examples include: \(styleColorSuggestions.joined(separator: ", "))."
        } else {
            prompt += " The primary color palette for this design must be '\(resolvedColorType.name)', which includes: [\(resolvedColorType.colors.joined(separator: ", "))]."
            }
        } else {
            // For .noStyle - use color palette based on colorType
            if resolvedColorType == .random {
                prompt += " Use a harmonious and appealing color palette that creates a beautiful, balanced design."
            } else {
                prompt += " The primary color palette for this design must be '\(resolvedColorType.name)', which includes: [\(resolvedColorType.colors.joined(separator: ", "))]."
            }
        }

        // --- 5. Жорсткі правила та обмеження ---
        prompt += " IMPORTANT RULES:"
        if designMode == .structuralPreservation {
        prompt += " 1. Preserve the original room layout, camera perspective, and the location of all architectural elements (like windows, doors, and fireplaces)."
        } else {
            prompt += " 1. For renovation design, you have FULL CREATIVE FREEDOM: You can modify, move, resize, or completely change windows, doors, openings, walls, and any architectural elements. You can rearrange the entire room layout, relocate all furniture, and redesign the space structure. Only maintain a realistic camera perspective and ensure the result looks like a real, professionally designed space."
        }
        if let style = interiorStyle, style != .noStyle {
        prompt += " 2. Replace ALL existing furniture, lighting, and decor. The new items must perfectly match the \(style.name) style."
        } else {
            prompt += " 2. Replace ALL existing furniture, lighting, and decor with beautiful, high-quality items that create a cohesive and appealing design."
        }
        prompt += " 3. The final image must be photorealistic, clean, and high-resolution, like a photo from an architectural magazine."
        prompt += " 4. Do NOT add any text, logos, or watermarks to the image."

        // --- 6. Фінальна команда ---
        prompt += " Generate the new image."
        
        return prompt
    }

    private func buildNewFlooringPrompt() throws -> String {
        let extra = surfaceCustomPrompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasExtra = !(extra?.isEmpty ?? true)
        
        guard surfaceMaterial != nil || hasExtra else {
            throw PromptError.missingData("Flooring material or custom prompt")
        }
        var prompt = "You are a world-class AI interior designer."
        prompt += " Your task is to modify the user-provided room photo."
        if let surfaceMaterial {
            prompt += " Update ONLY the flooring to: \(surfaceMaterial.promptDescriptor)."
        } else {
            prompt += " Update ONLY the flooring according to the user's custom request."
        }
        if let extra, !extra.isEmpty {
            prompt += " Custom flooring request: \(extra)."
        }
        prompt += " IMPORTANT RULES:"
        prompt += " 1. Preserve the original room layout, camera perspective, and the position of all architectural elements (walls, windows, doors, ceiling)."
        prompt += " 2. Do NOT change furniture types or positions. Keep rugs and floor objects consistent unless needed for a realistic flooring replacement."
        prompt += " 3. The final image must be photorealistic, clean, and high-resolution."
        prompt += " 4. Do NOT add any text, logos, or watermarks."
        prompt += " Generate the new image."
        return prompt
    }
    
    private func buildNewWallsPrompt() throws -> String {
        let extra = surfaceCustomPrompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasExtra = !(extra?.isEmpty ?? true)
        
        guard surfaceMaterial != nil || hasExtra else {
            throw PromptError.missingData("Wall material or custom prompt")
        }
        var prompt = "You are a world-class AI interior designer."
        prompt += " Your task is to modify the user-provided room photo."
        if let surfaceMaterial {
            prompt += " Update ONLY the walls to: \(surfaceMaterial.promptDescriptor)."
        } else {
            prompt += " Update ONLY the walls according to the user's custom request."
        }
        if let extra, !extra.isEmpty {
            prompt += " Custom wall request: \(extra)."
        }
        prompt += " IMPORTANT RULES:"
        prompt += " 1. Preserve the original room layout, camera perspective, and the position of all architectural elements (windows, doors, ceiling, floor)."
        prompt += " 2. Do NOT change furniture types or positions. Keep lighting and decor consistent unless needed for a realistic wall material replacement."
        prompt += " 3. The final image must be photorealistic, clean, and high-resolution."
        prompt += " 4. Do NOT add any text, logos, or watermarks."
        prompt += " Generate the new image."
        return prompt
    }
    
    private func buildExteriorPrompt() throws -> String {
        let typeName = exteriorBuildingType?.name ?? "building exterior"
        // Style is optional for .noStyle case
        let resolvedColorType = colorType ?? .random

        // --- Якщо є кастомний промпт, використовуємо його ---
        if let customPrompt = customPrompt, exteriorStyle == .custom {
            var prompt = "You are an expert AI exterior and architectural designer."
            prompt += " Redesign the provided image of this \(typeName)."
            prompt += " \(customPrompt)"
            
            // Додаємо стандартні правила
            prompt += " IMPORTANT RULES:"
            prompt += " 1. Preserve the original building shape, camera perspective, and core landscape elements (like large trees or pathways)."
            prompt += " 2. Completely change the facade materials, window styles, and colors according to the custom design requirements."
            prompt += " 3. The final image must be photorealistic."
            prompt += " 4. Do NOT add any text, logos, or watermarks."
            prompt += " Generate the new image."
            
            return prompt
        }

        var prompt = "You are an expert AI exterior and architectural designer."
        prompt += " Redesign the provided image of this \(typeName)."
        
        // --- Основні інструкції (Стиль) ---
        if let style = exteriorStyle, style != .noStyle {
            prompt += " Apply a \(style.name) architectural style."
        } else {
            // For .noStyle - just create a beautiful design without specific style
            prompt += " Create a beautiful, well-designed exterior for this building."
        }
        
        // --- Логіка кольору ---
        if let style = exteriorStyle, style != .noStyle {
            if resolvedColorType == .random {
                let styleColorSuggestions = getColors(for: .exterior(style))
                prompt += " Use a color palette that perfectly matches this style, such as \(styleColorSuggestions.joined(separator: ", "))."
            } else {
                prompt += " Use the '\(resolvedColorType.name)' color palette for the redesign: [\(resolvedColorType.colors.joined(separator: ", "))]."
            }
        } else {
            // For .noStyle - use color palette based on colorType
            if resolvedColorType == .random {
                prompt += " Use a harmonious and appealing color palette that creates a beautiful, balanced design."
            } else {
                prompt += " Use the '\(resolvedColorType.name)' color palette for the redesign: [\(resolvedColorType.colors.joined(separator: ", "))]."
            }
        }
        
        // Додаємо правила, аналогічні до інтер'єру
        prompt += " IMPORTANT RULES:"
        prompt += " 1. Preserve the original building shape, camera perspective, and core landscape elements (like large trees or pathways)."
        if let style = exteriorStyle, style != .noStyle {
            prompt += " 2. Completely change the facade materials, window styles, and colors to match the \(style.name) style."
        } else {
            prompt += " 2. Completely change the facade materials, window styles, and colors with beautiful, high-quality elements that create a cohesive and appealing design."
        }
        prompt += " 3. The final image must be photorealistic."
        prompt += " 4. Do NOT add any text, logos, or watermarks."
        prompt += " Generate the new image."
        
        return prompt
    }
    
    private func buildGardenPrompt() throws -> String {
        // Garden type is optional for .noStyle case
        
        // --- Якщо є кастомний промпт, використовуємо його ---
        if let customPrompt = customPrompt, gardenType == .custom {
            var prompt = "You are an expert AI landscape designer."
            prompt += " Redesign the provided garden/yard image."
            prompt += " \(customPrompt)"
            
            // Додаємо стандартні правила
            prompt += " IMPORTANT RULES:"
            prompt += " 1. Preserve the camera perspective and any existing buildings (like the house) in the background."
            prompt += " 2. Transform the garden according to the custom design requirements."
            prompt += " 3. The final image must be photorealistic."
            prompt += " 4. Do NOT add any text, logos, or watermarks."
            prompt += " Generate the new image."
            
            return prompt
        }
        
        var prompt = "You are an expert AI landscape designer."
        prompt += " Redesign the provided garden/yard image."
        
        // --- Основні інструкції (Тип саду) ---
        if let gardenType = gardenType, gardenType != .noStyle {
            prompt += " Transform it into a beautiful and photorealistic \(gardenType.name) style garden."
        } else {
            // For .noStyle - just create a beautiful design without specific style
            prompt += " Transform it into a beautiful and photorealistic garden design."
        }
        
        prompt += " Preserve the camera perspective and any existing buildings (like the house) in the background."
        prompt += " Generate the new image."
        return prompt
    }
    
    /**
         ✅ ОНОВЛЕНИЙ ПРОМПТ ДЛЯ РЕФЕРЕНСУ (v3)
         Акцент на перенесенні *естетики*, а не об'єктів/розташування.
         */
        private func buildReferencePrompt() throws -> String {
            // Перевірка на referenceImage вже відбувається у `generatePromptParts()`
            
            var prompt = "You are an expert AI visual style transfer artist."
            prompt += " You will receive two images:"
            prompt += " 1. 'Content Image': The scene (room, building) that needs a style update."
            prompt += " 2. 'Style Image': The image providing the target aesthetic."
            
            prompt += " Your task is to **re-imagine the 'Content Image' using ONLY the aesthetic qualities of the 'Style Image'.**"
            prompt += " This includes:"
            prompt += "   - Color palette"
            prompt += "   - Material choices (e.g., wood type, metal finish, fabric textures)"
            prompt += "   - Lighting style and mood"
            prompt += "   - Overall artistic feel (e.g., minimalist, rustic, futuristic)"
            
            prompt += "\n"
            
            prompt += " **CRITICAL RULES - DO NOT VIOLATE:**"
            prompt += " 1. **PRESERVE THE ORIGINAL STRUCTURE:** You MUST keep the exact layout, camera perspective, and positions of all architectural elements (walls, windows, doors, ceilings, floors, fireplaces etc.) from the 'Content Image'. Do NOT copy these from the 'Style Image'."
            prompt += " 2. **PRESERVE CORE FURNITURE PLACEMENT (if applicable):** Keep the main furniture pieces (like sofas, beds, tables) in their original locations from the 'Content Image'. You should change their *style, material, and color* to match the 'Style Image', but NOT their position or type unless it makes absolutely no sense in the new style."
            prompt += " 3. **DO NOT COPY OBJECTS:** Do NOT transfer specific objects, furniture, or decor items directly from the 'Style Image' into the 'Content Image'. Only transfer the *aesthetic characteristics* mentioned above."
            prompt += " 4. **PHOTOREALISM:** The final output must be a high-quality, photorealistic image."
            prompt += " 5. **NO TEXT/LOGOS:** Do not add any text, watermarks, or logos."
            
            prompt += "\n" // Додаємо порожній рядок
            
            prompt += " Generate the new image, applying the style essence, not the literal content, of the 'Style Image' onto the structure of the 'Content Image'."
            
            return prompt
        }
    
    /**
     ✅ ПРОМПТ ДЛЯ РЕЖИМУ .replace
     Заміна об'єктів у зображенні зі збереженням структури та контексту.
     */
    private func buildReplacePrompt() throws -> String {
        // Перевірка базового зображення вже відбувається у `generatePromptParts()`
        
        var prompt = "You are an expert AI image editing specialist for precise object replacement."
        prompt += " You will receive TWO images:"
        prompt += " 1. The FIRST image is the original photo that needs to be edited."
        
        // Додаємо інформацію про маску, якщо вона є
        if maskImage != nil {
            prompt += " 2. The SECOND image is a BINARY MASK (grayscale PNG with only black and white pixels)."
            prompt += " CRITICAL: The mask has the EXACT SAME dimensions as the first image."
            prompt += " In the mask:"
            prompt += " - WHITE pixels (value 255) = the EXACT area that MUST be replaced"
            prompt += " - BLACK pixels (value 0) = areas that MUST remain COMPLETELY UNCHANGED"
            prompt += " The mask is pixel-aligned with the first image - white pixels in the mask correspond to the exact same pixel positions in the first image."
            prompt += " You MUST replace ONLY the white pixels and leave ALL black pixels pixel-perfect unchanged."
            
            // Якщо є опис заміни, додаємо його
            if replaceMode == .remove {
                prompt += "\n\n**REMOVAL INSTRUCTION:** Remove ALL content inside the white masked area."
                prompt += " If multiple objects exist within the mask, remove every one of them."
                prompt += " Fill the area with realistic background that matches the surroundings (lighting, texture, perspective)."
                prompt += " The masked area must be EMPTY background only — no furniture, no decor, no objects."
            } else if let replacementDescription = objectToReplace, !replacementDescription.isEmpty {
                prompt += "\n\n**REPLACEMENT INSTRUCTION:** Replace the white masked area with: '\(replacementDescription)'."
                prompt += " The replacement must be photorealistic and seamlessly integrated into the scene."
            } else {
                prompt += "\n\nReplace the white masked area with a high-quality, photorealistic alternative that fits the scene."
            }
        } else if replaceMode == .remove {
            prompt += " 2. No mask provided - you need to locate the object in the image."
            prompt += "\n\nRemove the specified object from the image and inpaint the background naturally."
        } else if let objectName = objectToReplace, !objectName.isEmpty {
            prompt += " 2. No mask provided - you need to locate the object in the image."
            prompt += "\n\nFind and replace the '\(objectName)' in the image with a similar, style-appropriate alternative."
        } else {
            prompt += " 2. No mask or object description provided."
            prompt += "\n\nIdentify and replace objects in the image as requested."
        }
        
        prompt += "\n\n**YOUR TASK (STEP BY STEP):**"
        if maskImage != nil {
            prompt += "\nSTEP 1: Look at the SECOND image (the mask). It is a grayscale image with the SAME dimensions as the first image."
            prompt += "\nSTEP 2: Identify ALL pixels in the mask that are WHITE (bright, value close to 255)."
            prompt += "\nSTEP 3: In the FIRST image, find the EXACT SAME pixel positions where the mask is white."
            prompt += "\nSTEP 4: Replace ONLY the content at those exact pixel positions in the first image."
            if replaceMode == .remove {
                prompt += "\nSTEP 5: Remove EVERYTHING inside the white area and reconstruct only background (no objects)."
            } else if let replacementDescription = objectToReplace, !replacementDescription.isEmpty {
                prompt += "\nSTEP 5: Replace it with: '\(replacementDescription)'."
            }
            prompt += "\nSTEP 6: Keep ALL pixels where the mask is BLACK completely unchanged - do not modify even a single pixel outside the white mask area."
            prompt += "\nSTEP 7: The replacement must match the lighting, shadows, perspective, and color temperature of the surrounding scene."
        } else {
            if replaceMode == .remove {
                prompt += "\n1. Locate the specified object(s) in the image."
                prompt += "\n2. Remove them and inpaint the background naturally."
            } else {
                prompt += "\n1. Locate the specified object(s) in the image."
                prompt += "\n2. Replace it/them with a high-quality, photorealistic alternative that fits the room's style and context."
            }
        }
        
        prompt += "\n\n**CRITICAL RULES - DO NOT VIOLATE:**"
        if maskImage != nil {
            prompt += "\n1. **MASK IS MANDATORY:** The second image is a mask. WHITE = replace, BLACK = keep unchanged. You MUST respect this exactly."
            prompt += "\n2. **PRECISION:** Only modify pixels where the mask is WHITE. Every pixel where the mask is BLACK must remain identical to the original."
            prompt += "\n3. **NO LEAKAGE:** Do not modify any area outside the white mask region, even slightly."
            if replaceMode == .remove {
                prompt += "\n4. **EMPTY RESULT:** The white area must contain ONLY background after editing. No objects or furniture should remain there."
            }
        }
        prompt += "\n5. **PRESERVE STRUCTURE:** Keep all walls, floors, ceilings, windows, doors, and fixed architectural elements unchanged."
        prompt += "\n6. **MAINTAIN PERSPECTIVE:** Do not change the camera angle, field of view, or viewing position."
        prompt += "\n7. **SEAMLESS INTEGRATION:** The replaced area must look natural and belong in the scene, matching lighting, shadows, and reflections."
        prompt += "\n8. **NO GEOMETRIC DISTORTION:** Do not warp, stretch, or distort the image geometry."
        prompt += "\n9. **PHOTOREALISM:** The final output must be a high-quality, photorealistic image that looks like a real photograph."
        prompt += "\n10. **NO TEXT/LOGOS:** Do not add any text, watermarks, or logos."
        
        prompt += "\n\nGenerate the edited image now."
        
        return prompt
    }
    
    private func getColors(for style: UnifiedStyle) -> [String] {
        switch style {
        case .interior(let interiorStyle):
            switch interiorStyle {
            case .minimalist:
                return ["neutral tones", "white", "beige", "light gray"]
            case .classic:
                return ["deep blues", "rich reds", "gold", "cream"]
            case .scandinavian:
                return ["white", "light grey", "pale blue", "natural wood"]
            default:
                return ["neutral colors", "matching tones"]
            }
            
        case .exterior(let exteriorStyle):
            switch exteriorStyle {
            case .modern:
                return ["white", "black", "grey", "natural wood", "metal accents"]
            case .mediterranean:
                return ["terracotta", "white", "ocean blue", "sand beige"]
            default:
                return ["natural colors", "stone", "wood"]
            }
        case .garden(_):
            return [""]
        case .reference(_):
            return [""]
        }
    }
    
    // Додаємо підтримку .replace в updateStyle (якщо потрібно)
    // Для .replace режиму можливо не потрібен стиль, але залишаємо гнучкість
}
