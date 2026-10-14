import UIKit

/// A/07 · T6 Furnish empty room: room type, style circles, how much furniture. Layout: FurnishToolViewController.xib.
final class FurnishToolViewController: ToolStepViewController {

    @IBOutlet private weak var roomTitleLabel: UILabel!
    @IBOutlet private var roomChips: [DSChipControl]!
    @IBOutlet private weak var styleTitleLabel: UILabel!
    @IBOutlet private weak var stylesCollectionView: UICollectionView!
    @IBOutlet private weak var densityTitleLabel: UILabel!
    @IBOutlet private weak var densityView: UIView!
    @IBOutlet private weak var densityKnob: UIView!
    @IBOutlet private weak var densityKnobLeading: NSLayoutConstraint!
    @IBOutlet private var densityControls: [DSPressableControl]!
    @IBOutlet private var densityLabels: [UILabel]!
    @IBOutlet private weak var densityExplainerLabel: UILabel!

    private let rooms: [InteriorType] = [.livingroom, .bedroom, .dinningroom, .office, .kids, .study]
    private let styles: [StyleInteriorType] = [.japanese, .modern, .scandinavian, .bohemian, .classic, .minimalist,
                                               .industrial, .farmhouse, .mediterranean]
    private var room = 0
    private var style = 0
    private var density = 1

    override var styleTitleForGeneration: String? { styles[style].name }

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "Furnish empty room".localized
        subtitleLabel.text = "We add furniture that fits the space and the light.".localized
        roomTitleLabel.text = "Room type".localized
        styleTitleLabel.text = "Style".localized
        densityTitleLabel.text = "How much furniture".localized
        photoStatusLabel.isHidden = true
        setChipTitles(roomChips, rooms.map(\.name))
        if case .room(let detected)? = session.detectedPlace, let i = rooms.firstIndex(of: detected) { room = i }
        selectChip(roomChips, tag: room)
        let titles = ["Minimal", "Balanced", "Full"]
        densityLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = titles[$0].localized }
        updateExplainer()
        stylesCollectionView.register(UINib(nibName: "StyleCircleCell", bundle: nil),
                                      forCellWithReuseIdentifier: StyleCircleCell.reuseID)
        stylesCollectionView.dataSource = self
        stylesCollectionView.delegate = self
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applySegment(index: density, labels: densityLabels, knobLeading: densityKnobLeading, container: densityView,
                     count: 3, animated: false)
    }

    @IBAction private func didTapRoom(_ sender: UIControl) {
        room = sender.tag
        DS.Haptic.selection()
        selectChip(roomChips, tag: room)
    }

    @IBAction private func didTapDensity(_ sender: UIControl) {
        density = sender.tag
        DS.Haptic.selection()
        applySegment(index: density, labels: densityLabels, knobLeading: densityKnobLeading, container: densityView,
                     count: 3, animated: true)
        UIView.transition(with: densityExplainerLabel, duration: 0.2, options: .transitionCrossDissolve) {
            self.updateExplainer()
        }
    }

    private func updateExplainer() {
        densityExplainerLabel.text = [
            "Minimal: the key pieces only, lots of free space".localized,
            "Balanced: sofa, coffee table, rug, 2–3 decor pieces".localized,
            "Full: complete set with lighting, plants, art and textiles".localized
        ][density]
    }

    override func configure(_ manager: GemeniPromptManager) {
        super.configure(manager)
        manager.updateRoom(rooms[room])
        manager.updateStyle(.interior(styles[style]))
        manager.updateExtraDetails(["Furnish minimally with only the essential pieces.",
                                    "Furnish in a balanced way: main furniture, a rug and a few decor pieces.",
                                    "Furnish fully with lighting, plants, art and textiles."][density])
    }
}

extension FurnishToolViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { styles.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StyleCircleCell.reuseID, for: indexPath)
        (cell as? StyleCircleCell)?.configure(title: styles[indexPath.item].name, imagePath: styles[indexPath.item].image,
                                              selected: indexPath.item == style)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        style = indexPath.item
        DS.Haptic.selection()
        collectionView.reloadData()
    }
}

/// Round style thumb (72) with lime ring. Layout: StyleCircleCell.xib.
final class StyleCircleCell: UICollectionViewCell {
    static let reuseID = "StyleCircleCell"

    @IBOutlet private weak var thumbImageView: UIImageView!
    @IBOutlet private weak var ringView: UIView!
    @IBOutlet private weak var checkView: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    private var path: String?

    func configure(title: String, imagePath: String, selected: Bool) {
        titleLabel.text = title
        titleLabel.font = DS.Font.geologica(selected ? .semiBold : .regular, 12)
        ringView.alpha = selected ? 1 : 0
        checkView.alpha = selected ? 1 : 0
        isAccessibilityElement = true
        accessibilityLabel = title
        accessibilityTraits = selected ? [.button, .selected] : .button
        path = imagePath
        CatalogImage.load(imagePath) { [weak self] image in
            guard self?.path == imagePath else { return }
            self?.thumbImageView.image = image
        }
    }
}

/// A/07 · T7 Floor plan to 3D: plan card, view (isometric / top), style. Layout: FloorPlanToolViewController.xib.
final class FloorPlanToolViewController: ToolStepViewController {

