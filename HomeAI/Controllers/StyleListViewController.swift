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
    var onProceedToNextStep: (() -> Void)?
    var onSelectStyle: ((UnifiedStyle) -> Void)?
    var onGenerate: (() -> Void)?
    var canProceedToNextStep: Bool { selectedIndexPath != nil }
    
    var promptManager: GemeniPromptManager?
    var selectedOption: DesignOption = .interior
    var isPresentedModall = false

    private var dataSource: [StyleCellModel] = []
    
    private var selectedIndexPath: IndexPath?
    private let imageCache = NSCache<NSString, UIImage>()
    private let generateButton = UIButton(type: .system)
    private var didSelectForGenerate = false

    override func viewDidLoad() {
        super.viewDidLoad()
        applyNavigationTitleForContext()
        getData()
        collectionView.dataSource = self
        collectionView.delegate = self

        collectionView.register(UINib(nibName: "StyleCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "StyleCollectionViewCell")
        collectionView.allowsMultipleSelection = false

        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .vertical
            layout.sectionInset = UIEdgeInsets(top: 24, left: 13, bottom: 24, right: 13)
            layout.minimumLineSpacing = 20
            layout.minimumInteritemSpacing = 10
        }
        
        if isPresentedModall {
            setupGenerateButton()
            updateGenerateButtonVisibility()
        }
        
        prefetchImages()
        applyCollectionBottomInset()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyCollectionBottomInset()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyNavigationTitleForContext()
        syncCollectionSelection()
    }

    private func applyNavigationTitleForContext() {
        if parent is PageViewController { return }
        title = "Choose Style".localized
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
    
    private func presentCustomStylePrompt(
        at indexPath: IndexPath,
        promptManager: GemeniPromptManager,
        onSuccess: @escaping () -> Void
    ) {
        (parent as? PageViewController)?.cancelPendingAutoAdvance()
        revertPendingSelection(at: indexPath)
        
        NavigationManager.shared.showPrompt(
            promptManager: promptManager,
            onSelect: { [weak self] _ in
                guard let self else { return }
                onSuccess()
                self.applySelection(at: indexPath)
                self.didSelectForGenerate = true
                
                if self.isPresentedModall {
                    self.updateGenerateButtonVisibility()
                } else {
                    self.notifyPageFlowCompleted()
                }
            },
            onCancel: { [weak self] in
                self?.syncCollectionSelection()
            }
        )
    }
    
    private func getData() {
        switch selectedOption {
        case .exterior:
            StyleExteriorType.allCases.forEach {
                dataSource.append(StyleCellModel(name: $0.name, imageName: $0.image))
            }
        case .interior, .furnish, .floolPlan:
            StyleInteriorType.allCases.forEach {
                dataSource.append(StyleCellModel(name: $0.name, imageName: $0.image, isNew: $0.isNew))
            }
        case .garden:
            GardenType.allCases.forEach {
                dataSource.append(StyleCellModel(name: $0.name, imageName: $0.icon))
            }
        default:
            break
        }
    }
    
    // Метод для предзавантаження зображень
    private func prefetchImages() {
        // Avoid aggressive remote prefetch in modal edit flow (New Style from details):
        // cells lazily load visible images, which is enough and prevents noisy network errors.
        guard !isPresentedModall else { return }
        let paths = dataSource.map { $0.imageName }
        for path in paths {
            // Skip explicit remote URLs for eager prefetch; load them on demand in cells.
            if let url = URL(string: path), let scheme = url.scheme, !scheme.isEmpty {
                continue
            }
            SharedImageLoader.shared.loadImage(path: path) { _ in }
        }
    }
    
    private func setupGenerateButton() {
        generateButton.translatesAutoresizingMaskIntoConstraints = false
        generateButton.setTitle("Generate".localized, for: .normal)
        generateButton.setTitleColor(.black, for: .normal)
        generateButton.backgroundColor = Constants.Colors.yellowPremium
        generateButton.layer.cornerRadius = 27
        generateButton.layer.masksToBounds = true
        generateButton.addTarget(self, action: #selector(generateTapped), for: .touchUpInside)
        view.addSubview(generateButton)
        
        NSLayoutConstraint.activate([
            generateButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -UICollectionView.PageFlowBottomInset.overlayButtonBottomOffset),
            generateButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            generateButton.widthAnchor.constraint(equalToConstant: 165),
            generateButton.heightAnchor.constraint(equalToConstant: UICollectionView.PageFlowBottomInset.overlayButtonHeight)
        ])
    }
    
    private func applyCollectionBottomInset() {
        collectionView.applyPageFlowBottomInset(
            in: view,
            overlayButton: isPresentedModall ? generateButton : nil
        )
    }
    
    private func updateGenerateButtonVisibility() {
        let shouldShow = isPresentedModall && didSelectForGenerate
        generateButton.isHidden = !shouldShow
        generateButton.isEnabled = shouldShow
        generateButton.alpha = shouldShow ? 1.0 : 0.5
        applyCollectionBottomInset()
    }
    
    @objc private func generateTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onGenerate?()
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

        guard let model = dataSource[safe: indexPath.item] else { return cell }
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
        guard let layout = collectionViewLayout as? UICollectionViewFlowLayout else { return .zero }

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
        10
    }
}

