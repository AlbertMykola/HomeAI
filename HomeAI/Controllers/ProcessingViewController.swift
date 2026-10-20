import UIKit
import GoogleGenerativeAI
// import FirebaseAuth


private struct Defaults {
    struct Text {
        static let processing = "Processing...".localized
        static let description = "Please, don't close the app ".localized
    }

    struct Images {
        static let images: [UIImage] = [
            UIImage(named: "kitchen_room_icon"),
            UIImage(named: "bedroom_room_icon"),
            UIImage(named: "bathroom_room_icon"),
            UIImage(named: "living_room_icon"),
            UIImage(named: "dinning_room_icon"),
            UIImage(named: "office_room_icon"),
            UIImage(named: "study_room_icon"),
            UIImage(named: "kids_room_icon"),
            UIImage(named: "attic_room_icon"),
            UIImage(named: "balcony_room_icon"),
            UIImage(named: "hallway_room_icon")
        ].compactMap { $0 }
    }
}


final class ProcessingViewController: UIViewController {

    private enum Direction {
        case side, bottom
        var transitionOption: UIView.AnimationOptions {
            switch self {
            case .side:   return .transitionFlipFromLeft
            case .bottom: return .transitionFlipFromTop
            }
        }
    }
    
    // MARK: - Outlets
    @IBOutlet private weak var processingLabel: CustomFontLabel!
    @IBOutlet private weak var descriptionLabel: CustomFontLabel!
    @IBOutlet private weak var processingImageView: UIImageView!

    // MARK: - Private UI
    private let frontImageView = UIImageView()
    private let backImageView = UIImageView()

    // MARK: - Model
    private var frames: [UIImage] = []
    private var currentIndex = 0
    private var usingFrontOnTop = true

    private var nextDirection: Direction = .side
    
    private let imageStore = ImageHistoryService()
    
    var promptManager: GemeniPromptManager?

    // MARK: - Timing
    private let frameInterval: TimeInterval = 1.4
    private let swapDuration: TimeInterval = 0.45
    private var timer: Timer?

    // Guard to avoid parallel generations
    private var isGenerating = false
    private var isBlockedByAccess = false
    /// Після успішної генерації не запускати знову при `viewDidAppear` (закриття деталі, pop назад тощо).
    private var hasCompletedGenerationSuccessfully = false
    private let amplitude = AmplitudeService.shared
    private var progressTimer: Timer?
    private var currentAttemptID: String?
    private var currentAttemptStartedAt: Date?
    private var lastFailureReason = "unknown"
    private var retryNumber = 0

    // MARK: - Cancellation
    private var generationTask: Task<Void, Never>?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        processingLabel.text = Defaults.Text.processing
        descriptionLabel.text = Defaults.Text.description
        amplitude.logEvent(.showProcessing) // Виправте на .show_processing, якщо треба
        frames = Defaults.Images.images
        if frames.isEmpty, let img = processingImageView.image { frames = [img] }

