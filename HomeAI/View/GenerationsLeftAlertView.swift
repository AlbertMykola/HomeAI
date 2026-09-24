import UIKit
import Lottie

final class GenerationsLeftAlertView: UIView {

    private struct Defaults {
        struct Text {
            static let titleFormat = "generations_left_alert_title_format".localized
            static let subtitle = "generations_left_alert_subtitle".localized
            static let unlimited = "generations_left_alert_feature_unlimited".localized
            static let quality = "generations_left_alert_feature_quality".localized
            static let faster = "generations_left_alert_feature_faster".localized
            static let getPro = "generations_left_alert_get_pro".localized
            static let maybeLater = "generations_left_alert_maybe_later".localized
        }

        struct Images {
            static let unlimited = "pw_infinity_icon"
            static let quality = "pw_stars_icon"
            static let faster = "pw_flash_icon"
        }

        struct Lottie {
            static let trophyAnimationName = "Trophy"
        }

        struct Colors {
            static let title = UIColor.white
            static let subtitle = UIColor.white
            static let accent = UIColor(red: 164 / 255, green: 250 / 255, blue: 28 / 255, alpha: 1)
            static let getPro = UIColor(red: 255 / 255, green: 45 / 255, blue: 29 / 255, alpha: 1)
            static let maybeLater = UIColor.white.withAlphaComponent(0.6)
            static let cardTint = UIColor.white.withAlphaComponent(0.08)
            static let featuresTint = UIColor.black.withAlphaComponent(0.38)
            static let dimBackground = UIColor.black.withAlphaComponent(0.45)
        }

        struct Layout {
            static let cardWidth: CGFloat = 303
            static let cardCornerRadius: CGFloat = 34
            static let featuresCornerRadius: CGFloat = 12.3
        }
    }

    @IBOutlet weak private var cardGlassView: LiquidGlassView!
    @IBOutlet weak private var trophyImageView: UIImageView!
    @IBOutlet weak private var headlineLabel: UILabel!
    @IBOutlet weak private var subtitleLabel: UILabel!
    @IBOutlet weak private var featuresGlassView: LiquidGlassView!
    @IBOutlet weak private var unlimitedIconView: UIImageView!
    @IBOutlet weak private var unlimitedLabel: UILabel!
    @IBOutlet weak private var qualityIconView: UIImageView!
    @IBOutlet weak private var qualityLabel: UILabel!
    @IBOutlet weak private var fasterIconView: UIImageView!
    @IBOutlet weak private var fasterLabel: UILabel!
    @IBOutlet weak private var getProButton: UIButton!
    @IBOutlet weak private var maybeLaterButton: UIButton!

