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
        let vc = Self(nibName: String(describing: self), bundle: .main)
        vc.image = image
        vc.originalImage = original
        vc.onApply = onApply
        vc.modalPresentationStyle = .fullScreen
        vc.modalTransitionStyle = .crossDissolve
        return vc
    }

    required override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        canvasView.image = image
        originalOverlayView.image = originalImage
        canvasView.onChange = { [weak self] in self?.updateApplyState() }
        if let compareButton {
            let hold = UILongPressGestureRecognizer(target: self, action: #selector(handleCompare(_:)))
            hold.minimumPressDuration = 0
            compareButton.addGestureRecognizer(hold)
        }
        updateCostLabel()
        panelView.transform = CGAffineTransform(translationX: 0, y: 320)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let spring = DS.Motion.gentleSpring(duration: 0.5)
        spring.addAnimations { self.panelView.transform = .identity }
        spring.startAnimation()
        DS.Motion.enter(hintView, delay: 0.9, dy: 8)
    }

    /// Title for the apply button, e.g. "Remove" → "Remove · 1 credit" (Pro: no price).
    var applyTitle: String { "Apply".localized }

    func updateCostLabel() {
        applyLabel.text = AdaptyService.shared.hasActiveSubscription
            ? applyTitle
            : String(format: "%@ · 1 credit".localized, applyTitle)
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
        let alert = UIAlertController(title: "Discard changes?".localized, message: "Your edits won't be saved.".localized,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Keep editing".localized, style: .cancel))
        alert.addAction(UIAlertAction(title: "Discard".localized, style: .destructive) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }

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

    // MARK: Segmented helper

    func applySegment(index: Int, labels: [UILabel], knobLeading: NSLayoutConstraint, container: UIView,
                      count: Int, animated: Bool) {
        let width = (container.bounds.width - 6) / CGFloat(count)
        let changes = {
            knobLeading.constant = 3 + width * CGFloat(index)
            for (i, l) in labels.sorted(by: { $0.tag < $1.tag }).enumerated() {
                l.font = DS.Font.geologica(i == index ? .semiBold : .medium, 14)
                l.textColor = i == index ? DS.Color.textPrimary : DS.Color.textSecondary
            }
            container.layoutIfNeeded()
        }
        animated ? UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0,
                                  animations: changes) : changes()
    }
}
