import UIKit
import PhotosUI
import AVFoundation

/// A/04 · W1 Add photo (+ "selected" state). Layout: WizardPhotoViewController.xib.
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
        if session.photo != nil { showSelected(animated: false) }
        [titleStack, takePhotoCard, libraryCard, demoTitleLabel, tipsButton, nextButton].forEach { $0?.alpha = 0 }
        demoControls.forEach { $0.alpha = 0 }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didRunEntrance else { return }
        didRunEntrance = true
        runEntrance()
    }

    private func localize() {
        updateTitles()
        let titles = ["Take a photo", "Choose from library"]
        let subtitles = ["Camera with a framing guide", "Only the photo you pick is shared"]
        sourceTitleLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = titles[$0].localized }
        sourceSubtitleLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = subtitles[$0].localized }
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
        default:
            titleLabel.text = hasPhoto ? "Looks great!".localized : "Add a photo of your room".localized
        }
        if !hasPhoto {
            subtitleLabel.text = "One wide, well-lit photo works best.".localized
        } else if let place = session.detectedPlace {
            subtitleLabel.text = String(format: "We found a %@. Not right? You can change it next.".localized,
                                        place.title.lowercased())
        } else {
            subtitleLabel.text = "Nice shot. You can fine-tune the details next.".localized
        }
    }

    // MARK: Sources

    @IBAction private func didTapTakePhoto(_ sender: Any) {
        CameraViewController.requestAccess(from: self) { [weak self] granted in
            guard let self, granted else { return }
            let camera = CameraViewController(nibName: "CameraViewController", bundle: .main)
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

    @IBAction private func didTapDemo(_ sender: UIControl) {
        let demo = Self.demoRooms[min(sender.tag, Self.demoRooms.count - 1)]
        guard let image = UIImage(named: demo.0) else { return }
        didPick(image, isDemo: true, knownRoom: demo.1)
    }

    @IBAction private func didTapTips(_ sender: Any) {
        PhotoTipsSheetViewController.present(from: self)
    }

    @IBAction private func didTapNext(_ sender: Any) {
        guard session.photo != nil, !isChecking else {
            DS.Haptic.warning()
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
            if session.option == .interior || session.option == .floolPlan, let room {
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
        m.enter(titleStack, delay: 0.1, dy: 10)
        if session.photo == nil {
            m.enter(takePhotoCard, delay: 0.18, scale: 0.97)
            m.enter(libraryCard, delay: 0.25, scale: 0.97)
            m.enter(demoTitleLabel, delay: 0.32, dy: 8)
            demoControls.sorted { $0.tag < $1.tag }.enumerated().forEach { m.enter($1, delay: 0.38 + Double($0) * 0.06, dx: 28) }
            m.enter(tipsButton, delay: 0.62, scale: 0.6, duration: 0.4, pop: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in self?.wiggleBulb() }
        }
        UIView.animate(withDuration: 0.3, delay: 0.5) { self.nextButton.alpha = 1 }
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
            guard let image = object as? UIImage else { return }
            DispatchQueue.main.async { self?.didPick(image, isDemo: false) }
        }
    }
}
