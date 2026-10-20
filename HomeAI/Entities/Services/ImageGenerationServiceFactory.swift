import Foundation

enum ImageGenerationServiceFactory {
    static func make(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> any ImageGenerationService {
        #if DEBUG
        if AppQA.enabled && (environment["REHOMELY_FULL_QA"] == "1" || ProcessInfo.processInfo.arguments.contains("--app-qa")) {
            return AppQA.generationService
        }
        // Debug test without Cloudflare: key typed on the device (Profile → long-press the version).
        if let key = OpenAIDirectDebugKey.value {
            return OpenAIDirectDebugService(apiKey: key)
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

        let config = SupabaseAppConfigService.shared.current
        if config.imageGenerationProvider == .openAI,
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
