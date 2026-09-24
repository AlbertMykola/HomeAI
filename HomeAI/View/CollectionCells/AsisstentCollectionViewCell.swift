import UIKit

private extension UIColor {
    /// Змішування RGB-компонент для проміжних стопів градієнта.
    func assistantListMixed(with other: UIColor, amount: CGFloat) -> UIColor {
        let t = max(0, min(1, amount))
        guard let c1 = cgColor.components, let c2 = other.cgColor.components,
              c1.count >= 3, c2.count >= 3 else { return self }
        let a1 = c1.count > 3 ? c1[3] : 1
        let a2 = c2.count > 3 ? c2[3] : 1
        return UIColor(
            red: c1[0] + (c2[0] - c1[0]) * t,
            green: c1[1] + (c2[1] - c1[1]) * t,
            blue: c1[2] + (c2[2] - c1[2]) * t,
            alpha: a1 + (a2 - a1) * t
        )
    }
}

private struct Defaults {
    struct Text {
        static let chat = "Chat".localized
    }
    struct Layout {
        static let cardBorderWidth: CGFloat = 0.75
        /// Легка «скляна» обводка картки.
        static let cardBorderAlpha: CGFloat = 0.28
        static let avatarBorderWidth: CGFloat = 2
        static let avatarBorderAlpha: CGFloat = 0.35
        /// Трохи прозоріша «Chat»-пігулка — помітніший градієнт під нею на всю ширину картки.
        static let chatPillAlpha: CGFloat = 0.28
    }
}

final class AsisstentCollectionViewCell: UICollectionViewCell {

    static let reuseIdentifier = "AsisstentCollectionViewCell"

    @IBOutlet weak private var cardContainerView: UIView!
    @IBOutlet weak private var chatPillView: UIView!
    @IBOutlet weak private var assistantImageView: UIImageView!
    @IBOutlet weak private var nameLabel: UILabel!
    @IBOutlet weak private var descriptionLabel: UILabel!
    @IBOutlet weak private var chatIconImageView: UIImageView!
    @IBOutlet weak private var chatLabel: UILabel!

    @IBOutlet private var yCollectionConstraint: [NSLayoutConstraint]!
    @IBOutlet private var xCollectionConstraint: [NSLayoutConstraint]!

    private let cardMaskLayer = CAShapeLayer()
    private let cardBorderLayer = CAShapeLayer()
    private let chatMaskLayer = CAShapeLayer()
    private var scaledAvatarSide: CGFloat = 44
    private var scaledChatPillHeight: CGFloat = 30

    // MARK: - Lifecycle

    override func awakeFromNib() {
        super.awakeFromNib()
        setupStaticAppearance()
        xCollectionConstraint.forEach { $0.scaleConstant() }
        yCollectionConstraint.forEach { $0.scaleConstant() }
        scaledAvatarSide = avatarHeightConstraint()?.constant ?? 44
        scaledChatPillHeight = chatPillHeightConstraint()?.constant ?? 30
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        adaptContentSizesToCardHeight()
        applyCardPillShape()
        applyChatPillShape()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        resetEntranceAppearance()
        nameLabel.text = nil
        descriptionLabel.text = nil
        assistantImageView.image = nil
        chatLabel.text = Defaults.Text.chat
        chatIconImageView.tintColor = .white
        chatPillView.backgroundColor = nil
    }

    // MARK: - Configure

    func configure(with type: AssistantType) {
        nameLabel.text = type.title
        descriptionLabel.text = type.shortDescription
        chatLabel.text = Defaults.Text.chat
        assistantImageView.image = UIImage(named: type.imageName)

        let gradient = type.listCardGradientColors
        let left = gradient.0
        let right = gradient.1
        let mid = left.assistantListMixed(with: right, amount: 0.5)
        cardContainerView.setGradient(
            stops: [
                .init(percent: 0, color: left),
                .init(percent: 38, color: mid),
                .init(percent: 100, color: right)
            ],
            direction: .horizontal
        )
        let accent = type.ringColor
        chatPillView.backgroundColor = accent.withAlphaComponent(Defaults.Layout.chatPillAlpha)
        chatIconImageView.tintColor = .white
        chatLabel.textColor = .white

        assistantImageView.layer.borderWidth = Defaults.Layout.avatarBorderWidth
        assistantImageView.layer.borderColor = UIColor.white.withAlphaComponent(Defaults.Layout.avatarBorderAlpha).cgColor
        setNeedsLayout()
    }

    // MARK: - Private

    private func avatarHeightConstraint() -> NSLayoutConstraint? {
        yCollectionConstraint.first {
            $0.firstAttribute == .height && ($0.firstItem as? UIView) === assistantImageView
        }
    }

