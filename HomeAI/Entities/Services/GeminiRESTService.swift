import UIKit
import GoogleGenerativeAI

enum GeminiServiceError: ImageGenerationFailure {
    case invalidURL
    case requestFailed(Error)
    case httpError(statusCode: Int, message: String)
    case payloadTooLarge(maxBytes: Int)
    case noImageInResponse
    case responseDecodingFailed
    case imageDecodingFailed
    case partConversionFailed
    /// Safety / moderation refused the request (A/12 Content blocked). `reason` is Gemini's finish / block reason.
    case contentBlocked(reason: String)

    var category: String {
        switch self {
        case .invalidURL: "invalid_url"
        case .requestFailed(let error):
            (error as? URLError)?.code == .timedOut ? "timeout" : "network"
        case .httpError(let statusCode, _):
            switch statusCode {
            case 413: "payload_too_large"
            case 429: "rate_limited"
            case 500...599: "server"
            default: "http"
            }
        case .payloadTooLarge: "payload_too_large"
        case .noImageInResponse: "no_image"
        case .responseDecodingFailed, .imageDecodingFailed: "decoding"
        case .partConversionFailed: "request_encoding"
        case .contentBlocked: "content_blocked"
        }
    }

    var statusCode: Int? {
        if case .httpError(let statusCode, _) = self { return statusCode }
        return nil
    }

    var isTimeout: Bool {
        if case .requestFailed(let error) = self { return (error as? URLError)?.code == .timedOut }
        return false
    }

    /// Only where Google refused the request and billed nothing (429 rate limit, 503 overloaded). A timeout or
    /// 502/504 may already have produced — and charged for — an image, so repeating it would pay twice.
    var isRetryable: Bool {
        switch self {
        case .httpError(let statusCode, _):
            return [429, 503].contains(statusCode)
        default:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidURL, .partConversionFailed:
            return "The generation request could not be prepared. Please try again.".localized
        case .requestFailed(let error):
            if (error as? URLError)?.code == .timedOut {
                return "Generation is taking longer than expected. Please try again.".localized
            }
            return "Please check your internet connection and try again.".localized
        case .httpError(let statusCode, _):
            if statusCode == 413 {
                return "The selected image is too large. Please choose a smaller image.".localized
            }
            if statusCode == 429 {
                return "The generation service is busy. Please try again shortly.".localized
            }
            return "The generation service is temporarily unavailable. Please try again.".localized
        case .payloadTooLarge:
            return "The selected image is too large. Please choose a smaller image.".localized
        case .noImageInResponse:
            return "No image was generated. Please adjust your request and try again.".localized
        case .responseDecodingFailed, .imageDecodingFailed:
            return "The generated image could not be opened. Please try again.".localized
        case .contentBlocked:
            return "This request goes against our content rules.".localized
        }
    }
}

private enum GeminiGenerationPreset {
    case precise
    case redesign
    case creative

    init(option: DesignOption) {
        switch option {
        case .replace, .delete, .reference, .newFlooring, .newWalls, .floolPlan:
            self = .precise
        case .interior, .exterior, .garden, .furnish:
            self = .redesign
        case .rearrange:
            self = .creative
        }
    }

    var temperature: Double {
        switch self {
        case .precise: 0.2
        case .redesign: 0.45
        case .creative: 0.6
        }
    }

    var topP: Double {
        switch self {
        case .precise: 0.8
        case .redesign, .creative: 0.9
        }
    }
}

final class GeminiRESTService: ImageGenerationService {

    private let proxyURL: String
    private let session: URLSession
    private let retryDelay: (UInt64) async throws -> Void
    private let resultProvider: ImageGenerationProvider
    private let modelResolver: (DesignOption) -> String

    var provider: ImageGenerationProvider { resultProvider }

    func model(for option: DesignOption) -> String {
        modelResolver(option)
    }

