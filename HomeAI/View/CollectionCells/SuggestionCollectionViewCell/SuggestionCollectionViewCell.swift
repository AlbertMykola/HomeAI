import UIKit

class SuggestionCollectionViewCell: UICollectionViewCell {

    static let reuseIdentifier = "SuggestionCollectionViewCell"

    @IBOutlet weak private var suggestionImageView: UIImageView!
    @IBOutlet weak private var containerView: UIView!
    
    private let imageService = ImageStorageService()
    private var representedIdentifier: String?
    
    override var isSelected: Bool {
        didSet {
            if isSelected {
                containerView.borderWidth = 1.5
                containerView.borderColor = UIColor.systemGreen
            } else {
                containerView.borderWidth = 0
                containerView.borderColor = UIColor.clear
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.clipsToBounds = true
        clipsToBounds = true
        suggestionImageView.layer.cornerRadius = 20
        suggestionImageView.clipsToBounds = true
        suggestionImageView.contentMode = .scaleAspectFill
        containerView.borderColor = UIColor.clear
        containerView.layer.cornerRadius = 20
        containerView.layer.masksToBounds = true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageService.cancel(on: suggestionImageView)
        suggestionImageView.image = nil
        containerView.isHidden = false
        containerView.borderWidth = 0
        containerView.borderColor = UIColor.clear
        representedIdentifier = nil
    }
    
    func configure(with template: SuggestionTemplateType) {
        representedIdentifier = template.imagePath
        containerView.isHidden = false
        suggestionImageView.image = nil
        
        imageService.setImage(on: suggestionImageView, path: template.imagePath, placeholder: nil) { [weak self] image in
            guard let self else { return }
            guard self.representedIdentifier == template.imagePath else { return }
            self.containerView.isHidden = image != nil
        }
    }

}
