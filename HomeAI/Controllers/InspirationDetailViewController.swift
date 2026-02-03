import UIKit
import Photos

private struct Defaults {
    
    struct Text {
        static let done = "Done".localized
        static let saved = "Saved".localized
        static let error = "Error".localized
        static let message = "Image saved to photo gallery".localized
        static let ok = "OK".localized
        static let permissionDenied = "Permission Denied".localized
        static let permissionMessage = "Please grant access to your photo library in Settings.".localized
        static let color = "Color".localized
        static let style = "Style".localized
        static let edit = "Edit".localized
        static let save = "Save".localized
        static let regeneration = "Regeneration".localized
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
    
    @IBOutlet private var constaintsHeight: [NSLayoutConstraint]!
    @IBOutlet private var constraintsWidth: [NSLayoutConstraint]!
    
    // MARK: - Properties
    var data: ImageDetailModel?
    var promptManager: GemeniPromptManager?
    var showsRegenerateButton: Bool = true
    var onRegenerate: ((GemeniPromptManager) -> Void)?

    private var beforeImage: UIImage?
    private var afterImage: UIImage?
    private var imageAspectConstraint: NSLayoutConstraint?
    private var beforeLoadingIndicator: UIActivityIndicatorView?
    
    private let editorActions: [EditorActionType] = [
        .deleteObject, .replaceObject, .newWalls, .newFloor, .newStyle, .newColor
    ]
    
    var showsLimitedEditorActions: Bool = false
    
    private var visibleEditorActions: [EditorActionType] {
        if showsLimitedEditorActions {
            return [.deleteObject, .replaceObject]
        }
        return editorActions
    }

    // MARK: - Lifecycles
    override func viewDidLoad() {
        super.viewDidLoad()
        AmplitudeService.shared.logEvent(.showDetail)
        configure()
        constraintsWidth?.forEach { $0.scaleConstantByWidth() }
        constaintsHeight?.forEach { $0.scaleConstant() }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showRateAlertIfNeeded()
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

        doneButton.setTitle(Defaults.Text.done, for: .normal)
        configureEditorActions()
        collectionView.isHidden = showsLimitedEditorActions
        
        insirationImageView.clipsToBounds = true
        
        beforeImage = data?.previewsImage
        afterImage  = data?.image
                
        insirationImageView.image = afterImage
        updateImageAspect(for: afterImage)
        
        if beforeImage != nil {
            afterBeforeButton.isHidden = false
            afterbeforeContainerView.isHidden = false
        } else {
            afterBeforeButton.isHidden = true
            afterbeforeContainerView.isHidden = true
        }
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
    
    private func configureEditorActions() {
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(
            UINib(nibName: "EditorActionCollectionCell", bundle: nil),
            forCellWithReuseIdentifier: "EditorActionCollectionCell"
        )
        
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
            layout.minimumLineSpacing = 12
            layout.minimumInteritemSpacing = 0
            layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
            layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        }
    }
    
