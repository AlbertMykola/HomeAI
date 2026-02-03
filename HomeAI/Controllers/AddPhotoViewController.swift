import UIKit

private struct Defaults {
    struct Text {
        static let addPhoto = "Add a photo".localized
        static let headline = "Upload a photo of your current room.".localized
        static let headlineExterior = "Upload a photo of your current facade.".localized
        static let headlineGarden = "Upload a photo of your current outdoor space.".localized
        static let headlineReference = "Upload a photo of your current design.".localized
        static let headlineReplace = "Upload a photo of your current room.".localized
        static let headlineNewFlooring = "Upload a photo to redesign your floor".localized
        static let headlineNewWalls = "Upload a photo of your current walls.".localized
        static let getDreamDesign = "Get your dream design".localized
        static let takePhoto = "Take a photo".localized
        static let selectGallery = "Select from gallery".localized
        static let cancel = "Cancel".localized
        static let next = "Next".localized
        static let photoTips = "Photo Tips".localized

        static func headline(for option: DesignOption) -> String {
            switch option {
            case .interior:
                return headline
            case .exterior:
                return headlineExterior
            case .garden:
                return headlineGarden
            case .reference:
                return headlineReference
            case .replace:
                return headlineReplace
            case .newFlooring:
                return headlineNewFlooring
            case .newWalls:
                return headlineNewWalls
            case .delete:
                return headlineReplace
            }
        }
    }
}

final class AddPhotoViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PageStepDelegate, PromptManagerHolder {
    
    @IBOutlet weak private var descriptionLabel: UILabel!
    @IBOutlet weak private var headlineLabel: UILabel!
    
    @IBOutlet weak private var containerView: UIView!
    
    @IBOutlet private var constraintsHeight: [NSLayoutConstraint]!
    @IBOutlet private var constraintsWidth: [NSLayoutConstraint]!
    
    @IBOutlet weak private var containerImageView: UIImageView!
    
    @IBOutlet weak private var suggestionsCollectionVIew: UICollectionView!
    
    @IBOutlet weak private var photoButton: UIButton!
    @IBOutlet weak private var infoButton: UIButton!
    @IBOutlet weak private var nextButton: UIButton!
    
    private var deleteImageButton: UIButton?
    
    var completion: (() -> Void)?
    
    var canProceedToNextStep: Bool {
        return containerImageView.image != nil
    }
    
    var promptManager: GemeniPromptManager?
    var referenceType: ReferenceScreenType? = nil
    
    private let amplitude = AmplitudeService.shared
    private let imageService = ImageStorageService()
    private var selectedIndexPath: IndexPath?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if referenceType != nil && promptManager == nil {
            promptManager = GemeniPromptManager()
            promptManager?.updateOption(.reference)
        } else if let manager = promptManager {

        }
        
        infoButton.setTitle(Defaults.Text.photoTips, for: .normal)
        amplitude.logEvent(.showAddPhoto)
        configure()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        selectedIndexPath = nil
        suggestionsCollectionVIew.reloadData()
        updateInfoButtonVisibility()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        containerView.addDashedBorder(color: .label, lineWidth: 1, dashPattern: [6, 4], cornerRadius: 16)
        nextButton.layer.cornerRadius = nextButton.frame.height / 2
        infoButton.layer.cornerRadius = infoButton.frame.height / 2
        infoButton.clipsToBounds = true

        nextButton.backgroundColor = Constants.Colors.yellowPremium
        
