import UIKit

final class InspirationCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak private var inspirationImageView: UIImageView!
    @IBOutlet weak private var containerView: UIView!
    @IBOutlet weak private var deleteButton: UIButton?
    
    private let imageService = ImageStorageService()
    private var representedIdentifier: String?
    private var onDeleteTapped: (() -> Void)?
    
    var currentImage: UIImage?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        if let deleteButton {
            deleteButton.setImage(UIImage(systemName: "xmark"), for: .normal)
            deleteButton.tintColor = .white
            deleteButton.backgroundColor = UIColor.black.withAlphaComponent(0.55)
            deleteButton.layer.cornerRadius = 16
            deleteButton.layer.masksToBounds = true
            deleteButton.isHidden = true
            deleteButton.isUserInteractionEnabled = false
            deleteButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageService.cancel(on: inspirationImageView)
        inspirationImageView.image = nil
        containerView.isHidden = false
        representedIdentifier = nil
        currentImage = nil
        deleteButton?.isHidden = true
        deleteButton?.isUserInteractionEnabled = false
        onDeleteTapped = nil
    }
    
    func configure(storagePath: String, showsDeleteButton: Bool = false, onDelete: (() -> Void)? = nil) {
        representedIdentifier = storagePath
        containerView.isHidden = false
        currentImage = nil
        inspirationImageView.image = nil
        onDeleteTapped = onDelete
        deleteButton?.isHidden = !showsDeleteButton
        deleteButton?.isUserInteractionEnabled = showsDeleteButton
        
        let targetSize = inspirationImageView.bounds.size == .zero
        ? CGSize(width: contentView.bounds.width, height: contentView.bounds.height)
        : inspirationImageView.bounds.size
        
        imageService.setImage(on: inspirationImageView, path: storagePath, placeholder: nil, targetPointSize: targetSize) { [weak self] image in
            guard let self else { return }
            guard self.representedIdentifier == storagePath else { return }
            self.currentImage = image
            self.containerView.isHidden = image != nil
        }
    }
    
    @IBAction private func deleteButtonTapped(_ sender: UIButton) {
        onDeleteTapped?()
    }
}
