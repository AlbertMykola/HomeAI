import UIKit
import Photos

private struct Defaults {
    
    struct Text {
        static let done = "Done".localized
        static let save = "Save".localized
        static let share = "Share".localized
        static let saved = "Saved".localized
        static let error = "Error".localized
        static let message = "Image saved to photo gallery".localized
        static let ok = "OK".localized
        static let permissionDenied = "Permission Denied".localized
        static let permissionMessage = "Please grant access to your photo library in Settings.".localized
        static let regeneration = "Regeneration".localized
        static let color = "Color".localized
        static let style = "Style".localized
    }
}

final class InspirationDetailViewController: UIViewController {

    // MARK: - @IBOutlets
    @IBOutlet weak private var regenerateButton: UIButton!
    @IBOutlet weak private var shareButton: UIButton!
    @IBOutlet weak private var saveButton: UIButton!
    @IBOutlet weak private var afterBeforeButton: UIButton!
    @IBOutlet weak private var doneButton: UIButton!
    
    @IBOutlet weak private var insirationImageView: UIImageView!
    
    @IBOutlet weak private var afterbeforeContainerView: UIView!
    @IBOutlet weak private var chosenStyleLabel: UILabel!
    @IBOutlet weak private var styleTitleLabel: UILabel!
    @IBOutlet weak private var chosenColorLabel: UILabel!
    @IBOutlet weak private var colorTitleLabel: UILabel!
    
    @IBOutlet private var constaintsHeight: [NSLayoutConstraint]!
    @IBOutlet private var constraintsWidth: [NSLayoutConstraint]!
    
    // MARK: - Properties
    var data: ImageDetailModel?
    var promptManager: PromptManager?
    var onRegenerate: ((PromptManager) -> Void)?

    private var beforeImage: UIImage?
    private var afterImage: UIImage?
    private let imageService = ImageStorageService()
    private var imageAspectConstraint: NSLayoutConstraint?

    // MARK: - Lifecycles
    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let r: CGFloat = 14
        shareButton.layer.cornerRadius = r
        saveButton.layer.cornerRadius = r
        doneButton.layer.cornerRadius = r
        regenerateButton.layer.cornerRadius = r
        afterBeforeButton.layer.cornerRadius = r
        afterbeforeContainerView.layer.cornerRadius = r
        insirationImageView.layer.cornerRadius = r
        insirationImageView.clipsToBounds = true
    }
    
    // MARK: - Functions
    private func configure() {
        // Texts
        shareButton.setTitle(Defaults.Text.share, for: .normal)
        saveButton.setTitle(Defaults.Text.save, for: .normal)
        doneButton.setTitle(Defaults.Text.done, for: .normal)
        
        regenerateButton.setTitle(Defaults.Text.regeneration, for: .normal)
        
        colorTitleLabel.text = Defaults.Text.color + ":"
        styleTitleLabel.text = Defaults.Text.style + ":"
        chosenColorLabel.text = data?.color
        chosenStyleLabel.text = data?.style
        
        // Rendering mode to avoid distortion
        insirationImageView.contentMode = .scaleAspectFit
        insirationImageView.clipsToBounds = true
        
        beforeImage = data?.previewsImage
        afterImage  = data?.image
        
        if beforeImage != nil {
            insirationImageView.image = afterImage
            updateImageAspect(for: afterImage)
            afterBeforeButton.isHidden = false
            afterbeforeContainerView.isHidden = false
            regenerateButton.isHidden = false
        } else {
            insirationImageView.image = afterImage
            updateImageAspect(for: afterImage)
            afterBeforeButton.isHidden = true
            afterbeforeContainerView.isHidden = true
            regenerateButton.isHidden = true
        }
        
        afterBeforeButton.removeTarget(nil, action: nil, for: .allEvents)
        afterBeforeButton.addTarget(self, action: #selector(showBeforeHold), for: [.touchDown, .touchDragEnter])
        afterBeforeButton.addTarget(self, action: #selector(restoreAfterRelease), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    }
    
    private func updateImageAspect(for image: UIImage?) {
        imageAspectConstraint?.isActive = false
        guard let img = image, img.size.width > 0, img.size.height > 0 else { return }
        let ratio = img.size.height / img.size.width
        imageAspectConstraint = insirationImageView.heightAnchor.constraint(
            equalTo: insirationImageView.widthAnchor,
            multiplier: ratio
        )
        imageAspectConstraint?.priority = .required
        imageAspectConstraint?.isActive = true
        view.setNeedsLayout()
        view.layoutIfNeeded()
        insirationImageView.layer.cornerRadius = 14
        insirationImageView.clipsToBounds = true
    }

    
    // MARK: - IBActions
    @IBAction private func saveAction(_ sender: UIButton) {
        hapticVibration()
        guard let image = insirationImageView.image else { return }
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)}) { success, error in
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: success ? Defaults.Text.saved : Defaults.Text.error,
                    message: success ? Defaults.Text.message: (error?.localizedDescription ?? "Unknown error"),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    @IBAction private func shareAction(_ sender: UIButton) {
        hapticVibration()
        guard let image = insirationImageView.image else { return }
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = self.view
        self.present(activityVC, animated: true)
    }
    
    @IBAction private func doneAction(_ sender: UIButton) {
        dismiss(animated: true) {
            NavigationManager.shared.popToRoot(animated: true)
        }
    }
    
    @IBAction private func regenerateAction(_ sender: UIButton) {
        guard let promptManager else { return }
        if FreeGenerationManager.shared.canGenerateForFree || ApphudService.shared.hasActiveSubscription {
            dismiss(animated: true) { [weak self] in
                self?.onRegenerate?(promptManager)
            }
        } else {
            NavigationManager.shared.showPremium(placement: Constants.Keys.reachedLimit)
        }
    }
    
    @IBAction private func colorAction(_ sender: UIButton) {
        guard let promptManager else { return }
        NavigationManager.shared.presentColor(promptManager: promptManager) { [weak self] palette in
            self?.promptManager?.updatePalette(palette)
            self?.chosenColorLabel.text = palette.name
        }
    }
    
    @IBAction private func styleAction(_ sender: UIButton) {
        guard let data, let promptManager else { return }
        
        NavigationManager.shared.presentStyle(promptManager: promptManager, option: data.option) { [weak self] unified in
            self?.promptManager?.updateStyle(unified)
            self?.chosenStyleLabel.text = unified.name
        }
    }
    
    // MARK: - Before/After handlers
    @objc
    private func showBeforeHold() {
        guard let img = beforeImage else { return }
        insirationImageView.image = img
        updateImageAspect(for: img)
    }

    @objc
    private func restoreAfterRelease() {
        guard let img = afterImage ?? beforeImage else { return }
        insirationImageView.image = img
        updateImageAspect(for: img)
    }
}
