import UIKit

/// A/07 · T1 Exterior: facade style (palette cards), light, keep structure. Layout: ExteriorToolViewController.xib.
final class ExteriorToolViewController: ToolStepViewController {

    @IBOutlet private weak var facadeTitleLabel: UILabel!
    @IBOutlet private var facadeCards: [DSPressableControl]!
    @IBOutlet private var facadeLabels: [UILabel]!
    @IBOutlet private weak var lightTitleLabel: UILabel!
    @IBOutlet private var lightControls: [DSPressableControl]!
    @IBOutlet private var lightRings: [UIView]!
    @IBOutlet private var lightChecks: [UIView]!
    @IBOutlet private var lightLabels: [UILabel]!
    @IBOutlet private weak var keepTitleLabel: UILabel!
    @IBOutlet private weak var keepSubtitleLabel: UILabel!
    @IBOutlet private weak var keepSwitch: UISwitch!

    /// Facade cards → existing exterior styles (+ a short brief where there is no exact style).
    private static let facades: [(title: String, style: StyleExteriorType, brief: String?)] = [
        ("Modern farmhouse", .rustic, "modern farmhouse facade: white board-and-batten siding, black window frames, warm wood accents"),
        ("Scandinavian", .scandinavian, nil),
        ("Mediterranean", .mediterranean, nil),
        ("Contemporary", .contemporary, nil),
        ("Craftsman", .craftsman, nil),
        ("Coastal", .cottageStyle, "coastal facade: light shingle siding, soft blue and sand tones, white trims")
    ]
    private static let lights = ["natural daylight", "warm golden hour light, low sun", "dusk with warm exterior lighting on"]

    private var facade = 0
    private var light = 1

    override var styleTitleForGeneration: String? { Self.facades[facade].title.localized }

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "Exterior style".localized
        subtitleLabel.text = "The shape of your house stays. We change materials, colors and planting.".localized
        facadeTitleLabel.text = "Facade style".localized
        lightTitleLabel.text = "Light".localized
        keepTitleLabel.text = "Keep structure".localized
        keepSubtitleLabel.text = "Roof, windows and doors stay in place".localized
        facadeLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = Self.facades[$0].title.localized }
        if case .exterior(let preset)? = session.style,
           let i = Self.facades.firstIndex(where: { $0.brief == nil && $0.style == preset }) { facade = i }
        let lightTitles = ["Day", "Golden hour", "Dusk"]
        lightLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = lightTitles[$0].localized }
        applyFacade(animated: false)
        applyLight(animated: false)
    }

    @IBAction private func didTapFacade(_ sender: UIControl) {
        facade = sender.tag
        DS.Haptic.selection()
        applyFacade(animated: true)
    }

    @IBAction private func didTapLight(_ sender: UIControl) {
        light = sender.tag
        DS.Haptic.selection()
        applyLight(animated: true)
    }

    private func applyFacade(animated: Bool) {
        selectCards(facadeCards, tag: facade, animated: animated)
        facadeLabels.forEach { $0.font = DS.Font.geologica($0.tag == facade ? .semiBold : .medium, 14) }
    }

    private func applyLight(animated: Bool) {
        let changes = {
            self.lightRings.forEach { $0.alpha = $0.tag == self.light ? 1 : 0 }
            self.lightChecks.forEach { $0.alpha = $0.tag == self.light ? 1 : 0 }
        }
        lightLabels.forEach { $0.font = DS.Font.geologica($0.tag == light ? .semiBold : .regular, 13) }
        animated ? UIView.animate(withDuration: 0.25, animations: changes) : changes()
    }

    override func configure(_ manager: GemeniPromptManager) {
        super.configure(manager)
        let f = Self.facades[facade]
        if let brief = f.brief {
            manager.updateCustomPrompt(brief)
        } else {
            manager.updateStyle(.exterior(f.style))
        }
        if case .building(let b) = session.place { manager.updateExteriorType(b) } else { manager.updateExteriorType(.house) }
        manager.updateDesignMode(keepSwitch.isOn ? .structuralPreservation : .renovationDesign)
        manager.updateExtraDetails("Lighting: \(Self.lights[light]).")
    }
}

/// A/07 · T2 Garden: styles, season, keep paths & patio. Layout: GardenToolViewController.xib.
final class GardenToolViewController: ToolStepViewController {

