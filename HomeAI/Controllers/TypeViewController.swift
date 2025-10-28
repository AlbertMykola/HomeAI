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
    var canProceedToNextStep: Bool { selectedIndexPath != nil }
    
    private var selectedIndexPath: IndexPath?
    
    var selectedOption: DesignOption = .exterior
    var promptManager: PromptManager?

    private var dataSource: [StyleCellModel] = []
    private var amplitude = AmplitudeService.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        title = Defaults.Text.chooseStyle
        getData()
        
        collectionView.dataSource = self
        collectionView.delegate = self

        collectionView.register(UINib(nibName: "StyleCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "StyleCollectionViewCell")
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 150, right: 0)
        collectionView.allowsMultipleSelection = false

        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .vertical
            layout.sectionInset = UIEdgeInsets(top: 24, left: 16, bottom: 24, right: 16)
            layout.minimumLineSpacing = 20
            layout.minimumInteritemSpacing = 16
        }
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
        case .reference: break
        case .interior: break
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

        let model = dataSource[indexPath.row]
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
        let layout = collectionViewLayout as! UICollectionViewFlowLayout

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
        if let previous = selectedIndexPath, previous != indexPath,
           let prevCell = collectionView.cellForItem(at: previous) as? StyleCollectionViewCell {
            prevCell.isSelected = false
            collectionView.deselectItem(at: previous, animated: false)
        }

        if let newCell = collectionView.cellForItem(at: indexPath) as? StyleCollectionViewCell {
            newCell.isSelected = true
        }
        
        amplitude.logEvent(.chooseType(type: dataSource[indexPath.row].name))

        let selectedModel = dataSource[indexPath.row]
        
        promptManager?.updateTypeSelection(selectedModel.name, for: selectedOption)

        selectedIndexPath = indexPath
        completion?()
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) as? StyleCollectionViewCell {
            cell.isSelected = false
        }
    }
}