// MARK: - UICollectionViewDelegate
extension StyleListViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if parent is PageViewController {
            hapticVibration()
        }

        guard let selectedModel = dataSource[safe: indexPath.item] else { return }
        var unified: UnifiedStyle?

        switch selectedOption {
        case .interior, .furnish, .floolPlan:
            if let interiorStyle = StyleInteriorType.allCases.first(where: { $0.name == selectedModel.name }) {
                if interiorStyle == .custom {
                    presentCustomStylePrompt(
                        at: indexPath,
                        promptManager: promptManager ?? GemeniPromptManager()
                    ) { [weak self] in
                        let unified: UnifiedStyle = .interior(.custom)
                        self?.promptManager?.updateStyle(unified)
                        self?.onSelectStyle?(unified)
                    }
                    return
                }
                
                if interiorStyle == .noStyle {
                    promptManager?.clearInteriorStyle()
                    unified = .interior(.noStyle)
                } else {
                    let u: UnifiedStyle = .interior(interiorStyle)
                    promptManager?.updateStyle(u)
                    unified = u
                }
            }
        case .exterior:
            if let exteriorStyle = StyleExteriorType.allCases.first(where: { $0.name == selectedModel.name }) {
                if exteriorStyle == .custom {
                    presentCustomStylePrompt(
                        at: indexPath,
                        promptManager: promptManager ?? GemeniPromptManager()
                    ) { [weak self] in
                        let unified: UnifiedStyle = .exterior(.custom)
                        self?.promptManager?.updateStyle(unified)
                        self?.onSelectStyle?(unified)
                    }
                    return
                }
                
                if exteriorStyle == .noStyle {
                    promptManager?.clearExteriorStyle()
                    unified = .exterior(.noStyle)
                } else {
                    let u: UnifiedStyle = .exterior(exteriorStyle)
                    promptManager?.updateStyle(u)
                    unified = u
                }
            }
        case .garden:
            if let gardenStyle = GardenType.allCases.first(where: { $0.name == selectedModel.name }) {
                if gardenStyle == .custom {
                    let pm = promptManager ?? GemeniPromptManager()
                    pm.updateOption(.garden)
                    presentCustomStylePrompt(at: indexPath, promptManager: pm) { [weak self] in
                        pm.updateGardenType(.custom)
                        let u: UnifiedStyle = .garden(GardenType.custom.name)
                        self?.promptManager?.updateStyle(u)
                        self?.onSelectStyle?(u)
                    }
                    return
                }
                
                if gardenStyle == .noStyle {
                    promptManager?.clearGardenType()
                    unified = .garden(GardenType.noStyle.name)
                } else {
                    promptManager?.updateGardenType(gardenStyle)
                    unified = .garden(gardenStyle.name)
                }
            }
        default: break
        }

        applySelection(at: indexPath)
        didSelectForGenerate = true

        if isPresentedModall, let u = unified {
            onSelectStyle?(u)
            updateGenerateButtonVisibility()
            return
        }

        completion?()
    }


    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        
        if let cell = collectionView.cellForItem(at: indexPath) as? StyleCollectionViewCell {
            cell.isSelected = false
        }
    }
}
