import SafariServices
import UIKit

/// A/04 · W4 Final touches. Layout: Wizard.storyboard.
final class WizardFinalViewController: WizardStepViewController {

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var contentStack: UIStackView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var summaryView: UIView!
    @IBOutlet private weak var thumbImageView: UIImageView!
    @IBOutlet private weak var roomChip: DSChipControl!
    @IBOutlet private weak var styleChip: DSChipControl!
    @IBOutlet private var summaryChipLabels: [UILabel]!
    @IBOutlet private weak var kindLabel: UILabel!
    @IBOutlet private weak var structureTitleLabel: UILabel!
    @IBOutlet private weak var segmentedView: UIView!
    @IBOutlet private weak var segmentKnob: UIView!
    @IBOutlet private weak var segmentKnobLeading: NSLayoutConstraint!
    @IBOutlet private var segmentControls: [DSPressableControl]!
    @IBOutlet private var segmentLabels: [UILabel]!
    @IBOutlet private weak var modeIconView: UIImageView!
    @IBOutlet private weak var modeExplainerLabel: UILabel!
    @IBOutlet private weak var paletteTitleLabel: UILabel!
    @IBOutlet private weak var paletteScrollView: UIScrollView!
    @IBOutlet private var paletteControls: [DSPressableControl]!
    @IBOutlet private var paletteRings: [UIView]!
    @IBOutlet private var paletteLabels: [UILabel]!
    @IBOutlet private var paletteSwatches: [UIView]!
    @IBOutlet private weak var detailsTitleLabel: UILabel!
    @IBOutlet private weak var detailsBox: UIView!
    @IBOutlet private weak var detailsField: UITextField!
    @IBOutlet private weak var generateButton: DSPrimaryButton!
    @IBOutlet private weak var generateTitleLabel: UILabel!
    @IBOutlet private weak var generateSubtitleLabel: UILabel!
    @IBOutlet private weak var generateIconView: UIImageView!
    @IBOutlet private weak var aiDisclosureLabel: UILabel!

    override var step: WizardSession.Step { .final }

    private var didRunEntrance = false
    private var microTimers: [Timer] = []

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        (roomChip.superview as? DSAdaptiveChipRow)?.fit(in: view.dsLayoutSize.width - OnboardingLayout(size: view.dsAdaptiveReferenceSize).value(140))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "Final touches".localized
        subtitleLabel.text = "Here's what we'll make. Tap any item to edit.".localized
        structureTitleLabel.text = "Structure".localized
        paletteTitleLabel.text = "Color palette".localized
        detailsTitleLabel.text = "Anything specific? (optional)".localized
        detailsField.placeholder = "e.g. light oak floor, no rug".localized
        detailsField.delegate = self
        detailsField.text = session.details
        generateTitleLabel.text = "Generate design".localized
        configureDisclosure()
        sortedLabels(segmentLabels).enumerated().forEach { $1.text = ["Keep structure", "More freedom"][$0].localized }
        sortedLabels(paletteLabels).enumerated().forEach { $1.text = WizardSession.Palette(rawValue: $0)?.title }
        roomChip.isHidden = session.place == nil
        hideForEntrance()
        observeKeyboard()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshSummary()
        applyMode(animated: false)
        applyPalette(animated: false)
        updateCost()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !didRunEntrance {
            didRunEntrance = true
            runEntrance()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        microTimers.forEach { $0.invalidate() }
        session.details = detailsField.text ?? ""
    }

    private func sortedLabels(_ labels: [UILabel]) -> [UILabel] { labels.sorted { $0.tag < $1.tag } }

    private func refreshSummary() {
        thumbImageView.image = session.photo
        let labels = sortedLabels(summaryChipLabels)
        labels.first?.text = session.place?.title
        labels.last?.text = session.style?.title ?? "Style".localized
        kindLabel.text = session.kindTitle
        roomChip.accessibilityLabel = String(format: "Room: %@. Double tap to change.".localized, session.place?.title ?? "")
        styleChip.accessibilityLabel = String(format: "Style: %@. Double tap to change.".localized, session.style?.title ?? "")
    }

    /// Duration only; generate() still checks availability and entitlement.
    private func updateCost() {
        generateSubtitleLabel.text = costLine()
    }

    // MARK: Structure

    @IBAction private func didTapSegment(_ sender: UIControl) {
        let keep = sender.tag == 0
        guard keep != session.keepStructure else { return }
        session.keepStructure = keep
        DS.Haptic.selection()
        applyMode(animated: true)
    }

    private func applyMode(animated: Bool) {
        let keep = session.keepStructure
        let labels = sortedLabels(segmentLabels)
        let inset = OnboardingLayout(size: view.dsAdaptiveReferenceSize).value(3)
        let width = (segmentedView.bounds.width - 2 * inset) / 2
        let move = {
            self.segmentKnobLeading.constant = keep ? inset : inset + width
            labels[0].font = DS.Font.geologica(keep ? .semiBold : .medium, labels[0].font.pointSize)
            labels[1].font = DS.Font.geologica(keep ? .medium : .semiBold, labels[1].font.pointSize)
            labels[0].textColor = keep ? DS.Color.textPrimary : DS.Color.textSecondary
            labels[1].textColor = keep ? DS.Color.textSecondary : DS.Color.textPrimary
            self.segmentedView.layoutIfNeeded()
        }
        let text = keep
            ? "Walls, windows and furniture layout stay. Only the style changes.".localized
            : "We may move furniture and change the layout for a fresh look.".localized
        modeIconView.image = UIImage(systemName: keep ? "checkmark.shield" : "wand.and.stars")
        segmentControls.forEach { $0.accessibilityTraits = $0.tag == (keep ? 0 : 1) ? [.button, .selected] : .button }
        guard animated, !DS.Motion.reduceMotion else {
            move()
            modeExplainerLabel.text = text
            return
        }
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0, animations: move)
        UIView.transition(with: modeExplainerLabel, duration: 0.25, options: .transitionCrossDissolve) {
            self.modeExplainerLabel.text = text
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let inset = OnboardingLayout(size: view.dsAdaptiveReferenceSize).value(3)
        let width = (segmentedView.bounds.width - 2 * inset) / 2
        segmentKnobLeading.constant = session.keepStructure ? inset : inset + width
    }

