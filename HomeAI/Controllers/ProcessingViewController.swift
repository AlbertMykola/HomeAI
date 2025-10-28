import UIKit
import FirebaseAuth

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

final class ProcessingViewController: UIViewController, PromptManagerHolder  {

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
    private let imageStore = FirebaseImageService()

    var promptManager: PromptManager?

    // MARK: - Timing
    private let frameInterval: TimeInterval = 1.4
    private let swapDuration: TimeInterval = 0.45

    private var timer: Timer?

    // Guard to avoid parallel generations
    private var isGenerating = false
    private let amplitude = AmplitudeService.shared

    // MARK: - Cancellation
    private var generationTask: Task<Void, Never>?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        processingLabel.text = Defaults.Text.processing
        descriptionLabel.text = Defaults.Text.description
        amplitude.logEvent(.showProcessing)
        frames = Defaults.Images.images
        if frames.isEmpty, let img = processingImageView.image { frames = [img] }

        setupSwapImageViews()
        setInitialFrame()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSequence()
        if !isGenerating { startGeneration() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Скасувати довгу операцію при поверненні назад стандартною кнопкою/свайпом
        if isMovingFromParent {
            generationTask?.cancel()
            stopSequence()
        }
    }

    deinit {
        // Додаткова страховка, якщо VC звільняється із ще активною задачею
        generationTask?.cancel()
    }

    // MARK: - Public
    func startGeneration() {
        guard !isGenerating else { return }
        amplitude.logEvent(.startGeneration)

        isGenerating = true
        stopSequence()
        startSequence()
        generateImage()
    }

    // MARK: - Private
    private func finishGeneration() {
        amplitude.logEvent(.finishGeneration)

        isGenerating = false
        generationTask = nil
    }

    private func generateImage() {
        guard let pm = promptManager,
              let (payload, baseImage, referenceImage, maskPNG, apiSize) = pm.buildPrompt() else {
            print("Failed to build prompt")
            amplitude.logEvent(.filedBuildPrompt)

            finishGeneration()
            return
        }
        
        if !FreeGenerationManager.shared.canGenerateForFree && !ApphudService.shared.hasActiveSubscription {
            DispatchQueue.main.async {
                self.finishGeneration()
                NavigationManager.shared.showPremium(placement: Constants.Keys.reachedLimit)
            }
            return
        }
        FreeGenerationManager.shared.increment()

        amplitude.logEvent(.prompt(p: "Prompt: \(payload.user)"))

        generationTask = Task { [weak self] in
            guard let self else { return }
            do {
                try Task.checkCancellation()

                let service = try ImageGenService(endpoint: Constants.API.chatGPT)

                try Task.checkCancellation()

                let results: [UIImage]
                let model = payload.metadata["model"] as? String ?? "dall-e-2"  // З metadata (з PromptManager: dall-e-2 для edits/reference)
                
                if let baseImg = baseImage {
                    results = try await service.redesignImage(
                        baseImage: baseImg,
                        referenceImage: referenceImage,
                        prompt: payload.user,
                        maskPNG: maskPNG,
                        orientationHint: nil,
                        seed: nil,
                        model: model,
                        n: 1
                    )
                } else {
                    let genSize = apiSize ?? "1024x1536"
                    results = try await service.generateImage(
                        prompt: payload.user,
                        model: "gpt-image-1",
                        n: 1,
                        size: genSize,
                        seed: nil
                    )
                }

                try Task.checkCancellation()

                _ = try await AuthService.shared.ensureSignedIn()

                try Task.checkCancellation()

                var builtModel: ImageDetailModel?
                let styleName = promptManager?.context.style?.name ?? "Unknown"
                let color = promptManager?.context.palette?.name

                for img in results {
                    try Task.checkCancellation()
                    if let data = img.jpegData(compressionQuality: 0.9) {
                        _ = try await imageStore.saveGeneratedImage(
                            data,
                            prompt: payload.user,
                            model: model,
                            size: apiSize,
                            seed: nil,
                            makePreview: true,
                            style: styleName,
                            colorName: color
                        )
                        let modelDetail = ImageDetailModel(
                            previewsImage: baseImage,
                            image: img,
                            color: color ?? "Random",
                            style: styleName,
                            option: promptManager?.context.option ?? .interior
                        )
                        builtModel = modelDetail
                    }
                }

                try Task.checkCancellation()

                await MainActor.run {
                    guard !Task.isCancelled else {
                        self.finishGeneration()
                        return
                    }
                    guard let model = builtModel else {
                        self.finishGeneration()
                        return
                    }
                    NavigationManager.shared.showInspirationDetail(model: model, promptManager: self.promptManager)
                    self.finishGeneration()
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.processingLabel.text = "Cancelled"
                    self.finishGeneration()
                }
            } catch {
                self.amplitude.logEvent(.error(message: error.localizedDescription))

                await MainActor.run {
                    self.processingLabel.text = "Error occurred"
                    self.finishGeneration()
                }
            }
        }
    }

}

// MARK: - Setup
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
}

// MARK: - Sequence
private extension ProcessingViewController {
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