    @IBOutlet private weak var styleTitleLabel: UILabel!
    @IBOutlet private weak var stylesCollectionView: UICollectionView!
    @IBOutlet private weak var seasonTitleLabel: UILabel!
    @IBOutlet private var seasonChips: [DSChipControl]!
    @IBOutlet private weak var keepTitleLabel: UILabel!
    @IBOutlet private weak var keepSubtitleLabel: UILabel!
    @IBOutlet private weak var keepSwitch: UISwitch!

    private let styles = GardenType.allCases.filter { $0 != .noStyle && $0 != .custom }
    private var selected = 0
    private var season = 1

    override var styleTitleForGeneration: String? { styles[selected].name }

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "Garden style".localized
        subtitleLabel.text = "Plants, paths and lighting for your yard.".localized
        styleTitleLabel.text = "Garden style".localized
        seasonTitleLabel.text = "Season".localized
        keepTitleLabel.text = "Keep paths & patio".localized
        keepSubtitleLabel.text = "Hardscape stays, we redo planting".localized
        setChipTitles(seasonChips, ["Spring", "Summer", "Autumn", "Winter"].map(\.localized))
        if case .garden(let preset)? = session.style, let i = styles.firstIndex(of: preset) { selected = i }
        selectChip(seasonChips, tag: season)
        stylesCollectionView.register(UINib(nibName: "MaterialTileCell", bundle: nil),
                                      forCellWithReuseIdentifier: MaterialTileCell.reuseID)
        if let layout = stylesCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.itemSize = CGSize(width: 160, height: 136)
            layout.minimumLineSpacing = 12
            layout.minimumInteritemSpacing = 14
        }
        stylesCollectionView.dataSource = self
        stylesCollectionView.delegate = self
    }

    @IBAction private func didTapSeason(_ sender: UIControl) {
        season = sender.tag
        DS.Haptic.selection()
        selectChip(seasonChips, tag: season)
    }

    override func configure(_ manager: GemeniPromptManager) {
        super.configure(manager)
        manager.updateStyle(.garden(styles[selected].name))
        manager.updateDesignMode(keepSwitch.isOn ? .structuralPreservation : .renovationDesign)
        let seasons = ["spring blossom", "lush summer greenery", "autumn foliage colors", "winter planting with evergreens"]
        manager.updateExtraDetails("Season: \(seasons[season])." + (keepSwitch.isOn ? " Keep existing paths, patio and hardscape." : ""))
    }
}

extension GardenToolViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { styles.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MaterialTileCell.reuseID, for: indexPath)
        (cell as? MaterialTileCell)?.configure(title: styles[indexPath.item].name, imagePath: styles[indexPath.item].icon,
                                               selected: indexPath.item == selected)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selected = indexPath.item
        DS.Haptic.selection()
        collectionView.visibleCells.compactMap { $0 as? MaterialTileCell }.forEach { cell in
            if let ip = collectionView.indexPath(for: cell) { cell.setChosen(ip.item == selected, animated: true) }
        }
    }
}

/// Tile with image (r18), lime ring + check when chosen, title below. Layout: MaterialTileCell.xib.
final class MaterialTileCell: UICollectionViewCell {
    static let reuseID = "MaterialTileCell"

    @IBOutlet private weak var thumbImageView: UIImageView!
    @IBOutlet private weak var ringView: UIView!
    @IBOutlet private weak var checkView: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    private var path: String?

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbImageView.image = nil
    }

    func configure(title: String, imagePath: String?, image: UIImage? = nil, selected: Bool) {
        titleLabel.text = title
        isAccessibilityElement = true
        accessibilityLabel = title
        path = imagePath
        thumbImageView.image = image
        if let imagePath {
            CatalogImage.load(imagePath) { [weak self] img in
                guard self?.path == imagePath else { return }
                self?.thumbImageView.image = img
            }
        }
        setChosen(selected, animated: false)
    }

    func setChosen(_ chosen: Bool, animated: Bool) {
        let changes = {
            self.ringView.alpha = chosen ? 1 : 0
            self.checkView.alpha = chosen ? 1 : 0
            self.checkView.transform = chosen ? .identity : CGAffineTransform(scaleX: 0.4, y: 0.4)
        }
        titleLabel.font = DS.Font.geologica(chosen ? .semiBold : .regular, 13)
        accessibilityTraits = chosen ? [.button, .selected] : .button
        animated ? UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0,
                                  animations: changes) : changes()
    }
}