        setupSwapImageViews()
        setInitialFrame()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if hasCompletedGenerationSuccessfully {
            stopSequence()
            if let pending = NavigationManager.shared.consumePendingInspirationDetailReopen() {
                DispatchQueue.main.async {
                    _ = NavigationManager.shared.showInspirationDetail(
                        model: pending.model,
                        promptManager: pending.promptManager
                    )
                }
            }
            return
        }
        startSequence()
        if !isGenerating && !isBlockedByAccess {
            startGeneration()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            generationTask?.cancel()
            stopSequence()
            stopProgressTimer()
        }
    }

    deinit {
        generationTask?.cancel()
        progressTimer?.invalidate()
    }

    // MARK: - Public
    func startGeneration() {
        guard !isGenerating else { return }
        hasCompletedGenerationSuccessfully = false
        NavigationManager.shared.clearPendingInspirationDetailReopen()
        amplitude.logEvent(.startGeneration)
        let attemptID = UUID().uuidString
        let startedAt = Date()
        currentAttemptID = attemptID
        currentAttemptStartedAt = startedAt
        processingLabel.text = "Preparing your design".localized
        descriptionLabel.text = "Keep the app open while we create it.".localized
        startProgressTimer()
        let selectedOption = promptManager?.designOption ?? .interior
        let option = promptManager?.designOption.rawValue ?? "unknown"
        let service = ImageGenerationServiceFactory.make()
        let provider = service.provider
        let model = service.model(for: selectedOption)
        let promptVersion = ImageGenerationServiceFactory.promptVersion(for: provider)
        amplitude.logEvent(.generationStarted(
            attemptID: attemptID,
            option: option,
            promptVersion: promptVersion,
            provider: provider.rawValue,
            model: model
        ))
        updateGenerationStage("preparing", attemptID: attemptID, startedAt: startedAt)

        isGenerating = true
        stopSequence()
        startSequence()
        
        startImageGenerationTask(
            attemptID: attemptID,
            startedAt: startedAt,
            promptVersion: promptVersion,
            provider: provider.rawValue,
            model: model,
            service: service
        )
    }

    // MARK: - Private
    private func finishGeneration() {
        isGenerating = false
        generationTask = nil
        stopProgressTimer()
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, let startedAt = self.currentAttemptStartedAt else { return }
            if Date().timeIntervalSince(startedAt) >= 25 {
                self.descriptionLabel.text = "This is taking longer than usual. Your design is still in progress.".localized
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func updateGenerationStage(_ stage: String, attemptID: String, startedAt: Date) {
        let title: String
        switch stage {
        case "generating": title = "Creating your design".localized
        case "saving": title = "Saving your design".localized
        default: title = "Preparing your design".localized
        }
        processingLabel.text = title
        amplitude.logEvent(.generationStage(
            attemptID: attemptID,
            stage: stage,
            elapsedMS: latencyMilliseconds(since: startedAt)
        ))
    }

    private func startImageGenerationTask(
        attemptID: String,
        startedAt: Date,
        promptVersion: String,
        provider: String,
        model: String,
        service: any ImageGenerationService
    ) {
        guard let gpm = promptManager else {
            lastFailureReason = "configuration"
            amplitude.logEvent(.error(message: "PromptManager_nil"))
            amplitude.logEvent(.generationFailed(
                attemptID: attemptID,
                option: "unknown",
                promptVersion: promptVersion,
                provider: provider,
                model: model,
                category: "configuration",
                statusCode: nil,
                latencyMS: latencyMilliseconds(since: startedAt)
            ))
            finishGeneration()
            return
        }
        print(gpm)
            
        let access = GenerationAccess.evaluate()
        if access != .allowed {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                switch access {
                case .allowed:
                    break
                case .dailyLimitExceeded:
                    self.isBlockedByAccess = true
                    self.amplitude.logEvent(.generationBlocked(
                        attemptID: attemptID,
                        option: gpm.designOption.rawValue,
                        promptVersion: promptVersion,
                        reason: "daily_limit"
                    ))
                    DailyGenerationLimitManager.shared.presentDailyLimitAlert(from: self)
                case .requiresSubscription:
                    self.isBlockedByAccess = true
                    self.amplitude.logEvent(.reachedLimit)
                    self.amplitude.logEvent(.generationBlocked(
                        attemptID: attemptID,
                        option: gpm.designOption.rawValue,
                        promptVersion: promptVersion,
                        reason: "subscription_required"
                    ))
                    NavigationManager.shared.showPremium(
                        placement: Constants.Keys.reachedLimit,
                        origin: .inApp,
                        onPurchase: { [weak self] in
                            guard let self else { return }
                            self.isBlockedByAccess = false
                            self.startGeneration()
                        }
                    )
                }
                self.finishGeneration()
            }
            return
        }

        let isPremiumGeneration = AdaptyService.shared.hasActiveSubscription

        generationTask = Task { [weak self] in
            guard let self else { return }
            
            do {
                let input = try gpm.makeGenerationInput()
                amplitude.logEvent(.generationPromptMetadata(
                    option: gpm.designOption.rawValue,
                    promptVersion: promptVersion,
                    promptLength: input.prompt.count
                ))
                
                try Task.checkCancellation()
                
                // 2. Викликаємо автентифікацію
                try await self.performAuthCheck()
                
                try Task.checkCancellation()

                await MainActor.run {
                    self.updateGenerationStage("generating", attemptID: attemptID, startedAt: startedAt)
                }
                print("Calling \(provider) image generation service...")
                let result = try await service.generateImage(from: input)
                
                try Task.checkCancellation()

                await MainActor.run {
                    self.updateGenerationStage("saving", attemptID: attemptID, startedAt: startedAt)
                }
                // 4. Зберігаємо локально в історію
                let builtModel = try await self.saveGenerationLocally(
                    result: result,
                    baseImage: gpm.baseImage
                )

                try Task.checkCancellation()

                await MainActor.run {
                    guard !Task.isCancelled else {
                        self.amplitude.logEvent(.generationCancelled(
                            attemptID: attemptID,
                            option: gpm.designOption.rawValue,
                            promptVersion: promptVersion,
                            latencyMS: self.latencyMilliseconds(since: startedAt)
                        ))
                        self.finishGeneration()
                        return
                    }
                    if isPremiumGeneration {
                        DailyGenerationLimitManager.shared.recordSuccessfulGeneration()
                    } else {
                        FreeGenerationManager.shared.increment()
                    }
                    self.hasCompletedGenerationSuccessfully = true
                    self.amplitude.logEvent(.generationSucceeded(
                        attemptID: attemptID,
                        option: gpm.designOption.rawValue,
                        promptVersion: promptVersion,
                        provider: result.provider.rawValue,
                        model: result.model,
                        latencyMS: self.latencyMilliseconds(since: startedAt)
                    ))
                    self.amplitude.logEvent(.finishGeneration)
                    _ = NavigationManager.shared.showInspirationDetail(model: builtModel, promptManager: self.promptManager)
                    self.finishGeneration()
                }
                    
            } catch is CancellationError {
                await MainActor.run {
                    self.processingLabel.text = "Cancelled"
                    self.amplitude.logEvent(.generationCancelled(
                        attemptID: attemptID,
                        option: gpm.designOption.rawValue,
                        promptVersion: promptVersion,
                        latencyMS: self.latencyMilliseconds(since: startedAt)
                    ))
                    self.finishGeneration()
                }
            } catch let error as PromptError {
                await MainActor.run {
                    self.lastFailureReason = "prompt_validation"
                    self.amplitude.logEvent(.generationFailed(
                        attemptID: attemptID,
                        option: gpm.designOption.rawValue,
                        promptVersion: promptVersion,
                        provider: provider,
                        model: model,
                        category: "prompt_validation",
                        statusCode: nil,
                        latencyMS: self.latencyMilliseconds(since: startedAt)
                    ))
                    self.showErrorAlert(message: error.localizedDescription)
                    self.finishGeneration()
                }
            } catch let error as any ImageGenerationFailure {
                print("===== 🚨 ImageGenerationFailure caught 🚨 =====")
                print(error)
                await MainActor.run {
                    self.lastFailureReason = error.category
                    self.amplitude.logEvent(.generationFailed(
                        attemptID: attemptID,
                        option: gpm.designOption.rawValue,
                        promptVersion: promptVersion,
                        provider: provider,
                        model: model,
                        category: error.category,
                        statusCode: error.statusCode,
                        latencyMS: self.latencyMilliseconds(since: startedAt)
                    ))
                    self.showErrorAlert(message: error.localizedDescription)
                    self.finishGeneration()
                }
            } catch {
                print("===== 🚨 Unknown Error caught 🚨 =====")
                print(error)
                await MainActor.run {
                    self.lastFailureReason = "unknown"
                    self.amplitude.logEvent(.generationFailed(
                        attemptID: attemptID,
                        option: gpm.designOption.rawValue,
                        promptVersion: promptVersion,
                        provider: provider,
                        model: model,
                        category: "unknown",
                        statusCode: nil,
                        latencyMS: self.latencyMilliseconds(since: startedAt)
                    ))
                    self.showErrorAlert(message: "Something went wrong. Please try again.".localized)
                    self.finishGeneration()
                }
            }
        }
    }

    // MARK: - Допоміжні функції (без змін)
    private func performAuthCheck() async throws {
        print("[Firebase Stub] 1. Checking authentication...")
        try Task.checkCancellation()
        // _ = try await AuthService.shared.ensureSignedIn()
        try await Task.sleep(nanoseconds: 100_000_000)
        print("[Firebase Stub] 1. User 'authenticated'.")
    }

    private func latencyMilliseconds(since date: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(date) * 1_000))
    }

    private func saveGenerationLocally(
        result: ImageGenerationResult,
        baseImage: UIImage?
    ) async throws -> ImageDetailModel {
            print("2. Saving generated image to local history...")
            
            guard let gpm = promptManager else {
                throw PromptError.missingData("PromptManager")
            }
        print("[Processing] Starting generation with option:", gpm.designOption, "has base image:", gpm.baseImage != nil)
        print("[Processing] Style:", gpm.interiorStyle?.name ?? gpm.exteriorStyle?.name ?? "nil", "color:", gpm.colorType?.name ?? "nil")

            try Task.checkCancellation()

            let styleName: String = {
                switch gpm.designOption {
                case .interior:
                    return gpm.interiorStyle?.name ?? "No Style"
                case .exterior:
                    return gpm.exteriorStyle?.name ?? "No Style"
                case .garden:
                    return gpm.gardenType?.name ?? "No Style"
                case .newFlooring, .newWalls:
                    return gpm.surfaceMaterial?.title ?? gpm.surfaceCustomPrompt ?? "Custom"
                case .rearrange:
                    return gpm.rearrangeSubOption?.displayTitle ?? "Rearrange".localized
                default:
                    return gpm.interiorStyle?.name ?? gpm.exteriorStyle?.name ?? gpm.gardenType?.name ?? "Edited"
                }
            }()
            let colorName = gpm.colorType?.name

            guard let imageData = result.image.jpegData(compressionQuality: 0.9) else {
                throw PromptError.imageConversionFailed
            }

            let savedDoc = try await imageStore.saveGeneratedImage(
                imageData,
                prompt: result.prompt,
                provider: result.provider.rawValue,
                model: result.model,
                size: nil,
                seed: nil,
                makePreview: true, // Вмикаємо створення прев'ю (як у вашому сервісі)
                style: styleName,
                colorName: colorName,
                originalImage: baseImage,
                designOption: gpm.designOption,
                interiorRoomType: gpm.interiorRoomType,
                exteriorBuildingType: gpm.exteriorBuildingType,
                gardenType: gpm.gardenType,
                interiorStyle: gpm.interiorStyle,
                exteriorStyle: gpm.exteriorStyle,
                designMode: gpm.designMode,
                customPrompt: gpm.customPrompt,
                surfaceMaterial: gpm.surfaceMaterial,
                surfaceCustomPrompt: gpm.surfaceCustomPrompt,
                replaceMode: gpm.replaceMode,
                objectToReplace: gpm.objectToReplace,
                rearrangeSubOption: gpm.rearrangeSubOption
            )
            
            print("2. Image saved locally.")
            

            // Створюємо модель для наступного екрану (цей код вже правильний)
            let modelDetail = ImageDetailModel(
                previewsImage: baseImage,
                image: result.image,
                color: colorName ?? "Random",
                style: styleName,
                option: gpm.designOption,
                canRegenerate: true,
                storagePath: savedDoc.storagePath,
                originalPath: savedDoc.originalPath
            )
            return modelDetail
        }
    
}

