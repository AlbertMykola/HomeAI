import UIKit
import StoreKit
import Lottie

private struct Defaults {
    struct Text {
        static let likeApp = "LIKE THE APP?".localized
        static let description = "Enjoy creating beautiful spaces? Share your feedback and help us make home redesign better for you".localized
        static let rate = "YES, RATE!".localized
        static let no = "No, thanks".localized
    }
}

final class LikeAlertView: UIView {

    @IBOutlet weak private var descriptionLabel: UILabel!
    @IBOutlet weak private var headlineLabel: UILabel!
    
    @IBOutlet weak private var rateNowButton: UIButton!
    @IBOutlet weak private var closeButton: UIButton!
    
    weak private var parentViewController: UIViewController?
    
    @IBOutlet weak private var lottieContainerView: UIView!
    
    private let starsAnimationName = "5 stars"
    private var starsAnimationView: LottieAnimationView?
    private var backgroundView: UIView?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
        setupLottie()
    }
        
    private func setupUI() {
        layer.cornerRadius = 16
        layer.masksToBounds = true
        headlineLabel.text = Defaults.Text.likeApp
        descriptionLabel.text = Defaults.Text.description
        rateNowButton.setTitle(Defaults.Text.rate, for: .normal)
        closeButton.setTitle(Defaults.Text.no, for: .normal)
        
        rateNowButton.titleLabel?.numberOfLines = 2
        rateNowButton.titleLabel?.lineBreakMode = .byWordWrapping
        rateNowButton.titleLabel?.textAlignment = .center
        rateNowButton.contentHorizontalAlignment = .center
    }
    
    private func setupLottie() {
        lottieContainerView.backgroundColor = .clear
        
        starsAnimationView?.removeFromSuperview()
        starsAnimationView = nil
        
        let animationView = LottieAnimationView(name: starsAnimationName)
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.contentMode = .scaleAspectFit
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.loopMode = .playOnce
        animationView.animationSpeed = 1.0
        
        lottieContainerView.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.topAnchor.constraint(equalTo: lottieContainerView.topAnchor),
            animationView.leadingAnchor.constraint(equalTo: lottieContainerView.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: lottieContainerView.trailingAnchor),
            animationView.bottomAnchor.constraint(equalTo: lottieContainerView.bottomAnchor)
        ])
        
        starsAnimationView = animationView
    }
    
    func show(in viewController: UIViewController) {
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
        
        NSLayoutConstraint.activate([
            centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor),
            leadingAnchor.constraint(greaterThanOrEqualTo: viewController.view.leadingAnchor, constant: 20),
            trailingAnchor.constraint(lessThanOrEqualTo: viewController.view.trailingAnchor, constant: -20)
        ])
        
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.starsAnimationView?.play()
        }
        
        UIView.animate(withDuration: 0.3, delay: 0.5, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.alpha = 1
            self.transform = .identity
            self.backgroundView?.alpha = 1
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
        openAppStoreForRating()
        dismissAlert()
    }
        
    @objc private func dismissAlert() {
        starsAnimationView?.stop()
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            self.backgroundView?.alpha = 0
        }) { _ in
            self.removeFromSuperview()
            self.backgroundView?.removeFromSuperview()
            self.backgroundView = nil
        }
    }
}
