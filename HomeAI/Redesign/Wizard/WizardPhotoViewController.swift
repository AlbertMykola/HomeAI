import UIKit
import PhotosUI
import AVFoundation

/// A/04 · W1 Add photo (+ "selected" state). Layout: Wizard.storyboard.
final class WizardPhotoViewController: WizardStepViewController {

    @IBOutlet private weak var scrollView: UIScrollView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var sourcesStack: UIStackView!
    @IBOutlet private weak var takePhotoCard: DSPressableControl!
    @IBOutlet private weak var libraryCard: DSPressableControl!
    @IBOutlet private var sourceTitleLabels: [UILabel]!
    @IBOutlet private var sourceSubtitleLabels: [UILabel]!
    @IBOutlet private weak var demoTitleLabel: UILabel!
    @IBOutlet private var demoControls: [DSPressableControl]!
    @IBOutlet private weak var tipsButton: DSPressableControl!
    @IBOutlet private weak var tipsIconView: UIImageView!
    @IBOutlet private weak var tipsLabel: UILabel!

    @IBOutlet private weak var previewView: UIView!
    @IBOutlet private weak var photoImageView: UIImageView!
    @IBOutlet private weak var scanLineView: UIView!
    @IBOutlet private weak var scanBottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var changeButton: DSPressableControl!
    @IBOutlet private weak var changeLabel: UILabel!
    @IBOutlet private weak var checkBadgeView: UIView!
    @IBOutlet private weak var checkIconView: UIImageView!
    @IBOutlet private weak var checkLabel: UILabel!

    @IBOutlet private weak var nextButton: DSPrimaryButton!
    @IBOutlet private weak var nextTitleLabel: UILabel!

    // iPhone Duo unfolded, landscape (Figma Duo/L/04 · W1): the left pane holds the source cards, then the
    // picked photo with Change and the check badge; the right column lists the four steps. Wizard.storyboard.
    @IBOutlet private weak var paneSourcesStack: UIStackView?
    @IBOutlet private weak var paneChangeButton: UIView?
    @IBOutlet private weak var paneChangeLabel: UILabel?
    @IBOutlet private weak var paneCheckBadgeView: UIView?
    @IBOutlet private weak var paneCheckIconView: UIImageView?
    @IBOutlet private weak var paneCheckLabel: UILabel?
    @IBOutlet private weak var stepsListView: UIView?
    @IBOutlet private var stepRowViews: [UIView]?
    @IBOutlet private var stepIconContainers: [UIView]?
    @IBOutlet private var stepIconViews: [UIImageView]?
    @IBOutlet private var stepTitleLabels: [UILabel]?
    @IBOutlet private var stepSubtitleLabels: [UILabel]?
    @IBOutlet private weak var dragHintView: UIView?
    @IBOutlet private weak var dragHintLabel: UILabel?

    override var step: WizardSession.Step { .photo }

    private var didRunEntrance = false
    private var isChecking = false
    private var scanAnimator: UIViewPropertyAnimator?