    init(
        session: URLSession? = nil,
        proxyURL: String = Constants.API.gemini,
        resultProvider: ImageGenerationProvider = .gemini,
        modelResolver: @escaping (DesignOption) -> String = { _ in Constants.Generation.modelID },
        retryDelay: @escaping (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }
    ) {
        self.proxyURL = proxyURL
        self.resultProvider = resultProvider
        self.modelResolver = modelResolver
        self.retryDelay = retryDelay
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            #if DEBUG
            QANetworkBlocker.protect(configuration)
            #endif
            configuration.timeoutIntervalForRequest = Constants.Generation.requestTimeout
            configuration.timeoutIntervalForResource = Constants.Generation.resourceTimeout
            self.session = URLSession(configuration: configuration)
        }
    }
    
    func generateImage(
        from parts: [ModelContent.Part],
        designOption: DesignOption
    ) async throws -> (image: UIImage, promptText: String) {
        guard let url = URL(string: proxyURL) else { throw GeminiServiceError.invalidURL }

        // 1. Конвертуємо parts у JSON-тіло запиту.
        let (requestBody, promptText) = try convertToRequestBody(parts, preset: GeminiGenerationPreset(option: designOption))
        let requestData = try JSONEncoder().encode(requestBody)
        guard requestData.count <= Constants.Generation.maxRequestBodyBytes else {
            throw GeminiServiceError.payloadTooLarge(maxBytes: Constants.Generation.maxRequestBodyBytes)
        }

        // Розмір вхідного зображення для контролю (щоб порівняти з вихідним).
        let inputImageBytes = parts.reduce(into: 0) { acc, part in
            if case let .data(_, data) = part { acc += data.count }
        }
        print("[Gemini] → POST \(url.absoluteString) | promptLen=\(promptText.count) | inputImageBytes=\(inputImageBytes)")

        // 2. URL request.
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = requestData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // 3. Виконуємо запит.
        request.timeoutInterval = Constants.Generation.requestTimeout

        let (responseData, httpResponse) = try await performRequestWithRetry(request)

        print("[Gemini] ← status=\(httpResponse.statusCode) | bodyBytes=\(responseData.count)")

        let decodedResponse: GeminiRESTResponse
        do {
            decodedResponse = try JSONDecoder().decode(GeminiRESTResponse.self, from: responseData)
        } catch {
            throw GeminiServiceError.responseDecodingFailed
        }

        if let finishReason = decodedResponse.candidates?.first?.finishReason {
            print("[Gemini] finishReason=\(finishReason)")
        }
        if let textPart = decodedResponse.candidates?.first?.content?.parts.first(where: { $0.text != nil })?.text,
           !textPart.isEmpty {
            print("[Gemini] model text (first 200): \(textPart.prefix(200))")
        }

        // Moderation: blocked prompt or a safety finish without an image → A/12 Content blocked (credit not spent).
        let safetyReasons: Set<String> = ["SAFETY", "IMAGE_SAFETY", "PROHIBITED_CONTENT", "BLOCKLIST", "SPII",
                                          "IMAGE_PROHIBITED_CONTENT", "OTHER_SAFETY"]
        let finish = decodedResponse.candidates?.first?.finishReason ?? ""
        let hasImage = decodedResponse.candidates?.first?.content?.parts.contains { $0.inlineData != nil } ?? false
        if let block = decodedResponse.promptFeedback?.blockReason {
            throw GeminiServiceError.contentBlocked(reason: block)
        }
        if !hasImage, safetyReasons.contains(finish) {
            throw GeminiServiceError.contentBlocked(reason: finish)
        }

        guard let base64String = decodedResponse.candidates?
            .first?.content?.parts
            .first(where: { $0.inlineData != nil })?
            .inlineData?.data else {

            // Друкуємо «сирий хвіст» відповіді, щоб бачити причину (safety, prompt rejected тощо).
            let raw = String(data: responseData.prefix(500), encoding: .utf8) ?? "<binary>"
            print("[Gemini] ❌ no inlineData. Raw head: \(raw)")
            throw GeminiServiceError.noImageInResponse
        }

        guard let imageData = Data(base64Encoded: base64String) else {
            throw GeminiServiceError.imageDecodingFailed
        }
        guard let image = UIImage(data: imageData) else {
            throw GeminiServiceError.imageDecodingFailed
        }

        // Перевіряємо, чи модель не повернула просто копію вхідного зображення.
        if imageData.count == inputImageBytes {
            print("[Gemini] ⚠️ outputBytes == inputBytes (\(imageData.count)) — модель, ймовірно, повернула вхідне зображення без змін.")
        } else {
            print("[Gemini] ✅ outputImageBytes=\(imageData.count) (input=\(inputImageBytes))")
        }

        return (image, promptText)
    }

    func generateImage(from input: ImageGenerationInput) async throws -> ImageGenerationResult {
        guard let baseData = input.baseImage.jpegData(
            compressionQuality: Constants.Generation.jpegCompressionQuality
        ) else {
            throw GeminiServiceError.partConversionFailed
        }

        var parts: [ModelContent.Part] = [
            .data(mimetype: "image/jpeg", baseData)
        ]
        if let referenceImage = input.referenceImage {
            guard let referenceData = referenceImage.jpegData(
                compressionQuality: Constants.Generation.jpegCompressionQuality
            ) else {
                throw GeminiServiceError.partConversionFailed
            }
            parts.append(.data(mimetype: "image/jpeg", referenceData))
        }
        if let maskImage = input.maskImage {
            guard let maskData = maskImage.pngData() else {
                throw GeminiServiceError.partConversionFailed
            }
            parts.append(.data(mimetype: "image/png", maskData))
        }
        parts.append(.text(input.prompt(for: .gemini)))

        let generated = try await generateImage(
            from: parts,
            designOption: input.designOption
        )
        return ImageGenerationResult(
            image: generated.image,
            prompt: generated.promptText,
            provider: resultProvider,
            model: model(for: input.designOption)
        )
    }

    private func performRequestWithRetry(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var retryCount = 0
        var timeoutRetries = 0

        while true {
            try Task.checkCancellation()
            do {
                let (data, response) = try await session.data(for: request)
                if response is HTTPURLResponse { ServiceReachability.markReachable() }
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw GeminiServiceError.requestFailed(
                        URLError(.badServerResponse)
                    )
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    throw GeminiServiceError.httpError(
                        statusCode: httpResponse.statusCode,
                        message: parseError(from: data)
                    )
                }
                return (data, httpResponse)
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as URLError where error.code == .cancelled || Task.isCancelled {
                throw CancellationError()
            } catch {
                let serviceError = (error as? GeminiServiceError) ?? .requestFailed(error)
                // One more try after a client timeout (Albert's call): at most two attempts / ~3 min, and the
                // possibly billed first attempt is reported so it shows up in Sentry.
                if serviceError.isTimeout, timeoutRetries < Constants.Generation.maximumTimeoutRetryCount {
                    timeoutRetries += 1
                    ErrorReporter.report(serviceError, operation: "generation_timeout_retry",
                                         details: .init(provider: "gemini", retryCount: timeoutRetries))
                    continue
                }
                guard serviceError.isRetryable,
                      retryCount < Constants.Generation.maximumRetryCount else {
                    throw serviceError
                }
                let delay = UInt64(pow(2, Double(retryCount)) * 500_000_000)
                retryCount += 1
                try await retryDelay(delay)
            }
        }
    }
    
    // ... (всі приватні хелпери: convertToRequestBody, parseError залишаються без змін) ...
    
    private func convertToRequestBody(
        _ sdkParts: [ModelContent.Part],
        preset: GeminiGenerationPreset
    ) throws -> (body: GeminiRESTRequest, prompt: String) {
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
        
        // `responseModalities = [TEXT, IMAGE]` рекомендовано документацією Nano Banana 2 —
        // модель "думає" текстом перед видачою картинки. У `generateImage(...)` ми все одно
        // беремо лише `inlineData`-частину, тож текст не блокує image-вихід.
        //
        // Precise edits use lower sampling; redesign remains moderately creative;
        // rearrange keeps the existing 0.6 value that avoided chaotic layouts.
        let config = GeminiRESTGenerationConfig(
            responseModalities: ["TEXT", "IMAGE"],
            temperature: preset.temperature,
            topP: preset.topP
        )
        let body = GeminiRESTRequest(
            contents: [GeminiRESTContent(parts: jsonParts)],
            generationConfig: config
        )
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
        let (data, response) = try await session.data(for: request)
        
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
            .first?.content?.parts
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
    let generationConfig: GeminiRESTGenerationConfig?
}

