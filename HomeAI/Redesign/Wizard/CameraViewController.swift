import UIKit
import AVFoundation
import CoreMotion
import PhotosUI

/// Preview layer host for the camera XIB.
final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

/// A/04 · W1-c Camera with a framing guide (grid 3×3, level line, hint). Layout: CameraViewController.xib.
final class CameraViewController: UIViewController {

    @IBOutlet private weak var previewView: CameraPreviewView!
    @IBOutlet private weak var gridView: UIView!
    @IBOutlet private weak var levelView: UIView!
    @IBOutlet private weak var hintView: UIView!
    @IBOutlet private weak var hintLabel: UILabel!
    @IBOutlet private weak var closeButton: DSPressableControl!
    @IBOutlet private weak var flashButton: DSPressableControl!
    @IBOutlet private weak var zoomButton: DSPressableControl!
    @IBOutlet private weak var zoomLabel: UILabel!
    @IBOutlet private weak var libraryButton: DSPressableControl!
    @IBOutlet private weak var lastPhotoView: UIImageView!
    @IBOutlet private weak var shutterButton: DSPressableControl!
    @IBOutlet private weak var flipButton: DSPressableControl!
    @IBOutlet private weak var flashOverlay: UIView!

    var onCapture: ((UIImage) -> Void)?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session")
    private let motion = CMMotionManager()
    private var currentInput: AVCaptureDeviceInput?
    private var usingFront = false
    private var flashMode: AVCaptureDevice.FlashMode = .off
    private var isUltraWide = false
    private var breathingTimer: Timer?
    private var wasLevel = false

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    /// System camera permission (NSCameraUsageDescription), then calls back on main.
    static func requestAccess(from presenter: UIViewController, completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in DispatchQueue.main.async { completion(granted) } }
        default:
            let alert = UIAlertController(title: "Camera access is off".localized,
                                          message: "Allow camera access in Settings, or choose a photo from your library.".localized,
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Not now".localized, style: .cancel))
            alert.addAction(UIAlertAction(title: "Open Settings".localized, style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            })
            presenter.present(alert, animated: true)
            completion(false)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        hintLabel.text = "Step back to fit the whole room".localized
        previewView.previewLayer.session = session
        previewView.previewLayer.videoGravity = .resizeAspectFill
        configureSession()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        sessionQueue.async { [session] in if !session.isRunning { session.startRunning() } }
        runEntrance()
        startLevelUpdates()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        breathingTimer?.invalidate()
        motion.stopDeviceMotionUpdates()
        sessionQueue.async { [session] in if session.isRunning { session.stopRunning() } }
    }

    // MARK: Session

