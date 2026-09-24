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
        static let headlineRearrange = "Upload a photo of your current layout".localized
        static let headlineFurnish = "Upload a photo of your empty room".localized
        static let headlineFloorPlan = "Upload a photo of your floor plan".localized
        static let getDreamDesign = "Get your dream design".localized
        static let takePhoto = "Take a photo".localized
        static let selectGallery = "Select from gallery".localized
        static let cancel = "Cancel".localized
        static let next = "Next".localized
        static let photoTips = "Photo Tips".localized
        static let leftRearrangeTitle = "Rearrange Only".localized
        static let leftRearrangeDescription = "New layout with same furniture".localized
        static let rightRearrangeTitle = "Rearrange & Refresh".localized
        static let rightRearrangeDescription = "New layout with small furniture change".localized

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
            case .rearrange:
                return headlineRearrange
            case .furnish:
                return headlineFurnish
            case .floolPlan:
                return headlineFloorPlan
            }
        }
    }
    
    struct Color {
        static let leftContainerStart = UIColor(red: 255/255, green: 198/255, blue: 58/255, alpha: 1)
        static let leftContainerEnd = UIColor(red: 245/255, green: 175/255, blue: 1/255, alpha: 1)
        static let rightContainerStart = UIColor(red: 101/255, green: 205/255, blue: 30/255, alpha: 1)
        static let rightContainerEnd = UIColor(red: 75/255, green: 182/255, blue: 24/255, alpha: 1)
        static let infoButtonBackground = UIColor(red: 221/255, green: 197/255, blue: 223/255, alpha: 1)
    }

    struct Layout {
        static func rearrangeCardCornerRadius(for bounds: CGRect) -> CGFloat {
            min(40, max(0, floor(bounds.height / 2)))
        }
    }
}

final class AddPhotoViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PageStepDelegate, PromptManagerHolder {
    
    @IBOutlet weak private var rearrangeRightContainerView: UIView!
    @IBOutlet weak private var rearrangeRightDescriptionLabel: UILabel!
    @IBOutlet weak private var rearrangeRightTitleLabel: UILabel!
    @IBOutlet weak private var rearrangeLeftDescriptionLabel: UILabel!
    @IBOutlet weak private var rearrangeLeftTitleLabel: UILabel!
    
    @IBOutlet weak private var descriptionLabel: UILabel!
    @IBOutlet weak private var headlineLabel: UILabel!
    
    @IBOutlet weak private var rearrangeLeftContainerView: UIView!
    @IBOutlet weak private var containerView: UIView!
    
    @IBOutlet private var constraintsHeight: [NSLayoutConstraint]!
    @IBOutlet private var constraintsWidth: [NSLayoutConstraint]!
    
    @IBOutlet weak private var containerImageView: UIImageView!
    
    @IBOutlet weak private var suggestionsCollectionVIew: UICollectionView!
    
    @IBOutlet weak private var photoButton: UIButton!
    @IBOutlet weak private var infoButton: UIButton!
    @IBOutlet weak private var nextButton: UIButton!
    
    private var deleteImageButton: UIButton?
    private var didInstallRearrangeGestures = false

    var completion: (() -> Void)?
    
    var canProceedToNextStep: Bool {
        guard containerImageView.image != nil else { return false }
        if promptManager?.designOption == .rearrange {
            return promptManager?.rearrangeSubOption != nil
        }
        return true
    }
    
    var promptManager: GemeniPromptManager?
    var referenceType: ReferenceScreenType? = nil
    
    private let amplitude = AmplitudeService.shared
    private let imageService = ImageStorageService()
    private var selectedIndexPath: IndexPath?

    private enum RearrangeCardSide {
        case left
        case right
    }

    private var rearrangeCardSelection: RearrangeCardSide? {
        didSet { updateRearrangeCardHighlight() }
    }
    
    private var isEmbeddedInPageFlow: Bool {
        parent is PageViewController || parent is ReplaceObjectPageViewController
    }

    private var shouldHideEmbeddedNextButton: Bool {
        isEmbeddedInPageFlow || referenceType != nil
    }

    /// Шаблонні фото нижче (карусель).
    private var suggestionTemplates: [SuggestionTemplateType] {
        let option = promptManager?.designOption ?? .interior
        return SuggestionTemplateType.suggestions(for: option, referenceScreen: referenceType)
    }

