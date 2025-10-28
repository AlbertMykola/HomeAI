import UIKit

class OptionsCollectionCell: UICollectionViewCell {

    @IBOutlet weak private var glassView: LiquidGlassView!
    
    @IBOutlet weak private var descriptionLabel: UILabel!
    @IBOutlet weak private var headlineLabel: UILabel!
    
    @IBOutlet var constraintHeight: [NSLayoutConstraint]!
    
    @IBOutlet var constraintsWidth: [NSLayoutConstraint]!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        constraintHeight.forEach { $0.scaleConstant() }
        constraintsWidth.forEach { $0.scaleConstantByWidth() }
    }

    func config(model: OptionsCollectionModel) {
        descriptionLabel.text = model.description
        headlineLabel.text = model.title
    }
}
