import UIKit

enum AssistantChatServiceError: Error {
    case invalidURL
    case requestFailed(Error)
    case httpError(Int, String)
    case emptyResponse
    case decodingFailed
}

/// Сервіс для чату з асистентом через Gemini text-model.
/// `systemPrompt` йде окремим полем `systemInstruction`, що для Gemini тримає роль
/// надійніше, ніж класти його як перше `user`-повідомлення.
final class AssistantChatService {

    private let endpoint = Constants.API.assistantChat

    /// Скільки останніх повідомлень з історії передаємо моделі (щоб не роздувати токени).
    private let historyLimit = 20

    /// - Parameters:
    ///   - assistant: тип асистента, чий `systemPrompt` ставимо `systemInstruction`.
    ///   - history: попередні повідомлення (без поточного).
    ///   - userText: щойно набраний текст користувача.
    func send(assistant: AssistantType,
              history: [ChatMessage],
              userText: String) async throws -> String {

        guard let url = URL(string: endpoint) else {
            throw AssistantChatServiceError.invalidURL
        }

        var contents: [[String: Any]] = []
        for msg in history.suffix(historyLimit) {
            contents.append([
                "role": msg.role == .user ? "user" : "model",
                "parts": [["text": msg.text]]
            ])
        }
        contents.append([
            "role": "user",
            "parts": [["text": userText]]
        ])

        let body: [String: Any] = [
            "contents": contents,
            "systemInstruction": [
                "parts": [["text": assistant.systemPrompt]]
            ],
            "generationConfig": [
                "temperature": 0.6,
                "topP": 0.9,
                "responseMimeType": "text/plain"
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 45

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            print("[AssistantChat] network error: \(error)")
            throw AssistantChatServiceError.requestFailed(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AssistantChatServiceError.emptyResponse
        }

        if !(200...299).contains(http.statusCode) {
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            print("[AssistantChat] HTTP \(http.statusCode): \(raw.prefix(500))")
            throw AssistantChatServiceError.httpError(http.statusCode, raw)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let first = candidates.first,
            let content = first["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]]
        else {
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            print("[AssistantChat] decode failed. Raw: \(raw.prefix(500))")
            throw AssistantChatServiceError.decodingFailed
        }

        let text = parts.compactMap { $0["text"] as? String }.joined()
        let answer = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if answer.isEmpty {
            // Часто це означає safety-block. Лог допоможе зрозуміти причину.
            if let finishReason = first["finishReason"] as? String {
                print("[AssistantChat] empty text, finishReason=\(finishReason)")
            }
            throw AssistantChatServiceError.emptyResponse
        }
        return answer
    }

    // MARK: - A/09 AI designer (photo + free-form system prompt)

    struct Turn {
        let isUser: Bool
        let text: String
    }

    /// Same endpoint, but with a custom system prompt and an optional room photo (Gemini `inlineData`).
    func send(systemPrompt: String, history: [Turn], userText: String, image: UIImage?) async throws -> String {
        guard let url = URL(string: endpoint) else { throw AssistantChatServiceError.invalidURL }

        var contents: [[String: Any]] = history.suffix(historyLimit).map {
            ["role": $0.isUser ? "user" : "model", "parts": [["text": $0.text]]]
        }
        var parts: [[String: Any]] = []
        if let data = image?.resizedForAssistant().jpegData(compressionQuality: 0.75) {
            parts.append(["inlineData": ["mimeType": "image/jpeg", "data": data.base64EncodedString()]])
        }
        parts.append(["text": userText.isEmpty ? "What do you think about this room?" : userText])
        contents.append(["role": "user", "parts": parts])

        let body: [String: Any] = [
            "contents": contents,
            "systemInstruction": ["parts": [["text": systemPrompt]]],
            "generationConfig": ["temperature": 0.6, "topP": 0.9, "responseMimeType": "text/plain"]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AssistantChatServiceError.requestFailed(error)
        }
        guard let http = response as? HTTPURLResponse else { throw AssistantChatServiceError.emptyResponse }
        guard (200...299).contains(http.statusCode) else {
            let raw = String(data: data, encoding: .utf8) ?? "<binary>"
            print("[AssistantChat] HTTP \(http.statusCode): \(raw.prefix(500))")
            throw AssistantChatServiceError.httpError(http.statusCode, raw)
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let replyParts = content["parts"] as? [[String: Any]] else {
            throw AssistantChatServiceError.decodingFailed
        }
        let answer = replyParts.compactMap { $0["text"] as? String }.joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !answer.isEmpty else { throw AssistantChatServiceError.emptyResponse }
        return answer
    }
}

private extension UIImage {
    /// Longest side 1024 px is plenty for advice and keeps the request small.
    func resizedForAssistant() -> UIImage {
        let longest = max(size.width, size.height) * scale
        guard longest > 1024 else { return self }
        let ratio = 1024 / longest
        let target = CGSize(width: size.width * scale * ratio, height: size.height * scale * ratio)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}
