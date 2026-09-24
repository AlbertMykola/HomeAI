import Foundation

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
}
