import UIKit

/// Photo + editable mask for R3 Paint (brush), R4 Replace and R5 Remove.
/// One finger draws (brush / lasso); two fingers zoom and pan. The mask is kept in image pixels
/// (white = edit), ready for `GemeniPromptManager.updateMask`.
final class MaskCanvasView: UIView {

    enum Tool { case brush, erase, lasso, none }

    private enum Op {
        case stroke(points: [CGPoint], width: CGFloat, erase: Bool)
        case lasso(points: [CGPoint])
        case objectMask(CGImage)
        case clear
    }

    // MARK: Public

    var image: UIImage? {
        didSet {
            imageView.image = image
            resetMask()
            setNeedsLayout()
        }
    }
    var tool: Tool = .brush
    /// Brush diameter in points on screen (12–48).
    var brushSize: CGFloat = 28
    var maskColor: UIColor = DS.Color.lime.withAlphaComponent(0.6) { didSet { renderOverlay() } }
    var onChange: (() -> Void)?
    /// Taps when `tool == .none` (object hotspots / wall picking), in image pixel coordinates.
    var onTapImagePoint: ((CGPoint) -> Void)?

    var hasMask: Bool { !ops.filter { if case .clear = $0 { return false }; return true }.isEmpty && maskHasPixels }
    var canUndo: Bool { !ops.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    /// Binary mask at image pixel size (white = edit area).
    var maskImage: UIImage? {
        guard let ctx = maskContext, let cg = ctx.makeImage(), hasMask else { return nil }
        return UIImage(cgImage: cg, scale: 1, orientation: .up)
    }

    /// Lets the hosting screen draw extra overlays (selection frames, hotspots) aligned with the photo.
    let decorationView = UIView()
    /// Optional live preview layer (Paint) above the photo, under the mask overlay.
    let previewImageView = UIImageView()

    // MARK: Private

    private let contentView = UIView()
    private let imageView = UIImageView()
    private let overlayView = UIImageView()
    private let liveStroke = CAShapeLayer()
    private let cursor = CAShapeLayer()
    private var maskContext: CGContext?
    private var pixelSize: CGSize = .zero
    private var ops: [Op] = []
    private var redoStack: [Op] = []
    private var currentPoints: [CGPoint] = []
    private var maskHasPixels = false
    private var zoom: CGFloat = 1
    private var panOffset: CGPoint = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        clipsToBounds = true
        backgroundColor = .black
        addSubview(contentView)
        [imageView, previewImageView, overlayView, decorationView].forEach {
            $0.isUserInteractionEnabled = false
            contentView.addSubview($0)
        }
        imageView.contentMode = .scaleAspectFill
        for v in [imageView, previewImageView, overlayView] {
            v.setContentHuggingPriority(.init(1), for: .vertical)
            v.setContentCompressionResistancePriority(.init(1), for: .vertical)
        }
        previewImageView.contentMode = .scaleAspectFill
        overlayView.contentMode = .scaleAspectFill
        decorationView.isUserInteractionEnabled = true
        liveStroke.fillColor = UIColor.clear.cgColor
        liveStroke.lineCap = .round
        liveStroke.lineJoin = .round
        contentView.layer.addSublayer(liveStroke)
        cursor.fillColor = UIColor.clear.cgColor
        cursor.strokeColor = UIColor.white.cgColor
        cursor.lineWidth = 2
        cursor.isHidden = true
        layer.addSublayer(cursor)

        let draw = UIPanGestureRecognizer(target: self, action: #selector(handleDraw(_:)))
        draw.maximumNumberOfTouches = 1
        addGestureRecognizer(draw)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tap)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        let twoFingerPan = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
        twoFingerPan.minimumNumberOfTouches = 2
        pinch.delegate = self
        twoFingerPan.delegate = self
        addGestureRecognizer(pinch)
        addGestureRecognizer(twoFingerPan)
        isAccessibilityElement = true
        accessibilityLabel = "Photo. Draw with one finger to mark the area.".localized
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.bounds = bounds
        contentView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        [imageView, previewImageView, overlayView, decorationView].forEach { $0.frame = contentView.bounds }
        liveStroke.frame = contentView.bounds
        applyTransform()
    }

    // MARK: Geometry (aspect fill)

    /// Rect of the full image inside `contentView` (aspect-fill).
    var imageRectInView: CGRect {
        guard pixelSize.width > 0 else { return contentView.bounds }
        let b = contentView.bounds
        let r = max(b.width / pixelSize.width, b.height / pixelSize.height)
        let size = CGSize(width: pixelSize.width * r, height: pixelSize.height * r)
        return CGRect(x: b.midX - size.width / 2, y: b.midY - size.height / 2, width: size.width, height: size.height)
    }

