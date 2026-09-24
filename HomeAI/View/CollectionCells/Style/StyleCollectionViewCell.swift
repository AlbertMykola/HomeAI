import UIKit

final class StyleCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var newImageView: UIImageView!
    @IBOutlet private weak var styleImageView: UIImageView!
    @IBOutlet private weak var bottomBarView: LiquidGlassView!
    @IBOutlet private weak var nameLabel: CustomFontLabel!
    @IBOutlet private weak var containerView: UIView!
    
    private var currentImagePath: String?
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)

    override var isSelected: Bool {
        didSet {
            if isSelected {
                containerView.borderWidth = 2
                containerView.borderColor = UIColor.systemGreen
            } else {
                containerView.borderWidth = 0
                containerView.borderColor = UIColor.clear
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        containerView.borderColor = UIColor.clear
        styleImageView.contentMode = .scaleAspectFill
        styleImageView.clipsToBounds = true
        
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        contentView.addSubview(loadingIndicator)
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
  
        styleImageView.image = Constants.Images.previewPlaceholder
        currentImagePath = nil
        styleImageView.backgroundColor = .clear
        loadingIndicator.stopAnimating()
        layer.borderWidth = 0
        layer.borderColor = UIColor.clear.cgColor
    }

    func config(style: StyleCellModel) {
        nameLabel.text = style.name
        
        // 1) Prefer local asset if it exists
        if let local = UIImage(named: style.imageName) {
            currentImagePath = nil
            styleImageView.image = local
            styleImageView.backgroundColor = .clear
            loadingIndicator.stopAnimating()
        } else {
            // 2) Otherwise treat it as a remote (Supabase) path and load via shared loader + cache
            let path = style.imageName
            currentImagePath = path
            styleImageView.image = Constants.Images.previewPlaceholder
            styleImageView.backgroundColor = .clear
            loadingIndicator.stopAnimating()
            
            SharedImageLoader.shared.loadImage(path: path) { [weak self] image in
                guard let self else { return }
                guard self.currentImagePath == path else { return }
                self.styleImageView.image = image ?? Constants.Images.previewPlaceholder
                self.styleImageView.backgroundColor = .clear
            }
        }
        newImageView.isHidden = !style.isNew
    }
}
