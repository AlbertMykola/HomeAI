import UIKit

/// The generation pipeline (prompt → provider → save to history) without UI, so the A/05 screen can be
/// collapsed while it keeps running. Same analytics events as the legacy ProcessingViewController.
final class GenerationRunner {

    enum Stage { case preparing, generating, saving }

    enum Failure {
        /// Model returned no image / refused — show G4 "We couldn't find a room here".
        case photoNotSuitable
        /// Moderation refused the prompt or photo — A/12 "We can't create this one". No credit is spent.
        case contentBlocked
        /// Everything else — G3 "Something went wrong" with a short error code.
        case failed(code: String, message: String)
    }

    struct Outcome {
        let model: ImageDetailModel
        let docID: String
    }

    enum State {
        case idle
        case running(Stage)
        case blocked(GenerationAccess.Result)
        case succeeded(Outcome)
        case failed(Failure)
    }

    let promptManager: GemeniPromptManager
    /// Set when the result is an edit of an existing version → saved as the next version of that project.
    let baseDocID: String?
    private(set) var state: State = .idle { didSet { onStateChange?(state) } }
    var onStateChange: ((State) -> Void)?

    private(set) var startedAt: Date?
    private(set) var attemptID = UUID().uuidString
    private var task: Task<Void, Never>?
    private var retryNumber = 0
    private var lastFailureReason = "unknown"
    private let amplitude = AmplitudeService.shared
    private let imageStore = ImageHistoryService()

    init(promptManager: GemeniPromptManager, baseDocID: String? = nil) {
        self.promptManager = promptManager
        self.baseDocID = baseDocID
    }

    deinit { task?.cancel() }

    #if DEBUG
    /// Uses the real state renderer without starting a paid network request.
    func setQAState(_ state: State) {
        precondition(AppQA.enabled)
        self.state = state
    }
    #endif

    var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    func cancel() {
        task?.cancel()
    }

    func retry() {
        retryNumber += 1
        amplitude.logEvent(.tryAgainAction)
        amplitude.logEvent(.generationRetry(previousAttemptID: attemptID, reason: lastFailureReason, retryNumber: retryNumber))
        start()
    }

