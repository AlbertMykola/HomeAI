//
//  TypeViewController.swift
//  HomeAI
//
//  Created by Mykola Albert on 12.09.2025.
//

import UIKit

private struct Defaults {
    struct Text {
        static let chooseStyle = "Choose Type".localized
    }
}

class TypeViewController: UIViewController, PageStepDelegate, PromptManagerHolder {

    @IBOutlet weak private var collectionView: UICollectionView!
    
    var completion: (() -> Void)?
    var onProceedToNextStep: (() -> Void)?
    var canProceedToNextStep: Bool { selectedIndexPath != nil }
    
    private var selectedIndexPath: IndexPath?
    
    var selectedOption: DesignOption = .exterior
    var promptManager: GemeniPromptManager?

    private var dataSource: [StyleCellModel] = []
    private var amplitude = AmplitudeService.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = nil
        getData()
        
        collectionView.dataSource = self
        collectionView.delegate = self

        collectionView.register(UINib(nibName: "StyleCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "StyleCollectionViewCell")
        collectionView.allowsMultipleSelection = false

        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .vertical
            layout.sectionInset = UIEdgeInsets(top: 24, left: 16, bottom: 24, right: 16)
            layout.minimumLineSpacing = 20
            layout.minimumInteritemSpacing = 16
        }
        
        collectionView.applyPageFlowBottomInset(in: view)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.applyPageFlowBottomInset(in: view)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        syncCollectionSelection()
    }
    
    private func syncCollectionSelection() {
        let selectedPaths = Set(collectionView.indexPathsForSelectedItems ?? [])
        let expectedPath = selectedIndexPath.map { Set([$0]) } ?? []
        
        for indexPath in selectedPaths.subtracting(expectedPath) {
            collectionView.deselectItem(at: indexPath, animated: false)
            (collectionView.cellForItem(at: indexPath) as? StyleCollectionViewCell)?.isSelected = false
        }
        
        guard let selectedIndexPath else { return }
        collectionView.selectItem(at: selectedIndexPath, animated: false, scrollPosition: [])
        (collectionView.cellForItem(at: selectedIndexPath) as? StyleCollectionViewCell)?.isSelected = true
    }
    
    private func applySelection(at indexPath: IndexPath) {
        if let previous = selectedIndexPath, previous != indexPath {
            collectionView.deselectItem(at: previous, animated: false)
            (collectionView.cellForItem(at: previous) as? StyleCollectionViewCell)?.isSelected = false
        }
        
        selectedIndexPath = indexPath
        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        (collectionView.cellForItem(at: indexPath) as? StyleCollectionViewCell)?.isSelected = true
    }
    
    private func revertPendingSelection(at indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        (collectionView.cellForItem(at: indexPath) as? StyleCollectionViewCell)?.isSelected = false
        syncCollectionSelection()
    }
    
    private func notifyPageFlowCompleted() {
        completion?()
        onProceedToNextStep?()
    }
    
    private func getData() {
        switch selectedOption {
        case .exterior:
            ExteriorType.allCases.forEach {
                dataSource.append(StyleCellModel(name: $0.name, imageName: $0.icon))
            }
        case .garden:
            GardenType.allCases.forEach {
                dataSource.append(StyleCellModel(name: $0.name, imageName: $0.icon))
            }
        default: break
        }
    }
}


// MARK: - UICollectionViewDataSource
extension TypeViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        dataSource.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "StyleCollectionViewCell", for: indexPath) as? StyleCollectionViewCell else {
            return UICollectionViewCell()
        }

        let model = dataSource[safe: indexPath.row]
        guard let model else { return cell }
        cell.config(style: model)

        if let selectedIndexPath, selectedIndexPath == indexPath {
            cell.isSelected = true
        } else {
            cell.isSelected = false
        }
        return cell
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension TypeViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cellsPerRow: CGFloat = 3
        guard let layout = collectionViewLayout as? UICollectionViewFlowLayout else { return .zero }

        let sectionInsets = layout.sectionInset
        let interItemSpacing = layout.minimumInteritemSpacing

        let totalSpacing = sectionInsets.left + sectionInsets.right + interItemSpacing * (cellsPerRow - 1)
        let availableWidth = collectionView.bounds.width - totalSpacing

        let width = floor(availableWidth / cellsPerRow)
        let height = width * 130.0 / 110.0

        return CGSize(width: width, height: height)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        18
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        16
    }
}

// MARK: - UICollectionViewDelegate
extension TypeViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        hapticVibration()
        
        guard let model = dataSource[safe: indexPath.row] else { return }
        amplitude.logEvent(.chooseType(type: model.name))

        guard let manager = promptManager else {
            print("ПОМИЛКА: PromptManager не було передано у TypeViewController.")
            applySelection(at: indexPath)
            completion?()
            return
        }

        switch selectedOption {
        case .exterior:
            guard let selectedType = ExteriorType.allCases[safe: indexPath.row] else { return }
            applySelection(at: indexPath)
            manager.updateExteriorType(selectedType)
        case .garden:
            guard let selectedGardenType = GardenType.allCases[safe: indexPath.row] else { return }
            if selectedGardenType == .custom {
                (parent as? PageViewController)?.cancelPendingAutoAdvance()
                revertPendingSelection(at: indexPath)
                NavigationManager.shared.showPrompt(
                    promptManager: manager,
                    onSelect: { [weak self] _ in
                        manager.updateGardenType(.custom)
                        self?.applySelection(at: indexPath)
                        self?.notifyPageFlowCompleted()
                    },
                    onCancel: { [weak self] in
                        self?.syncCollectionSelection()
                    }
                )
                return
            }
            
            applySelection(at: indexPath)
            if selectedGardenType == .noStyle {
                manager.clearGardenType()
            } else {
                manager.updateGardenType(selectedGardenType)
            }
        case .interior, .reference, .replace, .newWalls, .newFlooring, .delete,
             .rearrange, .furnish, .floolPlan:
            applySelection(at: indexPath)
            break
        }
        
        completion?()
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) as? StyleCollectionViewCell {
            cell.isSelected = false
        }
    }
}
