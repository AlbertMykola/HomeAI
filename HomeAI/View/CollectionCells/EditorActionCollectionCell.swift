import UIKit

class EditorActionCollectionCell: UICollectionViewCell {

    @IBOutlet weak var liquidGlassContainerView: LiquidGlassView!
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    
    private let shadowView = UIView()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupShadowView()
        liquidGlassContainerView.fallbackShadow = false
        // Allow shadow to render outside cell bounds
        clipsToBounds = false
        contentView.clipsToBounds = false
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.layoutIfNeeded()
        let radius = liquidGlassContainerView.layer.cornerRadius > 0 ? liquidGlassContainerView.layer.cornerRadius : 24
        shadowView.layer.cornerRadius = radius
        shadowView.applyFigmaShadow(
            x: 0,
            y: 2,
            blur: 2,
            spread: 0,
            color: .black.withAlphaComponent(0.1),
            opacityPercent: 10,
            cornerRadius: radius
        )
    }
    
    private func setupShadowView() {
        shadowView.translatesAutoresizingMaskIntoConstraints = false
        shadowView.backgroundColor = .clear
        shadowView.isUserInteractionEnabled = false
        contentView.insertSubview(shadowView, belowSubview: liquidGlassContainerView)
        NSLayoutConstraint.activate([
            shadowView.topAnchor.constraint(equalTo: liquidGlassContainerView.topAnchor),
            shadowView.leadingAnchor.constraint(equalTo: liquidGlassContainerView.leadingAnchor),
            shadowView.trailingAnchor.constraint(equalTo: liquidGlassContainerView.trailingAnchor),
            shadowView.bottomAnchor.constraint(equalTo: liquidGlassContainerView.bottomAnchor)
        ])
    }
    
    func configure(action: EditorActionType) {
        nameLabel.text = action.title
        imageView.image = action.icon
    }
}
