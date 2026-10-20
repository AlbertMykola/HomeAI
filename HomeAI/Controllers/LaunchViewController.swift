import UIKit

final class LaunchViewController: UIViewController {
    @IBOutlet private weak var logoView: UIImageView!
    @IBOutlet private weak var wordmarkLabel: UILabel!
    @IBOutlet private weak var taglineLabel: UILabel!
    @IBOutlet private weak var glowView: OnboardingSplashGlowView!
    @IBOutlet private weak var logoSize: NSLayoutConstraint!
    @IBOutlet private weak var logoCenterY: NSLayoutConstraint!
    private var didStart = false
    private var completionWork: DispatchWorkItem?

    required init?(coder: NSCoder) { super.init(coder: coder) }
    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        taglineLabel.text = "onboarding_splash_tagline".localized
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let layout = OnboardingLayout(size: view.bounds.size)
        // The exact Figma export has 30 pt side padding and its drop shadow below the mark.
        logoSize.constant = layout.value(156)
        logoCenterY.constant = layout.value(-50)
        let wordmark = NSMutableAttributedString(string: "ReHomely", attributes: [
            .font: layout.font(.semiBold, 38), .kern: layout.value(-0.76), .foregroundColor: UIColor.black
        ])
        wordmark.addAttribute(.foregroundColor, value: DS.Color.limeText, range: NSRange(location: 2, length: 6))
        wordmarkLabel.attributedText = wordmark
        taglineLabel.font = layout.font(.regular, 15)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didStart else { return }
        didStart = true
        if !UIAccessibility.isReduceMotionEnabled, !OnboardingPreview.still {
            logoView.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
            logoView.alpha = 0
            for label in [wordmarkLabel, taglineLabel] {
                label?.alpha = 0
                label?.transform = CGAffineTransform(translationX: 0, y: 12)
            }
            glowView.alpha = 0
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                self.logoView.transform = .identity
                self.logoView.alpha = 1
                self.wordmarkLabel.alpha = 1
                self.wordmarkLabel.transform = .identity
                self.taglineLabel.alpha = 1
                self.taglineLabel.transform = .identity
                self.glowView.alpha = 0.45
            }
        }
        guard !OnboardingPreview.enabled, !AppQA.enabled else { return }
        let work = DispatchWorkItem { NavigationManager.shared.proceedToApp() }
        completionWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: work)
    }

    deinit { completionWork?.cancel() }
}

final class OnboardingSplashGlowView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }
    override func awakeFromNib() {
        super.awakeFromNib()
        let gradient = layer as! CAGradientLayer
        gradient.type = .radial
        gradient.colors = [DS.Color.lime.withAlphaComponent(0.4).cgColor, UIColor.clear.cgColor]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        alpha = 0.45
    }
}
