import UIKit

private struct Defaults {
    struct Text {
        static let placement = "Describe your design style idea...".localized
        static let floorOptions = "Floor options".localized
        static let wallsOptions = "Wall options".localized
        static let custom = "Custom".localized
        static let clear = "Clear".localized
    }
}

final class SurfaceMaterialPickerViewController: UIViewController, PageStepDelegate, PromptManagerHolder {

    @IBOutlet weak private var imageView: UIImageView!
    
    @IBOutlet weak private var segmentControl: UISegmentedControl!
    
    @IBOutlet weak private var myCollectionView: UICollectionView!
    
    @IBOutlet weak private var placementLabel: UILabel!
    
    @IBOutlet weak private var promptContainerView: UIView!
    
    @IBOutlet weak private var generateButton: UIButton!
    @IBOutlet weak private var promptButton: UIButton!
    @IBOutlet weak private var clearButton: UIButton!
    
    @IBOutlet var byWidthConstraints: [NSLayoutConstraint]!
    
    var completion: (() -> Void)?
    
    var canProceedToNextStep: Bool {
        if isCustomSelected {
            return !(customPrompt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }
        return selectedMaterial != nil
    }
    var promptManager: GemeniPromptManager?
    
    private var selectedIndexPath: IndexPath?
    private var customPrompt: String?
    private var selectedMaterial: SurfaceMaterialOption?
    
    private var isCustomSelected: Bool { segmentControl.selectedSegmentIndex == 1 }
    
    private var optionItems: [StyleCellModel] = []
    private let amplitude = AmplitudeService.shared

    private var placement: SurfaceMaterialOption.Placement? {
        guard let option = promptManager?.designOption else { return nil }
        switch option {
        case .newFlooring: return .floor
        case .newWalls: return .wall
        default: return nil
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        amplitude.logEvent(.showSurfaceMaterialPicker(type: placement ?? .wall))
        
        // Hide generate button when embedded in PageViewController (it has its own button)
        if parent is UIPageViewController {
            generateButton.isHidden = true
        }
    }
    
    private func configureUI() {
        myCollectionView.dataSource = self
        myCollectionView.delegate = self
        myCollectionView.isScrollEnabled = true
        myCollectionView.alwaysBounceHorizontal = true
        myCollectionView.alwaysBounceVertical = false
        myCollectionView.showsHorizontalScrollIndicator = false
        myCollectionView.showsVerticalScrollIndicator = false
        myCollectionView.backgroundColor = .clear
        myCollectionView.allowsMultipleSelection = false
        myCollectionView.register( UINib(nibName: "StyleCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "StyleCollectionViewCell")
        
        if let layout = myCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
            layout.minimumLineSpacing = 12
            layout.minimumInteritemSpacing = 10

            layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
            layout.estimatedItemSize = .zero
        }
        
        clearButton.setTitle(Defaults.Text.clear, for: .normal)
        
        placementLabel.text = Defaults.Text.placement
        placementLabel.textColor = .secondaryLabel
        
        if let baseImage = promptManager?.baseImage {
            imageView.image = baseImage
        }
        
        reloadOptionItems()
        segmentControl.setTitle(placement == .floor ? Defaults.Text.floorOptions : Defaults.Text.wallsOptions, forSegmentAt: 0)
        segmentControl.setTitle(Defaults.Text.custom, forSegmentAt: 1)
        if segmentControl.numberOfSegments >= 2, segmentControl.selectedSegmentIndex == UISegmentedControl.noSegment {
            segmentControl.selectedSegmentIndex = 0
        }
        applySegmentUI()
        byWidthConstraints.forEach { $0.scaleConstantByWidth() }
    }
    
    private func reloadOptionItems() {
        guard let placement else {
            optionItems = []
            return
        }
        optionItems = SurfaceMaterialOption.options(for: placement).map {
            StyleCellModel(name: $0.title, imageName: $0.imageName)
        }
        
        selectedIndexPath = nil
        selectedMaterial = nil
        promptManager?.updateSurfaceMaterial(nil)
        myCollectionView.reloadData()
    }
    
    private func applySegmentUI() {
        let showCustom = isCustomSelected
        promptContainerView.isHidden = !showCustom
        myCollectionView.isHidden = showCustom
        
        clearButton.isHidden = !showCustom
        clearButton.isEnabled = showCustom && !(customPrompt?.isEmpty ?? true)
    }
    
    private func markCompletedIfPossible() {
        completion?()
    }
    
    @IBAction private func segmentAction(_ sender: UISegmentedControl) {
        applySegmentUI()
        markCompletedIfPossible()
    }
    
    @IBAction private func openPromptAction(_ sender: UIButton) {
        guard let manager = promptManager else { return }
        NavigationManager.shared.showPrompt(promptManager: manager, showSuggestions: false, initialPrompt: customPrompt) { [weak self] prompt in
            guard let self else { return }
            self.customPrompt = prompt
            self.placementLabel.text = prompt
            self.placementLabel.textColor = .label
            self.promptManager?.updateSurfaceCustomPrompt(prompt)
            self.applySegmentUI()
            self.markCompletedIfPossible()
        }
    }
    
    @IBAction private func clearAction(_ sender: UIButton) {
        customPrompt = nil
        placementLabel.text = Defaults.Text.placement
        placementLabel.textColor = .secondaryLabel
        promptManager?.updateSurfaceCustomPrompt(nil)
        applySegmentUI()
    }
    
    @IBAction private func generateAction(_ sender: UIButton) {
        guard let promptManager else { return }
        
        if isCustomSelected {
            let trimmed = customPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmed.isEmpty else {
                showAlert(title: "Action Required".localized, message: "Please enter a prompt.".localized)
                return
            }
            promptManager.updateSurfaceCustomPrompt(trimmed)
            promptManager.updateSurfaceMaterial(nil)
        } else {
            guard let selectedMaterial else {
                showAlert(title: "Action Required".localized, message: "Please select a material option.".localized)
                return
            }
            promptManager.updateSurfaceMaterial(selectedMaterial)
            promptManager.updateSurfaceCustomPrompt(nil)
        }
        
        if FreeGenerationManager.shared.canGenerateForFree || ApphudService.shared.hasActiveSubscription {
            NavigationManager.shared.showProcessing(manager: promptManager)
        } else {
            NavigationManager.shared.showPremium(placement: Constants.Keys.reachedLimit)
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK".localized, style: .default))
        present(alert, animated: true)
    }
}

extension SurfaceMaterialPickerViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        optionItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "StyleCollectionViewCell", for: indexPath) as? StyleCollectionViewCell else {
            return UICollectionViewCell()
        }
        
        let model = optionItems[indexPath.item]
        cell.config(style: model)
        
        if let selectedIndexPath, selectedIndexPath == indexPath {
            cell.isSelected = true
        } else {
            cell.isSelected = false
        }
        
        return cell
    }
    
    
}

extension SurfaceMaterialPickerViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let previous = selectedIndexPath, previous != indexPath {
            collectionView.deselectItem(at: previous, animated: false)
            if let prevCell = collectionView.cellForItem(at: previous) as? StyleCollectionViewCell {
                prevCell.isSelected = false
            }
        }
        
        selectedIndexPath = indexPath
        if let newCell = collectionView.cellForItem(at: indexPath) as? StyleCollectionViewCell {
            newCell.isSelected = true
        }

        if let placement {
            let options = SurfaceMaterialOption.options(for: placement)
            if indexPath.item < options.count {
                let selected = options[indexPath.item]
                selectedMaterial = selected
                promptManager?.updateSurfaceMaterial(selected)
            }
        }
        
        markCompletedIfPossible()
    }
}

extension SurfaceMaterialPickerViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {

        let width = CGFloat(110).scaledByHeight()
        let height = width * (137.0 / 110.0)
        return CGSize(width: floor(width), height: floor(height))
    }
    
}