        configurePhotoButton()
        setupDeleteButton()
    }
    
    private func configurePhotoButton() {
        photoButton.layer.shadowColor = UIColor.black.cgColor
        photoButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        photoButton.layer.shadowRadius = 8
        photoButton.layer.shadowOpacity = 0.15
        photoButton.layer.masksToBounds = false
        
        if var config = photoButton.configuration {
            let symbolConfig = UIImage.SymbolConfiguration(pointSize: 32, weight: .regular, scale: .medium)
            config.preferredSymbolConfigurationForImage = symbolConfig
            config.title = nil
            config.imagePadding = 0
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
            photoButton.configuration = config
        }
    }
    
    private func setupDeleteButton() {
        guard deleteImageButton == nil else { return }
        
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "minus"), for: .normal)
        button.tintColor = .systemRed
        button.backgroundColor = UIColor.white
        button.layer.cornerRadius = 15
        button.layer.masksToBounds = true
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.systemRed.cgColor
        button.addTarget(self, action: #selector(deleteImageTapped), for: .touchUpInside)
        
        containerImageView.superview?.addSubview(button)
        
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: containerImageView.topAnchor, constant: 8),
            button.trailingAnchor.constraint(equalTo: containerImageView.trailingAnchor, constant: -8),
            button.widthAnchor.constraint(equalToConstant: 30),
            button.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        deleteImageButton = button
        updateDeleteButtonVisibility()
    }
    
    private func updateDeleteButtonVisibility() {
        let hasImage = containerImageView.image != nil
        deleteImageButton?.isHidden = !hasImage
    }
    
    @objc private func deleteImageTapped() {
        containerImageView.image = nil
        containerView.isHidden = false
        selectedIndexPath = nil
        suggestionsCollectionVIew.reloadData()
        updateInfoButtonVisibility()
        updateDeleteButtonVisibility()
        
        if let manager = promptManager {
            if manager.designOption == .replace {
                manager.clearBaseImage()
            } else {
                referenceType == .reference ? manager.clearReferenceImage() : manager.clearBaseImage()
            }
        }
        
        // Notify parent (PageViewController) that state has changed
        completion?()
    }
    
    private func configure() {
        headlineLabel.text = Defaults.Text.headline
        descriptionLabel.text = Defaults.Text.getDreamDesign
        constraintsHeight.forEach { $0.scaleConstant() }
        constraintsWidth.forEach { $0.scaleConstantByWidth() }
        nextButton.setTitle(Defaults.Text.next, for: .normal)
        updateText()
        configureSuggestionsCollectionView()
        updateInfoButtonVisibility()
        
        title = Defaults.Text.addPhoto
    }
    
    private func configureSuggestionsCollectionView() {
        
        suggestionsCollectionVIew.register(
            UINib(nibName: "SuggestionCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: SuggestionCollectionViewCell.reuseIdentifier
        )
        
        if let layout = suggestionsCollectionVIew.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
            layout.minimumLineSpacing = 12
            layout.minimumInteritemSpacing = 0
            layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
            layout.estimatedItemSize = .zero
            let width = CGFloat(110).scaledByHeight()
            let height = CGFloat(130).scaledByHeight()
            layout.itemSize = CGSize(width: width, height: height)
        }
        
        suggestionsCollectionVIew.delegate = self
        suggestionsCollectionVIew.dataSource = self
        suggestionsCollectionVIew.showsHorizontalScrollIndicator = false
        suggestionsCollectionVIew.backgroundColor = .clear
        suggestionsCollectionVIew.allowsMultipleSelection = false
    }

    private func updateText() {
        if let type = referenceType {
            containerImageView.image = nil
            headlineLabel.text = type.titleText
            descriptionLabel.text = type.subtitleText
            nextButton.isHidden = false
            containerView.isHidden = false
            return
        }

        if let option = promptManager?.designOption {
            headlineLabel.text = Defaults.Text.headline(for: option)
        }
    }

    private func updateInfoButtonVisibility() {
        let hasImage = containerImageView.image != nil
        infoButton?.isHidden = hasImage
        updateDeleteButtonVisibility()
    }
    
    @objc
    private func didTapPro() {
        amplitude.logEvent(.pressPro)
        NavigationManager.shared.showPremium(placement: Constants.Keys.optionPlacememt)
    }
    
    @IBAction private func addPhotoAction(_ sender: UIButton) {
        amplitude.logEvent(.pressAddPhoto)
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            let alert = UIAlertController(title: Defaults.Text.addPhoto, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: Defaults.Text.takePhoto, style: .default, handler: { [weak self] _ in
                self?.amplitude.logEvent(.takeAPhoto)
                self?.presentImagePicker(sourceType: .camera)
            }))
            alert.addAction(UIAlertAction(title: Defaults.Text.selectGallery, style: .default, handler: { [weak self] _ in
                self?.amplitude.logEvent(.selectGallery)
                self?.presentImagePicker(sourceType: .photoLibrary)
            }))
            alert.addAction(UIAlertAction(title: Defaults.Text.cancel, style: .cancel, handler: nil))
            present(alert, animated: true)
        } else {
            let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                alert.addAction(UIAlertAction(title: Defaults.Text.takePhoto, style: .default, handler: { [weak self] _ in
                    self?.amplitude.logEvent(.takeAPhoto)
                    self?.presentImagePicker(sourceType: .camera)
                }))
            }
            alert.addAction(UIAlertAction(title: Defaults.Text.selectGallery, style: .default, handler: { [weak self] _ in
                self?.amplitude.logEvent(.selectGallery)
                self?.presentImagePicker(sourceType: .photoLibrary)
            }))
            alert.addAction(UIAlertAction(title: Defaults.Text.cancel, style: .cancel, handler: nil))
            present(alert, animated: true)
        }
    }
    
    @IBAction private func nextAction(_ sender: UIButton) {
        amplitude.logEvent(.nextButton)
        guard let promptManager = promptManager else { return }
        if referenceType == .currentRoom {
            if parent is UIPageViewController {
                completion?()
            } else {
                referenceType = .reference
                updateText()
            }
        } else if promptManager.designOption == .replace {
            completion?()
        } else {
            // Перевірка підписки та ліміту безкоштовних генерацій перед показом екрану обробки
            if FreeGenerationManager.shared.canGenerateForFree || ApphudService.shared.hasActiveSubscription {
            NavigationManager.shared.showProcessing(manager: promptManager)
            } else {
                NavigationManager.shared.showPremium(placement: Constants.Keys.reachedLimit)
            }
        }
    }
    
    @IBAction func infoAction(_ sender: UIButton) {
        let option = promptManager?.designOption ?? .interior
        NavigationManager.shared.showPhotoTips(designOption: option)
    }
    
    
    private func presentImagePicker(sourceType: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        picker.allowsEditing = false
        present(picker, animated: true)
    }
    
    // MARK: - UIImagePickerControllerDelegate
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        if let image = info[.originalImage] as? UIImage {
            containerImageView.image = image
            if let manager = promptManager, manager.designOption == .replace {
                manager.updateBaseImage(image)
            } else {
                referenceType == .reference ? promptManager?.updateReferenceImage(image) : promptManager?.updateBaseImage(image)
            }
            containerImageView.contentMode = .scaleAspectFill
            containerImageView.clipsToBounds = true
            containerView.isHidden = true
            completion?()
            updateInfoButtonVisibility()
            updateDeleteButtonVisibility()
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

// MARK: - UICollectionViewDataSource
extension AddPhotoViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        suggestions.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: SuggestionCollectionViewCell.reuseIdentifier,
            for: indexPath
        ) as! SuggestionCollectionViewCell
        
        let template = suggestions[indexPath.item]
        cell.configure(with: template)
        
        if let selectedIndexPath, selectedIndexPath == indexPath {
            cell.isSelected = true
        } else {
            cell.isSelected = false
        }
        
        return cell
    }
    
    private var suggestions: [SuggestionTemplateType] {
        let option = promptManager?.designOption ?? .interior
        return SuggestionTemplateType.suggestions(for: option)
    }
}