    /// Ряд карток «Rearrange» замість каруселі.
    private var isRearrangeAddPhotoLayout: Bool {
        referenceType == nil && promptManager?.designOption == .rearrange
    }

    private var shouldShowSuggestionCarousel: Bool {
        !isRearrangeAddPhotoLayout && !suggestionTemplates.isEmpty
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if referenceType != nil && promptManager == nil {
            promptManager = GemeniPromptManager()
            promptManager?.updateOption(.reference)
        } else if let manager = promptManager {

        }
        
        configureInfoButton()
        amplitude.logEvent(.showAddPhoto)
        configure()
        installRearrangeGesturesIfNeeded()
        updateRearrangeAndSuggestionsAppearance()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        selectedIndexPath = nil
        suggestionsCollectionVIew.reloadData()
        updateInfoButtonVisibility()
        updateRearrangeAndSuggestionsAppearance()
        updateEmbeddedNextButtonVisibility()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentPhotoTipsOnFirstVisitIfNeeded()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        containerView.addDashedBorder(color: .label, lineWidth: 1, dashPattern: [6, 4], cornerRadius: 16)
        nextButton.layer.cornerRadius = nextButton.frame.height / 2
        infoButton.layer.cornerRadius = infoButton.frame.height / 2
        infoButton.clipsToBounds = true

        nextButton.backgroundColor = Constants.Colors.yellowPremium
        
        configureInfoButton()
        configurePhotoButton()
        setupDeleteButton()
        applyRearrangeGradientLayout()
    }
    
    private func configureInfoButton() {
        let foregroundColor = UIColor.black
        let font = UIFont(name: "Geologica-ExtraLight", size: 15) ?? UIFont.systemFont(ofSize: 15, weight: .light)
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let icon = UIImage(systemName: "info.circle", withConfiguration: symbolConfig)?
            .withTintColor(foregroundColor, renderingMode: .alwaysOriginal)

        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = foregroundColor
        config.background.backgroundColor = Defaults.Color.infoButtonBackground
        config.background.cornerRadius = max(infoButton.bounds.height / 2, 0)
        config.image = icon
        config.imagePlacement = .leading
        config.imagePadding = 6
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 12)

        var attributedTitle = AttributedString(Defaults.Text.photoTips)
        attributedTitle.font = font
        attributedTitle.foregroundColor = foregroundColor
        config.attributedTitle = attributedTitle

        infoButton.configuration = config
        infoButton.tintColor = foregroundColor
        infoButton.backgroundColor = .clear
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
        
