import UIKit

private struct Defaults {
    struct Text {
        static let generate = "Generate".localized
        static let detecting = "Detecting...".localized
        static let placeholder = "Swap the floor lamp for a plant.".localized
    }
}

class ObjectSelectionViewController: UIViewController, PageStepDelegate, PromptManagerHolder {
    
    // MARK: - Outlets
    @IBOutlet weak private var previewImageView: UIImageView?
    @IBOutlet weak private var brushSizeSlider: UISlider?
    
    @IBOutlet weak private var promptLabel: UILabel?
    
    @IBOutlet weak private var generateButton: UIButton!
    @IBOutlet weak private var undoButton: UIButton?
    @IBOutlet weak private var redoButton: UIButton?
    
    // MARK: - Properties
    var completion: (() -> Void)?
    var showsGenerateButton: Bool = true
    var requiresPromptInput: Bool = true
    var replacementDescription: String?
    var canProceedToNextStep: Bool { 
        let hasDrawing = drawingCanvas.hasDrawing
        guard requiresPromptInput else { return hasDrawing }
        let promptText = promptLabel?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasPrompt = hasCustomPrompt && !promptText.isEmpty && promptText != Defaults.Text.placeholder
        return hasDrawing && hasPrompt
    }
    
    var promptManager: GemeniPromptManager?
    
