import UIKit
import PencilKit
import CoreImage

/// View для малювання маски на зображенні з використанням PencilKit
class DrawingCanvasView: UIView {
    
    // MARK: - Properties
    
    enum MaskGenerationMode {
        case strokes
        case boundingRect
    }
    
    var maskGenerationMode: MaskGenerationMode = .strokes
    
    var baseImage: UIImage? {
        didSet {
            imageView.image = baseImage
            updateImageLayout()
        }
    }
    
    var brushSize: CGFloat = 200.0 {
        didSet {
            // Не обмежуємо brushSize тут, бо користувач може встановити будь-яке значення
            // Обмеження буде в updateBrushTool() якщо потрібно
            updateBrushTool()
        }
    }
    
    var maskColor: UIColor = UIColor.red.withAlphaComponent(0.7) {
        didSet {
            updateBrushTool()
            // Видаляємо overlay, бо тепер використовуємо колір інструменту
            overlayImageView.isHidden = true
        }
    }
    
    var showsMaskPreview: Bool = false {
        didSet { updateOverlay() }
    }
    
    var maskImage: UIImage? {
        return generateMaskImage()
    }
    
    var hasDrawing: Bool {
        return !canvasView.drawing.bounds.isEmpty
    }
    
    /// Встановлює білий контур навколо об'єкта (для відображення виявленого об'єкта)
    var objectRect: CGRect? {
        didSet {
            updateObjectOutline()
            updateZoomImage()
        }
    }
    
    // MARK: - Private Properties
    
    private let imageView = UIImageView()
    private let canvasView = PKCanvasView()
    private let overlayImageView = UIImageView() // Для червоного overlay
    private let objectOutlineView = UIView() // Для білого контуру об'єкта
    private let zoomImageView = UIImageView() // Збільшене зображення в куті
    private var maskPreviewImage: UIImage?
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        // Image view (нижній шар)
        addSubview(imageView)
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 34
        imageView.isUserInteractionEnabled = false
        
        // Canvas view (середній шар - для малювання)
        addSubview(canvasView)
        canvasView.delegate = self
        canvasView.drawingPolicy = .anyInput // Дозволяємо малювати пальцем та Apple Pencil
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.layer.cornerRadius = 34
        canvasView.clipsToBounds = true
        canvasView.isUserInteractionEnabled = true // Важливо для малювання
        
        // Важливо для відображення drawing
        canvasView.drawing = PKDrawing() // Ініціалізуємо порожнє drawing
        canvasView.allowsFingerDrawing = true // Дозволяємо малювати пальцем
        
        // Overlay image view (верхній шар - червоний overlay)
        addSubview(overlayImageView)
        overlayImageView.isUserInteractionEnabled = false
        overlayImageView.backgroundColor = .clear
        overlayImageView.contentMode = .scaleToFill
        overlayImageView.isHidden = true // Спочатку прихований, поки немає drawing
        
        // Object outline view (для білого контуру об'єкта)
        addSubview(objectOutlineView)
        objectOutlineView.isUserInteractionEnabled = false
        objectOutlineView.backgroundColor = .clear
        objectOutlineView.layer.borderWidth = 3
        objectOutlineView.layer.borderColor = UIColor.white.cgColor
        objectOutlineView.isHidden = true
        
        // Zoom image view (збільшене зображення в куті)
        addSubview(zoomImageView)
        zoomImageView.isUserInteractionEnabled = false
        zoomImageView.backgroundColor = .systemBackground
        zoomImageView.layer.cornerRadius = 8
        zoomImageView.layer.borderWidth = 2
        zoomImageView.layer.borderColor = UIColor.white.cgColor
        zoomImageView.contentMode = .scaleAspectFill
        zoomImageView.clipsToBounds = true
        zoomImageView.isHidden = true
        
