import UIKit

final class AssistentTableViewCell: UITableViewCell {

    static let reuseIdentifier = "AssistentTableViewCell"

    @IBOutlet weak private var portraitImageView: UIImageView!
    
    @IBOutlet weak private var nameLabel: UILabel!
    @IBOutlet weak private var descriptionLabel: UILabel!
    @IBOutlet weak private var professionLabel: UILabel!
    
    @IBOutlet weak private var nameContainerView: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        portraitImageView.clipsToBounds = true
        portraitImageView.contentMode = .scaleAspectFill
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        nameContainerView.layoutIfNeeded()
        portraitImageView.layoutIfNeeded()
        portraitImageView.layer.cornerRadius = portraitImageView.bounds.height / 2
        nameContainerView.layer.cornerRadius = nameContainerView.bounds.height / 2
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        nameLabel.text = nil
        descriptionLabel.text = nil
        professionLabel.text = nil
        portraitImageView.image = nil
        portraitImageView.layer.borderColor = UIColor.clear.cgColor
    }

    func configure(with type: AssistantType) {
        professionLabel.text = type.title
        descriptionLabel.text = type.chatBio
        nameLabel.text = type.name
        portraitImageView.image = UIImage(named: type.imageName)
        portraitImageView.layer.borderWidth = 3
        portraitImageView.layer.borderColor = type.ringColor.cgColor
    }
}