    private weak var parentViewController: UIViewController?
    private var backgroundView: UIView?
    private var trophyLottieView: LottieAnimationView?
    private var paywallPlacement = Constants.Keys.optionPlacememt
    private var remainingGenerations = 0
    private let amplitude = AmplitudeService.shared

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        cardGlassView.cornerRadiusValue = Defaults.Layout.cardCornerRadius.scaledByWidth()
        featuresGlassView.cornerRadiusValue = Defaults.Layout.featuresCornerRadius.scaledByWidth()
        getProButton.layer.cornerRadius = getProButton.bounds.height / 2
    }

    static func present(from viewController: UIViewController, placement: String = Constants.Keys.optionPlacememt) {
        guard !AdaptyService.shared.hasActiveSubscription else { return }
        guard let alertView = Bundle.main.loadNibNamed("GenerationsLeftAlertView", owner: nil, options: nil)?.first as? GenerationsLeftAlertView else {
            return
        }
        alertView.paywallPlacement = placement
        alertView.refreshContent()
        alertView.show(in: viewController)
    }

    private func setupUI() {
        backgroundColor = .clear
        overrideUserInterfaceStyle = .dark
        cardGlassView.overrideUserInterfaceStyle = .dark
        featuresGlassView.overrideUserInterfaceStyle = .dark

        cardGlassView.glassStyle = 0
        cardGlassView.glassTintColor = Defaults.Colors.cardTint
        cardGlassView.fallbackTintOpacity = 0.16
        cardGlassView.fallbackBlurAlpha = 0.88
        cardGlassView.fallbackGradient = true
        cardGlassView.fallbackShadow = true

        featuresGlassView.glassStyle = 0
        featuresGlassView.glassTintColor = Defaults.Colors.featuresTint
        featuresGlassView.fallbackTintOpacity = 0.4
        featuresGlassView.fallbackBlurAlpha = 0.9
        featuresGlassView.fallbackGradient = false
        featuresGlassView.fallbackShadow = false
        featuresGlassView.alpha = 1

        setupTrophyLottie()

        subtitleLabel.text = Defaults.Text.subtitle
        subtitleLabel.textColor = Defaults.Colors.subtitle

        unlimitedIconView.image = UIImage(named: Defaults.Images.unlimited)
        unlimitedLabel.text = Defaults.Text.unlimited
        unlimitedLabel.textColor = Defaults.Colors.title

        qualityIconView.image = UIImage(named: Defaults.Images.quality)
        qualityLabel.text = Defaults.Text.quality
        qualityLabel.textColor = Defaults.Colors.title

        fasterIconView.image = UIImage(named: Defaults.Images.faster)
        fasterLabel.text = Defaults.Text.faster
        fasterLabel.textColor = Defaults.Colors.title

        getProButton.backgroundColor = Defaults.Colors.getPro
        getProButton.setTitle(Defaults.Text.getPro, for: .normal)
        getProButton.setTitleColor(.white, for: .normal)
        getProButton.titleLabel?.font = UIFont.geologica(.standard(.regular), size: 14)

        maybeLaterButton.setTitle(Defaults.Text.maybeLater, for: .normal)
        maybeLaterButton.setTitleColor(Defaults.Colors.maybeLater, for: .normal)
        maybeLaterButton.titleLabel?.font = UIFont.geologica(.standard(.regular), size: 10)
        maybeLaterButton.backgroundColor = .clear
    }

    private func setupTrophyLottie() {
        trophyImageView.image = nil
        trophyImageView.backgroundColor = .clear
        trophyImageView.contentMode = .scaleAspectFit

        trophyLottieView?.removeFromSuperview()
        trophyLottieView = nil

        let animationView = LottieAnimationView(name: Defaults.Lottie.trophyAnimationName)
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.contentMode = .scaleAspectFit
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.loopMode = .loop
        animationView.animationSpeed = 1

        trophyImageView.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.topAnchor.constraint(equalTo: trophyImageView.topAnchor),
            animationView.leadingAnchor.constraint(equalTo: trophyImageView.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: trophyImageView.trailingAnchor),
            animationView.bottomAnchor.constraint(equalTo: trophyImageView.bottomAnchor)
        ])

        trophyLottieView = animationView
    }

    private func refreshContent() {
        remainingGenerations = FreeGenerationManager.shared.remainingFreeGenerations
        headlineLabel.attributedText = makeHeadline(remaining: remainingGenerations)
    }

    private func makeHeadline(remaining: Int) -> NSAttributedString {
        let full = String(format: Defaults.Text.titleFormat, "\(remaining)")
        let number = "\(remaining)"
        let attributed = NSMutableAttributedString(
            string: full,
            attributes: [
                .font: UIFont.geologica(.standard(.medium), size: 25) ?? .systemFont(ofSize: 25, weight: .medium),
                .foregroundColor: Defaults.Colors.title
            ]
        )

        if let range = full.range(of: number) {
            let nsRange = NSRange(range, in: full)
            attributed.addAttribute(.foregroundColor, value: Defaults.Colors.accent, range: nsRange)
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        attributed.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: attributed.length))
        return attributed
    }

    private func show(in viewController: UIViewController) {
        parentViewController = viewController

        let bgView = UIView(frame: viewController.view.bounds)
        bgView.backgroundColor = Defaults.Colors.dimBackground
        bgView.alpha = 0
        bgView.translatesAutoresizingMaskIntoConstraints = false

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissAlert))
        bgView.addGestureRecognizer(tapGesture)
        bgView.isUserInteractionEnabled = true

        viewController.view.addSubview(bgView)
        NSLayoutConstraint.activate([
            bgView.topAnchor.constraint(equalTo: viewController.view.topAnchor),
            bgView.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor),
            bgView.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor),
            bgView.bottomAnchor.constraint(equalTo: viewController.view.bottomAnchor)
        ])
        backgroundView = bgView

        viewController.view.addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false

        let cardWidth = Defaults.Layout.cardWidth.scaledByWidth()
        NSLayoutConstraint.activate([
            centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor),
            widthAnchor.constraint(equalToConstant: cardWidth),
            leadingAnchor.constraint(greaterThanOrEqualTo: viewController.view.leadingAnchor, constant: 20),
            trailingAnchor.constraint(lessThanOrEqualTo: viewController.view.trailingAnchor, constant: -20)
        ])

        amplitude.logEvent(.showGenerationsLeftAlert(remaining: remainingGenerations))

        alpha = 0
        transform = CGAffineTransform(scaleX: 0.92, y: 0.92)

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0.4, options: .curveEaseOut) {
            self.alpha = 1
            self.transform = .identity
            self.backgroundView?.alpha = 1
        } completion: { _ in
            self.trophyLottieView?.play()
        }
    }

    @IBAction private func getProAction(_ sender: UIButton) {
        amplitude.logEvent(.generationsLeftGetProAction(remaining: remainingGenerations))
        finishDismiss {
            NavigationManager.shared.showPremium(placement: self.paywallPlacement)
        }
    }

    @IBAction private func maybeLaterAction(_ sender: UIButton) {
        dismissAlert()
    }

    @objc private func dismissAlert() {
        amplitude.logEvent(.generationsLeftMaybeLaterAction(remaining: remainingGenerations))
        finishDismiss(completion: nil)
    }

    private func finishDismiss(completion: (() -> Void)?) {
        trophyLottieView?.stop()
        UIView.animate(withDuration: 0.25, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            self.backgroundView?.alpha = 0
        }) { _ in
            self.removeFromSuperview()
            self.backgroundView?.removeFromSuperview()
            self.backgroundView = nil
            completion?()
        }
    }
}
