import UIKit

/// A/06 · R4 Replace: tap a detected object (or paint over it), describe the replacement, keep size & position.
/// Layout: ReplaceEditorViewController.xib.
final class ReplaceEditorViewController: MaskEditorViewController {

    @IBOutlet private weak var suggestionScrollView: UIScrollView!
    @IBOutlet private var suggestionChips: [DSChipControl]!
    @IBOutlet private weak var promptView: UIView!
    @IBOutlet private weak var promptField: UITextField!
    @IBOutlet private weak var micButton: DSPressableControl!
    @IBOutlet private weak var keepTitleLabel: UILabel!
    @IBOutlet private weak var keepSubtitleLabel: UILabel!
    @IBOutlet private weak var keepSwitch: UISwitch!
    @IBOutlet private weak var brushFallbackButton: UIButton!

    private var objects: [ObjectDetector.Object] = []
    private var hotspots: [UIView] = []
    private var selection: UIView?
    private var selectedLabel: String?
    private let speech = SpeechInput()

    private static let suggestions: [String: [String]] = [
        "table": ["Travertine block", "Round marble", "Oak low table", "Nesting set", "Glass & brass"],
        "sofa": ["Bouclé sofa", "Leather chesterfield", "Modular sectional", "Linen loveseat", "Velvet curved sofa"],
        "chair": ["Rattan armchair", "Wingback chair", "Bouclé accent chair", "Eames lounge", "Oak dining chair"],
        "lamp": ["Paper globe lamp", "Brass arc lamp", "Ceramic table lamp", "Tripod floor lamp", "Mushroom lamp"],
        "plant": ["Olive tree", "Fiddle leaf fig", "Monstera", "Snake plant", "Bird of paradise"],
        "bed": ["Upholstered bed", "Oak platform bed", "Canopy bed", "Rattan headboard", "Linen bedding"],
        "default": ["Modern version", "Vintage piece", "Natural wood", "Matte black", "Something cozier"]
    ]

