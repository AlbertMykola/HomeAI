import UIKit

class RateCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak private var containerView: UIView!
    
    @IBOutlet weak private var commentLabel: UILabel!
    
    override func layoutSubviews() {
        super.layoutSubviews()
        containerView.layer.cornerRadius = containerView.frame.height / 2
    }
    
    func config(comment: String) {
        commentLabel.text = comment
        containerView.layoutIfNeeded()
    }
}
