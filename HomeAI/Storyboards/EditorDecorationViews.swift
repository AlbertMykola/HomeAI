import UIKit

final class SheetBackdropView: UIView {}

final class EditorHotspotView: UIView {
    override func awakeFromNib() {
        super.awakeFromNib()
        layer.cornerRadius = 8
        layer.borderWidth = 3
        layer.borderColor = UIColor.black.withAlphaComponent(0.15).cgColor
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 4
        layer.shadowOffset = CGSize(width: 0, height: 2)
        isUserInteractionEnabled = false
    }
}

final class EditorSelectionView: UIView {
    @IBOutlet private weak var titleLabel: PaddingLabel!
    var title: String? { didSet { titleLabel.text = title } }

    override func awakeFromNib() {
        super.awakeFromNib()
        layer.borderColor = DS.Color.lime.cgColor
        layer.borderWidth = 2.5
        layer.cornerRadius = 16
        backgroundColor = DS.Color.lime.withAlphaComponent(0.14)
        isUserInteractionEnabled = false
        titleLabel.font = DS.Font.geologica(.semiBold, 13)
        titleLabel.layer.cornerRadius = 14
        titleLabel.clipsToBounds = true
    }
}