    override var applyTitle: String { "Replace".localized }
    override var isReadyToApply: Bool {
        canvasView.hasMask && !(promptField.text ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navTitleLabel.text = "Replace".localized
        panelTitleLabel.text = "Replace".localized
        panelSubtitleLabel.text = "Tap an object on the photo".localized
        keepTitleLabel.text = "Keep size & position".localized
        keepSubtitleLabel.text = "Matches perspective, light and shadows".localized
        brushFallbackButton.setTitle("Can't find it? Paint over the object".localized, for: .normal)
        promptField.placeholder = "Describe the new object".localized
        promptField.delegate = self
        promptField.addTarget(self, action: #selector(promptChanged), for: .editingChanged)
        canvasView.tool = .none
        canvasView.onTapImagePoint = { [weak self] point in self?.pick(at: point) }
        fillSuggestions(for: nil)
        showHint("Tap any dot to pick an object".localized, symbol: "hand.raised")
        updateApplyState()
        detect()
    }

    @objc private func promptChanged() { updateApplyState() }

    private func detect() {
        guard ObjectDetector.isAvailable, let base = canvasView.baseImageForMask else {
            enableBrushFallback()
            return
        }
        ObjectDetector.detect(in: base) { [weak self] found in
            guard let self else { return }
            self.objects = found
            if found.isEmpty {
                self.enableBrushFallback()
                return
            }
            self.brushFallbackButton.isHidden = false
            self.hotspots = found.enumerated().map { index, object in
                let dot = HotspotDot.make(at: self.canvasView.imagePointToDecoration(object.center))
                self.canvasView.decorationView.addSubview(dot)
                DS.Motion.enter(dot, delay: Double(index) * 0.06, scale: 0.3, duration: 0.35, pop: true)
                return dot
            }
        }
    }

    private func enableBrushFallback() {
        canvasView.tool = .brush
        brushFallbackButton.isHidden = true
        showHint("Paint over the object to replace".localized, symbol: "paintbrush.pointed")
        panelSubtitleLabel.text = "Paint over the object to replace".localized
    }

    @IBAction private func didTapBrushFallback(_ sender: Any) {
        selection?.removeFromSuperview()
        hotspots.forEach { $0.removeFromSuperview() }
        canvasView.clear()
        enableBrushFallback()
    }

    private func pick(at point: CGPoint) {
        guard let object = ObjectDetector.object(at: point, in: objects) else {
            DSToastView.show("Nothing to select here".localized, style: .info, symbol: "hand.raised")
            return
        }
        DS.Haptic.selection()
        canvasView.setObjectMask(object.mask, replace: true)
        selectedLabel = object.label
        panelSubtitleLabel.text = String(format: "%@ selected · tap another object to switch".localized, object.label)
        drawSelection(for: object)
        fillSuggestions(for: object.label)
        promptField.becomeFirstResponder()
    }

    private func drawSelection(for object: ObjectDetector.Object) {
        selection?.removeFromSuperview()
        let rect = canvasView.imageRectToDecoration(object.bounds).insetBy(dx: -6, dy: -6)
        let frame = UIView(frame: rect)
        frame.layer.borderColor = DS.Color.lime.cgColor
        frame.layer.borderWidth = 2.5
        frame.layer.cornerRadius = 16
        frame.backgroundColor = DS.Color.lime.withAlphaComponent(0.14)
        frame.isUserInteractionEnabled = false
        let tag = PaddingLabel()
        tag.text = "✓ " + object.label
        tag.font = DS.Font.geologica(.semiBold, 13)
        tag.backgroundColor = DS.Color.lime
        tag.layer.cornerRadius = 14
        tag.clipsToBounds = true
        tag.sizeToFit()
        tag.frame.origin = CGPoint(x: 6, y: -tag.bounds.height - 8)
        frame.addSubview(tag)
        canvasView.decorationView.addSubview(frame)
        selection = frame
        frame.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
        frame.alpha = 0
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0) {
            frame.transform = .identity
            frame.alpha = 1
        }
    }

    private func fillSuggestions(for label: String?) {
        let key = label.flatMap { l in Self.suggestions.keys.first { l.lowercased().contains($0) } } ?? "default"
        let list = Self.suggestions[key] ?? Self.suggestions["default"]!
        suggestionChips.sorted { $0.tag < $1.tag }.enumerated().forEach { index, chip in
            chip.subviews.first?.subviews.compactMap { $0 as? UILabel }.first?.text = list[index].localized
            chip.setChipSelected(false, animated: false)
        }
    }

    @IBAction private func didTapSuggestion(_ sender: UIControl) {
        guard let chip = sender as? DSChipControl else { return }
        DS.Haptic.selection()
        suggestionChips.forEach { $0.setChipSelected($0 === chip, animated: true) }
        promptField.text = chip.subviews.first?.subviews.compactMap { $0 as? UILabel }.first?.text
        updateApplyState()
    }

    @IBAction private func didTapMic(_ sender: Any) {
        speech.requestAccess { [weak self] granted in
            guard let self, granted else {
                DSToastView.show("Allow microphone & speech access to talk".localized, style: .warning, symbol: "mic.slash")
                return
            }
            DS.Haptic.medium()
            self.speech.onText = { [weak self] text in
                self?.promptField.text = text
                self?.updateApplyState()
            }
            self.speech.onSilenceTimeout = { [weak self] in
                self?.speech.stop()
                self?.micButton.backgroundColor = DS.Color.card
            }
            self.micButton.backgroundColor = DS.Color.limeSoft
            try? self.speech.start()
        }
    }

    override func makePromptManager() -> (GemeniPromptManager, String)? {
        let text = (promptField.text ?? "").trimmingCharacters(in: .whitespaces)
        guard let manager = maskedManager(option: .replace, replaceMode: .replace, objectDescription: text,
                                          dilate: keepSwitch.isOn ? 4 : 40) else { return nil }
        return (manager, String(format: "Replaced with %@".localized, text))
    }
}

extension ReplaceEditorViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

/// Small pill label with horizontal padding (selection tags on photos).
final class PaddingLabel: UILabel {
    var insets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
    override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: insets)) }
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + insets.left + insets.right, height: s.height + insets.top + insets.bottom)
    }
    override func sizeThatFits(_ size: CGSize) -> CGSize { intrinsicContentSize }
}
