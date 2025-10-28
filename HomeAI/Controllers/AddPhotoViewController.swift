import UIKit

private struct Defaults {
    struct Text {
        static let addPhoto = "Add a photo".localized
        static let headline = "Upload a photo of your  current room.".localized
        static let getDreamDesign = "Get your dream design".localized
        static let takePhoto = "Take a photo".localized
        static let selectGallery = "Select from gallery".localized
        static let cancel = "Cancel".localized
        static let next = "Next".localized

    }
}

final class AddPhotoViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PageStepDelegate, PromptManagerHolder {
    
    @IBOutlet weak private var descriptionLabel: UILabel!
    @IBOutlet weak private var headlineLabel: UILabel!
    
    @IBOutlet weak private var photoTitleButton: UILabel!
    @IBOutlet weak private var cameraContainerView: UIView!
    @IBOutlet weak private var containerView: UIView!
    
    @IBOutlet private var constraintsHeight: [NSLayoutConstraint]!
    @IBOutlet private var constraintsWidth: [NSLayoutConstraint]!
    
    @IBOutlet weak private var containerImageView: UIImageView!
    
    @IBOutlet weak private var nextButton: UIButton!
    
    var completion: (() -> Void)?
    
    var canProceedToNextStep: Bool {
        return containerImageView.image != nil
    }
    
    var promptManager: PromptManager?
    var referenceType: ReferenceScreenType? = nil
    
    private let amplitude = AmplitudeService.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if referenceType != nil {
            promptManager = PromptManager()
            promptManager?.updateOption(.reference)
        }
        amplitude.logEvent(.showAddPhoto)
        configure()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        containerView.addDashedBorder(color: .label, lineWidth: 1, dashPattern: [6, 4], cornerRadius: 16)
        cameraContainerView.layer.cornerRadius = cameraContainerView.frame.height / 2
        nextButton.layer.cornerRadius = nextButton.frame.height / 2

        nextButton.backgroundColor = Constants.Colors.yellowPremium
    }
    
    private func configure() {
        headlineLabel.text = Defaults.Text.headline
        descriptionLabel.text = Defaults.Text.getDreamDesign
        photoTitleButton.text = Defaults.Text.addPhoto
        constraintsHeight.forEach { $0.scaleConstant() }
        constraintsWidth.forEach { $0.scaleConstantByWidth() }
        nextButton.setTitle(Defaults.Text.next, for: .normal)
        updateText()
        
        title = Defaults.Text.addPhoto
    }

    private func updateText() {
        if let type = referenceType {
            containerImageView.image = nil
            headlineLabel.text = type.titleText
            descriptionLabel.text = type.subtitleText
            nextButton.isHidden = false
            containerView.isHidden = false
        }
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
            referenceType = .reference
            updateText()
        } else {
            NavigationManager.shared.showProcessing(manager: promptManager)
        }
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
            referenceType == .reference ? promptManager?.updateReferenceImage(image) : promptManager?.updateBaseImage(image)
            containerImageView.contentMode = .scaleAspectFill
            containerImageView.clipsToBounds = true
            containerView.isHidden = true
            completion?()
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
