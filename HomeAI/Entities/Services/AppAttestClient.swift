import CryptoKit
import DeviceCheck
import Foundation
import Security

/// Apple App Attest for the OpenAI worker: proves that a request comes from this app, unmodified, on a real Apple
/// device. The Secure Enclave key never leaves the device; the worker stores only its public key.
///
/// Once per install: generate key → worker challenge → Apple attestation → `POST /attest/register`.
/// Every generation: an assertion over SHA256(request body) (`X-HomeAI-Attest-Key` / `-Assertion`). The worker
/// checks the signature and a strictly increasing counter, so a captured request can't be replayed or edited.
///
/// Simulators have no App Attest. Debug simulator builds instead send `X-HomeAI-Dev-Token`, read from
/// `~/.rehomely-dev-token` on the Mac (never bundled; Release builds don't contain this code).
actor AppAttestClient {

    enum AttestError: LocalizedError {
        case unsupported
        /// Apple's App Attest call failed (`DCError.Code`, e.g. server unavailable).
        case device(code: Int)
        case server(statusCode: Int, code: String)
        case invalidResponse

        var errorDescription: String? {
            "We couldn't verify this device. Please make sure the app is up to date and try again.".localized
        }
    }

    static let shared = AppAttestClient(
        workerBase: URL(string: Constants.Generation.OpenAI.productionWorkerURL).flatMap { url in
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.path = ""
            return components?.url
        }!,
        mobileGateKey: Constants.Generation.OpenAI.mobileGateKey
    )

    private let workerBase: URL
    private let mobileGateKey: String?
    private let session: URLSession
    private var registration: Task<String, Error>?

    init(workerBase: URL, mobileGateKey: String?, session: URLSession = .shared) {
        self.workerBase = workerBase
        self.mobileGateKey = mobileGateKey
        self.session = session
    }

    /// Headers proving this exact `body` comes from the attested app.
    func headers(for body: Data) async throws -> [String: String] {
        #if DEBUG && targetEnvironment(simulator)
        if let token = Self.simulatorDevToken { return ["X-HomeAI-Dev-Token": token] }
        #endif
        let service = DCAppAttestService.shared
        guard service.isSupported else { throw AttestError.unsupported }

        let keyID = try await attestedKeyID()
        let assertion: Data
        do {
            assertion = try await service.generateAssertion(keyID, clientDataHash: Data(SHA256.hash(data: body)))
        } catch let error as DCError where error.code == .invalidKey {
            // Key lost (reinstall / restore to another device): start over once.
            resetKey()
            let fresh = try await attestedKeyID()
            assertion = try await service.generateAssertion(fresh, clientDataHash: Data(SHA256.hash(data: body)))
            return Self.assertionHeaders(keyID: fresh, assertion: assertion)
        }
        return Self.assertionHeaders(keyID: keyID, assertion: assertion)
    }

    /// The worker no longer knows / trusts our key: forget it so the next call attests again.
    func resetKey() {
        registration = nil
        StoredKeyID.clear()
    }

    // MARK: Private

    private static func assertionHeaders(keyID: String, assertion: Data) -> [String: String] {
        ["X-HomeAI-Attest-Key": keyID, "X-HomeAI-Attest-Assertion": assertion.base64EncodedString()]
    }

    private func attestedKeyID() async throws -> String {
        if let keyID = StoredKeyID.value { return keyID }
        if let registration { return try await registration.value }
        let task = Task { try await self.register() }
        registration = task
        do {
            let keyID = try await task.value
            registration = nil
            return keyID
        } catch {
            registration = nil
            throw error
        }
    }

    private func register() async throws -> String {
        let service = DCAppAttestService.shared
        let challenge = try await fetchChallenge()
        let keyID: String
        let attestation: Data
        do {
            keyID = try await service.generateKey()
            attestation = try await service.attestKey(keyID, clientDataHash: Data(SHA256.hash(data: Data(challenge.utf8))))
        } catch let error as DCError {
            throw AttestError.device(code: error.code.rawValue)
        }

        var request = workerRequest(path: "/attest/register", method: "POST")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "keyId": keyID,
            "attestation": attestation.base64EncodedString(),
            "challenge": challenge
        ])
        let (data, response) = try await session.data(for: request)
        try Self.check(response, data)
        StoredKeyID.save(keyID)
        return keyID
    }

    private func fetchChallenge() async throws -> String {
        let (data, response) = try await session.data(for: workerRequest(path: "/attest/challenge", method: "GET"))
        try Self.check(response, data)
        guard let challenge = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["challenge"] as? String
        else { throw AttestError.invalidResponse }
        return challenge
    }

    private func workerRequest(path: String, method: String) -> URLRequest {
        var request = URLRequest(url: workerBase.appendingPathComponent(path))
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let mobileGateKey, !mobileGateKey.isEmpty {
            request.setValue(mobileGateKey, forHTTPHeaderField: "X-HomeAI-Mobile-Key")
        }
        return request
    }

    private static func check(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw AttestError.invalidResponse }
        guard (200...299).contains(http.statusCode) else {
            let error = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? [String: Any]
            throw AttestError.server(statusCode: http.statusCode, code: error?["code"] as? String ?? "http")
        }
    }

    #if DEBUG && targetEnvironment(simulator)
    private static var simulatorDevToken: String? {
        guard let home = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"],
              let token = try? String(contentsOfFile: home + "/.rehomely-dev-token", encoding: .utf8)
        else { return nil }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    #endif
}

/// The attested key id (not a secret by itself: useless without this device's Secure Enclave), this device only.
private enum StoredKeyID {
    private static let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "rehomely.appattest",
        kSecAttrAccount as String: "key-id"
    ]

    static var value: String? {
        var lookup = query
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(lookup as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data, let keyID = String(data: data, encoding: .utf8), !keyID.isEmpty
        else { return nil }
        return keyID
    }

    static func save(_ keyID: String) {
        clear()
        var item = query
        item[kSecValueData as String] = Data(keyID.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }

    static func clear() {
        SecItemDelete(query as CFDictionary)
    }
}

extension AppAttestClient.AttestError: ImageGenerationFailure, ErrorReporter.Reportable {
    var category: String {
        switch self {
        case .unsupported: return "attest_unsupported"
        case .device: return "attest_device"
        case .server(_, let code): return code
        case .invalidResponse: return "attest_invalid_response"
        }
    }

    var statusCode: Int? {
        if case .server(let status, _) = self { return status }
        return nil
    }

    var reportDetails: ErrorReporter.Details {
        switch self {
        case .unsupported:
            return .init(provider: ImageGenerationProvider.openAI.rawValue, workerError: "attest_unsupported")
        case .device(let code):
            return .init(provider: ImageGenerationProvider.openAI.rawValue, workerError: "attest_device",
                         extra: ["dc_error": String(code)])
        case .server(let status, let code):
            return .init(provider: ImageGenerationProvider.openAI.rawValue, httpStatus: status, workerError: code)
        case .invalidResponse:
            return .init(provider: ImageGenerationProvider.openAI.rawValue, workerError: "attest_invalid_response")
        }
    }
}
