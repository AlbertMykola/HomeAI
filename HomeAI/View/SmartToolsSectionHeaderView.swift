import UIKit

/// Хедер секції «розумні інструменти»: заголовок зліва, «Переглянути все» справа.
final class SmartToolsSectionHeaderView: UICollectionReusableView {

    static let reuseIdentifier = "SmartToolsSectionHeaderView"

    var onSeeAll: (() -> Void)?

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.applyTypography(.sectionHeaderTitle)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var seeAllButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.tintColor = .label
        btn.addTarget(self, action: #selector(seeAllTapped), for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onSeeAll = nil
    }

    private func setup() {
        addSubview(titleLabel)
        addSubview(seeAllButton)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: seeAllButton.leadingAnchor, constant: -8),

            seeAllButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            seeAllButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func configure(title: String, seeAllTitle: String) {
        titleLabel.text = title
        seeAllButton.setAttributedTitle(underlined(seeAllTitle), for: .normal)
    }

    private func underlined(_ text: String) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [.font: AppTypography.sectionHeaderLink.font,.underlineStyle: NSUnderlineStyle.single.rawValue,.foregroundColor: UIColor.label])
    }

    @objc private func seeAllTapped() {
        onSeeAll?()
    }
}
