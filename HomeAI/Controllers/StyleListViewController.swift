//
//  StyleListViewController.swift
//  HomeAI
//
//  Created by Mykola Albert on 11.09.2025.
//

import UIKit

final class StyleListViewController: UIViewController, PageStepDelegate, PromptManagerHolder {

    @IBOutlet private weak var collectionView: UICollectionView!
        
    var completion: (() -> Void)?
    var onSelectStyle: ((UnifiedStyle) -> Void)?
    var canProceedToNextStep: Bool { selectedIndexPath != nil }
    
    var promptManager: PromptManager?
    var selectedOption: DesignOption = .interior
    var isPresentedModall = false

    private var dataSource: [StyleCellModel] = []
    
    private var selectedIndexPath: IndexPath?
    private let imageCache = NSCache<NSString, UIImage>()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Choose Style".localized
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
        
        prefetchImages()
    }
    
    private func getData() {
        switch selectedOption {
            case .exterior: StyleExteriorType.allCases.forEach {
                dataSource.append(StyleCellModel(name: $0.name, imageName: $0.image))
            }
        case .interior:
            StyleInteriorType.allCases.forEach {
                dataSource.append(StyleCellModel(name: $0.name, imageName: $0.image))
            }
        default: break
        }
    }
    
    // Метод для предзавантаження зображень
    private func prefetchImages() {
        let paths = dataSource.map { $0.imageName }  // Шляхи до всіх зображень
        for path in paths {
            SharedImageLoader.shared.loadImage(path: path) { _ in }
        }
    }

}

// MARK: - UICollectionViewDataSource
extension StyleListViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        dataSource.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "StyleCollectionViewCell", for: indexPath) as? StyleCollectionViewCell else {
            return UICollectionViewCell()
        }

        let style = dataSource[indexPath.item]
        let model = StyleCellModel(name: style.name, imageName: style.imageName)
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
extension StyleListViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
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

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        18
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        16
    }
}

// MARK: - UICollectionViewDelegate
extension StyleListViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        if let previous = selectedIndexPath, previous != indexPath,
           let prevCell = collectionView.cellForItem(at: previous) as? StyleCollectionViewCell {
            prevCell.isSelected = false
            collectionView.deselectItem(at: previous, animated: false)
        }

        if let newCell = collectionView.cellForItem(at: indexPath) as? StyleCollectionViewCell {
            newCell.isSelected = true
        }

        let selectedModel = dataSource[indexPath.item]

        // Підготуємо єдиний об’єкт стилю для обох випадків
        var unified: UnifiedStyle?

        switch selectedOption {
        case .interior:
            if let interiorStyle = StyleInteriorType.allCases.first(where: { $0.name == selectedModel.name }) {
                let u: UnifiedStyle = .interior(interiorStyle)
                promptManager?.updateStyle(u)
                unified = u
            }
        case .exterior:
            if let exteriorStyle = StyleExteriorType.allCases.first(where: { $0.name == selectedModel.name }) {
                let u: UnifiedStyle = .exterior(exteriorStyle)
                promptManager?.updateStyle(u)
                unified = u
            }
        case .garden:
            // Аналогічно для garden, якщо буде GardenStyleType
            break
        case .reference:
            // Аналогічно, якщо потрібна логіка
            break
        }

        selectedIndexPath = indexPath

        // Якщо показано модально і є колбек — повертаємо вибір і закриваємо модалку
        if isPresentedModall, let u = unified, let onSelect = onSelectStyle {
            onSelect(u)
            dismiss(animated: true) // Закриває модально презентований контролер
            return
        }

        // Інакше — зберігаємо поточну поведінку
        completion?()
    }


    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        
        if let cell = collectionView.cellForItem(at: indexPath) as? StyleCollectionViewCell {
            cell.isSelected = false
        }
    }
}
