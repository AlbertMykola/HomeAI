import UIKit
import GoogleGenerativeAI

// ... (GeminiServiceError залишається без змін) ...

final class GeminiRESTService {
    
    // ❌ ВИДАЛЕНО: private let apiKey: String
    
    // ✅ ОНОВЛЕНО: Тепер ми звертаємось до нашого власного проксі-сервера
    private let proxyURL = Constants.API.gemini // 👈 ЗАМІНІТЬ ЦЕ
    
    init() {
        // ❌ ВИДАЛЕНО: self.apiKey = apiKey
    }
    
    func generateImage(from parts: [ModelContent.Part]) async throws -> (image: UIImage, promptText: String) {
        
        // ❌ ВИДАЛЕНО: guard !apiKey.isEmpty else { throw GeminiServiceError.invalidAPIKey }
        
        // ✅ ОНОВЛЕНО: Перевіряємо URL нашого проксі
        guard let url = URL(string: proxyURL) else { throw GeminiServiceError.invalidURL }
        
        // 1. Конвертуємо [ModelContent.Part] у тіло JSON-запиту (без змін)
        let (requestBody, promptText) = try convertToRequestBody(parts)
        let requestData = try JSONEncoder().encode(requestBody)
        
        // 2. Створюємо запит
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = requestData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // ❌ ВИДАЛЕНО: request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        // Ключ тепер додає Cloudflare, а не додаток!
        
        // 3. Виконуємо запит (без змін)
        let responseData: Data
        let httpResponse: HTTPURLResponse
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            responseData = data
            guard let resp = response as? HTTPURLResponse else {
                throw GeminiServiceError.requestFailed(NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"]))
            }
            httpResponse = resp
        } catch {
            throw GeminiServiceError.requestFailed(error)
        }
        
        // ... (вся інша логіка обробки помилок та відповіді залишається без змін) ...
        
        // 4. Обробка помилок (без змін)
        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = parseError(from: responseData)
            print("===== 🚨 HTTP ERROR: \(httpResponse.statusCode) 🚨 =====")
            print(errorMessage)
            print("=========================================")
            throw GeminiServiceError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        // 5. Обробка успішної відповіді (без змін)
        let decodedResponse = try JSONDecoder().decode(GeminiRESTResponse.self, from: responseData)
        
        guard let base64String = decodedResponse.candidates?
            .first?.content.parts
            .first(where: { $0.inlineData != nil })?
            .inlineData?.data else {
            
            print("Gemini REST response contained no image data.")
            throw GeminiServiceError.noImageInResponse
        }
        
        guard let imageData = Data(base64Encoded: base64String) else {
            throw GeminiServiceError.imageDecodingFailed
        }
        
        guard let image = UIImage(data: imageData) else {
            throw GeminiServiceError.imageDecodingFailed
        }
        
        return (image, promptText)
    }
    
    // ... (всі приватні хелпери: convertToRequestBody, parseError залишаються без змін) ...
    
    private func convertToRequestBody(_ sdkParts: [ModelContent.Part]) throws -> (body: GeminiRESTRequest, prompt: String) {
        // ... (код без змін) ...
        var promptText = ""
        
        let jsonParts: [GeminiRESTPart] = try sdkParts.map { sdkPart in
            switch sdkPart {
            case .text(let text):
                promptText = text
                return GeminiRESTPart(text: text)
            case .data(let mimeType, let data):
                let base64String = data.base64EncodedString()
                return GeminiRESTPart(inlineData: GeminiRESTInlineData(mimeType: mimeType, data: base64String))
            default:
                throw GeminiServiceError.partConversionFailed
            }
        }
        
        let body = GeminiRESTRequest(contents: [GeminiRESTContent(parts: jsonParts)])
        return (body, promptText)
    }
    
    private func parseError(from data: Data) -> String {
        // ... (код без змін) ...
        if let errorResponse = try? JSONDecoder().decode(GeminiRESTResponse.self, from: data),
           let error = errorResponse.error {
            return "Error \(error.code): \(error.message) (Status: \(error.status))"
        }
        return String(data: data, encoding: .utf8) ?? "Could not decode error body"
    }
    
    // MARK: - Object Detection & Segmentation
    
    /// Виявляє об'єкти на зображенні за допомогою Gemini API
    /// - Parameters:
    ///   - image: Зображення для аналізу
    ///   - objectDescription: Опис об'єкта для пошуку (наприклад, "стіл", "диван", "крісло")
    /// - Returns: Список виявлених об'єктів з координатами
    func detectObjects(in image: UIImage, objectDescription: String? = nil) async throws -> [DetectedObject] {
        guard let url = URL(string: proxyURL) else { throw GeminiServiceError.invalidURL }
        
        // Конвертуємо зображення в base64
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw GeminiServiceError.imageDecodingFailed
        }
        let base64Image = imageData.base64EncodedString()
        
