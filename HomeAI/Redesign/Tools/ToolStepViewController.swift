import UIKit

/// Base for the A/07 tool screens (W1 → T<n>, step 2/2): photo summary, sections, Generate.
class ToolStepViewController: WizardStepViewController {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentStack: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var photoSummaryView: UIView!
    @IBOutlet weak var photoThumbView: UIImageView!
    @IBOutlet weak var photoTitleLabel: UILabel!
    @IBOutlet weak var photoStatusLabel: UILabel!
    @IBOutlet weak var changePhotoButton: UIButton!
    @IBOutlet weak var generateButton: DSPrimaryButton!
    @IBOutlet weak var generateTitleLabel: UILabel!
    @IBOutlet weak var generateSubtitleLabel: UILabel!
    @IBOutlet weak var generateIconView: UIImageView!

    override var step: WizardSession.Step { .tool }

    /// Seconds shown in the cost line.
    var expectedSeconds: Int { 30 }
    /// Style name for G1 ("Applying … style") and the ready notification.
    var styleTitleForGeneration: String? { nil }
    var isReady: Bool { true }

    private var didRunEntrance = false

    override func viewDidLoad() {
        super.viewDidLoad()
        photoThumbView.image = session.photo
        photoTitleLabel.text = "Your photo".localized
        changePhotoButton.setTitle("Change".localized, for: .normal)
        generateSubtitleLabel.text = costLine(seconds: expectedSeconds)
        contentStack.arrangedSubviews.forEach { $0.alpha = 0 }
        generateButton.alpha = 0
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateGenerateState()
        guard !didRunEntrance else { return }
        didRunEntrance = true
        enter(contentStack.arrangedSubviews.filter { !$0.isHidden }, from: 0.05, step: 0.06, dy: 10)
        contentStack.arrangedSubviews.filter { $0.isHidden }.forEach { $0.alpha = 1 }
        DS.Motion.enter(generateButton, delay: 0.5, dy: 24, spring: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in self?.generateButton.runShimmer() }
    }

    func updateGenerateState() {
        generateButton.inactive = !isReady
        generateButton.isUserInteractionEnabled = isReady
    }

    @IBAction func didTapChangePhoto(_ sender: Any) {
        returnTo(.photo)
    }

    /// Subclasses fill the prompt manager (option, base image, settings).
    func configure(_ manager: GemeniPromptManager) {
        manager.updateOption(session.option)
        if let photo = session.photo { manager.updateBaseImage(photo.normalizedForGeneration()) }
    }

    @IBAction func didTapGenerate(_ sender: Any) {
        guard isReady else { return }
        generate(styleTitle: styleTitleForGeneration) { [weak self] manager in self?.configure(manager) }
    }

    // MARK: Helpers

    func label(of control: UIView) -> UILabel? {
        if let l = control as? UILabel { return l }
        for sub in control.subviews { if let l = label(of: sub) { return l } }
        return nil
    }

    func setChipTitles(_ chips: [DSChipControl], _ titles: [String]) {
        chips.sorted { $0.tag < $1.tag }.enumerated().forEach { i, chip in
            chip.isHidden = i >= titles.count
            if i < titles.count { label(of: chip)?.text = titles[i] }
        }
    }

    func selectChip(_ chips: [DSChipControl], tag: Int) {
        chips.forEach { $0.setChipSelected($0.tag == tag, animated: true) }
    }

    func selectCards(_ cards: [UIView], tag: Int, animated: Bool = true) {
        let changes = {
            for card in cards {
                let on = card.tag == tag
                card.backgroundColor = on ? DS.Color.limeSoft : DS.Color.surface
                card.layer.borderWidth = on ? 1.5 : 0
                card.layer.borderColor = DS.Color.lime.cgColor
                card.accessibilityTraits = on ? [.button, .selected] : .button
            }
        }
        animated ? UIView.animate(withDuration: 0.2, animations: changes) : changes()
    }
}

enum ToolStepFactory {
    static func make(session: WizardSession) -> WizardStepViewController {
        switch session.option {
        case .exterior: return ExteriorToolViewController.make(session: session)
        case .garden: return GardenToolViewController.make(session: session)
        case .reference: return ReferenceToolViewController.make(session: session)
        case .newWalls: return WallsToolViewController.make(session: session)
        case .newFlooring: return FloorToolViewController.make(session: session)
        case .furnish: return FurnishToolViewController.make(session: session)
        case .floolPlan: return FloorPlanToolViewController.make(session: session)
        case .rearrange: return RearrangeToolViewController.make(session: session)
        default: return WizardRoomViewController.make(session: session)
        }
    }
}
