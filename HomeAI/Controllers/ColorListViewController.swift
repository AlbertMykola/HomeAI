import UIKit

class ColorListViewController: UIViewController, PageStepDelegate, PromptManagerHolder {

    @IBOutlet private weak var collectionView: UICollectionView!
    
    var completion: (() -> Void)?
    // Колір обов'язковий: дозволяємо перейти тільки після вибору
    var canProceedToNextStep: Bool { selectedColorIndexPath != nil }
    var onSelectColor: ((ColorType) -> Void)?
    var isPresentedModall = false
    
    private var selectedColorIndexPath: IndexPath?
    private var selectedModeIndexPath: IndexPath = IndexPath(item: 0, section: 0)
    private var selectedMode: DesignMode = .structuralPreservation
    
    private enum Section: Int, CaseIterable {
        case mode
        case colors
        
        var title: String {
            switch self {
            case .mode: return "".localized
            case .colors: return "Color Palette".localized
            }
        }
    }
    
    private var colors: [ColorType] = ColorType.allCases
    private let modes: [DesignMode] = [.structuralPreservation, .renovationDesign]
    private let amplitude = AmplitudeService.shared
    
    var promptManager: GemeniPromptManager?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Choose Color".localized
        amplitude.logEvent(.showColorList)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(UINib(nibName: "StyleCollectionViewCell", bundle: nil),
                                forCellWithReuseIdentifier: "StyleCollectionViewCell")
        collectionView.register(UINib(nibName: "ModeCollectionViewCell", bundle: nil),
                                forCellWithReuseIdentifier: "ModeCollectionViewCell")
        collectionView.register(SectionHeaderView.self,
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                                withReuseIdentifier: SectionHeaderView.reuseIdentifier)
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 150, right: 0)
        collectionView.allowsMultipleSelection = true
        
        // Початково встановлюємо Structural
        selectedMode = .structuralPreservation
        promptManager?.updateDesignMode(selectedMode)
        
        // Якщо колір уже збережений — підсвітимо
        if let currentColor = promptManager?.colorType,
           let idx = colors.firstIndex(of: currentColor) {
            selectedColorIndexPath = IndexPath(item: idx, section: Section.colors.rawValue)
            collectionView.selectItem(at: selectedColorIndexPath, animated: false, scrollPosition: [])
        }
        // Програмно відмічаємо Structural як вибраний
        collectionView.selectItem(at: selectedModeIndexPath, animated: false, scrollPosition: [])

        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .vertical
            layout.sectionInset = UIEdgeInsets(top: 24, left: 16, bottom: 24, right: 16)
            layout.minimumLineSpacing = 20
            layout.minimumInteritemSpacing = 16
        }
        
        // Крок вважаємо виконаним тільки якщо колір вже вибраний
        if selectedColorIndexPath != nil {
            markCompleted()
        }
    }
    
    private func markCompleted() {
        completion?()
    }
}

// MARK: - UICollectionViewDataSource
extension ColorListViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        Section.allCases.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .mode: return modes.count
        case .colors: return colors.count
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let section = Section(rawValue: indexPath.section) else { return UICollectionViewCell() }
        switch section {
        case .mode:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ModeCollectionViewCell", for: indexPath) as! ModeCollectionViewCell
            let mode = modes[indexPath.item]
            cell.configure(mode: mode)
            let isSelected = indexPath == selectedModeIndexPath
            cell.isSelected = isSelected
            return cell
        case .colors:
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "StyleCollectionViewCell", for: indexPath) as? StyleCollectionViewCell else {
                return UICollectionViewCell()
            }
            
            let style = colors[indexPath.item]
            let model = StyleCellModel(name: style.name, imageName: style.image, isNew: false)
            cell.config(style: model)
            if let selectedColorIndexPath, selectedColorIndexPath == indexPath {
                cell.isSelected = true
            } else {
                cell.isSelected = false
            }
            
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader,
              let section = Section(rawValue: indexPath.section),
              let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: SectionHeaderView.reuseIdentifier, for: indexPath) as? SectionHeaderView else {
            return UICollectionReusableView()
        }
        header.configure(title: section.title)
        return header
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension ColorListViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard let section = Section(rawValue: indexPath.section) else { return .zero }
        let layout = collectionViewLayout as! UICollectionViewFlowLayout
        let sectionInsets = layout.sectionInset
        let interItemSpacing = layout.minimumInteritemSpacing
        
        switch section {
        case .mode:
            // Дві картки в ряд
            let cellsPerRow: CGFloat = 2
            let totalSpacing = sectionInsets.left + sectionInsets.right + interItemSpacing * (cellsPerRow - 1)
            let availableWidth = collectionView.bounds.width - totalSpacing
            let width = floor(availableWidth / cellsPerRow)
            let height = width * 0.65
            return CGSize(width: width, height: height)
        case .colors:
            let cellsPerRow: CGFloat = 3
            let totalSpacing = sectionInsets.left + sectionInsets.right + interItemSpacing * (cellsPerRow - 1)
            let availableWidth = collectionView.bounds.width - totalSpacing
            let width = floor(availableWidth / cellsPerRow)
            let height = width * 130.0 / 110.0
            return CGSize(width: width, height: height)
        }
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
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        referenceSizeForHeaderInSection section: Int) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: 32)
    }
}

// MARK: - UICollectionViewDelegate
extension ColorListViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let section = Section(rawValue: indexPath.section) else { return }
        switch section {
        case .mode:
            // Deselect previous
            if selectedModeIndexPath != indexPath,
               let prevCell = collectionView.cellForItem(at: selectedModeIndexPath) as? ModeCollectionViewCell {
                prevCell.isSelected = false
                collectionView.deselectItem(at: selectedModeIndexPath, animated: false)
            }
            
            if let cell = collectionView.cellForItem(at: indexPath) as? ModeCollectionViewCell {
                cell.isSelected = true
            } else {
                // ensure state persists
                collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
            }
            
            selectedModeIndexPath = indexPath
            let mode = modes[indexPath.item]
            selectedMode = mode
            promptManager?.updateDesignMode(mode)
            // Не викликаємо markCompleted() тут - крок вважається виконаним тільки після вибору кольору
            
        case .colors:
            if let previous = selectedColorIndexPath, previous != indexPath,
               let prevCell = collectionView.cellForItem(at: previous) as? StyleCollectionViewCell {
                prevCell.isSelected = false
                collectionView.deselectItem(at: previous, animated: false)
            }

            if let newCell = collectionView.cellForItem(at: indexPath) as? StyleCollectionViewCell {
                newCell.isSelected = true
            }

            let palette = colors[indexPath.item]
            promptManager?.updateColor(palette)
            selectedColorIndexPath = indexPath

            if isPresentedModall, let onSelect = onSelectColor {
                onSelect(palette)
                dismiss(animated: true)
                return
            }

            // Позначаємо крок як виконаний після вибору кольору
            markCompleted()
        }
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        guard let section = Section(rawValue: indexPath.section) else { return }
        if section == .colors {
            if let cell = collectionView.cellForItem(at: indexPath) as? StyleCollectionViewCell {
                cell.isSelected = false
            }
            // Якщо знято вибір кольору, очищаємо selectedColorIndexPath
            if selectedColorIndexPath == indexPath {
                selectedColorIndexPath = nil
                promptManager?.updateColor(nil)
            }
        }
    }
}