        // Створюємо промпт для виявлення об'єктів
        var prompt = """
        Analyze this image and identify all objects. 
        For each object, provide:
        1. Object name/description
        2. Bounding box coordinates (x, y, width, height) as percentages of image size (0-100)
        
        Format your response as JSON array with objects containing:
        - "name": string (object name)
        - "x": number (left position as percentage)
        - "y": number (top position as percentage)
        - "width": number (width as percentage)
        - "height": number (height as percentage)
        """
        
        if let objectDesc = objectDescription {
            prompt += "\n\nFocus on finding objects matching: \(objectDesc)"
        }
        
        prompt += "\n\nReturn ONLY valid JSON array, no other text."
        
        // Створюємо запит
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        [
                            "inlineData": [
                                "mimeType": "image/jpeg",
                                "data": base64Image
                            ]
                        ],
                        [
                            "text": prompt
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "responseMimeType": "application/json"
            ]
        ]
        
        let requestData = try JSONSerialization.data(withJSONObject: requestBody)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = requestData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Виконуємо запит
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiServiceError.requestFailed(NSError(domain: "NetworkError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"]))
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorMessage = parseError(from: data)
            throw GeminiServiceError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        // Парсимо відповідь
        let decodedResponse = try JSONDecoder().decode(GeminiRESTResponse.self, from: data)
        
        guard let textResponse = decodedResponse.candidates?
            .first?.content.parts
            .first(where: { $0.text != nil })?
            .text else {
            throw GeminiServiceError.noImageInResponse // Використовуємо існуючу помилку
        }
        
        // Парсимо JSON відповідь
        guard let jsonData = textResponse.data(using: .utf8),
              let objects = try? JSONDecoder().decode([DetectedObject].self, from: jsonData) else {
            // Якщо не вдалося розпарсити JSON, спробуємо витягти координати з тексту
            return parseObjectsFromText(textResponse, imageSize: image.size)
        }
        
        return objects
    }
    
    /// Парсить об'єкти з текстової відповіді (fallback)
    private func parseObjectsFromText(_ text: String, imageSize: CGSize) -> [DetectedObject] {
        // Простий парсинг для fallback
        // Можна покращити, використовуючи regex або інші методи
        var objects: [DetectedObject] = []
        
        // Спробуємо знайти JSON в тексті
        if let jsonRange = text.range(of: "\\[.*\\]", options: .regularExpression),
           let jsonData = String(text[jsonRange]).data(using: .utf8),
           let parsed = try? JSONDecoder().decode([DetectedObject].self, from: jsonData) {
            return parsed
        }
        
        return objects
    }
}

// MARK: - DetectedObject Model
struct DetectedObject: Codable {
    let name: String
    let x: Double // Відсоток від ширини
    let y: Double // Відсоток від висоти
    let width: Double // Відсоток від ширини
    let height: Double // Відсоток від висоти
    
    /// Конвертує координати в абсолютні значення для заданого розміру зображення
    func toRect(imageSize: CGSize) -> CGRect {
        let absX = (x / 100.0) * imageSize.width
        let absY = (y / 100.0) * imageSize.height
        let absWidth = (width / 100.0) * imageSize.width
        let absHeight = (height / 100.0) * imageSize.height
        return CGRect(x: absX, y: absY, width: absWidth, height: absHeight)
    }
}

private struct GeminiRESTRequest: Encodable {
    let contents: [GeminiRESTContent]
}

private struct GeminiRESTContent: Encodable {
    let parts: [GeminiRESTPart]
}

// Універсальна частина, яка може бути або текстом, або даними
private struct GeminiRESTPart: Encodable {
    var text: String? = nil
    var inlineData: GeminiRESTInlineData? = nil
    
    // Кастомний Encodable, щоб не надсилати порожні ключі (наприклад, "text": null)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let text = text {
            try container.encode(text, forKey: .text)
        }
        if let inlineData = inlineData {
            try container.encode(inlineData, forKey: .inlineData)
        }
    }
    
    // Ключі для кодування
    private enum CodingKeys: String, CodingKey {
        case text, inlineData
    }
}

private struct GeminiRESTInlineData: Encodable {
    let mimeType: String
    let data: String // Обов'язково Base64-encoded
}


// --- СТРУКТУРИ ДЛЯ ВІДПОВІДІ (Response) ---

private struct GeminiRESTResponse: Decodable {
    let candidates: [GeminiRESTCandidate]?
    let error: GeminiRESTError? // Ловимо помилки API
}

private struct GeminiRESTCandidate: Decodable {
    let content: GeminiRESTContentResponse
}

private struct GeminiRESTContentResponse: Decodable {
    let parts: [GeminiRESTPartResponse]
}

private struct GeminiRESTPartResponse: Decodable {
    let text: String?
    let inlineData: GeminiRESTInlineDataResponse?
}

private struct GeminiRESTInlineDataResponse: Decodable {
    let mimeType: String
    let data: String // Base64-encoded
}

// Структура для "сирих" помилок від Google
private struct GeminiRESTError: Decodable {
    let code: Int
    let message: String
    let status: String
}
