import UIKit

/// Shared logic of T4 New walls / T5 New flooring: filter chips + 3-column material grid.
class SurfaceToolViewController: ToolStepViewController {

    @IBOutlet weak var materialsCollectionView: UICollectionView!
    @IBOutlet weak var materialsHeightConstraint: NSLayoutConstraint!
    @IBOutlet var filterChips: [DSChipControl]!

    struct Item {
        let title: String
        let imagePath: String?
        let image: UIImage?
        let material: SurfaceMaterialOption?
        let custom: String?
    }

    var filters: [String] { [] }
    func items(for filter: Int) -> [Item] { [] }

    private(set) var filter = 0
    private(set) var visible: [Item] = []
    private(set) var selected: Item?

    override var isReady: Bool { selected != nil }
    override var styleTitleForGeneration: String? { selected?.title }

    override func viewDidLoad() {
        super.viewDidLoad()
        setChipTitles(filterChips, filters.map(\.localized))
        selectChip(filterChips, tag: 0)

        materialsCollectionView.dataSource = self
        materialsCollectionView.delegate = self
        reload()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let layout = materialsCollectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        let metrics = OnboardingLayout(size: view.dsLayoutSize)
        let w = floor((materialsCollectionView.bounds.width - metrics.value(26)) / 3)
        let size = CGSize(width: w, height: w * 90 / 109 + metrics.value(26))
        if layout.itemSize != size {
            layout.itemSize = size
            layout.minimumInteritemSpacing = metrics.value(13)
            layout.minimumLineSpacing = metrics.value(14)
            layout.sectionInset = .zero
            layout.invalidateLayout()
        }
        let rows = ceil(CGFloat(visible.count) / 3)
        materialsHeightConstraint.constant = max(0, rows * layout.itemSize.height + max(0, rows - 1) * metrics.value(14))
    }

    @IBAction func didTapFilter(_ sender: UIControl) {
        filter = sender.tag
        DS.Haptic.selection()
        selectChip(filterChips, tag: filter)
        UIView.transition(with: materialsCollectionView, duration: 0.2, options: .transitionCrossDissolve) {
            self.reload()
        }
    }

    private func reload() {
        visible = items(for: filter)
        materialsCollectionView.reloadData()
        view.setNeedsLayout()
    }
}

extension SurfaceToolViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { visible.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MaterialTileCell.reuseID, for: indexPath)
        let item = visible[indexPath.item]
        (cell as? MaterialTileCell)?.configure(title: item.title, imagePath: item.imagePath, image: item.image,
                                               selected: item.title == selected?.title)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selected = visible[indexPath.item]
        DS.Haptic.selection()
        collectionView.visibleCells.compactMap { $0 as? MaterialTileCell }.forEach { cell in
            if let ip = collectionView.indexPath(for: cell) { cell.setChosen(ip.item == indexPath.item, animated: true) }
        }
        updateGenerateState()
        generateButton.runShimmer(delay: 0.2)
    }
}

/// A/07 · T4 New walls. Layout: Tools.storyboard.
final class WallsToolViewController: SurfaceToolViewController {

    override var filters: [String] { ["All", "Paint", "Wood", "Stone", "Tile", "Wallpaper"] }

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "New walls".localized
        subtitleLabel.text = "Pick a material. We find the walls automatically.".localized
    }

    override func items(for filter: Int) -> [Item] {
        let groups: [[SurfaceMaterialOption]] = [
            SurfaceMaterialOption.options(for: .wall),
            [.mattePaint, .decorativePlaster, .microcement],
            [.woodSlats, .woodShiplap, .corkWall, .wallMolding],
            [.exposedBrick, .stoneVeneer, .rawConcrete, .marbleSlab],
            [.marbleSlab, .glassPanels, .microcement],
            [.patternedWallpaper, .fabricWallpaper, .livingWall]
        ]
        return groups[min(filter, groups.count - 1)].map {
            Item(title: $0.title.localized, imagePath: $0.imageName, image: nil, material: $0, custom: nil)
        }
    }

    override func configure(_ manager: GemeniPromptManager) {
        super.configure(manager)
        manager.updateSurfaceMaterial(selected?.material)
    }
}

