import Foundation

enum ImageGenerationServiceFactory {
    static func make(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> any ImageGenerationService {
        #if DEBUG
        if environment["HOMEAI_IMAGE_PROVIDER"]?.lowercased() == "openai",
           let endpoint = generationEndpoint(
               from: Constants.Generation.OpenAI.productionWorkerURL,
               requireHTTPS: true
           ) {
            return OpenAIWorkerImageGenerationService(endpoint: endpoint)
        }
        #endif

        let config = SupabaseAppConfigService.shared.current
        if config.imageGenerationProvider == .openAI,
           let endpoint = generationEndpoint(
               from: Constants.Generation.OpenAI.productionWorkerURL,
               requireHTTPS: true
           ) {
            return OpenAIWorkerImageGenerationService(endpoint: endpoint)
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
