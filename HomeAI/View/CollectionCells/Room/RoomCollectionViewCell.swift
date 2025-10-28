import UIKit

final class RoomCollectionViewCell: UICollectionViewCell {
    
    // MARK: - @IBOutlets
    @IBOutlet weak private var nameLabel: CustomFontLabel!
    @IBOutlet weak private var iconImageView: UIImageView!
    @IBOutlet weak private var containerView: UIView!

    @IBOutlet private var constraintsHeight: [NSLayoutConstraint]!
    @IBOutlet private var constraintsWidth: [NSLayoutConstraint]!
    
    // MARK: - Lifecycles
    override func awakeFromNib() {
        super.awakeFromNib()
        constraintsHeight.forEach { $0.scaleConstant() }
        constraintsWidth.forEach { $0.scaleConstantByWidth() }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        containerView.layer.cornerRadius = containerView.frame.height / 2
    }
    
    // MARK: - Methots
    func configure(room: InteriorType, isSelected: Bool) {
        nameLabel.text = room.name
        iconImageView.image = room.icon
        
        containerView.layoutIfNeeded()
        
        if isSelected {
            containerView.layer.borderColor = Constants.Colors.yellowPremium.cgColor
            containerView.layer.borderWidth = 1.5
            containerView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
            nameLabel.textColor = Constants.Colors.yellowPremium
            iconImageView.tintColor = Constants.Colors.yellowPremium
        } else {
            containerView.layer.borderColor = UIColor.lightGray.cgColor
            containerView.layer.borderWidth = 1
            containerView.backgroundColor = .clear
            nameLabel.textColor = .label
            iconImageView.tintColor = .label
        }
    }
}
