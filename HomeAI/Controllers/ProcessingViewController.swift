import UIKit
import GoogleGenerativeAI
// import FirebaseAuth

enum GeminiServiceError: Error {
    case invalidAPIKey // Цей кейс нам більше не потрібен, але нехай залишається
    case invalidURL
    case requestFailed(Error)
    case httpError(statusCode: Int, message: String)
    case noImageInResponse
    case imageDecodingFailed
    case partConversionFailed
}


private struct Defaults {
    struct Text {
        static let processing = "Processing...".localized
        static let description = "Please, don’t close the app ".localized
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
    /// Після успішної генерації не запускати знову при `viewDidAppear` (закриття деталі, pop назад тощо).
    private var hasCompletedGenerationSuccessfully = false
    private let amplitude = AmplitudeService.shared

    // MARK: - Cancellation
    private var generationTask: Task<Void, Never>?
    
    // MARK: - Gemini Model
    private lazy var geminiService: GeminiRESTService? = {
        return GeminiRESTService() // Ініціалізуємо без ключа
    }()

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
        if !isGenerating {
            startGeneration()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent {
            generationTask?.cancel()
            stopSequence()
        }
    }

    deinit {
        generationTask?.cancel()
    }

    // MARK: - Public
    func startGeneration() {
        guard !isGenerating else { return }
        hasCompletedGenerationSuccessfully = false
        NavigationManager.shared.clearPendingInspirationDetailReopen()
        amplitude.logEvent(.startGeneration)

        isGenerating = true
        stopSequence()
        startSequence()
        
        startGeminiGenerationTask()
    }

    // MARK: - Private
    private func finishGeneration() {
        amplitude.logEvent(.finishGeneration)
        isGenerating = false
        generationTask = nil
    }

    private func startGeminiGenerationTask() {
        guard let gpm = promptManager else {
            amplitude.logEvent(.error(message: "PromptManager_nil"))
            finishGeneration()
            return
        }
        print(gpm)
        guard let service = geminiService else {
            amplitude.logEvent(.error(message: "GeminiService_nil"))
            finishGeneration()
            return
        }
            
        let access = GenerationAccess.evaluate()
        if access != .allowed {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                switch access {
                case .allowed:
                    break
                case .dailyLimitExceeded:
                    DailyGenerationLimitManager.shared.presentDailyLimitAlert(from: self)
                case .requiresSubscription:
                    self.amplitude.logEvent(.reachedLimit)
                    NavigationManager.shared.showPremium(placement: Constants.Keys.reachedLimit)
                }
                self.finishGeneration()
            }
            return
        }

        if !ApphudService.shared.hasActiveSubscription {
            FreeGenerationManager.shared.increment()
        }

        generationTask = Task { [weak self] in
            guard let self else { return }
            
            do {
                let parts = try gpm.generatePromptParts()
                print(parts)
                // (Логування промпту - без змін)
                let tempTextForLog = parts.compactMap { $0.text }.joined(separator: "\n")
                let truncatedPrompt = String(tempTextForLog.prefix(100))
                amplitude.logEvent(.prompt(p: truncatedPrompt))
                
                try Task.checkCancellation()
                
                // 2. Викликаємо автентифікацію
                try await self.performAuthCheck()
                
                try Task.checkCancellation()

                // 3. 🔥 ВИКЛИКАЄМО НАШ НОВИЙ СЕРВІС 🔥
                print("Calling Gemini API via REST Service...")
                let (generatedImage, promptText) = try await service.generateImage(from: parts)
                
                try Task.checkCancellation()

                // 4. Зберігаємо локально в історію
                let builtModel = try await self.saveGenerationLocally(
                    generatedImage: generatedImage,
                    baseImage: gpm.baseImage,
                    prompt: promptText
                )

                try Task.checkCancellation()

                await MainActor.run {
                    guard !Task.isCancelled else {
                        self.finishGeneration()
                        return
                    }
                    DailyGenerationLimitManager.shared.recordSuccessfulGeneration()
                    self.hasCompletedGenerationSuccessfully = true
                    _ = NavigationManager.shared.showInspirationDetail(model: builtModel, promptManager: self.promptManager)
                    self.finishGeneration()
                }
                    
            } catch is CancellationError {
                await MainActor.run {
                    self.processingLabel.text = "Cancelled"
                    self.finishGeneration()
                }
            } catch let error as PromptError {
                await MainActor.run {
                    self.showErrorAlert(message: error.localizedDescription)
                    self.finishGeneration()
                }
            } catch let error as GeminiServiceError {
                print("===== 🚨 GeminiServiceError caught 🚨 =====")
                print(error)
                await MainActor.run {
                    self.showErrorAlert(message: error.localizedDescription)
                    self.finishGeneration()
                }
            } catch {
                print("===== 🚨 Unknown Error caught 🚨 =====")
                print(error)
                await MainActor.run {
                    self.showErrorAlert(message: error.localizedDescription)
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

    private func saveGenerationLocally(generatedImage: UIImage, baseImage: UIImage?, prompt: String) async throws -> ImageDetailModel {
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
                default:
                    return gpm.interiorStyle?.name ?? gpm.exteriorStyle?.name ?? gpm.gardenType?.name ?? "Edited"
                }
            }()
            let colorName = gpm.colorType?.name

            guard let imageData = generatedImage.jpegData(compressionQuality: 0.9) else {
                throw PromptError.imageConversionFailed
            }

            let savedDoc = try await imageStore.saveGeneratedImage(
                imageData,
                prompt: prompt,
                model: "gemini-2.5-flash-image", // Модель, яку ми використовуємо
                size: nil, // Gemini не повертає ці дані
                seed: nil, // Gemini не повертає ці дані
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
                objectToReplace: gpm.objectToReplace
            )
            
            print("2. Image saved locally.")
            

            // Створюємо модель для наступного екрану (цей код вже правильний)
            let modelDetail = ImageDetailModel(
                previewsImage: baseImage,
                image: generatedImage,
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
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Try again".localized, style: .default, handler: { [weak self] _ in
            self?.amplitude.logEvent(.tryAgainAction)
            self?.startGeneration()
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
