import UIKit
import CoreImage

/// Shared shell of R3 Paint / R4 Replace / R5 Remove: photo canvas, glass nav, hint, bottom panel.
/// The editor only prepares a prompt + mask; R1 runs the generation (compact loader) and adds the version.
class MaskEditorViewController: UIViewController {

    @IBOutlet weak var canvasView: MaskCanvasView!
    @IBOutlet weak var originalOverlayView: UIImageView!
    @IBOutlet weak var closeButton: DSPressableControl!
    @IBOutlet weak var navTitleLabel: UILabel!
    @IBOutlet weak var hintView: UIView!
    @IBOutlet weak var hintIconView: UIImageView!
    @IBOutlet weak var hintLabel: UILabel!
    @IBOutlet weak var panelView: UIView!
    @IBOutlet weak var panelStack: UIStackView!
    @IBOutlet weak var panelTitleLabel: UILabel!
    @IBOutlet weak var panelSubtitleLabel: UILabel!
    @IBOutlet weak var applyButton: DSPrimaryButton!
    @IBOutlet weak var applyLabel: UILabel!
    @IBOutlet weak var compareButton: DSPressableControl?

    /// Current version image (edits start from it) and the project's original (for compare).
    var image: UIImage!
    var originalImage: UIImage?
    /// Called with a ready prompt manager and a short note for the version subtitle.
    var onApply: ((GemeniPromptManager, String) -> Void)?

    var hasChanges: Bool { canvasView.hasMask }

    static func make(image: UIImage, original: UIImage?, onApply: @escaping (GemeniPromptManager, String) -> Void) -> Self {
        let vc = AppStoryboard.instantiate(Self.self)
        vc.image = image
        vc.originalImage = original
        vc.onApply = onApply
        vc.modalPresentationStyle = .fullScreen
        vc.modalTransitionStyle = .crossDissolve
        return vc
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        dsApplyWideColumn(fullWidth: usesFullWidthWhenWide && dsWantsWideLandscape)
    }

    /// Editors with their own two-pane layout on the unfolded Duo (Paint) skip the reading column.
    var usesFullWidthWhenWide: Bool { false }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Long translations must wrap inside the window. An unbounded, self-sizing hint with
        // safe-area-relative stack margins can otherwise enter a layout feedback loop on Duo.
        hintLabel.numberOfLines = 0
        hintLabel.adjustsFontSizeToFitWidth = false
        hintView.insetsLayoutMarginsFromSafeArea = false
        hintView.subviews.compactMap { $0 as? UIStackView }.forEach { $0.insetsLayoutMarginsFromSafeArea = false }
        hintLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        hintView.constraints.first { $0.firstAttribute == .height && $0.secondItem == nil }?.priority = UILayoutPriority(740)
        canvasView.image = image
        originalOverlayView.image = originalImage
        canvasView.onChange = { [weak self] in self?.updateApplyState() }
        if let compareButton {
            let hold = UILongPressGestureRecognizer(target: self, action: #selector(handleCompare(_:)))
            hold.minimumPressDuration = 0
            compareButton.addGestureRecognizer(hold)
        }
        updateDurationLabel()
        panelView.transform = DS.Motion.reduceMotion ? .identity : CGAffineTransform(translationX: 0, y: 320)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if DS.Motion.reduceMotion {
            panelView.transform = .identity
        } else {
            let spring = DS.Motion.gentleSpring(duration: 0.5)
            spring.addAnimations { self.panelView.transform = .identity }
            spring.startAnimation()
        }
        DS.Motion.enter(hintView, delay: 0.9, dy: 8)
    }

    /// Localized action; the button shows its estimated duration in every plan.
    var applyTitle: String { "Apply".localized }

    private func updateDurationLabel() {
        applyLabel.text = applyTitle + " · " + String(format: "About %d s".localized, 30)
    }

    func updateApplyState() {
        let ready = isReadyToApply
        applyButton.inactive = !ready
        applyButton.isUserInteractionEnabled = ready
    }

    var isReadyToApply: Bool { canvasView.hasMask }

    func showHint(_ text: String, symbol: String) {
        hintLabel.text = text
        hintIconView.image = UIImage(systemName: symbol)
    }

    @objc private func handleCompare(_ g: UILongPressGestureRecognizer) {
        guard originalImage != nil else { return }
        switch g.state {
        case .began: UIView.animate(withDuration: 0.2) { self.originalOverlayView.alpha = 1 }
        case .ended, .cancelled, .failed: UIView.animate(withDuration: 0.2) { self.originalOverlayView.alpha = 0 }
        default: break
        }
    }

    @IBAction func didTapClose(_ sender: Any) {
        guard hasChanges else {
            dismiss(animated: true)
            return
        }
        DSAlertViewController.show(from: self, title: "Discard changes?".localized, message: discardMessage, actions: [
            .init(title: "Keep editing".localized, style: .cancel),
            .init(title: "Discard".localized, style: .destructive) { [weak self] in self?.dismiss(animated: true) }
        ])
    }

    /// A/12 Discard edits alert body; Paint says what exactly is lost.
    var discardMessage: String { "Your edits will be lost. This doesn't use a credit.".localized }

    /// Builds the prompt; subclasses override.
    func makePromptManager() -> (GemeniPromptManager, String)? { nil }

    @IBAction func didTapApply(_ sender: Any) {
        guard isReadyToApply, let (manager, note) = makePromptManager() else {
            DS.Haptic.warning()
            return
        }
        DS.Haptic.medium()
        let onApply = self.onApply
        dismiss(animated: true) { onApply?(manager, note) }
    }

    /// Masked edit on the canvas photo (sizes match the mask).
    func maskedManager(option: DesignOption, replaceMode: GemeniPromptManager.ReplaceMode,
                       objectDescription: String?, dilate: CGFloat = 0) -> GemeniPromptManager? {
        guard let base = canvasView.baseImageForMask, var mask = canvasView.maskImage else { return nil }
        if dilate > 0, let grown = Self.dilate(mask, by: dilate) { mask = grown }
        let manager = GemeniPromptManager()
        manager.updateOption(option)
        manager.updateBaseImage(base)
        manager.updateReplaceMode(replaceMode)
        if let objectDescription { manager.updateObjectToReplace(objectDescription) }
        manager.updateMask(mask)
        return manager
    }

    /// Grows the white area of a mask (used when "Keep size & position" is off).
    static func dilate(_ mask: UIImage, by radius: CGFloat) -> UIImage? {
        guard let ci = CIImage(image: mask) else { return nil }
        let grown = ci.applyingFilter("CIMorphologyMaximum", parameters: [kCIInputRadiusKey: radius]).cropped(to: ci.extent)
        let context = CIContext()
        guard let cg = context.createCGImage(grown, from: ci.extent, format: .L8, colorSpace: CGColorSpaceCreateDeviceGray()) else {
            return nil
        }
        return UIImage(cgImage: cg, scale: 1, orientation: .up)
    }
}