    private func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            let ultraWide = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
            let device = ultraWide ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            self.isUltraWide = ultraWide != nil
            if let device, let input = try? AVCaptureDeviceInput(device: device), self.session.canAddInput(input) {
                self.session.addInput(input)
                self.currentInput = input
            }
            if self.session.canAddOutput(self.photoOutput) { self.session.addOutput(self.photoOutput) }
            self.session.commitConfiguration()
            let available = self.currentInput != nil
            let hasBoth = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) != nil
            DispatchQueue.main.async {
                self.zoomButton.isHidden = !hasBoth
                self.zoomLabel.text = self.isUltraWide ? "0.5×" : "1×"
                if !available { self.cameraUnavailable() }
            }
        }
    }

    private func switchTo(_ device: AVCaptureDevice?) {
        guard let device else { return }
        sessionQueue.async { [weak self] in
            guard let self, let input = try? AVCaptureDeviceInput(device: device) else { return }
            self.session.beginConfiguration()
            if let current = self.currentInput { self.session.removeInput(current) }
            if self.session.canAddInput(input) {
                self.session.addInput(input)
                self.currentInput = input
            }
            self.session.commitConfiguration()
        }
    }

    private func cameraUnavailable() {
        DSToastView.show("Camera isn't available on this device".localized, style: .info, symbol: "camera")
        shutterButton.isEnabled = false
        shutterButton.alpha = 0.4
    }

    // MARK: Actions

    @IBAction private func didTapClose(_ sender: Any) {
        dismiss(animated: true)
    }

    @IBAction private func didTapFlash(_ sender: Any) {
        flashMode = flashMode == .off ? .on : .off
        DS.Haptic.selection()
        (flashButton.subviews.first as? UIImageView)?.image = UIImage(systemName: flashMode == .on ? "bolt.fill" : "bolt.slash")
        flashButton.accessibilityValue = flashMode == .on ? "On".localized : "Off".localized
    }

    @IBAction private func didTapZoom(_ sender: Any) {
        isUltraWide.toggle()
        DS.Haptic.selection()
        zoomLabel.text = isUltraWide ? "0.5×" : "1×"
        let type: AVCaptureDevice.DeviceType = isUltraWide ? .builtInUltraWideCamera : .builtInWideAngleCamera
        switchTo(AVCaptureDevice.default(type, for: .video, position: .back))
    }

    @IBAction private func didTapFlip(_ sender: Any) {
        usingFront.toggle()
        DS.Haptic.selection()
        zoomButton.isHidden = usingFront
        let device = usingFront
            ? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            : AVCaptureDevice.default(isUltraWide ? .builtInUltraWideCamera : .builtInWideAngleCamera, for: .video, position: .back)
        UIView.transition(with: previewView, duration: 0.35, options: usingFront ? .transitionFlipFromLeft : .transitionFlipFromRight,
                          animations: nil)
        switchTo(device)
    }

    @IBAction private func didTapLibrary(_ sender: Any) {
        var config = PHPickerConfiguration()
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    @IBAction private func didTapShutter(_ sender: Any) {
        guard currentInput != nil else { return }
        DS.Haptic.medium()
        breathingTimer?.invalidate()
        flashOverlay.alpha = 1
        UIView.animate(withDuration: 0.1, delay: 0.05) { self.flashOverlay.alpha = 0 }
        let settings = AVCapturePhotoSettings()
        if photoOutput.supportedFlashModes.contains(flashMode) { settings.flashMode = flashMode }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    private func finish(with image: UIImage) {
        let onCapture = self.onCapture
        dismiss(animated: true) { onCapture?(image) }
    }

    // MARK: Level (CoreMotion, ±2°)

    private func startLevelUpdates() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1 / 30
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let g = data?.gravity else { return }
            let roll = atan2(g.x, -g.y)
            let level = abs(roll) < (2 * .pi / 180)
            self.levelView.transform = CGAffineTransform(rotationAngle: CGFloat(-roll))
            if level != self.wasLevel {
                self.wasLevel = level
                UIView.animate(withDuration: 0.2) {
                    self.levelView.backgroundColor = level ? DS.Color.lime : .white
                }
                if level { DS.Haptic.selection() }
            }
        }
    }

    // MARK: Motion

    private func runEntrance() {
        UIView.animate(withDuration: 0.4) { self.previewView.alpha = 1 }
        UIView.animate(withDuration: 0.4, delay: 0.3) { self.gridView.alpha = 1 }
        DS.Motion.enter(hintView, delay: 0.5, dy: -10)
        if !DS.Motion.reduceMotion {
            levelView.transform = CGAffineTransform(rotationAngle: -6 * .pi / 180)
            UIView.animate(withDuration: 0.8, delay: 0.7, usingSpringWithDamping: 0.4, initialSpringVelocity: 0) {
                self.levelView.transform = .identity
            }
        }
        UIView.animate(withDuration: 0.4, delay: 4.5, options: [.allowUserInteraction]) { self.hintView.alpha = 0 }
        breathingTimer = Timer.scheduledTimer(withTimeInterval: 1.4, repeats: true) { [weak self] _ in
            guard let self, !DS.Motion.reduceMotion else { return }
            UIView.animate(withDuration: 0.7, delay: 0, options: [.autoreverse, .allowUserInteraction, .curveEaseInOut]) {
                self.shutterButton.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            } completion: { _ in self.shutterButton.transform = .identity }
        }
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            DispatchQueue.main.async { DSToastView.show("Couldn't take the photo. Try again.".localized, style: .warning) }
            return
        }
        DispatchQueue.main.async { self.finish(with: image) }
    }
}

extension CameraViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            DispatchQueue.main.async { self?.finish(with: image) }
        }
    }
}