        // Переконаємося, що порядок правильний: imageView (нижній), canvasView (середній), overlayImageView (червоний), objectOutlineView (білий контур)
        imageView.removeFromSuperview()
        canvasView.removeFromSuperview()
        overlayImageView.removeFromSuperview()
        objectOutlineView.removeFromSuperview()
        
        // Додаємо в правильному порядку
        insertSubview(imageView, at: 0) // Нижній шар
        insertSubview(canvasView, at: 1) // Середній шар
        insertSubview(overlayImageView, at: 2) // Червоний overlay
        insertSubview(objectOutlineView, at: 3) // Білий контур
        insertSubview(zoomImageView, at: 4) // Збільшене зображення (найвищий шар)
        
        // Переконаємося, що view може приймати touches
        isUserInteractionEnabled = true
        
        // Додаткова перевірка для canvasView
        print("🎨 DrawingCanvasView setup:")
        print("   Subviews order: \(subviews.map { type(of: $0) })")
        print("   canvasView.isUserInteractionEnabled=\(canvasView.isUserInteractionEnabled)")
        print("   drawingPolicy=\(canvasView.drawingPolicy.rawValue)")
        print("   canvasView.frame=\(canvasView.frame)")
        print("   canvasView.bounds=\(canvasView.bounds)")
        
        updateBrushTool()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        print("👆 DrawingCanvasView touchesBegan: \(touches.count) touches")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        print("📐 DrawingCanvasView layoutSubviews:")
        print("   self.bounds=\(bounds)")
        print("   canvasView.frame=\(canvasView.frame)")
        print("   canvasView.bounds=\(canvasView.bounds)")
        print("   canvasView.isUserInteractionEnabled=\(canvasView.isUserInteractionEnabled)")
        updateImageLayout()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Переконаємося, що touches проходять до canvasView
        let hitView = super.hitTest(point, with: event)
        print("👆 hitTest: point=\(point), hitView=\(type(of: hitView ?? UIView()))")
        
        if hitView === overlayImageView || hitView === objectOutlineView || hitView === zoomImageView {
            // Якщо touch на overlay/outline/zoom, передаємо його до canvasView
            print("   → Redirecting to canvasView")
            return canvasView
        }
        
        if hitView === self {
            // Якщо touch на self, також передаємо до canvasView
            print("   → Redirecting to canvasView (self)")
            return canvasView
        }
        
