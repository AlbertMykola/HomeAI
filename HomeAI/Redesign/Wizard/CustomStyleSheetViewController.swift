import UIKit

/// A/04 · W3-p Describe your style (sheet, .large + keyboard). Layout: Wizard.storyboard.
final class CustomStyleSheetViewController: UIViewController, DSSheetContentMeasuring {

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var contentScrollView: UIScrollView!
    @IBOutlet private weak var closeButton: DSPressableControl!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var fieldView: UIView!
    @IBOutlet private weak var textView: UITextView!
    @IBOutlet private weak var placeholderLabel: UILabel!
    @IBOutlet private weak var counterLabel: UILabel!
    @IBOutlet private var exampleChips: [DSChipControl]!
    @IBOutlet private weak var useButton: DSPrimaryButton!
    @IBOutlet private weak var useLabel: UILabel!

    private static let limit = 200
    private static let examples = ["Cozy cabin", "Parisian flat", "Hotel lobby", "Bright coastal"]
    private static let exampleTexts = [
        "Cozy cabin with warm wood, wool throws and a soft fireplace glow",
        "Parisian flat with herringbone floors, moldings and brass accents",
        "Hotel lobby feel: marble, velvet seating and dramatic lighting",
        "Bright coastal with white oak, linen and sea-blue accents"
    ]

    private var initialText: String?
    private var onUse: ((String) -> Void)?
    private var didRunEntrance = false

    static func present(from presenter: UIViewController, initialText: String?, onUse: @escaping (String) -> Void) {
        let vc = AppStoryboard.instantiate(CustomStyleSheetViewController.self)
        vc.initialText = initialText
        vc.onUse = onUse
        DSSheet.present(vc, from: presenter, large: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let inset = OnboardingLayout(size: view.dsAdaptiveReferenceSize).value(40)
        exampleChips.forEach { ($0.superview as? DSAdaptiveChipRow)?.fit(in: view.dsLayoutSize.width - inset) }
    }

    func sheetContentHeight(width: CGFloat) -> CGFloat { dsSheetHeight(width: width, lastView: useButton) }

    override func viewDidLoad() {
        super.viewDidLoad()
        contentScrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -12).isActive = true
        contentScrollView.keyboardDismissMode = .interactive
        titleLabel.text = "Describe your style".localized
        subtitleLabel.text = "Materials, colors, mood — in your own words.".localized
        placeholderLabel.text = "Warm minimal with travertine, linen curtains and soft evening light".localized
        useLabel.text = "Use this style".localized
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        textView.isScrollEnabled = true
        textView.delegate = self
        textView.text = initialText
        exampleChips.sorted { $0.tag < $1.tag }.enumerated().forEach { index, chip in
            chip.subviews.first?.subviews.compactMap { $0 as? UILabel }.first?.text = Self.examples[index].localized
            chip.alpha = 0
        }
        updateState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didRunEntrance else { return }
        didRunEntrance = true
        exampleChips.sorted { $0.tag < $1.tag }.enumerated().forEach {
            DS.Motion.enter($1, delay: Double($0) * 0.05, dy: 8)
        }
        // Start the visible entrance before a first keyboard activation can block it.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.viewIfLoaded?.window != nil else { return }
        #if DEBUG
            if !(AppQA.enabled && AppQA.snapshot) { self.textView.becomeFirstResponder() }
        #else
            self.textView.becomeFirstResponder()
        #endif
        }
    }

    @IBAction private func didTapClose(_ sender: Any) {
        dismiss(animated: true)
    }

    @IBAction private func didTapExample(_ sender: UIControl) {
        DS.Haptic.selection()
        UIView.transition(with: textView, duration: 0.2, options: .transitionCrossDissolve) {
            self.textView.text = Self.exampleTexts[min(sender.tag, Self.exampleTexts.count - 1)].localized
        }
        updateState()
    }

    @IBAction private func didTapUse(_ sender: Any) {
        let text = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            DS.Haptic.warning()
            shake(fieldView)
            return
        }
        DS.Haptic.medium()
        let onUse = self.onUse
        dismiss(animated: true) { onUse?(text) }
    }

    private func updateState() {
        let count = textView.text.count
        placeholderLabel.isHidden = count > 0
        counterLabel.isHidden = count < 150
        counterLabel.text = "\(count)/\(Self.limit)"
        useButton.inactive = textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func shake(_ view: UIView) {
        let anim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        anim.values = [0, 8, -8, 5, 0]
        anim.duration = 0.3
        view.layer.add(anim, forKey: "shake")
    }
}

extension CustomStyleSheetViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateState()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let current = textView.text as NSString
        return current.replacingCharacters(in: range, with: text).count <= Self.limit
    }
}
