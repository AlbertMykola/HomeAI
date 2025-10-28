import Foundation
import UIKit

enum ImageGenError: Error {
    case invalidURL
    case emptyData
    case decodingFailed
    case imageDecodeFailed
    case networkError(Error)
    case apiError(code: Int, message: String, details: [String: Any]?)
}

final class ImageGenService {
    private let endpoint: URL
    private let session: URLSession
    private let isDebug: Bool

    init(endpoint: String, session: URLSession = .shared, debug: Bool = true) throws {
        guard let url = URL(string: endpoint) else {
            let err = ImageGenError.invalidURL
            if debug { print("ImageGenService Init Error: Invalid URL - \(endpoint)") }
            throw err
        }
        self.endpoint = url
        self.session = session
        self.isDebug = debug
    }

    private func logError(_ msg: String, details: [String: Any]? = nil, payload: Data? = nil) {
        if isDebug {
            print("ImageGenService Error: \(msg)")
            if let details = details { print("Details: \(details)") }
            if let payload = payload, let payloadStr = String(data: payload, encoding: .utf8) {
                print("Request Payload Preview: \(payloadStr.prefix(200))...") // Обмежити для великих промптів
            }
        }
    }

    // Helper: Parse API error response as JSON if possible
    private func parseAPIError(data: Data, statusCode: Int) -> (message: String, details: [String: Any]?) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let errorDict = json["error"] as? [String: Any] else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            return (msg, ["raw": msg])
        }
        let msg = errorDict["message"] as? String ?? "API error"
        let details: [String: Any] = [
            "type": errorDict["type"] ?? "",
            "code": errorDict["code"] ?? statusCode,
            "param": errorDict["param"] ?? NSNull()
        ]
        return (msg, details)
    }

    // 1) Text-to-image (JSON -> /images/generations)
    func generateImage(
        prompt: String,
        model: String = "gpt-image-1",
        n: Int = 1,
        size: String = "1024x1536",
        seed: Int? = nil,
        timeout: TimeInterval = 120
    ) async throws -> [UIImage] {

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout

        var dict: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "n": n,
            "size": size
        ]
        if let seed = seed { dict["seed"] = seed }

        request.httpBody = try JSONSerialization.data(withJSONObject: dict, options: [])

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw ImageGenError.emptyData
            }
            guard 200..<300 ~= http.statusCode else {
                let (msg, details) = parseAPIError(data: data, statusCode: http.statusCode)
                logError("GenerateImage API Error [\(http.statusCode)]: \(msg)", details: details, payload: request.httpBody)
                let nsError = NSError(domain: "ImageGenService.GenerateImage", code: http.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: msg,
                    "statusCode": http.statusCode,
                    "responseBody": String(data: data, encoding: .utf8) ?? "",
                    "requestBody": String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "",
                    "details": details ?? [:]
                ])
                throw ImageGenError.apiError(code: http.statusCode, message: msg, details: details)
            }

            let decoded = try JSONDecoder().decode(ImageGenResponse.self, from: data)
            guard !decoded.data.isEmpty else {
                logError("GenerateImage: Empty data response")
                throw ImageGenError.emptyData
            }

            let images: [UIImage] = try decoded.data.map { item in
                guard let b64 = item.b64_json,
                      let bytes = Data(base64Encoded: b64),
                      let img = UIImage(data: bytes) else {
                    logError("GenerateImage: Failed to decode b64 to UIImage")
                    throw ImageGenError.imageDecodeFailed
                }
                return img
            }
            if isDebug { print("GenerateImage Success: Generated \(images.count) images") }
            return images
        } catch let error as ImageGenError {
            throw error
        } catch {
            logError("GenerateImage Network Error: \(error.localizedDescription)")
            throw ImageGenError.networkError(error)
        }
    }

    // 2) Image edits (multipart -> /images/edits) with high fidelity, optional mask and reference
    func redesignImage(
        baseImage: UIImage,
        referenceImage: UIImage? = nil,  // Опціонально: для reference-режиму (стильовий бриф)
        prompt: String,
        maskPNG: Data? = nil,  // Опціональна маска (PNG для прозорості)
        orientationHint: String? = nil,
        seed: Int? = nil,
        model: String = "dall-e-2",  // Дефолт для сумісності з /images/edits (DALL·E 2)
        n: Int = 1,  // Фікс: 1 для edits (не підтримує >1)
        timeout: TimeInterval = 180
    ) async throws -> [UIImage] {

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout

        var body = Data()

        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        func appendFile(name: String, filename: String, mime: String, data: Data) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
        }

        // Ресайз baseImage до square (1:1, 1024x1024 max для DALL·E 2)
        let paddedBase = baseImage.padToAspect(aspectWidth: 1, aspectHeight: 1, fill: .white)  // Білий фон для інтер'єрів
        guard let baseData = paddedBase.jpegData(compressionQuality: 0.9) else {
            logError("RedesignImage: Failed to encode base image to JPEG")
            throw ImageGenError.imageDecodeFailed
        }
        appendFile(name: "image", filename: "base.jpg", mime: "image/jpeg", data: baseData)

        // Reference image для reference-режиму (відправка в Worker для витягування стилю)
        if let ref = referenceImage {
            let paddedRef = ref.padToAspect(aspectWidth: 1, aspectHeight: 1, fill: .white)
            guard let refData = paddedRef.jpegData(compressionQuality: 0.9) else {
                logError("RedesignImage: Failed to encode reference image to JPEG")
                throw ImageGenError.imageDecodeFailed
            }
            appendFile(name: "reference", filename: "ref.jpg", mime: "image/jpeg", data: refData)
        }

        // Маска для захисту зон (PNG, чорний = protect)
        if let mask = maskPNG {
            appendFile(name: "mask", filename: "mask.png", mime: "image/png", data: mask)
        }

        let defaultAnchors = "Keep left/right orientation identical to the base photo; do not change camera angle or FOV; never mirror or flip."
        let anchors = [orientationHint, defaultAnchors].compactMap { $0 }.joined(separator: " ")
        let fullPrompt = "\(prompt) \(anchors)"  // Для reference: prompt вже включає style brief з PromptManager/Worker

        appendField("prompt", fullPrompt)
        appendField("model", model)
        appendField("input_fidelity", "high")  // Кастомний для Worker (якщо підтримується)
        appendField("n", "1")  // Фікс: n=1 для edits
        if let seed = seed { appendField("seed", String(seed)) }
        // Видалено: "size" — не підтримується в /images/edits; вивід базується на input розмірі

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw ImageGenError.emptyData
            }
            guard 200..<300 ~= http.statusCode else {
                let (msg, details) = parseAPIError(data: data, statusCode: http.statusCode)
                let bodyPreview = String(data: request.httpBody ?? Data(), encoding: .utf8)?.prefix(200) ?? ""  // Обмежено для логування
                logError("RedesignImage API Error [\(http.statusCode)]: \(msg)", details: details, payload: request.httpBody)
                let nsError = NSError(domain: "ImageGenService.RedesignImage", code: http.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: msg,
                    "statusCode": http.statusCode,
                    "responseBody": String(data: data, encoding: .utf8) ?? "",
                    "requestBodyPreview": bodyPreview,
                    "details": details ?? [:]
                ])
                throw ImageGenError.apiError(code: http.statusCode, message: msg, details: details)
            }

            let decoded = try JSONDecoder().decode(ImageGenResponse.self, from: data)
            guard !decoded.data.isEmpty else {
                logError("RedesignImage: Empty data response")
                throw ImageGenError.emptyData
            }

            // Async for-loop для fallback з URL (виправлення помилки map)
            var images: [UIImage] = []
            for item in decoded.data {
                var img: UIImage?
                
                // Спочатку b64_json (синхронно)
                if let b64 = item.b64_json,
                   let bytes = Data(base64Encoded: b64),
                   let decodedImg = UIImage(data: bytes) {
                    img = decodedImg
                }
                // Fallback: Фетч з URL (асинхронно, якщо Worker повертає URL)
                else if let urlStr = item.url, let url = URL(string: urlStr) {
                    do {
                        let (imgData, _) = try await session.data(from: url)
                        img = UIImage(data: imgData)
                    } catch {
                        logError("RedesignImage: Failed to fetch and decode from URL \(urlStr): \(error.localizedDescription)")
                    }
                }
                
                guard let finalImg = img else {
                    logError("RedesignImage: No b64_json or valid URL in response item")
                    throw ImageGenError.imageDecodeFailed
                }
                images.append(finalImg)
            }
            if isDebug { print("RedesignImage Success: Generated \(images.count) images") }
            return images
        } catch let error as ImageGenError {
            throw error
        } catch {
            logError("RedesignImage Network Error: \(error.localizedDescription)")
            throw ImageGenError.networkError(error)
        }
    }


    func redesignWithReference(baseImage: UIImage, promptWithStyleBrief: String, orientationHint: String? = nil, seed: Int? = nil, model: String = "gpt-image-1", n: Int = 1, size: String? = nil,
        timeout: TimeInterval = 180) async throws -> [UIImage] {

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout

        var body = Data()

        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        func appendFile(name: String, filename: String, mime: String, data: Data) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(mime)\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
        }

        let imageForEdit = baseImage // або padToAspect(baseImage, aspectWidth: 9, aspectHeight: 16)
        guard let baseData = imageForEdit.jpegData(compressionQuality: 0.9) else {
            logError("RedesignWithReference: Failed to encode base image to JPEG")
            throw ImageGenError.imageDecodeFailed
        }
        appendFile(name: "image", filename: "base.jpg", mime: "image/jpeg", data: baseData)

        let defaultAnchors = "Keep left/right orientation identical to the base photo; do not change camera angle or FOV; never mirror or flip."
        let anchors = [orientationHint, defaultAnchors].compactMap { $0 }.joined(separator: " ")

        appendField("prompt", "\(promptWithStyleBrief) \(anchors)")
        appendField("model", model)
        appendField("input_fidelity", "high")
        appendField("n", String(n))
        if let seed = seed { appendField("seed", String(seed)) }
        if let size = size { appendField("size", size) }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw ImageGenError.emptyData
            }
            guard 200..<300 ~= http.statusCode else {
                let (msg, details) = parseAPIError(data: data, statusCode: http.statusCode)
                logError("RedesignWithReference API Error [\(http.statusCode)]: \(msg)", details: details, payload: request.httpBody)
                let nsError = NSError(domain: "ImageGenService.RedesignWithReference", code: http.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: msg,
                    "statusCode": http.statusCode,
                    "responseBody": String(data: data, encoding: .utf8) ?? "",
                    "requestBody": String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "",
                    "details": details ?? [:]
                ])
                throw ImageGenError.apiError(code: http.statusCode, message: msg, details: details)
            }

            let decoded = try JSONDecoder().decode(ImageGenResponse.self, from: data)
            guard !decoded.data.isEmpty else {
                logError("RedesignWithReference: Empty data response")
                throw ImageGenError.emptyData
            }

            let images: [UIImage] = try decoded.data.map { item in
                guard let b64 = item.b64_json,
                      let bytes = Data(base64Encoded: b64),
                      let img = UIImage(data: bytes) else {
                    logError("RedesignWithReference: Failed to decode b64 to UIImage")
                    throw ImageGenError.imageDecodeFailed
                }
                return img
            }
            if isDebug { print("RedesignWithReference Success: Generated \(images.count) images") }
            return images
        } catch let error as ImageGenError {
            throw error
        } catch {
            logError("RedesignWithReference Network Error: \(error.localizedDescription)")
            throw ImageGenError.networkError(error)
        }
    }
}

// MARK: - Helpers (без змін)
extension UIImage {
    func padToAspect(aspectWidth: CGFloat, aspectHeight: CGFloat, fill color: UIColor = .black) -> UIImage {
        let targetRatio = aspectWidth / aspectHeight
        let imgRatio = size.width / size.height

        var targetSize = size
        if imgRatio > targetRatio {
            targetSize.height = size.width / targetRatio
        } else if imgRatio < targetRatio {
            targetSize.width = size.height * targetRatio
        } else {
            return self
        }

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: targetSize))
            let x = (targetSize.width - size.width) / 2
            let y = (targetSize.height - size.height) / 2
            self.draw(in: CGRect(x: x, y: y, width: size.width, height: size.height))
        }
    }
}

struct ImageGenDataItem: Codable {
    let b64_json: String?
    let url: String?
    let revised_prompt: String?
}
