import UIKit

/// A/04 · W3 Pick a style. Layout: Wizard.storyboard.
final class WizardStyleViewController: WizardStepViewController {

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var chipScrollView: UIScrollView!
    @IBOutlet private var filterChips: [DSChipControl]!
    @IBOutlet private weak var collectionView: UICollectionView!

    override var step: WizardSession.Step { .style }

    private enum Filter: Int, CaseIterable { case all, popular, cozy, minimal, seasonal }

    private struct Item: Equatable {
        let style: WizardSession.Style?   // nil = Custom tile
        let title: String
        let imagePath: String?
        let popular: Bool
    }

    private var filter: Filter = .all
    private var items: [Item] = []
    private var didAnimate = false

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "Pick a style".localized
        subtitleLabel.text = "Swipe for more. You can mix styles later.".localized
        let chipTitles = ["All", "Popular", "Cozy", "Minimal", "Seasonal"]
        sortedChips.enumerated().forEach { index, chip in
            chip.subviews.first?.subviews.compactMap { $0 as? UILabel }.first?.text = chipTitles[index].localized
            chip.accessibilityLabel = chipTitles[index].localized
        }

        collectionView.dataSource = self
        collectionView.delegate = self
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handlePeek(_:)))
        collectionView.addGestureRecognizer(longPress)
        reloadItems()
        collectionView.alpha = 0
        chipScrollView.alpha = 0
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let metrics = OnboardingLayout(size: view.dsLayoutSize)
            let width = floor((collectionView.bounds.width - metrics.value(40 + 26)) / 3)
            layout.minimumLineSpacing = metrics.value(16)
            let size = CGSize(width: width, height: width * 136 / 109 + metrics.value(23))
            if layout.itemSize != size { layout.itemSize = size }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didAnimate else { return }
        didAnimate = true
        chipScrollView.alpha = 1
        collectionView.alpha = 1
        enter(sortedChips, from: 0.05, step: 0.05, dy: 0, dx: 24)
        let cells = collectionView.visibleCells.sorted { ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX) }
        enter(cells, from: 0.15, step: 0.04, dy: 0, scale: 0.92, spring: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
            (self?.collectionView.cellForItem(at: IndexPath(item: 0, section: 0)) as? WizardStyleCell)?.spinCustomIcon()
        }
    }

    private var sortedChips: [DSChipControl] { filterChips.sorted { $0.tag < $1.tag } }

    // MARK: Data

    private func reloadItems() {
        var list: [Item] = [Item(style: nil, title: "Custom".localized, imagePath: nil, popular: false)]
        switch session.option {
        case .exterior:
            list += StyleExteriorType.allCases.filter { $0 != .noStyle && $0 != .custom && matches(exterior: $0) }
                .map { Item(style: .exterior($0), title: $0.name, imagePath: $0.image, popular: [.modern, .contemporary].contains($0)) }
        case .garden:
            list += GardenType.allCases.filter { $0 != .noStyle && $0 != .custom && matches(garden: $0) }
                .map { Item(style: .garden($0), title: $0.name, imagePath: $0.icon, popular: [.cozy, .frontGarden].contains($0)) }
        default:
            list += Self.interiorOrder.filter(matches(interior:))
                .map { Item(style: .interior($0), title: $0.name, imagePath: $0.image, popular: Self.popularInterior.contains($0)) }
        }
        items = list
        collectionView.reloadData()
    }

    private static let popularInterior: [StyleInteriorType] = [.modern, .japanese, .scandinavian, .minimalist]
    private static var interiorOrder: [StyleInteriorType] {
        let first: [StyleInteriorType] = [.modern, .japanese, .scandinavian, .contemporary, .industrial, .bohemian,
                                          .wabiSabi, .mediterranean, .farmhouse, .artDeco, .loft]
        let rest = StyleInteriorType.allCases.filter { !first.contains($0) && $0 != .noStyle && $0 != .custom }
        return first + rest
    }

    private func matches(interior s: StyleInteriorType) -> Bool {
        switch filter {
        case .all: return true
        case .popular: return Self.popularInterior.contains(s) || [.contemporary, .industrial].contains(s)
        case .cozy: return [.bohemian, .farmhouse, .rustic, .wood, .vintage, .wabiSabi, .chocolate, .mediterranean].contains(s)
        case .minimal: return [.minimalist, .japanese, .scandinavian, .contemporary, .wabiSabi, .modern].contains(s)
        case .seasonal: return [.halloween, .creepy, .tropical, .pink, .cartoon].contains(s)
        }
    }

    private func matches(exterior s: StyleExteriorType) -> Bool {
        switch filter {
        case .all, .seasonal: return filter == .all
        case .popular: return [.modern, .contemporary, .minimalist, .scandinavian, .mediterranean].contains(s)
        case .cozy: return [.cottageStyle, .rustic, .craftsman, .tudor].contains(s)
        case .minimal: return [.minimalist, .modern, .hightech, .scandinavian].contains(s)
        }
    }

    private func matches(garden g: GardenType) -> Bool {
        switch filter {
        case .all: return true
        case .popular: return [.cozy, .frontGarden, .english, .mediterranean, .japaneese].contains(g)
        case .cozy: return [.cozy, .bohemian, .english, .retro].contains(g)
        case .minimal: return [.minimalist, .japaneese, .rockery].contains(g)
        case .seasonal: return [.christmas, .tropical].contains(g)
        }
    }

    // MARK: Actions

    @IBAction private func didTapFilter(_ sender: UIControl) {
        guard let f = Filter(rawValue: sender.tag), f != filter else { return }
        filter = f
        DS.Haptic.selection()
        sortedChips.forEach { $0.setChipSelected($0.tag == f.rawValue, animated: true) }
        UIView.transition(with: collectionView, duration: 0.2, options: .transitionCrossDissolve) {
            self.reloadItems()
        }
    }

    private func select(_ item: Item, at indexPath: IndexPath) {
        guard let style = item.style else {
            CustomStyleSheetViewController.present(from: self, initialText: {
                if case .custom(let text) = session.style { return text }
                return nil
            }()) { [weak self] text in
                self?.session.style = .custom(text)
                self?.collectionView.reloadData()
                self?.goToNextStep()
            }
            return
        }
        session.style = style
        DS.Haptic.selection()
        collectionView.visibleCells.compactMap { $0 as? WizardStyleCell }.forEach { $0.setChosen(false, animated: true) }
        (collectionView.cellForItem(at: indexPath) as? WizardStyleCell)?.setChosen(true, animated: true)
        view.isUserInteractionEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.view.isUserInteractionEnabled = true
            self?.goToNextStep()
        }
    }

    /// Long press → full-screen peek of the style preview.
    @objc private func handlePeek(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let indexPath = collectionView.indexPathForItem(at: gesture.location(in: collectionView)),
              let cell = collectionView.cellForItem(at: indexPath) as? WizardStyleCell,
              let image = cell.previewImage else { return }
        DS.Haptic.medium()
        let peek = AppStoryboard.instantiate(StylePreviewViewController.self)
        peek.image = image
        peek.modalTransitionStyle = .crossDissolve
        peek.modalPresentationStyle = .overFullScreen
        present(peek, animated: true)
    }
}

extension WizardStyleViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: WizardStyleCell.reuseID, for: indexPath)
        guard let cell = cell as? WizardStyleCell else { return cell }
        let item = items[indexPath.item]
        if item.style == nil {
            cell.configureCustom(title: item.title, chosen: { if case .custom = session.style { return true }; return false }())
        } else {
            cell.configure(title: item.title, imagePath: item.imagePath, popular: item.popular,
                           chosen: item.style == session.style)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        select(items[indexPath.item], at: indexPath)
    }
}

extension UIViewController {
    @objc func dismissPeek() { dismiss(animated: true) }
}