/// A/07 · T5 New flooring: material, pattern (wood only), keep rugs. Layout: Tools.storyboard.
final class FloorToolViewController: SurfaceToolViewController {

    @IBOutlet private weak var patternTitleLabel: UILabel!
    @IBOutlet private weak var patternView: UIView!
    @IBOutlet private weak var patternKnob: UIView!
    @IBOutlet private weak var patternKnobLeading: NSLayoutConstraint!
    @IBOutlet private var patternControls: [DSPressableControl]!
    @IBOutlet private var patternLabels: [UILabel]!
    @IBOutlet private weak var rugsTitleLabel: UILabel!
    @IBOutlet private weak var rugsSubtitleLabel: UILabel!
    @IBOutlet private weak var rugsSwitch: UISwitch!

    private var pattern = 0

    override var filters: [String] { ["All", "Wood", "Tile", "Stone", "Carpet"] }

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "New flooring".localized
        subtitleLabel.text = "Furniture and rugs stay. Only the floor changes.".localized
        patternTitleLabel.text = "Pattern".localized
        rugsTitleLabel.text = "Keep rugs".localized
        rugsSubtitleLabel.text = "Rugs stay on top of the new floor".localized
        let titles = ["Straight", "Herringbone", "Chevron"]
        patternLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = titles[$0].localized }
        updatePatternVisibility()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applySegment(index: pattern, labels: patternLabels, knobLeading: patternKnobLeading, container: patternView,
                     count: 3, animated: false)
    }

    override func items(for filter: Int) -> [Item] {
        let groups: [[SurfaceMaterialOption]] = [
            SurfaceMaterialOption.options(for: .floor),
            [.naturalOak, .bleachedOak, .smokedOak, .parquet, .chevron, .americanWalnut, .greyOak, .widePlank, .ash,
             .modularParquet],
            [.cementTile, .hexagonTile, .moroccanTile, .terrazzo, .quartzVinyl],
            [.whiteMarble, .anthraciteSlate, .matteAnthracite, .terrazzo],
            [.loopPile, .plush, .sisal]
        ]
        return groups[min(filter, groups.count - 1)].map {
            Item(title: $0.title.localized, imagePath: $0.imageName, image: nil, material: $0, custom: nil)
        }
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        super.collectionView(collectionView, didSelectItemAt: indexPath)
        updatePatternVisibility()
    }

    /// Pattern only makes sense for wood planks.
    private func updatePatternVisibility() {
        let wood: Set<SurfaceMaterialOption> = [.naturalOak, .bleachedOak, .smokedOak, .americanWalnut, .greyOak,
                                                 .widePlank, .ash]
        let show = selected?.material.map { wood.contains($0) } ?? false
        UIView.animate(withDuration: 0.25) {
            self.patternTitleLabel.isHidden = !show
            self.patternView.isHidden = !show
            self.patternTitleLabel.alpha = show ? 1 : 0
            self.patternView.alpha = show ? 1 : 0
        }
    }

    @IBAction private func didTapPattern(_ sender: UIControl) {
        pattern = sender.tag
        DS.Haptic.selection()
        applySegment(index: pattern, labels: patternLabels, knobLeading: patternKnobLeading, container: patternView,
                     count: 3, animated: true)
    }

    override func configure(_ manager: GemeniPromptManager) {
        super.configure(manager)
        manager.updateSurfaceMaterial(selected?.material)
        var details: [String] = []
        if !patternView.isHidden { details.append(["Lay the planks straight.", "Lay the planks in a herringbone pattern.", "Lay the planks in a chevron pattern."][pattern]) }
        details.append(rugsSwitch.isOn ? "Keep existing rugs on top of the new floor." : "Remove rugs so the whole floor is visible.")
        manager.updateExtraDetails(details.joined(separator: " "))
    }
}