    @IBOutlet private weak var planImageView: UIImageView!
    @IBOutlet private weak var planBadgeLabel: UILabel!
    @IBOutlet private weak var planTipLabel: UILabel!
    @IBOutlet private weak var replacePlanButton: DSPressableControl!
    @IBOutlet private weak var viewTitleLabel: UILabel!
    @IBOutlet private var viewCards: [DSPressableControl]!
    @IBOutlet private var viewTitleLabels: [UILabel]!
    @IBOutlet private var viewSubtitleLabels: [UILabel]!
    @IBOutlet private weak var planStyleTitleLabel: UILabel!
    @IBOutlet private var planStyleChips: [DSChipControl]!

    private let styles: [StyleInteriorType] = [.japanese, .modern, .scandinavian, .classic, .loft]
    private var viewMode = 0
    private var style = 0

    override var expectedSeconds: Int { 60 }
    override var styleTitleForGeneration: String? { styles[style].name }

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "Floor plan to 3D".localized
        subtitleLabel.text = "Upload a plan or a photo of one. We build the rooms in 3D.".localized
        generateTitleLabel.text = "Build 3D".localized
        planImageView.image = session.photo
        planBadgeLabel.text = "Plan added".localized
        planTipLabel.text = "Clear 2D plans with labelled rooms work best. Hand sketches are fine too.".localized
        label(of: replacePlanButton)?.text = "Replace".localized
        viewTitleLabel.text = "View".localized
        planStyleTitleLabel.text = "Style".localized
        let titles = [("Isometric", "3D cut-away"), ("Top view", "Furnished plan")]
        viewTitleLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = titles[$0].0.localized }
        viewSubtitleLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = titles[$0].1.localized }
        setChipTitles(planStyleChips, styles.map(\.name))
        selectChip(planStyleChips, tag: style)
        selectCards(viewCards, tag: viewMode, animated: false)
    }

    @IBAction private func didTapView(_ sender: UIControl) {
        viewMode = sender.tag
        DS.Haptic.selection()
        selectCards(viewCards, tag: viewMode)
    }

    @IBAction private func didTapPlanStyle(_ sender: UIControl) {
        style = sender.tag
        DS.Haptic.selection()
        selectChip(planStyleChips, tag: style)
    }

    override func configure(_ manager: GemeniPromptManager) {
        super.configure(manager)
        manager.updateStyle(.interior(styles[style]))
        manager.updateExtraDetails(viewMode == 0
            ? "Render as an isometric 3D cut-away of the whole apartment with walls cut at waist height."
            : "Render as a furnished top-down plan view, orthographic, showing every room.")
    }
}

/// A/07 · T8 Rearrange: layout presets as radio rows. Layout: RearrangeToolViewController.xib.
final class RearrangeToolViewController: ToolStepViewController {

    @IBOutlet private var optionCards: [DSPressableControl]!
    @IBOutlet private var optionTitleLabels: [UILabel]!
    @IBOutlet private var optionSubtitleLabels: [UILabel]!
    @IBOutlet private var optionRadios: [UIView]!
    @IBOutlet private var optionRadioDots: [UIView]!

    private static let options = [
        ("Open space", "Big pieces to the walls, more floor", "Push large pieces towards the walls to open up the floor."),
        ("Cozy", "Seating around the coffee table", "Group the seating closely around the coffee table for a cozy conversation area."),
        ("Work zone", "Desk by the window, reading corner", "Create a work zone with the desk by the window and a reading corner."),
        ("Conversation", "Sofas facing each other", "Arrange the sofas and chairs to face each other.")
    ]
    private var option = 1

    override var styleTitleForGeneration: String? { Self.options[option].0.localized }

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "Rearrange furniture".localized
        subtitleLabel.text = "Same furniture, new layout. Nothing new is added.".localized
        if case .room(let room)? = session.detectedPlace {
            photoStatusLabel.text = room.name
            photoStatusLabel.textColor = DS.Color.textTertiary
            photoStatusLabel.isHidden = false
        }
        optionTitleLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = Self.options[$0].0.localized }
        optionSubtitleLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = Self.options[$0].1.localized }
        apply(animated: false)
    }

    @IBAction private func didTapOption(_ sender: UIControl) {
        option = sender.tag
        DS.Haptic.selection()
        apply(animated: true)
    }

    private func apply(animated: Bool) {
        selectCards(optionCards, tag: option, animated: animated)
        let changes = {
            self.optionRadioDots.forEach { $0.alpha = $0.tag == self.option ? 1 : 0 }
            self.optionRadios.forEach { $0.layer.borderColor = ($0.tag == self.option ? DS.Color.textPrimary : UIColor(white: 0.6, alpha: 1)).resolvedColor(with: self.traitCollection).cgColor }
        }
        animated ? UIView.animate(withDuration: 0.2, animations: changes) : changes()
    }

    override func configure(_ manager: GemeniPromptManager) {
        super.configure(manager)
        manager.updateRearrangeSubOption(.sameFurnitureOnly)
        manager.updateExtraDetails(Self.options[option].2)
    }
}
