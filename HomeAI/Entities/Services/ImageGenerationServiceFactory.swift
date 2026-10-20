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
        return make(environment: environment,
                    provider: SupabaseAppConfigService.shared.imageGenerationProvider,
                    directDebugKey: directDebugKey)
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
            return OpenAIWorkerImageGenerationService(endpoint: endpoint,
                                                       mobileGateKey: Constants.Generation.OpenAI.mobileGateKey)
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