    // MARK: Palette

    @IBAction private func didTapPalette(_ sender: UIControl) {
        guard let palette = WizardSession.Palette(rawValue: sender.tag), palette != session.palette else { return }
        session.palette = palette
        session.colorOverride = nil
        DS.Haptic.selection()
        applyPalette(animated: true)
    }

    private func applyPalette(animated: Bool) {
        let selected = session.palette.rawValue
        let rings = paletteRings.sorted { $0.tag < $1.tag }
        let labels = sortedLabels(paletteLabels)
        let changes = {
            for (i, ring) in rings.enumerated() {
                ring.alpha = i == selected ? 1 : 0
                ring.transform = i == selected ? .identity : CGAffineTransform(scaleX: 1.15, y: 1.15)
                labels[i].font = DS.Font.geologica(i == selected ? .semiBold : .regular, labels[i].font.pointSize)
            }
        }
        paletteControls.forEach { $0.accessibilityTraits = $0.tag == selected ? [.button, .selected] : .button }
        guard animated else { changes(); return }
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0, animations: changes)
    }

    // MARK: Summary chips

    @IBAction private func didTapRoomChip(_ sender: Any) { returnTo(.room) }
    @IBAction private func didTapStyleChip(_ sender: Any) { returnTo(.style) }

    // MARK: Generate

    @IBAction private func didTapGenerate(_ sender: Any) {
        session.details = detailsField.text ?? ""
        let session = self.session!
        generate(styleTitle: session.style?.title) { _ in session.applyToPromptManager() }
    }

    // MARK: AI disclosure (App Review 5.1.2(i): who gets the photo; tapping Generate = agreeing)

    private func configureDisclosure() {
        aiDisclosureLabel.attributedText = AIPhotoConsent.disclosureText(
            font: aiDisclosureLabel.font, color: DS.Color.textSecondary, linkColor: DS.Color.textPrimary)
        aiDisclosureLabel.accessibilityTraits = .link
        aiDisclosureLabel.accessibilityHint = "Opens the Privacy Policy".localized
        aiDisclosureLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapPrivacy)))
    }

    @objc private func didTapPrivacy() {
        guard let url = URL(string: Constants.API.privacy) else { return }
        present(SFSafariViewController(url: url), animated: true)
    }

    // MARK: Keyboard

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil,
                                               queue: .main) { [weak self] note in
            guard let self, let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let overlap = max(0, self.view.bounds.maxY - self.view.convert(frame, from: nil).minY - self.view.safeAreaInsets.bottom)
            self.scrollView.contentInset.bottom = overlap
            if overlap > 0 {
                let rect = self.detailsBox.convert(self.detailsBox.bounds, to: self.scrollView).insetBy(dx: 0, dy: -24)
                self.scrollView.scrollRectToVisible(rect, animated: true)
            }
        }
    }

    // MARK: Motion

    private var blocks: [UIView] {
        contentStack.arrangedSubviews
    }

    private func hideForEntrance() {
        blocks.forEach { $0.alpha = 0 }
        generateButton.alpha = 0
        aiDisclosureLabel.alpha = 0
    }

    /// Blocks 60 ms apart → palettes slide in → field → CTA from below; shimmer 1.6 / 4.4 s, pulse 3.0 s, sparkle 1.0 / 3.8 s.
    private func runEntrance() {
        enter(blocks, from: 0.08, step: 0.06, dy: 10)
        paletteControls.sorted { $0.tag < $1.tag }.enumerated().forEach {
            DS.Motion.enter($1, delay: 0.45 + Double($0) * 0.05, dx: 24, scale: 0.9)
        }
        DS.Motion.enter(generateButton, delay: 0.7, dy: 24, spring: true)
        DS.Motion.enter(aiDisclosureLabel, delay: 0.8, dy: 12)
        guard !DS.Motion.reduceMotion else { return }
        let plan: [(TimeInterval, () -> Void)] = [
            (1.0, { [weak self] in self?.spinSparkle() }),
            (1.6, { [weak self] in self?.generateButton.runShimmer() }),
            (3.0, { [weak self] in self?.generateButton.pulse() }),
            (3.8, { [weak self] in self?.spinSparkle() }),
            (4.4, { [weak self] in self?.generateButton.runShimmer() })
        ]
        microTimers = plan.map { delay, block in Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in block() } }
    }

    private func spinSparkle() {
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = Double.pi
        spin.duration = 0.6
        spin.timingFunction = CAMediaTimingFunction(name: .easeOut)
        generateIconView.layer.add(spin, forKey: "spin")
    }
}

extension WizardFinalViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let current = (textField.text ?? "") as NSString
        return current.replacingCharacters(in: range, with: string).count <= 200
    }
}