        return hitView
    }
    
    private func updateImageLayout() {
        guard let image = baseImage else {
            let frame = bounds
            imageView.frame = frame
            canvasView.frame = frame
            overlayImageView.frame = frame
            print("⚠️ No base image, using full bounds: \(frame)")
            return
        }
        
        let imageSize = image.size
        let viewSize = bounds.size
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height
        
        var displaySize: CGSize
        var displayOrigin: CGPoint
        
        if imageAspect > viewAspect {
            displaySize = CGSize(width: viewSize.width, height: viewSize.width / imageAspect)
            displayOrigin = CGPoint(x: 0, y: (viewSize.height - displaySize.height) / 2)
        } else {
            displaySize = CGSize(width: viewSize.height * imageAspect, height: viewSize.height)
            displayOrigin = CGPoint(x: (viewSize.width - displaySize.width) / 2, y: 0)
        }
        
        let frame = CGRect(origin: displayOrigin, size: displaySize)
        imageView.frame = frame
        canvasView.frame = frame
        overlayImageView.frame = frame
        objectOutlineView.frame = frame
        
        // Налаштування збільшеного зображення (в лівому верхньому куті)
        let zoomSize: CGFloat = 120
        zoomImageView.frame = CGRect(
            x: frame.origin.x + 16,
            y: frame.origin.y + 16,
            width: zoomSize,
            height: zoomSize
        )
        
        print("🖼️ Layout updated:")
        print("   imageView.frame=\(imageView.frame)")
        print("   canvasView.frame=\(canvasView.frame)")
        print("   canvasView.bounds=\(canvasView.bounds)")
        print("   self.bounds=\(bounds)")
        print("   canvasView.isUserInteractionEnabled=\(canvasView.isUserInteractionEnabled)")
        print("   canvasView.drawingPolicy=\(canvasView.drawingPolicy.rawValue)")
        print("   canvasView.allowsFingerDrawing=\(canvasView.allowsFingerDrawing)")
        
        // Переконаємося, що canvasView може приймати touches
        canvasView.isUserInteractionEnabled = true
        canvasView.isOpaque = false
        canvasView.backgroundColor = .clear
        
        // Не викликаємо updateOverlay() тут, бо overlay вимкнений
        // updateOverlay() викликається тільки при зміні layout
    }
    
    private func updateBrushTool() {
        // Використовуємо яскравий червоний колір для інструменту
        let visibleColor = UIColor.red.withAlphaComponent(0.7)
        
        // PencilKit очікує ширину в точках
        // Масштабуємо значення з діапазону 200-15000000 до 10-300 точок для дуже товстих ліній
        let minInput: CGFloat = 200
        let maxInput: CGFloat = 15000000
        let minOutput: CGFloat = 10
        let maxOutput: CGFloat = 300
        
        let clampedBrushSize = max(minInput, min(maxInput, brushSize))
        let adjustedBrushSize = minOutput + (clampedBrushSize - minInput) * (maxOutput - minOutput) / (maxInput - minInput)
        
        print("🎨 Brush tool updated:")
        print("   Input value: \(brushSize)")
        print("   Clamped value: \(clampedBrushSize)")
        print("   Adjusted (PencilKit) width: \(adjustedBrushSize) points")
        print("   Range: \(minOutput)-\(maxOutput) points (from \(minInput)-\(maxInput) slider)")
        
        // Використовуємо .marker замість .pen для статичної ширини
        // .marker не реагує на force (силу натискання) і завжди має однакову ширину
        let tool = PKInkingTool(.marker, color: visibleColor, width: adjustedBrushSize)
        canvasView.tool = tool
        
        // Переконаємося, що canvasView видимий і може приймати touches
        canvasView.isUserInteractionEnabled = true
        canvasView.isOpaque = false
        canvasView.backgroundColor = .clear
    }
    
    // MARK: - Actions
    
    func undo() {
        canvasView.undoManager?.undo()
        updateOverlay()
    }
    
    func redo() {
        canvasView.undoManager?.redo()
        updateOverlay()
    }
    
    func clear() {
        canvasView.drawing = PKDrawing()
        updateOverlay()
    }
    
    /// Встановлює маску на основі координат об'єкта (для використання з Gemini API)
    /// Створює візуалізацію маски в canvasView для відображення користувачу
    func setMaskFromRect(rect: CGRect, imageSize: CGSize) {
        guard !canvasView.bounds.isEmpty else { return }
        
        // Очищаємо поточне drawing
        canvasView.drawing = PKDrawing()
        
        // Масштабуємо координати до розміру canvasView
        let scaleX = canvasView.bounds.width / imageSize.width
        let scaleY = canvasView.bounds.height / imageSize.height
        
        let scaledRect = CGRect(
            x: rect.origin.x * scaleX,
            y: rect.origin.y * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )
        
        // Створюємо drawing з заповненим прямокутником
        // Використовуємо горизонтальні лінії для заповнення
        var strokes: [PKStroke] = []
        let step: CGFloat = max(5, brushSize / 2)
        let creationDate = Date()
        
        for y in stride(from: scaledRect.minY, to: scaledRect.maxY, by: step) {
            // Створюємо точки для лінії
            var points: [PKStrokePoint] = []
            let numPoints = max(2, Int(scaledRect.width / step))
            
            for i in 0..<numPoints {
                let x = scaledRect.minX + (CGFloat(i) / CGFloat(numPoints - 1)) * scaledRect.width
                let point = PKStrokePoint(
                    location: CGPoint(x: x, y: y),
                    timeOffset: Double(i) / Double(numPoints - 1),
                    size: CGSize(width: brushSize, height: brushSize),
                    opacity: 1,
                    force: 1,
                    azimuth: 0,
                    altitude: 1.57
                )
                points.append(point)
            }
            
            let path = PKStrokePath(controlPoints: points, creationDate: creationDate)
            let ink = PKInk(.pen, color: maskColor)
            // Використовуємо правильний ініціалізатор: init(ink:path:transform:mask:)
            let stroke = PKStroke(ink: ink, path: path, transform: .identity, mask: nil)
            strokes.append(stroke)
        }
        
        // Створюємо нове drawing з усіма strokes
        var drawing = PKDrawing()
        for stroke in strokes {
            drawing.strokes.append(stroke)
        }
        
        canvasView.drawing = drawing
        updateOverlay()
        
        NotificationCenter.default.post(name: NSNotification.Name("DrawingChanged"), object: nil)
    }
    
    // MARK: - Overlay Update
    
    private func updateOverlay() {
        // Покажемо overlay тільки якщо ввімкнено debug-прев'ю маски
        if showsMaskPreview, let maskPreviewImage {
            overlayImageView.image = maskPreviewImage
            overlayImageView.alpha = 0.45
            overlayImageView.isHidden = false
        } else {
            overlayImageView.isHidden = true
        }
        
        // Переконаємося, що білий контур поверх всього
        bringSubviewToFront(objectOutlineView)
        bringSubviewToFront(zoomImageView)
    }

    func setMaskPreview(_ image: UIImage?) {
        maskPreviewImage = image
        updateOverlay()
    }
    
    /// Оновлює білий контур навколо об'єкта
    private func updateObjectOutline() {
        guard let rect = objectRect, !canvasView.bounds.isEmpty else {
            objectOutlineView.isHidden = true
            return
        }
        
        // Масштабуємо координати до розміру canvasView
        guard let baseImage = baseImage else {
            objectOutlineView.isHidden = true
            return
        }
        
        let imageSize = baseImage.size
        let scaleX = canvasView.bounds.width / imageSize.width
        let scaleY = canvasView.bounds.height / imageSize.height
        
        // Координати відносно canvasView
        let scaledRect = CGRect(
            x: rect.origin.x * scaleX,
            y: rect.origin.y * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )
        
        // Встановлюємо frame для контуру відносно canvasView
        objectOutlineView.frame = CGRect(
            x: canvasView.frame.origin.x + scaledRect.origin.x,
            y: canvasView.frame.origin.y + scaledRect.origin.y,
            width: scaledRect.width,
            height: scaledRect.height
        )
        
        objectOutlineView.isHidden = false
        objectOutlineView.layer.cornerRadius = 8
        objectOutlineView.layer.borderWidth = 3
        objectOutlineView.layer.borderColor = UIColor.white.cgColor
        
        // Переконаємося, що контур поверх всього
        bringSubviewToFront(objectOutlineView)
        bringSubviewToFront(zoomImageView)
    }
    
    /// Оновлює збільшене зображення в куті
    private func updateZoomImage() {
        guard let rect = objectRect, let baseImage = baseImage, !zoomImageView.bounds.isEmpty else {
            zoomImageView.isHidden = true
            return
        }
        
        // Вирізаємо область об'єкта з зображення
        let imageSize = baseImage.size
        let cropRect = CGRect(
            x: max(0, rect.origin.x - rect.width * 0.2), // Додаємо відступ
            y: max(0, rect.origin.y - rect.height * 0.2),
            width: min(imageSize.width - rect.origin.x, rect.width * 1.4),
            height: min(imageSize.height - rect.origin.y, rect.height * 1.4)
        )
        
        guard let cgImage = baseImage.cgImage?.cropping(to: cropRect) else {
            zoomImageView.isHidden = true
            return
        }
        
        let croppedImage = UIImage(cgImage: cgImage, scale: baseImage.scale, orientation: baseImage.imageOrientation)
        zoomImageView.image = croppedImage
        zoomImageView.isHidden = false
        
        // Додаємо білий контур навколо збільшеного зображення
        zoomImageView.layer.borderWidth = 2
        zoomImageView.layer.borderColor = UIColor.white.cgColor
        
        // Переконаємося, що збільшене зображення поверх всього
        bringSubviewToFront(zoomImageView)
    }
    
    // MARK: - Mask Generation
    
    /// Створює бінарну маску (чорне/біле) для API
    /// Білий = область для заміни, Чорний = область, яку не замінюємо
    private func generateMaskImage() -> UIImage? {
        guard let image = baseImage, !canvasView.bounds.isEmpty else { return nil }
        guard !canvasView.drawing.bounds.isEmpty else { return nil }
        
        let imageSize = image.size
        let canvasBounds = canvasView.bounds
        let scale = imageSize.width / canvasBounds.width
        
        if maskGenerationMode == .boundingRect {
            let renderer = UIGraphicsImageRenderer(size: imageSize)
            let rectImage = renderer.image { ctx in
                UIColor.black.setFill()
                ctx.fill(CGRect(origin: .zero, size: imageSize))
                
                var expandedRect = canvasView.drawing.bounds.insetBy(dx: -8, dy: -8)
                expandedRect = expandedRect.intersection(canvasBounds)
                
                let scaledRect = CGRect(
                    x: expandedRect.origin.x * scale,
                    y: expandedRect.origin.y * scale,
                    width: expandedRect.width * scale,
                    height: expandedRect.height * scale
                )
                
                UIColor.white.setFill()
                ctx.fill(scaledRect)
            }
            return rectImage
        } else {
            let fullDrawingImage = canvasView.drawing.image(from: canvasBounds, scale: scale)
            guard let drawingCGImage = fullDrawingImage.cgImage else { return nil }
            guard let drawingGrayImage = convertToGrayscale(drawingCGImage) else { return nil }
            let binaryDrawingImg = binarizeGrayscaleImage(drawingGrayImage, threshold: 10) ?? drawingGrayImage
            return UIImage(cgImage: binaryDrawingImg, scale: UIScreen.main.scale, orientation: .up)
        }
    }
    
    /// Конвертує CGImage в grayscale для бінарної маски
    private func convertToGrayscale(_ image: CGImage) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: nil,
            width: image.width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: image.width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }

    /// Бінаризує grayscale зображення для чіткої маски
    private func binarizeGrayscaleImage(_ image: CGImage, threshold: UInt8) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let width = image.width
        let height = image.height
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return nil }
        
        let buffer = data.bindMemory(to: UInt8.self, capacity: width * height)
        let count = width * height
        for idx in 0..<count {
            buffer[idx] = buffer[idx] >= threshold ? 255 : 0
        }
        
        return context.makeImage()
    }
}

// MARK: - PKCanvasViewDelegate
extension DrawingCanvasView: PKCanvasViewDelegate {
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        print("✅ Drawing changed! bounds: \(canvasView.drawing.bounds), canvas bounds: \(canvasView.bounds)")
        // Не викликаємо updateOverlay() тут, бо overlay вимкнений
        // updateOverlay() викликається тільки при зміні layout
        NotificationCenter.default.post(name: NSNotification.Name("DrawingChanged"), object: nil)
    }
    
    func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
        print("✅ Started drawing with tool width: \(canvasView.tool)")
        // Переконаємося, що tool має правильний розмір
        if let inkingTool = canvasView.tool as? PKInkingTool {
            print("   Current tool width: \(inkingTool.width)")
        }
    }
    
    func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
        print("✅ Ended drawing")
        // Оновлюємо маску після завершення малювання
        NotificationCenter.default.post(name: NSNotification.Name("DrawingChanged"), object: nil)
    }
}

