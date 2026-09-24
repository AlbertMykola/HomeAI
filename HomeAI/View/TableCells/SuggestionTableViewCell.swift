import UIKit

class SuggestionTableViewCell: UITableViewCell {

    @IBOutlet weak private var suggestionLabel: UILabel!
    
    @IBOutlet weak private var containerView: UIView!
    @IBOutlet weak private var heightConstraint: NSLayoutConstraint!
    
    override func layoutSubviews() {
        super.layoutSubviews()
        suggestionLabel.textColor = .label
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        heightConstraint.scaleConstant()
        suggestionLabel.scaleFontByHeight = true
        selectionStyle = .none
        selectedBackgroundView = UIView()
        tintColor = .label
        suggestionLabel.textColor = .label
        suggestionLabel.highlightedTextColor = .label
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        suggestionLabel.attributedText = nil
        suggestionLabel.textColor = .label
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        suggestionLabel.textColor = .label
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        suggestionLabel.textColor = .label
    }
    
    func configure(suggestion: String) {
        let font = suggestionLabel.font ?? UIFont.systemFont(ofSize: 14)
        suggestionLabel.attributedText = NSAttributedString(
            string: suggestion,
            attributes: [
                .foregroundColor: UIColor.label,
                .font: font
            ]
        )
        containerView.cornerRadius = containerView.frame.height / 2
    }
}