// MARK: - UICollectionViewDelegate
extension AddPhotoViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let previous = selectedIndexPath, previous != indexPath,
           let prevCell = collectionView.cellForItem(at: previous) as? SuggestionCollectionViewCell {
            prevCell.isSelected = false
            collectionView.deselectItem(at: previous, animated: false)
        }
        
        if let newCell = collectionView.cellForItem(at: indexPath) as? SuggestionCollectionViewCell {
            newCell.isSelected = true
        }
        
        selectedIndexPath = indexPath
        
        let template = suggestions[indexPath.item]
        
        imageService.fetchImage(path: template.imagePath) { [weak self] image in
            guard let self = self, let image = image else { return }
            
            DispatchQueue.main.async {
                self.containerImageView.image = image
                self.containerImageView.contentMode = .scaleAspectFill
                self.containerImageView.clipsToBounds = true
                
                if let manager = self.promptManager {
                    if manager.designOption == .replace {
                        manager.updateBaseImage(image)
                    } else {
                        self.referenceType == .reference ? manager.updateReferenceImage(image) : manager.updateBaseImage(image)
                    }
                }
                
                self.containerView.isHidden = true
                self.updateInfoButtonVisibility()
                self.updateDeleteButtonVisibility()
                
                self.completion?()
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) as? SuggestionCollectionViewCell {
            cell.isSelected = false
        }
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension AddPhotoViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = CGFloat(110).scaledByHeight()
        let height = CGFloat(130).scaledByHeight()
        return CGSize(width: width, height: height)
    }
}
