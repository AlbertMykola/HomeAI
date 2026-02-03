import UIKit

class SuggestionTableViewCell: UITableViewCell {

    @IBOutlet weak private var suggestionLabel: UILabel!
    
    @IBOutlet weak private var containerView: UIView!
    @IBOutlet weak private var heightConstraint: NSLayoutConstraint!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        heightConstraint.scaleConstant()
        suggestionLabel.scaleFontByHeight = true
        selectionStyle = .none
        selectedBackgroundView = UIView()
    }
    
    func configure(suggestion: String) {
        suggestionLabel.text = suggestion
        containerView.cornerRadius = containerView.frame.height / 2
    }
}