private struct GeminiRESTGenerationConfig: Encodable {
    let responseModalities: [String]
    let temperature: Double?
    let topP: Double?
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
    let promptFeedback: GeminiRESTPromptFeedback?
    let error: GeminiRESTError? // Ловимо помилки API
}

private struct GeminiRESTCandidate: Decodable {
    /// Missing when the candidate was blocked by safety filters.
    let content: GeminiRESTContentResponse?
    let finishReason: String?
}

private struct GeminiRESTPromptFeedback: Decodable {
    let blockReason: String?
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

extension GeminiServiceError: ErrorReporter.Reportable {
    var reportDetails: ErrorReporter.Details {
        var d = ErrorReporter.Details(provider: ImageGenerationProvider.gemini.rawValue, workerError: category)
        switch self {
        case .httpError(let status, let message):
            d.httpStatus = status
            d.upstreamStatus = status
            d.upstreamMessage = message  // Google's "Error <code>: <message> (Status: <STATUS>)", passed by the proxy.
            if let range = message.range(of: #"Status: ([A-Z_]+)"#, options: .regularExpression) {
                d.upstreamCode = String(message[range].dropFirst("Status: ".count))
            }
        case .contentBlocked(let reason):
            d.upstreamCode = reason
        case .requestFailed(let error):
            let ns = error as NSError
            d.extra["url_error"] = "\(ns.domain):\(ns.code)"
        default:
            break
        }
        return d
    }
}