    func start() {
        guard !isRunning else { return }
        let gpm = promptManager
        amplitude.logEvent(.startGeneration)
        attemptID = UUID().uuidString
        let attemptID = self.attemptID
        let started = Date()
        startedAt = started
        let option = gpm.designOption
        let service = ImageGenerationServiceFactory.make()
        let provider = service.provider.rawValue
        let model = service.model(for: option)
        let promptVersion = ImageGenerationServiceFactory.promptVersion(for: service.provider)
        amplitude.logEvent(.generationStarted(attemptID: attemptID, option: option.rawValue, promptVersion: promptVersion,
                                              provider: provider, model: model))
        setStage(.preparing)

        let access = GenerationAccess.evaluate()
        guard access == .allowed else {
            let reason = access == .dailyLimitExceeded ? "daily_limit" : "subscription_required"
            if access == .requiresSubscription { amplitude.logEvent(.reachedLimit) }
            amplitude.logEvent(.generationBlocked(attemptID: attemptID, option: option.rawValue,
                                                  promptVersion: promptVersion, reason: reason))
            state = .blocked(access)
            return
        }
        let isPremium = AdaptyService.shared.hasActiveSubscription

        #if DEBUG
        // Simulator QA without spending generations: -fakeGeneration [-fakeGenerationFail | -fakeGenerationNoImage]
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-fakeGeneration") {
            task = Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                self?.setStage(.generating)
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                guard let self, !Task.isCancelled else { return }
                if args.contains("-fakeGenerationBlocked") {
                    self.state = .failed(.contentBlocked)
                } else if args.contains("-fakeGenerationFail") {
                    self.state = .failed(.failed(code: "502", message: "Fake failure"))
                } else if args.contains("-fakeGenerationNoImage") {
                    self.state = .failed(.photoNotSuitable)
                } else if let image = gpm.baseImage {
                    let fake = ImageGenerationResult(image: image, prompt: "fake", provider: service.provider, model: "fake")
                    if let outcome = try? await self.save(result: fake, baseImage: image) {
                        self.state = .succeeded(outcome)
                    }
                }
            }
            return
        }
        #endif

        task = Task { [weak self] in
            guard let self else { return }
            func fail(_ category: String, status: Int?, failure: Failure) async {
                await MainActor.run {
                    self.lastFailureReason = category
                    self.amplitude.logEvent(.generationFailed(attemptID: attemptID, option: option.rawValue,
                                                              promptVersion: promptVersion, provider: provider,
                                                              model: model, category: category, statusCode: status,
                                                              latencyMS: self.latency(since: started)))
                    self.state = .failed(failure)
                }
            }
            do {
                let input = try gpm.makeGenerationInput()
                self.amplitude.logEvent(.generationPromptMetadata(option: option.rawValue, promptVersion: promptVersion,
                                                                  promptLength: input.prompt.count))
                try Task.checkCancellation()
                await MainActor.run { self.setStage(.generating) }
                let result = try await service.generateImage(from: input)
                try Task.checkCancellation()
                await MainActor.run { self.setStage(.saving) }
                let outcome = try await self.save(result: result, baseImage: gpm.baseImage)
                try Task.checkCancellation()
                await MainActor.run {
                    if isPremium {
                        DailyGenerationLimitManager.shared.recordSuccessfulGeneration()
                    } else {
                        FreeGenerationManager.shared.increment()
                    }
                    self.amplitude.logEvent(.generationSucceeded(attemptID: attemptID, option: option.rawValue,
                                                                 promptVersion: promptVersion,
                                                                 provider: result.provider.rawValue, model: result.model,
                                                                 latencyMS: self.latency(since: started)))
                    self.amplitude.logEvent(.finishGeneration)
                    RatePrompt.recordSuccessfulGeneration(docID: outcome.docID)
                    self.state = .succeeded(outcome)
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.amplitude.logEvent(.generationCancelled(attemptID: attemptID, option: option.rawValue,
                                                                 promptVersion: promptVersion,
                                                                 latencyMS: self.latency(since: started)))
                    self.state = .idle
                }
            } catch let error as PromptError {
                await fail("prompt_validation", status: nil,
                           failure: .failed(code: "PV", message: error.localizedDescription))
            } catch let error as any ImageGenerationFailure {
                let failure: Failure
                switch error.category {
                case "no_image": failure = .photoNotSuitable
                case "content_blocked": failure = .contentBlocked
                default: failure = .failed(code: error.statusCode.map(String.init) ?? error.category,
                                           message: error.localizedDescription)
                }
                await fail(error.category, status: error.statusCode, failure: failure)
            } catch {
                await fail("unknown", status: nil, failure: .failed(code: "UNK", message: error.localizedDescription))
            }
        }
    }

    private func setStage(_ stage: Stage) {
        state = .running(stage)
        guard let startedAt else { return }
        let name: String
        switch stage {
        case .preparing: name = "preparing"
        case .generating: name = "generating"
        case .saving: name = "saving"
        }
        amplitude.logEvent(.generationStage(attemptID: attemptID, stage: name, elapsedMS: latency(since: startedAt)))
    }

    private func latency(since date: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(date) * 1_000))
    }

    /// Saves to local history (same fields as the legacy flow) and builds the result model.
    private func save(result: ImageGenerationResult, baseImage: UIImage?) async throws -> Outcome {
        let gpm = promptManager
        let styleName: String = {
            switch gpm.designOption {
            case .interior: return gpm.interiorStyle?.name ?? "No Style"
            case .exterior: return gpm.exteriorStyle?.name ?? "No Style"
            case .garden: return gpm.gardenType?.name ?? "No Style"
            case .newFlooring, .newWalls: return gpm.surfaceMaterial?.title ?? gpm.surfaceCustomPrompt ?? "Custom"
            case .rearrange: return gpm.rearrangeSubOption?.displayTitle ?? "Rearrange".localized
            default: return gpm.interiorStyle?.name ?? gpm.exteriorStyle?.name ?? gpm.gardenType?.name ?? "Edited"
            }
        }()
        let colorName = gpm.colorType?.name
        guard let data = result.image.jpegData(compressionQuality: 0.9) else { throw PromptError.imageConversionFailed }
        let doc = try await imageStore.saveGeneratedImage(
            data, prompt: result.prompt, provider: result.provider.rawValue, model: result.model, size: nil, seed: nil,
            makePreview: true, style: styleName, colorName: colorName, originalImage: baseImage,
            designOption: gpm.designOption, interiorRoomType: gpm.interiorRoomType,
            exteriorBuildingType: gpm.exteriorBuildingType, gardenType: gpm.gardenType,
            interiorStyle: gpm.interiorStyle, exteriorStyle: gpm.exteriorStyle, designMode: gpm.designMode,
            customPrompt: gpm.customPrompt, surfaceMaterial: gpm.surfaceMaterial,
            surfaceCustomPrompt: gpm.surfaceCustomPrompt, replaceMode: gpm.replaceMode,
            objectToReplace: gpm.objectToReplace, rearrangeSubOption: gpm.rearrangeSubOption,
            referenceImage: gpm.designOption == .reference ? gpm.referenceImage : nil,
            maskImage: [.replace, .delete].contains(gpm.designOption) ? gpm.maskImage : nil)
        await MainActor.run {
            if let baseDocID {
                ProjectStore.shared.addVersion(docID: doc.id, toProjectContaining: baseDocID)
            } else {
                ProjectStore.shared.createProject(firstDocID: doc.id)
            }
        }
        let model = ImageDetailModel(previewsImage: baseImage, image: result.image, color: colorName ?? "Random",
                                     style: styleName, option: gpm.designOption, canRegenerate: true,
                                     storagePath: doc.storagePath, originalPath: doc.originalPath)
        return Outcome(model: model, docID: doc.id)
    }
}
