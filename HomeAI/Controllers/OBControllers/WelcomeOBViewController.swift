import UIKit

private struct Defaults {
    struct Colors {
        static let gray = UIColor(red: 93 / 255, green: 80 / 255, blue: 68 / 255, alpha: 1)
    }
    
    struct Text {
        static let headline = "WELCOME TO THE WORLD OF CREATIVITY!".localized
        static let description = "Discover ideas and create your dream home in minutes.".localized
        static let next = "Next".localized
    }
}
class WelcomeOBViewController: UIViewController, OBPageChild {
    
    @IBOutlet weak private var liquidGlassView: LiquidGlassView!
    
    @IBOutlet weak private var bottomContainerView: UIView!
    
    @IBOutlet weak private var nextButton: UIButton!
    
    @IBOutlet weak private var descriptionLabel: UILabel!
    @IBOutlet weak private var headlineLabel: UILabel!
    
    @IBOutlet private var widthConstaints: [NSLayoutConstraint]!
    @IBOutlet private var heightConstraints: [NSLayoutConstraint]!
    
    weak var obDelegate: OBPageChildDelegate?

    private var addedGradient = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        config()
        AmplitudeService.shared.logEvent(.showOBWelcome)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if !addedGradient {
            bottomContainerView.setGradient(
                stops: [.init(percent: 0,  color: Defaults.Colors.gray.withAlphaComponent(0)),
                    .init(percent: 50, color: Defaults.Colors.gray.withAlphaComponent(50)),
                        .init(percent: 100, color: Defaults.Colors.gray)
                ],
                direction: .vertical
            )
            addedGradient = true
        }
        liquidGlassView.cornerRadiusValue = liquidGlassView.frame.height / 2
        liquidGlassView.topLeftCorner = true
        liquidGlassView.topRightCorner = true
    }
    
    private func config() {
        nextButton.setTitle(Defaults.Text.next, for: .normal)
        headlineLabel.text = Defaults.Text.headline
        descriptionLabel.text = Defaults.Text.description
        widthConstaints.forEach { $0.scaleConstantByWidth() }
        heightConstraints.forEach { $0.scaleConstant() }
    }
    
    @IBAction private func nextAction(_ sender: UIButton) {
        obDelegate?.obChildRequestsNext(self)
    }
}
