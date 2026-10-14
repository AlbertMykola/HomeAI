import UIKit

/// A/06 · R5 Remove: brush / lasso / tap object, size slider, undo / redo, clear. Layout: RemoveEditorViewController.xib.
final class RemoveEditorViewController: MaskEditorViewController {

    @IBOutlet private weak var undoButton: DSPressableControl!
    @IBOutlet private weak var redoButton: DSPressableControl!
    @IBOutlet private weak var modeView: UIView!
    @IBOutlet private weak var modeKnob: UIView!
    @IBOutlet private weak var modeKnobLeading: NSLayoutConstraint!
    @IBOutlet private var modeControls: [DSPressableControl]!
    @IBOutlet private var modeLabels: [UILabel]!
    @IBOutlet private weak var brushSizeRow: UIStackView!
    @IBOutlet private weak var sizeTitleLabel: UILabel!
    @IBOutlet private weak var sizeSlider: UISlider!
    @IBOutlet private weak var clearButton: DSPressableControl!

    private var mode = 0
    private var objects: [ObjectDetector.Object] = []
    private var hotspots: [UIView] = []

    override var applyTitle: String { "Remove".localized }

    override func viewDidLoad() {
        super.viewDidLoad()
        navTitleLabel.text = "Remove".localized
        panelTitleLabel.text = "Remove".localized
        panelSubtitleLabel.text = "Brush over anything you want gone".localized
        sizeTitleLabel.text = "Size".localized
        (clearButton.subviews.first?.subviews.compactMap { $0 as? UILabel }.first)?.text = "Clear".localized
        let titles = ["Brush", "Lasso", "Tap object"]
        modeLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = titles[$0].localized }
        sizeSlider.minimumTrackTintColor = DS.Color.lime
        showHint("Pinch to zoom · two fingers to move".localized, symbol: "paintbrush.pointed")
        canvasView.onChange = { [weak self] in
            self?.updateApplyState()
            self?.updateUndo()
        }
        canvasView.onTapImagePoint = { [weak self] point in self?.pickObject(at: point) }
        updateApplyState()
        updateUndo()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applySegment(index: mode, labels: modeLabels, knobLeading: modeKnobLeading, container: modeView, count: 3,
                     animated: false)
    }

    private func updateUndo() {
        undoButton.alpha = canvasView.canUndo ? 1 : 0.4
        redoButton.alpha = canvasView.canRedo ? 1 : 0.4
    }

    @IBAction private func didTapMode(_ sender: UIControl) {
        mode = sender.tag
        DS.Haptic.selection()
        applySegment(index: mode, labels: modeLabels, knobLeading: modeKnobLeading, container: modeView, count: 3, animated: true)
        brushSizeRow.isHidden = mode != 0
        switch mode {
        case 0:
            canvasView.tool = .brush
            showHint("Pinch to zoom · two fingers to move".localized, symbol: "paintbrush.pointed")
            removeHotspots()
        case 1:
            canvasView.tool = .lasso
            showHint("Draw a loop around the object".localized, symbol: "lasso")
            removeHotspots()
        default:
            canvasView.tool = .none
            showHint("Tap any dot to pick an object".localized, symbol: "hand.raised")
            detectObjects()
        }
    }

    @IBAction private func didChangeSize(_ sender: UISlider) {
        canvasView.brushSize = CGFloat(sender.value)
    }

    @IBAction private func didTapUndo(_ sender: Any) { canvasView.undo() }
    @IBAction private func didTapRedo(_ sender: Any) { canvasView.redo() }
    @IBAction private func didTapClear(_ sender: Any) { canvasView.clear() }

    // MARK: Tap object

    private func detectObjects() {
        guard ObjectDetector.isAvailable, let base = canvasView.baseImageForMask else {
            DSToastView.show("Object picking needs iOS 17 — use Brush instead".localized, style: .info, symbol: "info.circle")
            return
        }
        if !objects.isEmpty {
            showHotspots()
            return
        }
        ObjectDetector.detect(in: base) { [weak self] found in
            self?.objects = found
            if found.isEmpty {
                DSToastView.show("No objects found — use Brush instead".localized, style: .info, symbol: "info.circle")
            }
            self?.showHotspots()
        }
    }

    private func showHotspots() {
        removeHotspots()
        hotspots = objects.enumerated().map { index, object in
            let dot = HotspotDot.make(at: canvasView.imagePointToDecoration(object.center))
            canvasView.decorationView.addSubview(dot)
            DS.Motion.enter(dot, delay: Double(index) * 0.06, scale: 0.3, duration: 0.35, pop: true)
            return dot
        }
    }

    private func removeHotspots() {
        hotspots.forEach { $0.removeFromSuperview() }
        hotspots.removeAll()
    }

    private func pickObject(at point: CGPoint) {
        guard let object = ObjectDetector.object(at: point, in: objects) else {
            DSToastView.show("Nothing to select here".localized, style: .info, symbol: "hand.raised")
            return
        }
        DS.Haptic.selection()
        canvasView.setObjectMask(object.mask, replace: false)
    }

    override func makePromptManager() -> (GemeniPromptManager, String)? {
        guard let manager = maskedManager(option: .delete, replaceMode: .remove, objectDescription: nil, dilate: 6) else {
            return nil
        }
        return (manager, "Object removed".localized)
    }
}

/// White pulsing dot marking a detected object.
enum HotspotDot {
    static func make(at center: CGPoint) -> UIView {
        let dot = UIView(frame: CGRect(x: center.x - 8, y: center.y - 8, width: 16, height: 16))
        dot.backgroundColor = UIColor.white.withAlphaComponent(0.95)
        dot.layer.cornerRadius = 8
        dot.layer.borderWidth = 3
        dot.layer.borderColor = UIColor.black.withAlphaComponent(0.15).cgColor
        dot.layer.shadowOpacity = 0.3
        dot.layer.shadowRadius = 4
        dot.layer.shadowOffset = CGSize(width: 0, height: 2)
        dot.isUserInteractionEnabled = false
        if !DS.Motion.reduceMotion {
            let pulse = CABasicAnimation(keyPath: "transform.scale")
            pulse.fromValue = 1
            pulse.toValue = 1.25
            pulse.duration = 0.8
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            pulse.timeOffset = .random(in: 0...1.6)
            dot.layer.add(pulse, forKey: "pulse")
        }
        return dot
    }
}