private extension ProcessingViewController {
    
    func showErrorAlert(message: String) {
        amplitude.logEvent(.alert(message: message))
        processingLabel.text = "Couldn't create your design".localized
        descriptionLabel.text = "Your photo and choices are saved. Try again.".localized
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Try again".localized, style: .default, handler: { [weak self] _ in
            guard let self else { return }
            self.amplitude.logEvent(.tryAgainAction)
            self.retryNumber += 1
            self.amplitude.logEvent(.generationRetry(
                previousAttemptID: self.currentAttemptID ?? "unknown",
                reason: self.lastFailureReason,
                retryNumber: self.retryNumber
            ))
            self.startGeneration()
        }))
        alert.addAction(UIAlertAction(title: "OK".localized, style: .cancel))
        present(alert, animated: true)
    }
}


// MARK: - Анімація (без змін)
private extension ProcessingViewController {
    func setupSwapImageViews() {
        for iv in [frontImageView, backImageView] {
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.contentMode = processingImageView.contentMode
            iv.clipsToBounds = processingImageView.clipsToBounds
            processingImageView.addSubview(iv)
            NSLayoutConstraint.activate([
                iv.leadingAnchor.constraint(equalTo: processingImageView.leadingAnchor),
                iv.trailingAnchor.constraint(equalTo: processingImageView.trailingAnchor),
                iv.topAnchor.constraint(equalTo: processingImageView.topAnchor),
                iv.bottomAnchor.constraint(equalTo: processingImageView.bottomAnchor)
            ])
        }
        frontImageView.isHidden = false
        backImageView.isHidden = true
    }

    func setInitialFrame() {
        guard let first = frames.first else { return }
        frontImageView.image = first
        backImageView.image = first
    }
    
    func startSequence() {
        guard frames.count > 1 else { return }
        scheduleNext()
    }

    func stopSequence() {
        timer?.invalidate()
        timer = nil
    }

    func scheduleNext() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: false) { [weak self] _ in
            self?.advance()
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    func advance() {
        guard frames.count > 1 else { return }

        let nextIndex = (currentIndex + 1) % frames.count
        let nextImage = frames[nextIndex]

        let fromView = usingFrontOnTop ? frontImageView : backImageView
        let toView   = usingFrontOnTop ? backImageView  : frontImageView

        toView.image = nextImage
        toView.isHidden = false

        let options: UIView.AnimationOptions = [.showHideTransitionViews, nextDirection.transitionOption]

        UIView.transition(from: fromView,
                          to: toView,
                          duration: swapDuration,
                          options: options,
                          completion: { [weak self] _ in
            guard let self else { return }
            self.currentIndex = nextIndex
            self.usingFrontOnTop.toggle()
            self.nextDirection = (self.nextDirection == .side) ? .bottom : .side
            self.scheduleNext()
        })
    }
}
