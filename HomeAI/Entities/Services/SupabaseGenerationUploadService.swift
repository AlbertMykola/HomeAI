import Foundation

/// Завантажує original + generated у bucket `UserPhotos` після локального збереження.
/// TTL 3 дні — Cron job у Supabase Dashboard.
final class SupabaseGenerationUploadService {
    static let shared = SupabaseGenerationUploadService()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.ephemeral
        #if DEBUG
        QANetworkBlocker.protect(config)
        #endif
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        session = URLSession(configuration: config)
    }

    func scheduleUpload(fileId: String, generatedFileURL: URL, originalFileURL: URL?) {
        #if DEBUG
        if AppQA.enabled { return }
        #endif
        Task.detached(priority: .utility) { [weak self] in
            let adaptyUserId = await MainActor.run { AdaptyService.shared.userID }
            await self?.uploadGeneration(
                adaptyUserId: adaptyUserId,
                fileId: fileId,
                generatedFileURL: generatedFileURL,
                originalFileURL: originalFileURL
            )
        }
    }

    private func uploadGeneration(
        adaptyUserId: String,
        fileId: String,
        generatedFileURL: URL,
        originalFileURL: URL?
    ) async {
        let bucket = Constants.API.supabaseUserPhotosBucket
        let userFolder = sanitizedStorageUserId(adaptyUserId)

        do {
            try await uploadObject(
                bucket: bucket,
                objectPath: "\(userFolder)/\(fileId)_generated.jpg",
                fileURL: generatedFileURL
            )
            log("uploaded generated \(userFolder)/\(fileId)_generated.jpg")

            if let originalFileURL,
               FileManager.default.fileExists(atPath: originalFileURL.path) {
                try await uploadObject(
                    bucket: bucket,
                    objectPath: "\(userFolder)/\(fileId)_original.jpg",
                    fileURL: originalFileURL
                )
                log("uploaded original \(userFolder)/\(fileId)_original.jpg")
            }
        } catch {
            log("upload failed for \(userFolder)/\(fileId): \(error)")
        }
    }

    private func sanitizedStorageUserId(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "unknown" }
        return trimmed.lowercased()
    }

    private func uploadObject(bucket: String, objectPath: String, fileURL: URL) async throws {
        guard let url = storageObjectURL(bucket: bucket, objectPath: objectPath) else {
            throw UploadError.invalidURL
        }

        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            throw UploadError.emptyFile
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        applySupabaseAuthHeaders(to: &request)

        let (responseData, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: responseData, encoding: .utf8) ?? ""
            throw UploadError.httpStatus(http.statusCode, body)
        }
    }

    private func storageObjectURL(bucket: String, objectPath: String) -> URL? {
        let encodedPath = objectPath
            .split(separator: "/")
            .map { segment in
                segment.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(segment)
            }
            .joined(separator: "/")
        return URL(string: "\(Constants.API.supabaseURL)/storage/v1/object/\(bucket)/\(encodedPath)")
    }

    private func applySupabaseAuthHeaders(to request: inout URLRequest) {
        let key = Constants.API.supabaseAnonKey
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    }

    private func log(_ message: String) {
        print("[SupabaseGenerationUpload] \(message)")
    }
}

private enum UploadError: LocalizedError {
    case invalidURL
    case emptyFile
    case invalidResponse
    case httpStatus(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid storage URL"
        case .emptyFile:
            return "File is empty"
        case .invalidResponse:
            return "Invalid HTTP response"
        case let .httpStatus(code, body):
            return "HTTP \(code): \(body)"
        }
    }
}