    private var pointsToPixels: CGFloat {
        let rect = imageRectInView
        return rect.width > 0 ? pixelSize.width / rect.width : 1
    }

    func viewPointToImage(_ p: CGPoint) -> CGPoint {
        let local = convert(p, to: contentView)
        let rect = imageRectInView
        return CGPoint(x: (local.x - rect.minX) * pointsToPixels, y: (local.y - rect.minY) * pointsToPixels)
    }

    /// Image pixel rect → rect in `decorationView` coordinates.
    func imageRectToDecoration(_ r: CGRect) -> CGRect {
        let rect = imageRectInView
        let s = 1 / pointsToPixels
        return CGRect(x: rect.minX + r.minX * s, y: rect.minY + r.minY * s, width: r.width * s, height: r.height * s)
    }

    func imagePointToDecoration(_ p: CGPoint) -> CGPoint {
        let rect = imageRectInView
        let s = 1 / pointsToPixels
        return CGPoint(x: rect.minX + p.x * s, y: rect.minY + p.y * s)
    }

    // MARK: Mask ops

    private func resetMask() {
        guard let cg = image?.cgImage ?? image.flatMap({ $0.downscaled(maxSide: 2048)?.cgImage }) else {
            maskContext = nil
            return
        }
        let maxSide: CGFloat = 1536
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let r = min(1, maxSide / max(w, h))
        pixelSize = CGSize(width: (w * r).rounded(), height: (h * r).rounded())
        maskContext = CGContext(data: nil, width: Int(pixelSize.width), height: Int(pixelSize.height),
                                bitsPerComponent: 8, bytesPerRow: Int(pixelSize.width),
                                space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        ops.removeAll()
        redoStack.removeAll()
        rebuildMask()
    }

    /// The photo at mask resolution (use as the generation base so mask and image sizes match).
    var baseImageForMask: UIImage? {
        guard let image, pixelSize.width > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: pixelSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: pixelSize))
        }
    }

    func clear() {
        ops.append(.clear)
        redoStack.removeAll()
        rebuildMask()
    }

    func undo() {
        guard let last = ops.popLast() else { return }
        redoStack.append(last)
        rebuildMask()
    }

    func redo() {
        guard let op = redoStack.popLast() else { return }
        ops.append(op)
        rebuildMask()
    }

    /// Adds a ready-made mask (object selection). `replace` clears previous marks first.
    func setObjectMask(_ mask: CGImage, replace: Bool) {
        if replace { ops.append(.clear) }
        ops.append(.objectMask(mask))
        redoStack.removeAll()
        rebuildMask()
    }

    private func rebuildMask() {
        guard let ctx = maskContext else { return }
        let full = CGRect(origin: .zero, size: pixelSize)
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(full)
        // CG origin is bottom-left; flip once so ops use top-left image coordinates.
        ctx.saveGState()
        ctx.translateBy(x: 0, y: pixelSize.height)
        ctx.scaleBy(x: 1, y: -1)
        for op in ops {
            switch op {
            case .clear:
                ctx.setFillColor(gray: 0, alpha: 1)
                ctx.fill(full)
            case .stroke(let points, let width, let erase):
                ctx.setStrokeColor(gray: erase ? 0 : 1, alpha: 1)
                ctx.setLineWidth(width)
                ctx.setLineCap(.round)
                ctx.setLineJoin(.round)
                ctx.addLines(between: points.count == 1 ? [points[0], points[0]] : points)
                ctx.strokePath()
            case .lasso(let points):
                guard points.count > 2 else { continue }
                ctx.setFillColor(gray: 1, alpha: 1)
                ctx.addLines(between: points)
                ctx.closePath()
                ctx.fillPath()
            case .objectMask(let mask):
                ctx.saveGState()
                ctx.translateBy(x: 0, y: pixelSize.height)
                ctx.scaleBy(x: 1, y: -1)
                ctx.clip(to: full, mask: mask)
                ctx.setFillColor(gray: 1, alpha: 1)
                ctx.fill(full)
                ctx.restoreGState()
            }
        }
        ctx.restoreGState()
        maskHasPixels = checkPixels(ctx)
        renderOverlay()
        onChange?()
    }

    private func checkPixels(_ ctx: CGContext) -> Bool {
        guard let data = ctx.data else { return false }
        let bytes = data.bindMemory(to: UInt8.self, capacity: ctx.bytesPerRow * ctx.height)
        let step = max(1, (ctx.bytesPerRow * ctx.height) / 40_000)
        for i in stride(from: 0, to: ctx.bytesPerRow * ctx.height, by: step) where bytes[i] > 0 { return true }
        return false
    }

    private func renderOverlay() {
        guard let ctx = maskContext, let mask = ctx.makeImage(), pixelSize.width > 0 else {
            overlayView.image = nil
            return
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        overlayView.image = UIGraphicsImageRenderer(size: pixelSize, format: format).image { r in
            let cg = r.cgContext
            cg.translateBy(x: 0, y: pixelSize.height)
            cg.scaleBy(x: 1, y: -1)
            cg.clip(to: CGRect(origin: .zero, size: pixelSize), mask: mask)
            cg.setFillColor(maskColor.cgColor)
            cg.fill(CGRect(origin: .zero, size: pixelSize))
        }
    }

    // MARK: Gestures

    @objc private func handleDraw(_ g: UIPanGestureRecognizer) {
        guard tool != .none, maskContext != nil else { return }
        let p = g.location(in: self)
        switch g.state {
        case .began:
            currentPoints = [viewPointToImage(p)]
            DS.Haptic.light()
            liveStroke.lineWidth = tool == .lasso ? 2 : brushSize / zoom
            liveStroke.strokeColor = tool == .erase ? UIColor.white.withAlphaComponent(0.6).cgColor : maskColor.cgColor
            liveStroke.fillColor = tool == .lasso ? maskColor.withAlphaComponent(0.25).cgColor : UIColor.clear.cgColor
            liveStroke.lineDashPattern = tool == .lasso ? [6, 4] : nil
            updateCursor(at: p, visible: tool != .lasso)
        case .changed:
            currentPoints.append(viewPointToImage(p))
            updateLiveStroke()
            updateCursor(at: p, visible: tool != .lasso)
        default:
            liveStroke.path = nil
            updateCursor(at: p, visible: false)
            let op: Op = tool == .lasso
                ? .lasso(points: currentPoints)
                : .stroke(points: currentPoints, width: brushSize / zoom * pointsToPixels, erase: tool == .erase)
            ops.append(op)
            redoStack.removeAll()
            currentPoints.removeAll()
            rebuildMask()
        }
    }

    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        let p = viewPointToImage(g.location(in: self))
        if tool == .none {
            onTapImagePoint?(p)
            return
        }
        guard tool == .brush || tool == .erase else { return }
        ops.append(.stroke(points: [p], width: brushSize / zoom * pointsToPixels, erase: tool == .erase))
        redoStack.removeAll()
        rebuildMask()
    }

    private func updateLiveStroke() {
        let rect = imageRectInView
        let s = 1 / pointsToPixels
        let path = UIBezierPath()
        for (i, p) in currentPoints.enumerated() {
            let v = CGPoint(x: rect.minX + p.x * s, y: rect.minY + p.y * s)
            i == 0 ? path.move(to: v) : path.addLine(to: v)
        }
        if tool == .lasso { path.close() }
        liveStroke.path = path.cgPath
    }

    private func updateCursor(at p: CGPoint, visible: Bool) {
        cursor.isHidden = !visible
        let r = brushSize / 2
        cursor.path = UIBezierPath(ovalIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)).cgPath
    }

    @objc private func handlePinch(_ g: UIPinchGestureRecognizer) {
        zoom = min(max(zoom * g.scale, 1), 5)
        g.scale = 1
        if zoom <= 1.01 { panOffset = .zero }
        applyTransform()
    }

    @objc private func handleTwoFingerPan(_ g: UIPanGestureRecognizer) {
        guard zoom > 1.01 else { return }
        let t = g.translation(in: self)
        panOffset.x += t.x
        panOffset.y += t.y
        g.setTranslation(.zero, in: self)
        applyTransform()
    }

    private func applyTransform() {
        let maxX = bounds.width * (zoom - 1) / 2, maxY = bounds.height * (zoom - 1) / 2
        panOffset.x = min(max(panOffset.x, -maxX), maxX)
        panOffset.y = min(max(panOffset.y, -maxY), maxY)
        contentView.transform = CGAffineTransform(translationX: panOffset.x, y: panOffset.y).scaledBy(x: zoom, y: zoom)
    }
}

extension MaskCanvasView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        (g is UIPinchGestureRecognizer || g is UIPanGestureRecognizer) && (other is UIPinchGestureRecognizer || other is UIPanGestureRecognizer)
            && !(g is UIPanGestureRecognizer && (g as! UIPanGestureRecognizer).maximumNumberOfTouches == 1)
    }
}