    private static let demoRooms: [(String, InteriorType)] = [
        ("wizard_demo_living", .livingroom), ("wizard_demo_study", .study), ("wizard_demo_kitchen", .kitchen)
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        localize()
        nextButton.inactive = true
        for control in demoControls {
            (control.subviews.first as? UIImageView)?.image = UIImage(named: demoImages[min(control.tag, 2)].0)
        }
        if session.photo != nil { showSelected(animated: false) }
        // Split View / iPhone Duo: a photo dragged in from Photos, Files or Safari is picked like the library.
        view.addInteraction(UIDropInteraction(delegate: self))
        [titleStack, takePhotoCard, libraryCard, demoTitleLabel, tipsButton, nextButton].forEach { $0?.alpha = 0 }
        demoControls.forEach { $0.alpha = 0 }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !didRunEntrance else { return }
        didRunEntrance = true
        // Content arrives with the push (it used to slide in empty and fill ~1 s after the tap).
        let views: [UIView?] = [titleStack, takePhotoCard, libraryCard, demoTitleLabel, tipsButton, nextButton] + demoControls
        let revealed = DS.Motion.revealWithTransition(of: self, views) { [weak self] in
            guard let self, self.session.photo == nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in self?.wiggleBulb() }
        }
        if !revealed { runEntrance() }
    }

    private func localize() {
        updateTitles()
        let titles = ["Take a photo", "Choose from library"]
        let subtitles = ["Camera with a framing guide", "Only the photo you pick is shared"]
        sourceTitleLabels.forEach { $0.text = titles[min($0.tag, 1)].localized }   // tags 0/1; the Duo pane has copies
        sourceSubtitleLabels.forEach { $0.text = subtitles[min($0.tag, 1)].localized }
        paneChangeLabel?.text = "Change".localized
        let stepTitles = ["Photo", "Room", "Style", "Final touches"]
        stepTitleLabels?.forEach { $0.text = stepTitles[min($0.tag, 3)].localized }
        dragHintLabel?.text = "Drag another photo onto the left side to replace it.".localized
        demoTitleLabel.text = "No photo handy? Try one of ours".localized
        tipsLabel.text = "Photo tips".localized
        changeLabel.text = "Change".localized
        nextTitleLabel.text = "Next".localized
        demoControls.forEach { $0.accessibilityLabel = "Demo photo".localized }
    }

    private func updateTitles() {
        let hasPhoto = session.photo != nil
        switch session.option {
        case .exterior:
            titleLabel.text = hasPhoto ? "Looks great!".localized : "Add a photo of your home".localized
        case .garden:
            titleLabel.text = hasPhoto ? "Looks great!".localized : "Add a photo of your garden".localized
        case .floolPlan:
            titleLabel.text = hasPhoto ? "Plan added".localized : "Add your floor plan".localized
        case .reference:
            titleLabel.text = hasPhoto ? "Looks great!".localized : "Add a photo of your room".localized
        default:
            titleLabel.text = hasPhoto ? "Looks great!".localized : "Add a photo of your room".localized
        }
        if !hasPhoto {
            subtitleLabel.text = session.option == .floolPlan
                ? "A photo or scan of the plan, straight from above.".localized
                : "One wide, well-lit photo works best.".localized
        } else if let place = session.detectedPlace {
            subtitleLabel.text = String(format: "We found a %@. Not right? You can change it next.".localized,
                                        place.title.lowercased())
        } else {
            subtitleLabel.text = "Nice shot. You can fine-tune the details next.".localized
        }
    }

    // MARK: Sources

    @IBAction private func didTapTakePhoto(_ sender: Any) {
        CameraViewController.requestAccess(from: self, onLibrary: { [weak self] in self?.presentLibraryPicker() }) { [weak self] granted in
            guard let self, granted else { return }
            let camera = AppStoryboard.instantiate(CameraViewController.self)
            camera.onCapture = { [weak self] image in self?.didPick(image, isDemo: false) }
            camera.modalPresentationStyle = .fullScreen
            self.present(camera, animated: true)
        }
    }

    @IBAction private func didTapLibrary(_ sender: Any) {
        presentLibraryPicker()
    }

    @IBAction private func didTapChange(_ sender: Any) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Take a photo".localized, style: .default) { [weak self] _ in
            self?.didTapTakePhoto(sender)
        })
        sheet.addAction(UIAlertAction(title: "Choose from library".localized, style: .default) { [weak self] _ in
            self?.presentLibraryPicker()
        })
        sheet.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel))
        sheet.popoverPresentationController?.sourceView = changeButton
        present(sheet, animated: true)
    }

    /// Demo photos per tool (bundled): rooms for interior tools, facades / gardens otherwise.
    private var demoImages: [(String, InteriorType?)] {
        switch session.option {
        case .exterior: return [("ob_2_before_image", nil), ("home_card_exterior", nil), ("ob_2_after_image", nil)]
        case .garden: return [("ob_3_before_image", nil), ("home_card_garden", nil), ("ob_3_after_image", nil)]
        case .floolPlan: return [("floorplan_demo_one", nil), ("floorplan_demo_two", nil), ("floorplan_demo_three", nil)]
        default: return Self.demoRooms.map { ($0.0, $0.1) }
        }
    }

    @IBAction private func didTapDemo(_ sender: UIControl) {
        let demo = demoImages[min(sender.tag, 2)]
        guard let image = UIImage(named: demo.0) else { return }
        // Some demo photos are 2160×3840: shrink them off the main thread like a picked photo.
        UIImage.prepareForEditing(image) { [weak self] in self?.didPick($0, isDemo: true, knownRoom: demo.1) }
    }

    @IBAction private func didTapTips(_ sender: Any) {
        PhotoTipsSheetViewController.present(from: self, option: session.option)
    }

    @IBAction private func didTapNext(_ sender: Any) {
        guard let photo = session.photo, !isChecking else {
            DS.Haptic.warning()
            return
        }
        // Home quick edits Replace / Remove: W1 → editor (R4 / R5) → generation of a new project.
        if session.option == .replace || session.option == .delete {
            let start: (GemeniPromptManager, String) -> Void = { [weak self] manager, _ in
                guard let self else { return }
                self.generate(styleTitle: nil) { target in
                    target.updateOption(manager.designOption)
                    if let base = manager.baseImage { target.updateBaseImage(base) }
                    target.updateReplaceMode(manager.replaceMode)
                    if let object = manager.objectToReplace { target.updateObjectToReplace(object) }
                    if let mask = manager.maskImage { target.updateMask(mask) }
                }
            }
            let editor: MaskEditorViewController = session.option == .replace
                ? ReplaceEditorViewController.make(image: photo, original: nil, onApply: start)
                : RemoveEditorViewController.make(image: photo, original: nil, onApply: start)
            present(editor, animated: true)
            return
        }
        goToNextStep()
    }

    private func presentLibraryPicker() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        guard let pane = previewPaneView else { return }
        let split = dsWantsWideLandscape
        let hasPhoto = session.photo != nil
        pane.isHidden = !split
        pane.backgroundColor = hasPhoto ? DS.Color.surface : .clear
        previewImageView?.isHidden = !hasPhoto
        paneSourcesStack?.isHidden = hasPhoto
        paneChangeButton?.isHidden = !hasPhoto
        paneCheckBadgeView?.isHidden = !hasPhoto || isChecking || (checkLabel.text ?? "").isEmpty
        [takePhotoCard, libraryCard].forEach { $0?.isHidden = split }
        if hasPhoto { previewView.isHidden = split }
        stepsListView?.isHidden = !(split && hasPhoto)
        dragHintView?.isHidden = !(split && hasPhoto)
        guard split && hasPhoto else { return }
        paneCheckLabel?.text = checkLabel.text
        paneCheckIconView?.image = checkIconView.image
        paneCheckIconView?.tintColor = checkIconView.tintColor
        paneCheckBadgeView?.backgroundColor = checkBadgeView.backgroundColor
        updateStepRows()
    }

    /// Photo done, Room current, Style and Final touches next (Figma Duo/L/04 · W1 selected).
    private func updateStepRows() {
        let room = session.detectedPlace?.title
        let subtitles = [isChecking ? "Checking the photo…".localized : (checkLabel.text ?? ""),
                         room.map { String(format: "%@ · detected".localized, $0) } ?? "Next: pick the room".localized,
                         "Next: pick a look".localized, "Structure, colors, details".localized]
        stepSubtitleLabels?.forEach { $0.text = subtitles[min($0.tag, 3)] }
        for row in stepRowViews ?? [] {
            let current = row.tag == 1
            row.backgroundColor = current ? .white : .clear
            row.layer.borderWidth = current ? 2 : 0
            row.layer.borderColor = DS.Color.lime.cgColor
        }
        stepIconContainers?.forEach { $0.backgroundColor = $0.tag == 0 ? DS.Color.lime : UIColor(named: "dsChip") }
        stepIconViews?.forEach { $0.alpha = $0.tag >= 2 ? 0.45 : 1 }
        stepTitleLabels?.forEach { $0.alpha = $0.tag >= 2 ? 0.45 : 1 }
    }

    // MARK: Selected state

    func didPick(_ image: UIImage, isDemo: Bool, knownRoom: InteriorType? = nil) {
        session.photo = image
        session.isDemoPhoto = isDemo
        session.detectedPlace = nil
        session.place = nil
        photoImageView.image = image
        showSelected(animated: true)
        isChecking = true
        nextButton.inactive = true
        startScan()
        let started = Date()
        PhotoQualityChecker.check(image) { [weak self] result in
            guard let self else { return }
            let room = knownRoom ?? result.room
            if [.interior, .furnish, .rearrange, .newWalls, .newFlooring, .reference].contains(session.option), let room {
                session.detectedPlace = .room(room)
            }
            // Keep the scan visible for at least one pass (dev notes: 0.35–1.35 s).
            let wait = max(0, 1.35 - Date().timeIntervalSince(started))
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) {
                self.finishCheck(tooDark: result.isTooDark && !isDemo)
            }
        }
    }

    private func showSelected(animated: Bool) {
        updateTitles()
        let changes = {
            self.sourcesStack.isHidden = true
            self.sourcesStack.alpha = 0
            self.previewView.isHidden = false
            self.previewView.alpha = 1
        }
        photoImageView.image = session.photo
        guard animated, !DS.Motion.reduceMotion else {
            changes()
            nextButton.inactive = false
            checkBadgeView.alpha = 1
            return
        }
        previewView.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        checkBadgeView.alpha = 0
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut) {
            changes()
            self.previewView.transform = .identity
            self.view.layoutIfNeeded()
        }
        scrollView.setContentOffset(.zero, animated: true)
    }

    private func startScan() {
        guard !DS.Motion.reduceMotion else { return }
        scanLineView.alpha = 1
        scanBottomConstraint.constant = 0
        previewView.layoutIfNeeded()
        let height = previewView.bounds.height + 90
        scanAnimator = UIViewPropertyAnimator(duration: 1.0, curve: .easeInOut) {
            self.scanBottomConstraint.constant = -height
            self.previewView.layoutIfNeeded()
        }
        scanAnimator?.addCompletion { [weak self] _ in
            guard let self else { return }
            if self.isChecking { self.startScan() } else { self.scanLineView.alpha = 0 }
        }
        scanAnimator?.startAnimation(afterDelay: 0.35)
    }

    private func finishCheck(tooDark: Bool) {
        isChecking = false
        updateTitles()
        let room = session.detectedPlace?.title
        if tooDark {
            checkLabel.text = "Too dark — results may vary".localized
            checkIconView.image = UIImage(systemName: "exclamationmark.triangle")
            checkIconView.tintColor = UIColor(red: 0.75, green: 0.5, blue: 0, alpha: 1)
            checkBadgeView.backgroundColor = UIColor(named: "dsWarningSoft")
            DS.Haptic.warning()
        } else {
            checkLabel.text = room.map { String(format: "%@ · good light".localized, $0) } ?? "Good light".localized
            checkIconView.image = UIImage(systemName: "checkmark.circle")
            checkIconView.tintColor = DS.Color.link
            checkBadgeView.backgroundColor = UIColor.white.withAlphaComponent(0.85)
            DS.Haptic.success()
        }
        UIAccessibility.post(notification: .announcement, argument: checkLabel.text)
        DS.Motion.enter(checkBadgeView, delay: 0, scale: 0.5, duration: 0.4, pop: true)
        DS.Motion.enter(changeButton, delay: 0.15, scale: 0.5, duration: 0.4, pop: true)
        nextButton.inactive = false
        DS.Motion.enter(nextButton, delay: 0.15, dy: 16)
        nextButton.runShimmer(delay: 0.85)
    }

    // MARK: Motion

    private func runEntrance() {
        let m = DS.Motion.self
        m.enter(titleStack, delay: 0.0, dy: 10, duration: 0.35)
        if session.photo == nil {
            m.enter(takePhotoCard, delay: 0.04, scale: 0.97, duration: 0.35)
            m.enter(libraryCard, delay: 0.08, scale: 0.97, duration: 0.35)
            m.enter(demoTitleLabel, delay: 0.12, dy: 8, duration: 0.35)
            demoControls.sorted { $0.tag < $1.tag }.enumerated().forEach {
                m.enter($1, delay: 0.14 + Double($0) * 0.04, dx: 28, duration: 0.35)
            }
            m.enter(tipsButton, delay: 0.3, scale: 0.6, duration: 0.35, pop: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in self?.wiggleBulb() }
        }
        UIView.animate(withDuration: 0.25, delay: 0.15) { self.nextButton.alpha = 1 }
    }

    private func wiggleBulb() {
        guard !DS.Motion.reduceMotion else { return }
        let anim = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        let a = CGFloat.pi / 15
        anim.values = [0, a, -a, a * 0.5, 0]
        anim.duration = 0.6
        tipsIconView.layer.add(anim, forKey: "wiggle")
    }
}

extension WizardPhotoViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = (object as? UIImage)?.preparedForEditing() else { return }
            DispatchQueue.main.async { self?.didPick(image, isDemo: false) }
        }
    }
}

extension WizardPhotoViewController: UIDropInteractionDelegate {
    func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        session.items.count == 1 && session.canLoadObjects(ofClass: UIImage.self)
    }

    func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        UIDropProposal(operation: .copy)
    }

    func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        session.loadObjects(ofClass: UIImage.self) { [weak self] objects in
            guard let image = objects.first as? UIImage else { return }
            AmplitudeService.shared.logRedesignEvent("wizard_photo_dropped", properties: [:])
            UIImage.prepareForEditing(image) { self?.didPick($0, isDemo: false) }
        }
    }
}
