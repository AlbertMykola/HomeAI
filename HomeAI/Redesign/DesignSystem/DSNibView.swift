import UIKit

/// Reusable view whose layout lives in `<ClassName>.xib` (File's Owner = the class, root view → `contentView`).
/// Can be placed inside other XIBs as a plain view with this custom class.
class DSNibView: UIView {

    @IBOutlet var contentView: UIView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        loadFromNib()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadFromNib()
    }

    private func loadFromNib() {
        let name = String(describing: type(of: self))
        Bundle(for: type(of: self)).loadNibNamed(name, owner: self)
        guard let contentView else { return }
        backgroundColor = .clear
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        didLoadFromNib()
    }

    /// Override to configure outlets once the XIB is loaded.
    func didLoadFromNib() {}
}