        completion?()
    }
    
    private func configure() {
        rearrangeLeftTitleLabel.text = Defaults.Text.leftRearrangeTitle
        rearrangeLeftDescriptionLabel.text = Defaults.Text.leftRearrangeDescription
        rearrangeRightTitleLabel.text = Defaults.Text.rightRearrangeTitle
        rearrangeRightDescriptionLabel.text = Defaults.Text.rightRearrangeDescription
        [rearrangeLeftTitleLabel, rearrangeLeftDescriptionLabel, rearrangeRightTitleLabel, rearrangeRightDescriptionLabel]
            .forEach { $0.numberOfLines = 0 }
        headlineLabel.text = Defaults.Text.headline
        descriptionLabel.text = Defaults.Text.getDreamDesign
        constraintsHeight.forEach { $0.scaleConstant() }
        constraintsWidth.forEach { $0.scaleConstantByWidth() }
        nextButton.setTitle(Defaults.Text.next, for: .normal)
        updateText()
        updateEmbeddedNextButtonVisibility()
        configureSuggestionsCollectionView()
        updateInfoButtonVisibility()

        if parent is PageViewController == false {
            title = Defaults.Text.addPhoto
        }
    }


    private func installRearrangeGesturesIfNeeded() {
        guard !didInstallRearrangeGestures else { return }
        didInstallRearrangeGestures = true
        rearrangeLeftContainerView.isUserInteractionEnabled = true
        rearrangeRightContainerView.isUserInteractionEnabled = true
        rearrangeLeftContainerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(rearrangeLeftTapped)))
        rearrangeRightContainerView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(rearrangeRightTapped)))
    }

    @objc private func rearrangeLeftTapped() {
        if parent is PageViewController {
            hapticVibration()
        }
        promptManager?.updateRearrangeSubOption(.sameFurnitureOnly)
        rearrangeCardSelection = .left
        completion?()
    }

    @objc private func rearrangeRightTapped() {
        if parent is PageViewController {
            hapticVibration()
        }
        promptManager?.updateRearrangeSubOption(.rearrangeAndRefresh)
        rearrangeCardSelection = .right
        completion?()
    }

    private func updateRearrangeAndSuggestionsAppearance() {
        rearrangeLeftContainerView.isHidden = !isRearrangeAddPhotoLayout
        rearrangeRightContainerView.isHidden = !isRearrangeAddPhotoLayout

        if isRearrangeAddPhotoLayout {
            // Залишаємо ту ж геометрію каруселі в Auto Layout — лише ховаємо візуально, щоб верхній блок не «плив».
            suggestionsCollectionVIew.isHidden = false
            suggestionsCollectionVIew.alpha = 0
            suggestionsCollectionVIew.isUserInteractionEnabled = false
            view.bringSubviewToFront(rearrangeLeftContainerView)
            view.bringSubviewToFront(rearrangeRightContainerView)
        } else {
            suggestionsCollectionVIew.alpha = 1
            suggestionsCollectionVIew.isUserInteractionEnabled = true
            suggestionsCollectionVIew.isHidden = !shouldShowSuggestionCarousel
            if rearrangeCardSelection != nil {
                rearrangeCardSelection = nil
            }
        }

        if isRearrangeAddPhotoLayout {
            syncRearrangeSelectionFromManager()
        }
    }

    private func syncRearrangeSelectionFromManager() {
        guard isRearrangeAddPhotoLayout else { return }
        switch promptManager?.rearrangeSubOption {
        case .sameFurnitureOnly:
            rearrangeCardSelection = .left
        case .rearrangeAndRefresh:
            rearrangeCardSelection = .right
        case nil:
            rearrangeCardSelection = nil
        }
    }

    private func updateRearrangeCardHighlight() {
        applyRearrangeContainerHighlight(rearrangeLeftContainerView, selected: rearrangeCardSelection == .left)
        applyRearrangeContainerHighlight(rearrangeRightContainerView, selected: rearrangeCardSelection == .right)
    }

    private func applyRearrangeContainerHighlight(_ container: UIView, selected: Bool) {
        guard isRearrangeAddPhotoLayout else { return }
        container.layer.borderWidth = selected ? 2 : 0
        container.layer.borderColor = selected ? UIColor.label.cgColor : UIColor.clear.cgColor
    }

    /// Горизонтальні градієнти на картках `.rearrange` (або їх корекція під розмір у `layout`).
    private func applyRearrangeGradientLayout() {
        guard isRearrangeAddPhotoLayout,
              rearrangeLeftContainerView.bounds.width > 1,
              rearrangeLeftContainerView.bounds.height > 1,
              rearrangeRightContainerView.bounds.width > 1,
              rearrangeRightContainerView.bounds.height > 1 else { return }

        rearrangeLeftContainerView.backgroundColor = .clear
        rearrangeRightContainerView.backgroundColor = .clear

        rearrangeLeftContainerView.layer.cornerRadius = Defaults.Layout.rearrangeCardCornerRadius(for: rearrangeLeftContainerView.bounds)
        rearrangeRightContainerView.layer.cornerRadius = Defaults.Layout.rearrangeCardCornerRadius(for: rearrangeRightContainerView.bounds)
        rearrangeLeftContainerView.layer.masksToBounds = true
        rearrangeRightContainerView.layer.masksToBounds = true

        rearrangeLeftContainerView.setGradient(
            stops: [
                UIView.GradientStop(percent: 0, color: Defaults.Color.leftContainerStart),
                UIView.GradientStop(percent: 100, color: Defaults.Color.leftContainerEnd)
            ],
            direction: .horizontal
        )
        rearrangeRightContainerView.setGradient(
            stops: [
                UIView.GradientStop(percent: 0, color: Defaults.Color.rightContainerStart),
                UIView.GradientStop(percent: 100, color: Defaults.Color.rightContainerEnd)
            ],
            direction: .horizontal
        )

        rearrangeLeftContainerView.updateGradientFrame()
        rearrangeRightContainerView.updateGradientFrame()

        rearrangeLeftContainerView.bringSubviewToFront(rearrangeLeftTitleLabel)
        rearrangeLeftContainerView.bringSubviewToFront(rearrangeLeftDescriptionLabel)
        rearrangeRightContainerView.bringSubviewToFront(rearrangeRightTitleLabel)
        rearrangeRightContainerView.bringSubviewToFront(rearrangeRightDescriptionLabel)
        updateRearrangeCardHighlight()
    }
    
    private func configureSuggestionsCollectionView() {
        
        suggestionsCollectionVIew.register(
            UINib(nibName: "SuggestionCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: SuggestionCollectionViewCell.reuseIdentifier)
        
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
            nextButton.isHidden = shouldHideEmbeddedNextButton
            containerView.isHidden = false
            return
        }

        if let option = promptManager?.designOption {
            headlineLabel.text = Defaults.Text.headline(for: option)
        }
    }

    private func applyReferenceScreenTransition() {
        selectedIndexPath = nil
        containerImageView.image = nil
        containerView.isHidden = false
        updateText()
        suggestionsCollectionVIew.reloadData()
        updateRearrangeAndSuggestionsAppearance()
        updateInfoButtonVisibility()
        updateDeleteButtonVisibility()
    }

    private func updateEmbeddedNextButtonVisibility() {
        nextButton.isHidden = shouldHideEmbeddedNextButton
    }

    private func handlePhotoSelectionCompleted() {
        updateInfoButtonVisibility()
        updateDeleteButtonVisibility()

        if referenceType == .currentRoom, !isEmbeddedInPageFlow {
            applyReferenceScreenTransition()
            return
        }

        completion?()
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
                applyReferenceScreenTransition()
            }
        } else if promptManager.designOption == .replace {
            completion?()
        } else {
            if GenerationAccess.requestProcessingIfAllowed(presentingFrom: self) {
                NavigationManager.shared.showProcessing(manager: promptManager)
            }
        }
    }
    
    @IBAction func infoAction(_ sender: UIButton) {
        let option = promptManager?.designOption ?? .interior
        NavigationManager.shared.showPhotoTips(designOption: option, presentingViewController: self)
    }
    
    private func presentPhotoTipsOnFirstVisitIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: Constants.Keys.didShowAddPhotoPhotoTips) else { return }

        let option = promptManager?.designOption ?? .interior
        let tipsTrimmed = option.tipsDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tipsTrimmed.isEmpty else { return }

        UserDefaults.standard.set(true, forKey: Constants.Keys.didShowAddPhotoPhotoTips)
        UserDefaults.standard.synchronize()
        NavigationManager.shared.showPhotoTips(designOption: option, presentingViewController: self)
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
        if let image = info[.originalImage] as? UIImage {
            if parent is PageViewController {
                hapticVibration()
            }
            containerImageView.image = image
            if let manager = promptManager, manager.designOption == .replace {
                manager.updateBaseImage(image)
            } else {
                referenceType == .reference ? promptManager?.updateReferenceImage(image) : promptManager?.updateBaseImage(image)
            }
            containerImageView.contentMode = .scaleAspectFill
            containerImageView.clipsToBounds = true
            containerView.isHidden = true
            picker.dismiss(animated: true) { [weak self] in
                self?.handlePhotoSelectionCompleted()
            }
        } else {
            picker.dismiss(animated: true)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

// MARK: - UICollectionViewDataSource
extension AddPhotoViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        suggestionTemplates.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: SuggestionCollectionViewCell.reuseIdentifier,
            for: indexPath
        ) as? SuggestionCollectionViewCell else {
            return UICollectionViewCell()
        }
        
        guard let template = suggestionTemplates[safe: indexPath.item] else { return cell }
        cell.configure(with: template)
        
        if let selectedIndexPath, selectedIndexPath == indexPath {
            cell.isSelected = true
        } else {
            cell.isSelected = false
        }
        
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension AddPhotoViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if parent is PageViewController {
            hapticVibration()
        }
        if let previous = selectedIndexPath, previous != indexPath,
           let prevCell = collectionView.cellForItem(at: previous) as? SuggestionCollectionViewCell {
            prevCell.isSelected = false
            collectionView.deselectItem(at: previous, animated: false)
        }
        
        if let newCell = collectionView.cellForItem(at: indexPath) as? SuggestionCollectionViewCell {
            newCell.isSelected = true
        }
        
        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
        
        selectedIndexPath = indexPath

        guard let template = suggestionTemplates[safe: indexPath.item] else { return }

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
                self.handlePhotoSelectionCompleted()
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
        let width = CGFloat(130).scaledByHeight()
        let height = CGFloat(160).scaledByHeight()
        return CGSize(width: width, height: height)
    }
}
