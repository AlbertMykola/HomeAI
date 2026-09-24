import UIKit
import StoreKit
import Lottie

final class LikeAlertView: UIView {

    private struct Defaults {
        struct Text {
            static let titlePrefix = "like_alert_title_prefix".localized
            static let description = "like_alert_description".localized
            static let rate = "YES, RATE!".localized
            static let no = "No, thanks".localized
        }

        struct Colors {
            static let cardBackground = UIColor.white
            static let title = UIColor.black
            static let description = UIColor.black
            static let rateButton = UIColor(red: 255 / 255, green: 45 / 255, blue: 29 / 255, alpha: 1)
            static let close = UIColor.black.withAlphaComponent(0.5)
            static let gradientStart = UIColor(red: 1, green: 7 / 255, blue: 69 / 255, alpha: 1)
            static let gradientEnd = UIColor(red: 1, green: 74 / 255, blue: 178 / 255, alpha: 1)
            static let brandStroke = UIColor(red: 186 / 255, green: 29 / 255, blue: 29 / 255, alpha: 1)
        }

        struct Layout {
            static let cardWidth: CGFloat = 364
            static let cardCornerRadius: CGFloat = 26.1
            static let imageCornerRadius: CGFloat = 25.1
            static let rateButtonHeight: CGFloat = 43.9
            static let rateButtonMinWidth: CGFloat = 157.1
        }

        struct Lottie {
            static let fiveStarsAnimationName = "5 stars"
        }
    }

    @IBOutlet weak private var imageContainerView: UIView!
    @IBOutlet weak private var heroImageView: UIImageView!
    @IBOutlet weak private var titlePrefixLabel: UILabel!
    @IBOutlet weak private var brandTitleLabel: UILabel!
    @IBOutlet weak private var descriptionLabel: UILabel!
    @IBOutlet weak private var starsLottieContainerView: UIView!
    @IBOutlet weak private var rateNowButton: UIButton!
    @IBOutlet weak private var closeButton: UIButton!

