import UIKit

class PhotoTipsExampleCollectionCell: UICollectionViewCell {
    
    static let reuseIdentifier = "PhotoTipsExampleCollectionCell"

    @IBOutlet weak var levelLabel: UILabel!
    @IBOutlet weak var stateImageView: UIImageView!
    @IBOutlet weak var exampleImageView: UIImageView!
    
    private let imageService = ImageStorageService()
    private var representedIdentifier: String?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        exampleImageView.contentMode = .scaleAspectFill
        exampleImageView.clipsToBounds = true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageService.cancel(on: exampleImageView)
        exampleImageView.image = Constants.Images.previewPlaceholder
        representedIdentifier = nil
    }
    
    func configure(with model: PhotoTipsModel, isGoodExample: Bool) {
        levelLabel.text = model.state
        
        if isGoodExample {
            stateImageView.image = UIImage(systemName: "checkmark.circle.fill")
            stateImageView.tintColor = .systemGreen
        } else {
            stateImageView.image = UIImage(systemName: "xmark.circle.fill")
            stateImageView.tintColor = .systemRed
        }
        
        let imagePath = "photo_tips/\(model.image).webp"
        representedIdentifier = imagePath
        
        imageService.setImage(on: exampleImageView, path: imagePath, placeholder: Constants.Images.previewPlaceholder) { [weak self] image in
            guard let self else { return }
            guard self.representedIdentifier == imagePath else { return }
        }
    }

}
