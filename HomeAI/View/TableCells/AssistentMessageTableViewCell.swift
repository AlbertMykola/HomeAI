import UIKit
import Lottie

final class AssistentMessageTableViewCell: UITableViewCell {

    static let reuseIdentifier = "AssistentMessageTableViewCell"
    private static let typingAnimationName = "Typing"

    @IBOutlet weak private var portraitImageVIew: UIImageView!
    @IBOutlet weak private var messageLabel: UILabel!
    @IBOutlet weak private var messageContainerView: UIView!
    @IBOutlet weak private var lottieContainerView: UIView!

    private var typingView: LottieAnimationView?

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        portraitImageVIew.clipsToBounds = true
        portraitImageVIew.contentMode = .scaleAspectFill
        portraitImageVIew.layer.borderWidth = 2

        messageLabel.numberOfLines = 0
        messageContainerView.backgroundColor = UIColor.secondarySystemBackground
        lottieContainerView.backgroundColor = .clear

        setupTyping()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        portraitImageVIew.layer.cornerRadius = portraitImageVIew.bounds.height / 2
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        messageLabel.text = nil
        portraitImageVIew.image = nil
        portraitImageVIew.layer.borderColor = UIColor.clear.cgColor
        stopTyping()
        messageContainerView.isHidden = false
        lottieContainerView.isHidden = true
    }

    // MARK: - Configure
    func configure(text: String, type: AssistantType) {
        applyAssistantAppearance(type)
        messageLabel.text = text
        messageContainerView.isHidden = false
        lottieContainerView.isHidden = true
        stopTyping()
    }

    func configureTyping(type: AssistantType) {
        applyAssistantAppearance(type)
        messageLabel.text = nil
        messageContainerView.isHidden = true
        lottieContainerView.isHidden = false
        startTyping()
    }

    // MARK: - Private

    private func applyAssistantAppearance(_ type: AssistantType) {
        portraitImageVIew.image = UIImage(named: type.imageName)
        portraitImageVIew.layer.borderColor = type.ringColor.cgColor
    }

    private func setupTyping() {
        guard typingView == nil else { return }
        let v = LottieAnimationView(name: Self.typingAnimationName)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.contentMode = .scaleAspectFit
        v.loopMode = .loop
        v.backgroundBehavior = .pauseAndRestore
        lottieContainerView.addSubview(v)
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: lottieContainerView.topAnchor),
            v.leadingAnchor.constraint(equalTo: lottieContainerView.leadingAnchor),
            v.trailingAnchor.constraint(equalTo: lottieContainerView.trailingAnchor),
            v.bottomAnchor.constraint(equalTo: lottieContainerView.bottomAnchor)
        ])
        typingView = v
    }

    private func startTyping() {
        typingView?.play()
    }

    private func stopTyping() {
        typingView?.stop()
    }
}
