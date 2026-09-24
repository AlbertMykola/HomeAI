import UIKit

class SuggestionCollectionViewCell: UICollectionViewCell {

    static let reuseIdentifier = "SuggestionCollectionViewCell"

    @IBOutlet weak private var suggestionImageView: UIImageView!
    @IBOutlet weak private var containerView: UIView!
    
    private let imageService = ImageStorageService()
    private var representedIdentifier: String?
    
    override var isSelected: Bool {
        didSet {
            updateSelectionAppearance()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.clipsToBounds = true
        clipsToBounds = true
        contentView.layer.cornerRadius = 20
        suggestionImageView.layer.cornerRadius = 20
        suggestionImageView.clipsToBounds = true
        suggestionImageView.contentMode = .scaleAspectFill
        containerView.borderColor = UIColor.clear
        containerView.layer.cornerRadius = 20
        containerView.layer.masksToBounds = true
        updateSelectionAppearance()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageService.cancel(on: suggestionImageView)
        suggestionImageView.image = Constants.Images.previewPlaceholder
        containerView.isHidden = true
        containerView.borderWidth = 0
        containerView.borderColor = UIColor.clear
        representedIdentifier = nil
        updateSelectionAppearance()
    }
    
    private func updateSelectionAppearance() {
        if isSelected {
            contentView.borderWidth = 2
            contentView.borderColor = UIColor.systemGreen
        } else {
            contentView.borderWidth = 0
            contentView.borderColor = UIColor.clear
        }
    }
    
    func configure(with template: SuggestionTemplateType) {
        representedIdentifier = template.imagePath
        containerView.isHidden = true
        suggestionImageView.image = Constants.Images.previewPlaceholder
        
        imageService.setImage(on: suggestionImageView, path: template.imagePath, placeholder: Constants.Images.previewPlaceholder) { [weak self] image in
            guard let self else { return }
            guard self.representedIdentifier == template.imagePath else { return }
            self.updateSelectionAppearance()
        }
        updateSelectionAppearance()
    }

}
