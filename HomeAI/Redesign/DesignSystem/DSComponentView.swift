import UIKit

/// A reusable component whose hierarchy and connections are declared in its owning storyboard.
class DSComponentView: UIView {
    @IBOutlet var contentView: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
        didLoadFromStoryboard()
    }

    func didLoadFromStoryboard() {}
}
