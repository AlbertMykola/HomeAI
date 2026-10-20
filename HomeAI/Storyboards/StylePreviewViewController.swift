import UIKit

final class StylePreviewViewController: UIViewController {
    @IBOutlet private weak var imageView: UIImageView!
    var image: UIImage?

    override func viewDidLoad() {
        super.viewDidLoad()
        imageView.image = image
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = "Style".localized
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(close)))
    }

    @objc private func close() { dismiss(animated: true) }
}
