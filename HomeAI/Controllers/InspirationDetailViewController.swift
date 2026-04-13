import UIKit

private struct Defaults {
    
    struct Text {
        static let done = "Done".localized
        static let color = "Color".localized
        static let style = "Style".localized
        static let edit = "Edit".localized
        static let save = "Save".localized
        static let regeneration = "Regeneration".localized
        static let generate = "Generate".localized
        static let share = "Share".localized
    }
}

final class InspirationDetailViewController: UIViewController {

    // MARK: - @IBOutlets
    @IBOutlet weak private var regenerateButton: UIButton!
    @IBOutlet weak private var shareButton: UIButton!
    @IBOutlet weak private var saveButton: UIButton!
    @IBOutlet weak private var afterBeforeButton: UIButton!
    @IBOutlet weak private var doneButton: UIButton!
    
    @IBOutlet weak private var shareLabel: UILabel!
    @IBOutlet weak private var regenerationLabel: UILabel!
    @IBOutlet weak private var saveLabel: UILabel!
    
    @IBOutlet weak private var insirationImageView: UIImageView!
    
    @IBOutlet weak private var afterbeforeContainerView: UIView!
    
    @IBOutlet weak private var collectionView: UICollectionView!
    
    @IBOutlet weak private var dislikeImageView: UIImageView!
    @IBOutlet weak private var likeImageView: UIImageView!
    
    @IBOutlet private var constaintsHeight: [NSLayoutConstraint]!
    @IBOutlet private var constraintsWidth: [NSLayoutConstraint]!
    
    // MARK: - Public properties
    var data: ImageDetailModel?
    var promptManager: GemeniPromptManager?
    var showsRegenerateButton: Bool = true
    var onRegenerate: ((GemeniPromptManager) -> Void)?
    var showsLimitedEditorActions: Bool = false

    // MARK: - Private properties
    private var beforeImage: UIImage?
    private var afterImage: UIImage?
    private var imageAspectConstraint: NSLayoutConstraint?
    private var beforeLoadingIndicator: UIActivityIndicatorView?
    private var isGenerateMode = false

    private let imageManager = InspirationDetailImageManager()
    private let feedbackManager = InspirationDetailFeedbackManager()
    private let editorRouter = InspirationDetailEditorRouter()

    private var visibleEditorActions: [EditorActionType] {
        editorRouter.visibleActions(for: data?.option, showsLimited: showsLimitedEditorActions)
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        AmplitudeService.shared.logEvent(.showDetail)
        configure()
        constraintsWidth?.forEach { $0.scaleConstantByWidth() }
        constaintsHeight?.forEach { $0.scaleConstant() }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        feedbackManager.showRateAlertIfNeeded(in: self)
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
    
    // MARK: - Public
    func startBeforeLoading() {
        guard data?.canRegenerate == true else { return }
        afterbeforeContainerView.isHidden = false
        afterBeforeButton.isHidden = true
        beforeLoadingIndicator?.startAnimating()
    }
    
    func updateBeforeImage(_ image: UIImage?) {
        guard let image else { return }
        beforeImage = image
        afterBeforeButton.isHidden = false
        afterbeforeContainerView.isHidden = false
        regenerateButton.isHidden = false
        beforeLoadingIndicator?.stopAnimating()
    }
    
    func updateAfterImage(_ image: UIImage) {
        afterImage = image
        insirationImageView.image = image
        updateImageAspect(for: image)
    }

    // MARK: - IBActions
    @IBAction private func saveAction(_ sender: UIButton) {
        hapticVibration()
        guard let image = afterImage ?? insirationImageView.image else { return }
        imageManager.saveToGallery(image: image, storagePath: data?.storagePath, from: self)
    }

    @IBAction private func shareAction(_ sender: UIButton) {
        hapticVibration()
        guard let image = insirationImageView.image else { return }
        imageManager.share(image: image, from: self)
    }
    
    @IBAction private func doneAction(_ sender: UIButton) {
        dismiss(animated: true) {
            NavigationManager.shared.popToRoot(animated: true)
        }
    }
    
    @IBAction private func regenerateAction(_ sender: UIButton) {
        guard let promptManager else { return }
        if isGenerateMode {
            triggerGenerateFromSelection()
            return
        }

        let alert = UIAlertController(
            title: "Regenerate Image".localized,
            message: "Do you want to regenerate this image?".localized,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel))
        alert.addAction(UIAlertAction(title: "Regenerate".localized, style: .default) { [weak self] _ in
            self?.performRegeneration(promptManager: promptManager)
        })
        
        present(alert, animated: true)
    }
    
