import UIKit
import CoreImage

/// A/06 · R3 Paint walls. Auto: the AI finds and repaints the walls. Brush: paint the walls yourself and see a live
/// on-device preview (colour × photo, multiply) before applying. Layout: Editors.storyboard.
final class PaintEditorViewController: MaskEditorViewController {

    override var discardMessage: String { "Your paint preview will be lost. This doesn't use a credit.".localized }

    @IBOutlet private weak var modeView: UIView!
    @IBOutlet private weak var modeKnob: UIView!
    @IBOutlet private weak var modeKnobLeading: NSLayoutConstraint!
    @IBOutlet private var modeControls: [DSPressableControl]!
    @IBOutlet private var modeLabels: [UILabel]!
    @IBOutlet private var paletteChips: [DSChipControl]!
    @IBOutlet private var swatchControls: [DSPressableControl]!
    @IBOutlet private var swatchColorViews: [UIView]!
    @IBOutlet private weak var brushSizeRow: UIStackView!
    @IBOutlet private weak var sizeTitleLabel: UILabel!
    @IBOutlet private weak var sizeSlider: UISlider!

    struct Paint {
        let name: String
        let hex: String
        var color: UIColor {
            var v: UInt64 = 0
            Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&v)
            return UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
                           blue: CGFloat(v & 0xFF) / 255, alpha: 1)
        }
    }

    /// Palette chips → swatches (could come from remote config later).
    private static let palettes: [[Paint]] = [
        [Paint(name: "Sage Mist", hex: "#A9B59A"), Paint(name: "Warm Linen", hex: "#E6DCCB"), Paint(name: "Clay", hex: "#C98F72"),
         Paint(name: "Terracotta", hex: "#B9572E"), Paint(name: "Olive Grove", hex: "#6E7451"), Paint(name: "Fog Blue", hex: "#9FB2BF"),
         Paint(name: "Ink", hex: "#3A3D40"), Paint(name: "Ivory", hex: "#F3EEE3")],
        [Paint(name: "Chalk White", hex: "#F4F1EA"), Paint(name: "Greige", hex: "#CFC6B8"), Paint(name: "Mushroom", hex: "#B5A897"),
         Paint(name: "Stone", hex: "#9E978C"), Paint(name: "Taupe", hex: "#8B7D6F"), Paint(name: "Pebble", hex: "#C9C5BD")],
        [Paint(name: "Sage Mist", hex: "#A9B59A"), Paint(name: "Eucalyptus", hex: "#8FA38A"), Paint(name: "Olive Grove", hex: "#6E7451"),
         Paint(name: "Forest", hex: "#3F5245"), Paint(name: "Mint Cream", hex: "#DDE8D8"), Paint(name: "Moss", hex: "#7A8250")],
        [Paint(name: "Clay", hex: "#C98F72"), Paint(name: "Terracotta", hex: "#B9572E"), Paint(name: "Blush", hex: "#E3C2B4"),
         Paint(name: "Ochre", hex: "#C9993F"), Paint(name: "Sand", hex: "#DCC7A1"), Paint(name: "Rust", hex: "#9C4A2C")],
        [Paint(name: "Fog Blue", hex: "#9FB2BF"), Paint(name: "Sky", hex: "#C6D7E2"), Paint(name: "Denim", hex: "#58718A"),
         Paint(name: "Navy", hex: "#2E3D52"), Paint(name: "Teal", hex: "#3E6E6F"), Paint(name: "Powder", hex: "#DDE6EC")],
        [Paint(name: "Ink", hex: "#3A3D40"), Paint(name: "Charcoal", hex: "#4A4A4A"), Paint(name: "Espresso", hex: "#4B3A30"),
         Paint(name: "Midnight", hex: "#262E3B"), Paint(name: "Aubergine", hex: "#4A3340"), Paint(name: "Bottle Green", hex: "#2F4237")]
    ]

    private var palette = 0
    private var paint: Paint?
    private var isBrush = false
    private var breathing = false

    override var applyTitle: String { "Apply".localized }
    override var isReadyToApply: Bool { paint != nil && (!isBrush || canvasView.hasMask) }
    override var hasChanges: Bool { paint != nil || canvasView.hasMask }

    override func viewDidLoad() {
        super.viewDidLoad()
        navTitleLabel.text = ""
        panelTitleLabel.text = "Paint walls".localized
        sizeTitleLabel.text = "Size".localized
        sizeSlider.minimumTrackTintColor = DS.Color.lime
        let modes = ["Auto", "Brush"]
        modeLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = modes[$0].localized }
        let chips = ["Trending", "Neutrals", "Greens", "Warm", "Blues", "Darks"]
        paletteChips.sorted { $0.tag < $1.tag }.enumerated().forEach { index, chip in
            chip.subviews.first?.subviews.compactMap { $0 as? UILabel }.first?.text = chips[index].localized
        }
        canvasView.tool = .none
        canvasView.maskColor = DS.Color.lime.withAlphaComponent(0.4)
        canvasView.onChange = { [weak self] in
            self?.updatePreview()
            self?.updateApplyState()
        }
        applyMode()
        reloadSwatches()
        updateApplyState()
    }

    /// Chip and swatch rows bleed to the screen edge on a phone; in the split they stop at the panel column.
    @IBOutlet private var bleedScrollViews: [UIScrollView]!

    override func didChangeSplit(_ split: Bool) {
        super.didChangeSplit(split)
        bleedScrollViews.forEach { $0.clipsToBounds = split }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applySegment(index: isBrush ? 1 : 0, labels: modeLabels, knobLeading: modeKnobLeading, container: modeView,
                     count: 2, animated: false)
    }

    @IBAction private func didTapMode(_ sender: UIControl) {
        let brush = sender.tag == 1
        guard brush != isBrush else { return }
        isBrush = brush
        DS.Haptic.selection()
        applySegment(index: isBrush ? 1 : 0, labels: modeLabels, knobLeading: modeKnobLeading, container: modeView,
                     count: 2, animated: true)
        applyMode()
    }

    private func applyMode() {
        brushSizeRow.isHidden = !isBrush
        canvasView.tool = isBrush ? .brush : .none
        if isBrush {
            panelSubtitleLabel.text = "Paint over the walls to recolour".localized
            showHint("Live preview · hold compare to see original".localized, symbol: "eye")
        } else {
            panelSubtitleLabel.text = "AI finds your walls when you apply".localized
            showHint("Pick a colour — AI repaints every wall".localized, symbol: "sparkles")
            canvasView.clear()
        }
        updatePreview()
        updateApplyState()
    }

    @IBAction private func didChangeSize(_ sender: UISlider) {
        canvasView.brushSize = CGFloat(sender.value)
    }

    @IBAction private func didTapPalette(_ sender: UIControl) {
        palette = sender.tag
        DS.Haptic.selection()
        paletteChips.forEach { $0.setChipSelected($0.tag == palette, animated: true) }
        reloadSwatches()
    }

    private func reloadSwatches() {
        let paints = Self.palettes[palette]
        let colors = swatchColorViews.sorted { $0.tag < $1.tag }
        for (i, control) in swatchControls.sorted(by: { $0.tag < $1.tag }).enumerated() {
            control.isHidden = i >= paints.count
            guard i < paints.count else { continue }
            colors[i].backgroundColor = paints[i].color
            control.accessibilityLabel = paints[i].name
            let selected = paint?.hex == paints[i].hex
            control.layer.borderWidth = selected ? 2 : 0
            control.layer.borderColor = DS.Color.textPrimary.resolvedColor(with: traitCollection).cgColor
            control.accessibilityTraits = selected ? [.button, .selected] : .button
        }
        paletteChips.forEach { $0.setChipSelected($0.tag == palette, animated: false) }
    }

    @IBAction private func didTapSwatch(_ sender: UIControl) {
        let paints = Self.palettes[palette]
        guard sender.tag < paints.count else { return }
        paint = paints[sender.tag]
        DS.Haptic.selection()
        reloadSwatches()
        panelSubtitleLabel.text = isBrush
            ? String(format: "%@ · paint over the walls".localized, paint!.name)
            : String(format: "%@ · AI repaints every wall".localized, paint!.name)
        updatePreview()
        updateApplyState()
        if isReadyToApply { applyButton.runShimmer(delay: 0.3) }
    }

    /// Brush mode: colour × photo (multiply, 88 %) inside the mask — on-device, free.
    private func updatePreview() {
        guard isBrush, let paint, let base = canvasView.baseImageForMask, let mask = canvasView.maskImage,
              let ciBase = CIImage(image: base), let ciMask = CIImage(image: mask) else {
            UIView.transition(with: canvasView.previewImageView, duration: 0.2, options: .transitionCrossDissolve) {
                self.canvasView.previewImageView.image = nil
            }
            canvasView.maskColor = DS.Color.lime.withAlphaComponent(isBrush ? 0.6 : 0.4)
            return
        }
        let color = CIImage(color: CIColor(color: paint.color)).cropped(to: ciBase.extent)
        let gray = ciBase.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0,
                                                                          kCIInputBrightnessKey: 0.08])
        let multiplied = color.applyingFilter("CIMultiplyBlendMode", parameters: [kCIInputBackgroundImageKey: gray])
        let tinted = multiplied.applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.88)])
            .composited(over: ciBase)
        let blended = tinted.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: ciBase,
                                                                           kCIInputMaskImageKey: ciMask])
        guard let cg = CIContext().createCGImage(blended, from: ciBase.extent) else { return }
        canvasView.maskColor = .clear
        UIView.transition(with: canvasView.previewImageView, duration: 0.3, options: .transitionCrossDissolve) {
            self.canvasView.previewImageView.image = UIImage(cgImage: cg)
        }
    }

    override func makePromptManager() -> (GemeniPromptManager, String)? {
        guard let paint else { return nil }
        let note = String(format: "%@ walls".localized, paint.name)
        let colorText = "\(paint.name) (\(paint.hex)) matte paint"
        if isBrush {
            let description = "the same wall surface repainted in \(colorText); keep the wall texture, trims, outlets, artwork position, lighting and shadows"
            guard let manager = maskedManager(option: .replace, replaceMode: .replace, objectDescription: description,
                                              dilate: 2) else { return nil }
            return (manager, note)
        }
        let manager = GemeniPromptManager()
        manager.updateOption(.newWalls)
        manager.updateBaseImage(image)
        manager.updateSurfaceCustomPrompt(colorText)
        return (manager, note)
    }
}