    weak private var parentViewController: UIViewController?
    private var backgroundView: UIView?
    private var onDismissed: (() -> Void)?
    private var brandGradientLayer: CAGradientLayer?
    private var lastBrandGradientBounds: CGRect = .zero
    private var starsLottieView: LottieAnimationView?

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = Defaults.Layout.cardCornerRadius.scaledByWidth()
        let imageRadius = Defaults.Layout.imageCornerRadius.scaledByWidth()
        imageContainerView.layer.cornerRadius = imageRadius
        heroImageView.layer.cornerRadius = imageRadius
        rateNowButton.layer.cornerRadius = rateNowButton.bounds.height / 2
        updateBrandTitleGradientIfNeeded()
    }

    private func setupUI() {
        backgroundColor = Defaults.Colors.cardBackground
        layer.masksToBounds = true

        imageContainerView.clipsToBounds = true
        imageContainerView.layer.masksToBounds = true
        imageContainerView.backgroundColor = .clear

        heroImageView.image = UIImage(named: "doulike_alert_image")
        heroImageView.contentMode = .scaleAspectFit
        heroImageView.clipsToBounds = true
        heroImageView.layer.cornerRadius = Defaults.Layout.imageCornerRadius.scaledByWidth()
        heroImageView.layer.masksToBounds = true

        titlePrefixLabel.text = Defaults.Text.titlePrefix
        titlePrefixLabel.textColor = Defaults.Colors.title

        brandTitleLabel.text = "\(Constants.Text.brand)?"
        brandTitleLabel.textColor = .clear

        descriptionLabel.text = Defaults.Text.description
        descriptionLabel.textColor = Defaults.Colors.description

        setupStarsLottie()

        rateNowButton.backgroundColor = Defaults.Colors.rateButton
        rateNowButton.setTitle(Defaults.Text.rate, for: .normal)
        rateNowButton.setTitleColor(.white, for: .normal)
        rateNowButton.titleLabel?.font = UIFont.geologica(.standard(.regular), size: 14)
        rateNowButton.contentEdgeInsets = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)

        closeButton.setTitle(Defaults.Text.no, for: .normal)
        closeButton.setTitleColor(Defaults.Colors.close, for: .normal)
        closeButton.titleLabel?.font = UIFont.geologica(.standard(.regular), size: 14)
        closeButton.backgroundColor = .clear
    }

    private func setupStarsLottie() {
        starsLottieContainerView.backgroundColor = .clear

        starsLottieView?.removeFromSuperview()
        starsLottieView = nil

        let animationView = LottieAnimationView(name: Defaults.Lottie.fiveStarsAnimationName)
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.contentMode = .scaleAspectFit
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.loopMode = .loop
        animationView.animationSpeed = 1

        starsLottieContainerView.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.topAnchor.constraint(equalTo: starsLottieContainerView.topAnchor),
            animationView.leadingAnchor.constraint(equalTo: starsLottieContainerView.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: starsLottieContainerView.trailingAnchor),
            animationView.bottomAnchor.constraint(equalTo: starsLottieContainerView.bottomAnchor)
        ])

        starsLottieView = animationView
    }

    private func updateBrandTitleGradientIfNeeded() {
        brandTitleLabel.layoutIfNeeded()
        let bounds = brandTitleLabel.bounds
        guard bounds.width > 1, bounds.height > 1, bounds != lastBrandGradientBounds else { return }
        lastBrandGradientBounds = bounds

        brandGradientLayer?.removeFromSuperlayer()

        let gradient = CAGradientLayer()
        gradient.frame = bounds
        gradient.colors = [
            Defaults.Colors.gradientStart.cgColor,
            Defaults.Colors.gradientEnd.cgColor
        ]
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)

        let renderer = UIGraphicsImageRenderer(size: bounds.size)
        let maskImage = renderer.image { _ in
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center

            let font = brandTitleLabel.font ?? UIFont.geologica(.standard(.bold), size: 41) ?? .boldSystemFont(ofSize: 41)
            let text = brandTitleLabel.text ?? ""
            let strokeWidth: CGFloat = -1.02

            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.black,
                .strokeColor: Defaults.Colors.brandStroke,
                .strokeWidth: strokeWidth,
                .paragraphStyle: paragraph
            ]

            let textSize = (text as NSString).size(withAttributes: attrs)
            let rect = CGRect(
                x: (bounds.width - textSize.width) / 2,
                y: (bounds.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            (text as NSString).draw(in: rect, withAttributes: attrs)
        }

        let mask = CALayer()
        mask.frame = bounds
        mask.contents = maskImage.cgImage
        gradient.mask = mask

        brandTitleLabel.layer.addSublayer(gradient)
        brandGradientLayer = gradient
    }

    func show(in viewController: UIViewController, onDismissed: (() -> Void)? = nil) {
        self.onDismissed = onDismissed
        parentViewController = viewController

        let bgView = UIView(frame: viewController.view.bounds)
        bgView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
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

        alpha = 0
        transform = CGAffineTransform(scaleX: 0.92, y: 0.92)

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.82, initialSpringVelocity: 0.4, options: .curveEaseOut) {
            self.alpha = 1
            self.transform = .identity
            self.backgroundView?.alpha = 1
        } completion: { _ in
            self.starsLottieView?.play()
        }
    }

    private func openAppStoreForRating() {
        let appleId = Constants.Keys.appleId
        guard let url = URL(string: "https://apps.apple.com/app/id\(appleId)?action=write-review") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    @IBAction private func closeAction(_ sender: UIButton) {
        dismissAlert()
    }

    @IBAction private func rateNowAction(_ sender: UIButton) {
        AmplitudeService.shared.logEvent(.rateNowAction)
        openAppStoreForRating()
        finishDismiss()
    }

    @objc private func dismissAlert() {
        AmplitudeService.shared.logEvent(.dontRateAction)
        finishDismiss()
    }

    private func finishDismiss() {
        starsLottieView?.pause()
        UIView.animate(withDuration: 0.25, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
            self.backgroundView?.alpha = 0
        }) { _ in
            self.removeFromSuperview()
            self.backgroundView?.removeFromSuperview()
            self.backgroundView = nil
            self.onDismissed?()
            self.onDismissed = nil
        }
    }
}
