import UIKit
import PhotosUI

/// A/07 · T3 Match a reference: "Style from" + "My room", Inspiration picks, what to copy.
/// Layout: ReferenceToolViewController.xib.
final class ReferenceToolViewController: ToolStepViewController {

    @IBOutlet private weak var referenceImageView: UIImageView!
    @IBOutlet private weak var referenceEmptyView: UIView!
    @IBOutlet private weak var roomImageView: UIImageView!
    @IBOutlet private weak var roomEmptyView: UIView!
    @IBOutlet private weak var clearReferenceButton: DSPressableControl!
    @IBOutlet private var slotLabels: [UILabel]!
    @IBOutlet private weak var inspirationTitleLabel: UILabel!
    @IBOutlet private weak var inspirationCollectionView: UICollectionView!
    @IBOutlet private weak var copyTitleLabel: UILabel!
    @IBOutlet private var copyChips: [DSChipControl]!

    private var reference: UIImage? { didSet { updateReference(animated: true) } }
    private var copies: Set<Int> = [0, 1, 3]
    private var inspirationPaths: [String] = []
    private static let copyTitles = ["Colors", "Materials", "Furniture", "Lighting", "Layout"]

    override var isReady: Bool { reference != nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "Match a reference".localized
        subtitleLabel.text = "We'll copy the look of any photo onto your room.".localized
        let slots = ["Style from", "My room"]
        slotLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = slots[$0].localized }
        inspirationTitleLabel.text = "Or pick from Inspiration".localized
        copyTitleLabel.text = "What to copy".localized
        setChipTitles(copyChips, Self.copyTitles.map(\.localized))
        applyCopies()
        roomImageView.image = session.photo
        roomEmptyView.isHidden = session.photo != nil
        loadInspiration()
        inspirationCollectionView.register(UINib(nibName: "MaterialTileCell", bundle: nil),
                                           forCellWithReuseIdentifier: MaterialTileCell.reuseID)
        if let layout = inspirationCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.itemSize = CGSize(width: 76, height: 100)
            layout.minimumLineSpacing = 8
        }
        inspirationCollectionView.dataSource = self
        inspirationCollectionView.delegate = self
        updateReference(animated: false)
    }

    private func loadInspiration() {
        let categories = (try? InspirationDataProvider.shared.loadInspirationsFromBundle()) ?? []
        inspirationPaths = Array(categories.flatMap { $0.items.map(\.image) }.prefix(12))
    }

    private func updateReference(animated: Bool) {
        let has = reference != nil
        let changes = {
            self.referenceImageView.image = self.reference
            self.referenceEmptyView.alpha = has ? 0 : 1
            self.clearReferenceButton.alpha = has ? 1 : 0
        }
        clearReferenceButton.isUserInteractionEnabled = has
        animated ? UIView.transition(with: referenceImageView, duration: 0.25, options: .transitionCrossDissolve,
                                     animations: changes) : changes()
        updateGenerateState()
    }

    @IBAction private func didTapReferenceSlot(_ sender: Any) {
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    @IBAction private func didTapClearReference(_ sender: Any) {
        DS.Haptic.light()
        reference = nil
    }

    @IBAction private func didTapCopyOption(_ sender: UIControl) {
        if copies.contains(sender.tag) { copies.remove(sender.tag) } else { copies.insert(sender.tag) }
        if copies.isEmpty { copies.insert(sender.tag) }
        DS.Haptic.selection()
        applyCopies()
    }

    private func applyCopies() {
        for chip in copyChips {
            let on = copies.contains(chip.tag)
            chip.setChipSelected(on, animated: true)
            chip.subviews.first?.subviews.compactMap { $0 as? UIImageView }.first?.isHidden = !on
        }
    }

    override func configure(_ manager: GemeniPromptManager) {
        super.configure(manager)
        if let reference { manager.updateReferenceImage(reference.normalizedForGeneration()) }
        let parts = copies.sorted().map { Self.copyTitles[$0].lowercased() }
        manager.updateExtraDetails("Copy only these aspects from the reference: \(parts.joined(separator: ", ")).")
    }
}

extension ReferenceToolViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            DispatchQueue.main.async { self?.reference = object as? UIImage }
        }
    }
}

extension ReferenceToolViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        inspirationPaths.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MaterialTileCell.reuseID, for: indexPath)
        (cell as? MaterialTileCell)?.configure(title: "", imagePath: inspirationPaths[indexPath.item], selected: false)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        DS.Haptic.selection()
        CatalogImage.load(inspirationPaths[indexPath.item]) { [weak self] image in
            if let image { self?.reference = image }
        }
    }
}