    private func setupButtonIcons() {
        let largeConfig = UIImage.SymbolConfiguration(pointSize: 30, weight: .regular , scale: .large)
        if let currentSaveImage = saveButton.image(for: .normal) {
            let resizedImage = currentSaveImage.withConfiguration(largeConfig)
            saveButton.setImage(resizedImage, for: .normal)
        } else if let downloadImage = UIImage(systemName: "download_icon") {
            saveButton.setImage(downloadImage.withConfiguration(largeConfig), for: .normal)
        }
        
        if let currentRegenerateImage = regenerateButton.image(for: .normal) {
            let resizedImage = currentRegenerateImage.withConfiguration(largeConfig)
            regenerateButton.setImage(resizedImage, for: .normal)
        } else if let refreshImage = UIImage(systemName: "regenerate_icon") {
            regenerateButton.setImage(refreshImage.withConfiguration(largeConfig), for: .normal)
        }
        
        if let currentShareImage = shareButton.image(for: .normal) {
            let resizedImage = currentShareImage.withConfiguration(largeConfig)
            shareButton.setImage(resizedImage, for: .normal)
        } else if let shareImage = UIImage(named: "share_icon") {
            shareButton.setImage(shareImage.withConfiguration(largeConfig), for: .normal)
        }

        insirationImageView.isUserInteractionEnabled = false
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
    
    private func setupBeforeLoadingIndicator() {
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
    
    private func showRateAlertIfNeeded() {
        let isFirstGeneration = FreeGenerationManager.shared.currentCount == 1
        let didShowAlert = UserDefaults.standard.bool(forKey: Constants.Keys.didShowRateAlert)
        let shouldShow = isFirstGeneration && !didShowAlert
        guard shouldShow else { return }
        guard let alertView = Bundle.main.loadNibNamed("LikeAlertView", owner: nil, options: nil)?.first as? LikeAlertView else {
            return
        }
        
        alertView.show(in: self)
        UserDefaults.standard.set(true, forKey: Constants.Keys.didShowRateAlert)
        UserDefaults.standard.synchronize()
    }
    
    private func colorAction() {
        guard let promptManager else { return }
        NavigationManager.shared.presentColor(promptManager: promptManager) { [weak self] palette in
            self?.promptManager?.updateColor(palette)
        }
    }
    
    private func styleAction() {
        guard let data else { return }
        let manager: GemeniPromptManager
        if let existing = promptManager {
            manager = existing
        } else {
            let newManager = GemeniPromptManager()
            newManager.updateOption(data.option)
            promptManager = newManager
            manager = newManager
        }

        NavigationManager.shared.presentStyle(promptManager: manager, option: data.option) { [weak self] unified in
            self?.promptManager?.updateStyle(unified)
        }
    }
    
    // MARK: - IBActions
    @IBAction private func saveAction(_ sender: UIButton) {
        hapticVibration()
        guard let image = afterImage ?? insirationImageView.image else { return }
        PHPhotoLibrary.shared().performChanges({
            if let storagePath = self.data?.storagePath,
               FileManager.default.fileExists(atPath: storagePath) {
                let url = URL(fileURLWithPath: storagePath)
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
            } else {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        }) { success, error in
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
        
        // Показуємо алерт з підтвердженням
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
    
    private func performRegeneration(promptManager: GemeniPromptManager) {
        print("[InspirationDetailVC] Regenerate confirmed. baseImage:", promptManager.baseImage as Any)
        print("[InspirationDetailVC] Current option:", promptManager.designOption, "style:", promptManager.interiorStyle?.name ?? promptManager.exteriorStyle?.name ?? "nil", "color:", promptManager.colorType?.name ?? "nil")
        
        if FreeGenerationManager.shared.canGenerateForFree || ApphudService.shared.hasActiveSubscription {
            // Capture callback before dismiss to avoid losing it when self is deallocated
            let callback = onRegenerate
            dismiss(animated: true) {
                callback?(promptManager)
            }
        } else {
            NavigationManager.shared.showPremium(placement: Constants.Keys.reachedLimit)
        }
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

    @objc
    private func handleImageTap() { }
}

// MARK: - Editor actions
extension InspirationDetailViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        visibleEditorActions.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "EditorActionCollectionCell",for: indexPath) as? EditorActionCollectionCell else {
            return UICollectionViewCell()
        }
        
        let action = visibleEditorActions[indexPath.item]
        cell.configure(action: action)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        AmplitudeService.shared.logEvent(.selectingEdit(type: visibleEditorActions[indexPath.row]))
        
        switch visibleEditorActions[indexPath.row] {
        case .deleteObject:
            let manager = GemeniPromptManager()
            manager.updateOption(.replace)
            if let image = afterImage ?? insirationImageView.image {
                manager.updateBaseImage(image)
            }
            let deletionPrompt = "remove the selected object and fill the area with realistic background matching the surroundings"
            NavigationManager.shared.showObjectSelection(promptManager: manager,
                                                         requiresPromptInput: false,
                                                         replacementDescription: deletionPrompt)
            dismiss(animated: true)
        case .replaceObject:
            let manager = GemeniPromptManager()
            manager.updateOption(.replace)
            if let image = afterImage ?? insirationImageView.image {
                manager.updateBaseImage(image)
            }
            NavigationManager.shared.showObjectSelection(promptManager: manager)
            dismiss(animated: true)
        case .newWalls:
            let manager = GemeniPromptManager()
            manager.updateOption(.newWalls)
            if let image = afterImage ?? insirationImageView.image {
                manager.updateBaseImage(image)
            }
            NavigationManager.shared.showSurfaceMaterialPicker(promptManager: manager)
            dismiss(animated: true)
        case .newFloor:
            let manager = GemeniPromptManager()
            manager.updateOption(.newFlooring)
            if let image = afterImage ?? insirationImageView.image {
                manager.updateBaseImage(image)
            }
            NavigationManager.shared.showSurfaceMaterialPicker(promptManager: manager)
            dismiss(animated: true)
        case .newStyle: styleAction()
        case .newColor: colorAction()
        }
        
    }
}


// MARK: - Fullscreen image viewer
private final class FullscreenImageViewController: UIViewController, UIScrollViewDelegate {

    private let image: UIImage
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let closeButton = UIButton(type: .system)

    init(image: UIImage) {
        self.image = image
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissSelf))
        tap.numberOfTapsRequired = 1
        view.addGestureRecognizer(tap)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
        tap.require(toFail: doubleTap)

        setupCloseButton()
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > 1.0 {
            scrollView.setZoomScale(1.0, animated: true)
        } else {
            let point = gesture.location(in: imageView)
            zoom(to: point, scale: 2.0)
        }
    }

    private func zoom(to point: CGPoint, scale: CGFloat) {
        let size = scrollView.bounds.size
        let width = size.width / scale
        let height = size.height / scale
        let rect = CGRect(x: point.x - width / 2, y: point.y - height / 2, width: width, height: height)
        scrollView.zoom(to: rect, animated: true)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    private func setupCloseButton() {
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        closeButton.layer.cornerRadius = 18
        closeButton.layer.masksToBounds = true
        closeButton.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)

        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -12),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
}


