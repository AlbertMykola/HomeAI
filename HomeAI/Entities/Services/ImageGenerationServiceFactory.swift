import Foundation

enum ImageGenerationServiceFactory {
    static func make(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> any ImageGenerationService {
        #if DEBUG
        let directDebugKey = OpenAIDirectDebugKey.value
        #else
        let directDebugKey: String? = nil
        #endif
        // The worker config wins (rollouts without a build); OpenAI isn't used again once it said this region
        // isn't served.
        var provider = WorkerConfigService.shared.imageProvider ?? SupabaseAppConfigService.shared.imageGenerationProvider
        if provider == .openAI && OpenAIRegion.isUnavailable { provider = .gemini }
        return make(environment: environment, provider: provider, directDebugKey: directDebugKey)
    }

    /// `provider` = Supabase `App_Config.image_generation_provider` (OpenAI unless set to "gemini").
    /// `directDebugKey` is honoured only in Debug builds.
    static func make(
        environment: [String: String],
        provider: ImageGenerationProvider,
        directDebugKey: String?
    ) -> any ImageGenerationService {
        #if DEBUG
        if AppQA.enabled && (environment["REHOMELY_FULL_QA"] == "1" || ProcessInfo.processInfo.arguments.contains("--app-qa")) {
            return AppQA.generationService
        }
        // Debug test without Cloudflare: key typed on the device (Profile → long-press the title).
        if let directDebugKey, !directDebugKey.isEmpty {
            return OpenAIDirectDebugService(apiKey: directDebugKey)
        }
        if environment["HOMEAI_IMAGE_PROVIDER"]?.lowercased() == "openai",
           let endpoint = generationEndpoint(
               from: Constants.Generation.OpenAI.productionWorkerURL,
               requireHTTPS: true
           ) {
            return OpenAIWorkerImageGenerationService(endpoint: endpoint,
                                                       mobileGateKey: Constants.Generation.OpenAI.mobileGateKey)
        }
        #endif

        if provider == .openAI,
           let endpoint = generationEndpoint(
               from: Constants.Generation.OpenAI.productionWorkerURL,
               requireHTTPS: true
           ) {
            return RegionFallbackImageService(
                primary: OpenAIWorkerImageGenerationService(endpoint: endpoint,
                                                           mobileGateKey: Constants.Generation.OpenAI.mobileGateKey),
                fallback: GeminiRESTService())
        }
        return GeminiRESTService()
    }

    static func promptVersion(for provider: ImageGenerationProvider) -> String {
        switch provider {
        case .gemini:
            return Constants.Generation.promptVersion
        case .openAI:
            return Constants.Generation.gptImagePromptVersion
        }
    }

    private static func generationEndpoint(
        from rawURL: String,
        requireHTTPS: Bool
    ) -> URL? {
        guard var components = URLComponents(string: rawURL),
              components.host != nil,
              !requireHTTPS || components.scheme == "https" else {
            return nil
        }
        if components.path.isEmpty || components.path == "/" {
            components.path = "/v1/images/generate"
        }
        return components.url
    }
}

/// OpenAI isn't served in some countries / regions (the worker answers `region_unavailable` before calling it):
/// remembered for this device, and that generation runs on Gemini instead.
enum OpenAIRegion {
    private static let key = "openai_region_unavailable_until"

    static var isUnavailable: Bool {
        UserDefaults.standard.double(forKey: key) > Date().timeIntervalSince1970
    }

    static func markUnavailable() {
        // Re-checked after a week (travel, VPN off).
        UserDefaults.standard.set(Date().addingTimeInterval(7 * 86_400).timeIntervalSince1970, forKey: key)
    }

    static func isRegionError(_ error: Error) -> Bool {
        if case .server(_, let code, _, _, _, _)? = error as? OpenAIWorkerImageError { return code == "region_unavailable" }
        return false
    }
}

/// OpenAI first; a `region_unavailable` answer (no OpenAI call was made, nothing billed) retries on Gemini.
struct RegionFallbackImageService: ImageGenerationService {
    let primary: any ImageGenerationService
    let fallback: any ImageGenerationService

    var provider: ImageGenerationProvider { primary.provider }

    func model(for option: DesignOption) -> String { primary.model(for: option) }

    func generateImage(from input: ImageGenerationInput) async throws -> ImageGenerationResult {
        do {
            return try await primary.generateImage(from: input)
        } catch where OpenAIRegion.isRegionError(error) {
            OpenAIRegion.markUnavailable()
            AmplitudeService.shared.logRedesignEvent("openai_region_fallback", properties: [:])
            return try await fallback.generateImage(from: input)
        }
    }
}