    private func chatPillHeightConstraint() -> NSLayoutConstraint? {
        yCollectionConstraint.first {
            $0.firstAttribute == .height && ($0.firstItem as? UIView) === chatPillView
        }
    }

    /// На SE рядок інколи нижчий за «ідеальний» аватар — піджимаємо аватар/Chat, щоб капсула не ламалась.
    private func adaptContentSizesToCardHeight() {
        cardContainerView.layoutIfNeeded()
        let cardH = cardContainerView.bounds.height
        guard cardH > 1 else { return }

        let verticalPadding: CGFloat = 12
        let maxContent = max(24, floor(cardH - verticalPadding))
        avatarHeightConstraint()?.constant = min(scaledAvatarSide, maxContent)
        chatPillHeightConstraint()?.constant = min(scaledChatPillHeight, maxContent)
        cardContainerView.layoutIfNeeded()
    }

    private func applyCardPillShape() {
        let bounds = cardContainerView.bounds
        guard bounds.width > 2, bounds.height > 2 else { return }

        let radius = bounds.height * 0.5
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: radius)

        cardMaskLayer.frame = bounds
        cardMaskLayer.path = path.cgPath
        cardContainerView.layer.mask = cardMaskLayer

        if cardBorderLayer.superlayer == nil {
            cardContainerView.layer.addSublayer(cardBorderLayer)
        }
        cardBorderLayer.frame = bounds
        cardBorderLayer.path = path.cgPath
        cardBorderLayer.fillColor = UIColor.clear.cgColor
        cardBorderLayer.strokeColor = UIColor.white
            .withAlphaComponent(Defaults.Layout.cardBorderAlpha).cgColor
        cardBorderLayer.lineWidth = Defaults.Layout.cardBorderWidth

        cardContainerView.updateGradientFrame(cornerRadius: radius)

        let avatarRadius = assistantImageView.bounds.height * 0.5
        guard avatarRadius > 0 else { return }
        assistantImageView.layer.cornerRadius = avatarRadius
        assistantImageView.layer.cornerCurve = .continuous
    }

    private func applyChatPillShape() {
        chatPillView.layoutIfNeeded()
        let bounds = chatPillView.bounds
        guard bounds.width > 2, bounds.height > 2 else { return }

        let radius = bounds.height * 0.5
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: radius)
        chatMaskLayer.frame = bounds
        chatMaskLayer.path = path.cgPath
        chatPillView.layer.mask = chatMaskLayer
    }

    func resetEntranceAppearance() {
        cardContainerView.alpha = 1
        cardContainerView.transform = .identity
    }

    private func setupStaticAppearance() {
        contentView.backgroundColor = .clear
        backgroundColor = .clear

        cardContainerView.backgroundColor = .clear
        cardContainerView.clipsToBounds = false

        assistantImageView.clipsToBounds = true
        assistantImageView.contentMode = .scaleAspectFill

        nameLabel.textColor = .white
        nameLabel.font = .geologica(.standard(.semiBold), size: CGFloat(15).scaledByHeight())
        nameLabel.numberOfLines = 2
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        descriptionLabel.textColor = UIColor.white.withAlphaComponent(0.72)
        descriptionLabel.font = .geologica(.standard(.regular), size: CGFloat(12).scaledByHeight())
        descriptionLabel.numberOfLines = 2
        descriptionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        chatLabel.font = .geologica(.standard(.semiBold), size: CGFloat(12).scaledByHeight())
        chatLabel.textColor = .white
        chatLabel.text = Defaults.Text.chat
        chatLabel.setContentHuggingPriority(.required, for: .horizontal)
        chatLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        chatIconImageView.contentMode = .scaleAspectFit
        chatIconImageView.setContentCompressionResistancePriority(.required, for: .horizontal)

        chatPillView.clipsToBounds = true
        chatPillView.setContentCompressionResistancePriority(.required, for: .horizontal)
        chatPillView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
    }

    // MARK: - Вхідна анімація (список асистентів)

    /// Готує клітинку до появи знизу (викликати з контролера до старту анімації).
    /// Анімуємо `cardContainerView`, а не `contentView` — інакше `clipsToBounds` ріже заокруглення «пігулки».
    func prepareForEntranceAppearance(slideY: CGFloat, scale: CGFloat) {
        resetEntranceAppearance()
        cardContainerView.alpha = 0
        cardContainerView.transform = CGAffineTransform(translationX: 0, y: slideY).scaledBy(x: scale, y: scale)
    }

    func animateEntrance(delay: TimeInterval, duration: TimeInterval) {
        UIView.animate(
            withDuration: duration,
            delay: delay,
            usingSpringWithDamping: 0.86,
            initialSpringVelocity: 0.38,
            options: [.curveEaseOut, .allowUserInteraction],
            animations: {
                self.cardContainerView.alpha = 1
                self.cardContainerView.transform = .identity
            }
        )
    }
}