    @IBAction private func zoomAction(_ sender: UIButton) {
        guard let image = insirationImageView.image else { return }
        let vc = FullscreenImageViewController(image: image)
        vc.modalPresentationStyle = .overFullScreen
        present(vc, animated: true)
    }
    
    @IBAction private func editAction(_ sender: UIButton) {
        hapticVibration()
        guard let image = afterImage ?? beforeImage else { return }
        
        let editManager = GemeniPromptManager()
        editManager.updateOption(.replace)
        editManager.updateBaseImage(image)
        
        dismiss(animated: true) {
            NavigationManager.shared.showReplaceObjectPage(initialImage: image, promptManager: editManager, flowMode: .replace)
        }
    }
    
    @IBAction private func likeAction(_ sender: UIButton) {
        hapticVibration()
        feedbackManager.handleLike(from: self) { [weak self] in
            self?.wobbleIconRotation(self?.likeImageView)
        }
    }
    
    @IBAction private func disslikeAction(_ sender: UIButton) {
        hapticVibration()
        feedbackManager.handleDislike(from: self) { [weak self] in
            self?.wobbleIconRotation(self?.dislikeImageView)
        }
    }
}

// MARK: - Private configuration
private extension InspirationDetailViewController {

    /// Легке гойдання через rotation (нахил вліво/вправо навколо центру), без зсуву імеджа.
    func wobbleIconRotation(_ view: UIView?) {
        guard let v = view else { return }
        v.layer.removeAllAnimations()
        v.transform = .identity
        let tilt: CGFloat = .pi / 16
        let duration: TimeInterval = 1.0
        UIView.animateKeyframes(withDuration: duration, delay: 0, options: [.calculationModeCubic, .beginFromCurrentState]) {
            UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 0.22) {
                v.transform = CGAffineTransform(rotationAngle: tilt)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.22, relativeDuration: 0.22) {
                v.transform = CGAffineTransform(rotationAngle: -tilt)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.44, relativeDuration: 0.18) {
                v.transform = CGAffineTransform(rotationAngle: tilt * 0.55)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.62, relativeDuration: 0.18) {
                v.transform = CGAffineTransform(rotationAngle: -tilt * 0.4)
            }
            UIView.addKeyframe(withRelativeStartTime: 0.8, relativeDuration: 0.2) {
                v.transform = .identity
            }
        } completion: { _ in
            v.transform = .identity
        }
    }

    func configure() {
        doneButton.setTitle(Defaults.Text.done, for: .normal)
        configureEditorActions()
        collectionView.isHidden = showsLimitedEditorActions
        
        insirationImageView.clipsToBounds = true
        
        beforeImage = data?.previewsImage
        afterImage  = data?.image
                
        insirationImageView.image = afterImage
        updateImageAspect(for: afterImage)
        
        let hasBeforeImage = beforeImage != nil
        afterBeforeButton.isHidden = !hasBeforeImage
        afterbeforeContainerView.isHidden = !hasBeforeImage

        regenerateButton.isHidden = !showsRegenerateButton
        regenerationLabel.isHidden = !showsRegenerateButton
        
        afterBeforeButton.removeTarget(nil, action: nil, for: .allEvents)
        afterBeforeButton.addTarget(self, action: #selector(showBeforeHold), for: [.touchDown, .touchDragEnter])
        afterBeforeButton.addTarget(self, action: #selector(restoreAfterRelease), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        
        setupBeforeLoadingIndicator()
        setupButtonIcons()
        saveLabel.text = Defaults.Text.save
        regenerationLabel.text = Defaults.Text.regeneration
        shareLabel.text = Defaults.Text.share
    }
    
    func configureEditorActions() {
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(UINib(nibName: "EditorActionCollectionCell", bundle: nil), forCellWithReuseIdentifier: "EditorActionCollectionCell")
        
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
            layout.minimumLineSpacing = 12
            layout.minimumInteritemSpacing = 0
            layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
            layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        }
    }
    
    func setupButtonIcons() {
        let largeConfig = UIImage.SymbolConfiguration(pointSize: 30, weight: .regular, scale: .large)
        if let currentSaveImage = saveButton.image(for: .normal) {
            saveButton.setImage(currentSaveImage.withConfiguration(largeConfig), for: .normal)
        } else if let downloadImage = UIImage(systemName: "download_icon") {
            saveButton.setImage(downloadImage.withConfiguration(largeConfig), for: .normal)
        }
        
        if let currentRegenerateImage = regenerateButton.image(for: .normal) {
            regenerateButton.setImage(currentRegenerateImage.withConfiguration(largeConfig), for: .normal)
        } else if let refreshImage = UIImage(systemName: "regenerate_icon") {
            regenerateButton.setImage(refreshImage.withConfiguration(largeConfig), for: .normal)
        }
        
        if let currentShareImage = shareButton.image(for: .normal) {
            shareButton.setImage(currentShareImage.withConfiguration(largeConfig), for: .normal)
        } else if let shareImage = UIImage(named: "share_icon") {
            shareButton.setImage(shareImage.withConfiguration(largeConfig), for: .normal)
        }

        insirationImageView.isUserInteractionEnabled = false
    }
    
    func setupBeforeLoadingIndicator() {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        afterbeforeContainerView.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: afterbeforeContainerView.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: afterbeforeContainerView.centerYAnchor)
        ])
        beforeLoadingIndicator = indicator
    }
    
    func updateImageAspect(for image: UIImage?) {
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
}

