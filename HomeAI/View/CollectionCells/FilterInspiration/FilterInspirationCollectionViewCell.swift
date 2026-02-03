import UIKit

class FilterInspirationCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak private var containerView: UIView!
    @IBOutlet weak private var titleLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        containerView.layer.borderWidth = 0
        containerView.layer.borderColor = UIColor.label.cgColor
        containerView.layer.masksToBounds = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        containerView.layer.cornerRadius = containerView.bounds.height / 2
    }

    override var isSelected: Bool {
        didSet { updateBorder(animated: true) }
    }

    override var isHighlighted: Bool {
        didSet { updateBorder(animated: true) }
    }

    private func updateBorder(animated: Bool) {
        let apply = {
            let active = self.isSelected || self.isHighlighted
            self.containerView.layer.borderWidth = active ? 1 : 0
            self.containerView.layer.borderColor = active ? UIColor.label.cgColor : UIColor.clear.cgColor
        }
        
        if animated {
            UIView.animate(withDuration: 0.15, animations: apply)
        } else {
            apply()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        containerView.layer.borderWidth = 0
        containerView.layer.borderColor = UIColor.clear.cgColor
    }

    func config(title: String) {
        titleLabel.text = title
        setNeedsLayout()
        layoutIfNeeded()
        updateBorder(animated: true)
    }
}