    private let amplitude = AmplitudeService.shared
    private let drawingCanvas = DrawingCanvasView()
    private let geminiService = GeminiRESTService()
    private var detectedObjects: [DetectedObject] = []
    private var hasCustomPrompt: Bool = false
    private let scrollView = UIScrollView()
    private var baseImageForProcessing: UIImage?
    private var debugMaskPreviewEnabled: Bool = false
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCanvas()
        loadImage()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        generateButton.cornerRadius = generateButton.frame.height / 2
        drawingCanvas.setNeedsLayout()
        drawingCanvas.layoutIfNeeded()
    }
    
    // MARK: - Setup
    private func setupUI() {
        brushSizeSlider?.minimumValue = 200
        brushSizeSlider?.maximumValue = 15000000
        brushSizeSlider?.value = 200

        generateButton.isHidden = !showsGenerateButton
        generateButton.setTitle(Defaults.Text.generate, for: .normal)
        if !requiresPromptInput {
            promptLabel?.superview?.isHidden = true
        }
        drawingCanvas.maskGenerationMode = requiresPromptInput ? .strokes : .boundingRect
        // Встановлюємо placeholder текст
        promptLabel?.text = Defaults.Text.placeholder
        hasCustomPrompt = false
        
        drawingCanvas.brushSize = 200
        setupUndoRedoButtons()
    }
    
    private func setupUndoRedoButtons() {
        configureButton(undoButton)
        configureButton(redoButton)
    }
    
    private func configureButton(_ button: UIButton?) {
        guard let button = button else { return }
        
        button.tintColor = .label
        
        if var config = button.configuration {
            config.imagePlacement = .all
            config.imagePadding = 0
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            config.title = nil
            button.configuration = config
        }
        
        button.imageView?.contentMode = .center
    }
    
    private func setupCanvas() {
        // Налаштування ScrollView для зуму
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.backgroundColor = .clear
        view.addSubview(scrollView)
        
        // Додаємо drawingCanvas в scrollView
        drawingCanvas.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(drawingCanvas)
        drawingCanvas.showsMaskPreview = debugMaskPreviewEnabled
        
        previewImageView?.isUserInteractionEnabled = false
        
        if let previewImageView = previewImageView, previewImageView.superview != nil {
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: previewImageView.topAnchor),
                scrollView.leadingAnchor.constraint(equalTo: previewImageView.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: previewImageView.trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: previewImageView.bottomAnchor),
                
                drawingCanvas.topAnchor.constraint(equalTo: scrollView.topAnchor),
                drawingCanvas.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
                drawingCanvas.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
                drawingCanvas.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
                drawingCanvas.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
                drawingCanvas.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
            ])
        } else {
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100),
                scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -200),
                
                drawingCanvas.topAnchor.constraint(equalTo: scrollView.topAnchor),
                drawingCanvas.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
                drawingCanvas.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
                drawingCanvas.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
                drawingCanvas.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
                drawingCanvas.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
            ])
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(drawingChanged),
            name: NSNotification.Name("DrawingChanged"),
            object: nil
        )
    }
    
    private func loadImage() {
        guard let baseImage = promptManager?.baseImage else {
            return
        }
        baseImageForProcessing = baseImage
        
        drawingCanvas.baseImage = baseImage
        previewImageView?.isHidden = true
        
        previewImageView?.layer.cornerRadius = 34
        previewImageView?.clipsToBounds = true
        
        // Оновлюємо contentSize scrollView після завантаження зображення
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let imageSize = baseImage.size
            let scrollViewSize = self.scrollView.bounds.size
            
            // Розраховуємо розмір для aspect fit
            let imageAspect = imageSize.width / imageSize.height
            let viewAspect = scrollViewSize.width / scrollViewSize.height
            
            let contentSize: CGSize
            if imageAspect > viewAspect {
                contentSize = CGSize(width: scrollViewSize.width, height: scrollViewSize.width / imageAspect)
            } else {
                contentSize = CGSize(width: scrollViewSize.height * imageAspect, height: scrollViewSize.height)
            }
            
            self.scrollView.contentSize = contentSize
            self.drawingCanvas.frame = CGRect(origin: .zero, size: contentSize)
        }
    }
    
    private func createMaskFromObject(_ object: DetectedObject, imageSize: CGSize) {
        let rect = object.toRect(imageSize: imageSize)
        guard let baseImage = promptManager?.baseImage else { return }
        
        drawingCanvas.objectRect = rect
        
        let maskImage = createMaskImage(from: rect, imageSize: baseImage.size, canvasSize: drawingCanvas.bounds.size)
        
        if let mask = maskImage {
            promptManager?.updateMask(mask)
        }
        
        drawingCanvas.setMaskFromRect(rect: rect, imageSize: baseImage.size)
        
        checkDrawingState()
    }
    
    private func createMaskImage(from rect: CGRect, imageSize: CGSize, canvasSize: CGSize) -> UIImage? {
        let scaleX = canvasSize.width / imageSize.width
        let scaleY = canvasSize.height / imageSize.height
        
        let scaledRect = CGRect(
            x: rect.origin.x * scaleX,
            y: rect.origin.y * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )
        
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        return renderer.image { context in
            let cgContext = context.cgContext
            
            UIColor.black.setFill()
            cgContext.fill(CGRect(origin: .zero, size: imageSize))
            
            // Білий прямокутник для об'єкта
            UIColor.white.setFill()
            cgContext.fill(rect)
        }
    }
    
    private func showObjectSelection(objects: [DetectedObject], imageSize: CGSize) {
        let alert = UIAlertController(
            title: "Select Object".localized,
            message: "Multiple objects found. Please select one:".localized,
            preferredStyle: .actionSheet
        )
        
        for object in objects {
            alert.addAction(UIAlertAction(title: object.name, style: .default) { [weak self] _ in
                self?.createMaskFromObject(object, imageSize: imageSize)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel))
        
        // Для iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        }
        
        present(alert, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK".localized, style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Helpers
    
    private func checkDrawingState() {
        // Оновлюємо стан completion для PageViewController
        completion?()
    }
    
    // Метод для перевірки, чи можна перейти далі (викликається з ReplaceObjectPageViewController)
    func validateBeforeProceeding() -> Bool {
        let hasDrawing = drawingCanvas.hasDrawing
        let promptText = promptLabel?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasPrompt = hasCustomPrompt && !promptText.isEmpty && promptText != Defaults.Text.placeholder
        
        // Перевіряємо обидві умови окремо для конкретних повідомлень
        if !hasDrawing {
            showAlert(
                title: "Action Required".localized,
                message: "Please select an object on the image.".localized
            )
            return false
        }
        
        if requiresPromptInput && !hasPrompt {
            showAlert(
                title: "Action Required".localized,
                message: "Please enter a prompt.".localized
            )
            return false
        }
        
        return true
    }
    
    
    // MARK: - Actions
    @IBAction func sliderAction(_ sender: UISlider) {
        let brushSize = CGFloat(sender.value)
        updateBrushSize(brushSize)
    }
    
    @IBAction func undoAction(_ sender: UIButton) {
        drawingCanvas.undo()
        checkDrawingState()
        if !drawingCanvas.hasDrawing {
            showAlert(
                title: "Action Required".localized,
                message: "Please select an object on the image.".localized
            )
        }
    }
    
    @IBAction func redoAction(_ sender: UIButton) {
        drawingCanvas.redo()
        checkDrawingState()
        
        if !drawingCanvas.hasDrawing {
            showAlert(
                title: "Action Required".localized,
                message: "Please select an object on the image.".localized
            )
        }
    }
    
    @objc private func brushSizeChanged(_ slider: UISlider) {
        let brushSize = CGFloat(slider.value)
        updateBrushSize(brushSize)
    }
    
    private func updateBrushSize(_ size: CGFloat) {
        drawingCanvas.brushSize = size
    }
    
    @IBAction private func generateAction(_ sender: UIButton) {
        guard prepareForGeneration() else { return }
        
        guard let promptManager else { return }
        if GenerationAccess.requestProcessingIfAllowed(presentingFrom: self) {
            NavigationManager.shared.showProcessing(manager: promptManager)
        }
    }
    
    @IBAction private func openEnterPrompt(_ sender: UIButton) {
        guard let promptManager = promptManager else { return }
        guard requiresPromptInput else { return }

        let currentPromptText = promptLabel?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let currentPrompt = (currentPromptText != Defaults.Text.placeholder && hasCustomPrompt) ? currentPromptText : nil
        
        NavigationManager.shared.showPrompt(promptManager: promptManager, showSuggestions: false, initialPrompt: currentPrompt) { [weak self] prompt in
            guard let self = self else { return }
            
            let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedPrompt.isEmpty {
                self.promptLabel?.text = Defaults.Text.placeholder
                self.hasCustomPrompt = false
            } else {
                self.promptLabel?.text = trimmedPrompt
                self.hasCustomPrompt = true
            }
            
            if !trimmedPrompt.isEmpty {
                self.promptManager?.updateObjectToReplace(trimmedPrompt)
            } else {
                self.promptManager?.updateObjectToReplace("")
            }
            
            self.checkDrawingState()
        }
    }
    
    @objc private func drawingChanged() {
        if let mask = drawingCanvas.maskImage {
            promptManager?.updateMask(mask)
            if debugMaskPreviewEnabled {
                drawingCanvas.setMaskPreview(mask)
                print("🧪 Mask debug: base=\(baseImageForProcessing?.size as Any) mask=\(mask.size)")
            }
        }
        checkDrawingState()
    }

    func prepareForGeneration() -> Bool {
        guard validateBeforeProceeding(), let promptManager else { return false }
        if let baseImageForProcessing {
            promptManager.updateBaseImage(baseImageForProcessing)
        }

        if let mask = drawingCanvas.maskImage {
            promptManager.updateMask(mask)
            if debugMaskPreviewEnabled {
                drawingCanvas.setMaskPreview(mask)
                print("🧪 Mask debug: base=\(baseImageForProcessing?.size as Any) mask=\(mask.size)")
            }
        }

        if requiresPromptInput {
            let promptText = promptLabel?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if hasCustomPrompt && !promptText.isEmpty && promptText != Defaults.Text.placeholder {
                promptManager.updateObjectToReplace(promptText)
            }
            promptManager.updateReplaceMode(.replace)
        } else {
            let description = replacementDescription?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallback = "an empty spot with clean background that matches the surroundings, no objects"
            promptManager.updateObjectToReplace((description?.isEmpty == false) ? description! : fallback)
            promptManager.updateReplaceMode(.replace)
        }
        promptManager.updateOption(.replace)
        return true
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UIScrollViewDelegate
extension ObjectSelectionViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return drawingCanvas
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // Центруємо зображення при зумі
        let boundsSize = scrollView.bounds.size
        var frameToCenter = drawingCanvas.frame
        
        if frameToCenter.size.width < boundsSize.width {
            frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
        } else {
            frameToCenter.origin.x = 0
        }
        
        if frameToCenter.size.height < boundsSize.height {
            frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
        } else {
            frameToCenter.origin.y = 0
        }
        
        drawingCanvas.frame = frameToCenter
    }
}