// MARK: - Before/After & Generation
private extension InspirationDetailViewController {

    @objc func showBeforeHold() {
        guard let img = beforeImage else { return }
        insirationImageView.image = img
        updateImageAspect(for: img)
    }

    @objc func restoreAfterRelease() {
        guard let img = afterImage ?? beforeImage else { return }
        insirationImageView.image = img
        updateImageAspect(for: img)
    }

    func performRegeneration(promptManager: GemeniPromptManager) {
        print("[InspirationDetailVC] Regenerate confirmed. baseImage:", promptManager.baseImage as Any)
        print("[InspirationDetailVC] Current option:", promptManager.designOption, "style:", promptManager.interiorStyle?.name ?? promptManager.exteriorStyle?.name ?? "nil", "color:", promptManager.colorType?.name ?? "nil")
        
        if GenerationAccess.requestProcessingIfAllowed(presentingFrom: self) {
            let callback = onRegenerate
            dismiss(animated: true) {
                callback?(promptManager)
            }
        }
    }

    func prepareGenerateMode() {
        isGenerateMode = true
        regenerateButton.isHidden = false
        regenerationLabel.isHidden = false
        regenerationLabel.text = Defaults.Text.generate
    }

    func triggerGenerateFromSelection() {
        guard let promptManager else { return }
        isGenerateMode = false
        regenerateButton.setTitle(nil, for: .normal)
        regenerationLabel.text = Defaults.Text.regeneration
        if let currentGenerated = afterImage ?? insirationImageView.image ?? beforeImage {
            promptManager.updateBaseImage(currentGenerated)
        }
        performRegeneration(promptManager: promptManager)
    }
}

// MARK: - Style & Color flows
private extension InspirationDetailViewController {

    func resolvePromptManager() -> GemeniPromptManager {
        if let existing = promptManager { return existing }
        let manager = GemeniPromptManager()
        if let option = data?.option { manager.updateOption(option) }
        promptManager = manager
        return manager
    }

    func styleAction() {
        guard let data else { return }
        let manager = resolvePromptManager()
        let styleOption = editorRouter.inferredDesignOption(from: data)
        manager.updateOption(styleOption)

        NavigationManager.shared.presentStyle(promptManager: manager, option: styleOption, onSelect: { [weak self] unified in
            self?.promptManager?.updateStyle(unified)
            self?.prepareGenerateMode()
        }, onGenerate: { [weak self] in
            self?.triggerGenerateFromSelection()
        })
    }

    func colorAction() {
        guard let data else { return }
        let manager = resolvePromptManager()
        manager.updateOption(editorRouter.inferredDesignOption(from: data))

        NavigationManager.shared.presentColor(promptManager: manager, onSelect: { [weak self] palette in
            self?.promptManager?.updateColor(palette)
            self?.prepareGenerateMode()
        }, onGenerate: { [weak self] in
            self?.triggerGenerateFromSelection()
        })
    }
}

// MARK: - Editor actions collection
extension InspirationDetailViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        visibleEditorActions.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EditorActionCollectionCell", for: indexPath) as? EditorActionCollectionCell else {
            return UICollectionViewCell()
        }
        cell.configure(action: visibleEditorActions[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let action = visibleEditorActions[indexPath.row]
        editorRouter.route(
            action: action,
            currentImage: afterImage ?? insirationImageView.image,
            data: data,
            promptManager: promptManager,
            onStyleAction: { [weak self] in self?.styleAction() },
            onColorAction: { [weak self] in self?.colorAction() },
            dismiss: { [weak self] in self?.dismiss(animated: true) }
        )
    }
}
