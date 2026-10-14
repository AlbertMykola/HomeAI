import UIKit

/// A/06 · R2 Compare fullscreen: drag the divider, Original / Split / Result, pinch zoom on both.
/// Layout: CompareViewController.xib.
final class CompareViewController: UIViewController {

    @IBOutlet private weak var stageView: UIView!
    @IBOutlet private weak var afterImageView: UIImageView!
    @IBOutlet private weak var beforeImageView: UIImageView!
    @IBOutlet private weak var beforeClipView: UIView!
    @IBOutlet private weak var beforeWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var dividerView: UIView!
    @IBOutlet private weak var handleView: UIImageView!
    @IBOutlet private weak var closeButton: DSPressableControl!
    @IBOutlet private weak var fitButton: DSPressableControl!
    @IBOutlet private weak var segmentedView: UIView!
    @IBOutlet private weak var segmentKnob: UIView!
    @IBOutlet private weak var segmentKnobLeading: NSLayoutConstraint!
    @IBOutlet private var segmentControls: [DSPressableControl]!
    @IBOutlet private var segmentLabels: [UILabel]!

    var beforeImage: UIImage?
    var afterImage: UIImage?

    private enum Mode: Int { case original, split, result }
    private var mode: Mode = .split
    private var splitFraction: CGFloat = 0.5
    private var zoom: CGFloat = 1
    private var pan: CGPoint = .zero

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        beforeImageView.image = beforeImage
        afterImageView.image = afterImage
        let titles = ["Original", "Split", "Result"]
        segmentLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = titles[$0].localized }
        stageView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handleDrag(_:))))
        stageView.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:))))
        apply(mode: .split, animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        hintSlide()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutDivider()
        let width = (segmentedView.bounds.width - 6) / 3
        segmentKnobLeading.constant = 3 + width * CGFloat(mode.rawValue)
    }

    private func layoutDivider() {
        let fraction: CGFloat = mode == .original ? 1 : (mode == .result ? 0 : splitFraction)
        beforeWidthConstraint.isActive = false
        beforeWidthConstraint = beforeClipView.widthAnchor.constraint(equalToConstant: stageView.bounds.width * fraction)
        beforeWidthConstraint.isActive = true
        dividerView.alpha = mode == .split ? 1 : 0
        handleView.alpha = mode == .split ? 1 : 0
    }

    @objc private func handleDrag(_ gesture: UIPanGestureRecognizer) {
        if zoom > 1.01 {
            let t = gesture.translation(in: stageView)
            pan = CGPoint(x: pan.x + t.x, y: pan.y + t.y)
            gesture.setTranslation(.zero, in: stageView)
            applyZoom()
            return
        }
        guard mode == .split else { return }
        splitFraction = min(max(gesture.location(in: stageView).x / max(stageView.bounds.width, 1), 0), 1)
        layoutDivider()
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        zoom = min(max(zoom * gesture.scale, 1), 4)
        gesture.scale = 1
        if zoom <= 1.01 { pan = .zero }
        applyZoom()
    }

    private func applyZoom() {
        let t = CGAffineTransform(translationX: pan.x, y: pan.y).scaledBy(x: zoom, y: zoom)
        afterImageView.transform = t
        beforeImageView.transform = t
    }

    @IBAction private func didTapFit(_ sender: Any) {
        zoom = 1
        pan = .zero
        UIView.animate(withDuration: 0.3) { self.applyZoom() }
    }

    @IBAction private func didTapClose(_ sender: Any) {
        dismiss(animated: true)
    }

    @IBAction private func didTapSegment(_ sender: UIControl) {
        guard let m = Mode(rawValue: sender.tag), m != mode else { return }
        DS.Haptic.selection()
        apply(mode: m, animated: true)
    }

    private func apply(mode: Mode, animated: Bool) {
        self.mode = mode
        let labels = segmentLabels.sorted { $0.tag < $1.tag }
        let changes = {
            self.layoutDivider()
            let width = (self.segmentedView.bounds.width - 6) / 3
            self.segmentKnobLeading.constant = 3 + width * CGFloat(mode.rawValue)
            for (i, l) in labels.enumerated() {
                l.font = DS.Font.geologica(i == mode.rawValue ? .semiBold : .medium, 14)
                l.textColor = i == mode.rawValue ? DS.Color.textPrimary : DS.Color.textSecondary
            }
            self.view.layoutIfNeeded()
        }
        animated ? UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0,
                                  animations: changes) : changes()
    }

    /// Handle pops, then the divider glides +90 → −90 → centre to show it can be dragged.
    private func hintSlide() {
        guard !DS.Motion.reduceMotion else { return }
        DS.Motion.enter(handleView, delay: 0.1, scale: 0.4, duration: 0.35, pop: true)
        let w = max(stageView.bounds.width, 1)
        let steps: [CGFloat] = [0.5 + 90 / w, 0.5 - 90 / w, 0.5]
        for (i, f) in steps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + Double(i) * 0.5) { [weak self] in
                guard let self, self.mode == .split else { return }
                UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                    self.splitFraction = f
                    self.layoutDivider()
                    self.stageView.layoutIfNeeded()
                }
            }
        }
    }
}
