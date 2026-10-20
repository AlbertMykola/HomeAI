import UIKit

/// A/04 · W2 Which room is it? (Exterior: building type). Layout: Wizard.storyboard.
final class WizardRoomViewController: WizardStepViewController {

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var collectionView: UICollectionView!

    override var step: WizardSession.Step { .room }

    private var places: [WizardSession.Place] = []
    private var selectedIndex: Int?
    private var didAnimateCells = false

    override func viewDidLoad() {
        super.viewDidLoad()
        if session.option == .exterior {
            titleLabel.text = "What kind of building?".localized
            places = ExteriorType.allCases.map { .building($0) }
        } else {
            titleLabel.text = "Which room is it?".localized
            places = InteriorType.allCases.map { .room($0) }
        }
        subtitleLabel.text = session.detectedPlace != nil
            ? "We guessed from your photo. Tap to confirm.".localized
            : "Tap the one that matches your photo.".localized
        // Detected type goes first.
        if let detected = session.detectedPlace, let i = places.firstIndex(of: detected) {
            places.insert(places.remove(at: i), at: 0)
        }
        selectedIndex = session.place.flatMap { places.firstIndex(of: $0) }

        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.alpha = 0
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let metrics = OnboardingLayout(size: view.dsLayoutSize)
            let width = floor((collectionView.bounds.width - metrics.value(40 + 26)) / 3)
            let size = CGSize(width: width, height: metrics.value(112))
            if layout.itemSize != size { layout.itemSize = size }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didAnimateCells else { return }
        didAnimateCells = true
        collectionView.alpha = 1
        // Tiles "assemble": stagger 35 ms, scale 0.9 → 1 spring.
        for cell in collectionView.visibleCells.sorted(by: { ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX) })
            .enumerated() {
            DS.Motion.enter(cell.element, delay: Double(cell.offset) * 0.035, scale: 0.9, spring: true)
        }
    }
}

extension WizardRoomViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        places.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: WizardTileCell.reuseID, for: indexPath)
        guard let cell = cell as? WizardTileCell else { return cell }
        let place = places[indexPath.item]
        switch place {
        case .room(let room):
            cell.configure(title: room.name, image: room.icon)
        case .building(let building):
            cell.configure(title: building.name, image: nil)
            CatalogImage.load(building.icon) { [weak cell] image in
                cell?.setImage(image, fill: true)
            }
        }
        cell.setDetected(place == session.detectedPlace)
        cell.setSelected(indexPath.item == selectedIndex, animated: false)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let previous = selectedIndex
        selectedIndex = indexPath.item
        session.place = places[indexPath.item]
        DS.Haptic.selection()
        if let previous, let old = collectionView.cellForItem(at: IndexPath(item: previous, section: 0)) as? WizardTileCell {
            old.setSelected(false, animated: true)
        }
        (collectionView.cellForItem(at: indexPath) as? WizardTileCell)?.setSelected(true, animated: true)
        view.isUserInteractionEnabled = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.view.isUserInteractionEnabled = true
            self?.goToNextStep()
        }
    }
}
