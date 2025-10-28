import UIKit
import FirebaseStorage
import Kingfisher

final class InspirationCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak private var inspirationImageView: UIImageView!
    @IBOutlet weak private var containerView: UIView!

    private var representedIdentifier: String?
    var currentImage: UIImage?
    
    override func prepareForReuse() {
        super.prepareForReuse()
        inspirationImageView.kf.cancelDownloadTask()
        containerView.isHidden = false
        // image можна не зануляти — якщо є кеш, Kingfisher поставить миттєво
        currentImage = nil
    }

    func configure(storagePath: String) {
        representedIdentifier = storagePath
        let ref = Storage.storage().reference(withPath: storagePath)
        ref.downloadURL { [weak self] url, _ in
            guard let self, let url, self.representedIdentifier == storagePath else { return }
            let resource = Kingfisher.ImageResource(downloadURL: url, cacheKey: storagePath) // стабільний ключ кешу
            self.inspirationImageView.kf.setImage(
                with: resource,
                options: [.cacheOriginalImage]
            ) { result in
                if case .success(let value) = result {
                    self.currentImage = value.image
                    self.containerView.isHidden = true
                }
            }
        }
    }
}
