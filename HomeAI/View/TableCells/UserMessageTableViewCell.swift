import UIKit

final class UserMessageTableViewCell: UITableViewCell {

    static let reuseIdentifier = "UserMessageTableViewCell"

    @IBOutlet weak private var containerView: UIView!
    @IBOutlet weak private var messageLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        containerView.backgroundColor = UIColor.tertiarySystemFill
        messageLabel?.numberOfLines = 0
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        messageLabel?.text = nil
    }

    func configure(text: String) {
        messageLabel?.text = text
    }
}
