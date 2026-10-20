import UIKit

/// A/02 · P5 Welcome to Pro: confetti (lime / black / white, 1.2 s, CAEmitterLayer) then the content eases in
/// (1.2 s ease-out). Haptic .success. Layout: Paywall.storyboard.
final class WelcomeProViewController: UIViewController {

    @IBOutlet private weak var markView: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var listView: UIView!
    @IBOutlet private var itemLabels: [UILabel]!
    @IBOutlet private weak var startButton: DSPrimaryButton!
    @IBOutlet private weak var startLabel: UILabel!

    private var onStart: (() -> Void)?
    private var didRun = false

    static func make(onStart: @escaping () -> Void) -> WelcomeProViewController {
        let vc = AppStoryboard.instantiate(WelcomeProViewController.self)
        vc.onStart = onStart
        vc.modalPresentationStyle = .fullScreen
        vc.overrideUserInterfaceStyle = .light
        return vc
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "Welcome to Pro".localized
        subtitleLabel.text = "Everything is unlocked. Go make every room yours.".localized
        let items = ["Unlimited redesigns", "All 11 tools", "HD export without caption"]
        itemLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = items[$0].localized }
        startLabel.text = "Start designing".localized
        [markView, titleLabel, subtitleLabel, listView, startButton].forEach { $0?.alpha = 0 }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didRun else { return }
        didRun = true
        DS.Haptic.success()
        if !DS.Motion.reduceMotion { burstConfetti() }
        let m = DS.Motion.self
        m.enter(markView, delay: 0.1, scale: 0.6, duration: 0.6, pop: true)
        m.enter(titleLabel, delay: 0.3, dy: 16, duration: 0.6)
        m.enter(subtitleLabel, delay: 0.4, dy: 16, duration: 0.6)
        m.enter(listView, delay: 0.55, dy: 20, duration: 0.7)
        m.enter(startButton, delay: 0.8, dy: 24, spring: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in self?.startButton.runShimmer() }
    }

    private func burstConfetti() {
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: view.bounds.midX, y: -20)
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: view.bounds.width, height: 1)
        let colors: [UIColor] = [UIColor(hex: "A5EE2F"), UIColor(hex: "7BC41A"), .black, .white, UIColor(hex: "EEFFD6")]
        emitter.emitterCells = colors.map { color in
            let cell = CAEmitterCell()
            cell.contents = Self.confettiImage(color: color).cgImage
            cell.birthRate = 14
            cell.lifetime = 4
            cell.velocity = 260
            cell.velocityRange = 120
            cell.emissionLongitude = .pi
            cell.emissionRange = .pi / 5
            cell.spin = 3
            cell.spinRange = 4
            cell.scale = 0.9
            cell.scaleRange = 0.4
            cell.yAcceleration = 220
            cell.alphaSpeed = -0.2
            return cell
        }
        view.layer.insertSublayer(emitter, at: 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { emitter.birthRate = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) { emitter.removeFromSuperlayer() }
    }

    private static func confettiImage(color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 10, height: 7)).image { ctx in
            color.setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 10, height: 7), cornerRadius: 1.5).fill()
            if color == .white {
                UIColor.black.withAlphaComponent(0.08).setStroke()
                ctx.cgContext.stroke(CGRect(x: 0.5, y: 0.5, width: 9, height: 6))
            }
        }
    }

    @IBAction private func didTapStart(_ sender: Any) {
        let onStart = self.onStart
        dismiss(animated: true) { onStart?() }
    }
}
