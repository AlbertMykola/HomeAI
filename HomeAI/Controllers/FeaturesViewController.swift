import UIKit

// MARK: - Defaults

private struct Defaults {
    struct Layout {
        static let rowHeight: CGFloat = 107
        static let interGroupSpacing: CGFloat = 16
        static let horizontalInset: CGFloat = 16
        static let sectionTopInset: CGFloat = 10
        static let sectionBottomInset: CGFloat = 24
    }
    
    struct Text {
        static let title = "AI Renovation Tools"
    }
}

// MARK: - FeaturesViewController

final class FeaturesViewController: UIViewController {

    // MARK: - Properties

    @IBOutlet weak var collectionView: UICollectionView!

    private let options: [DesignOption] = DesignOption.allCases

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        configureCollectionView()
    }

    // MARK: - Setup

    private func setupNavigationBar() {
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.title = Defaults.Text.title

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.shadowColor = .clear
        appearance.largeTitleTextAttributes = [.font: UIFont.geologica(.standard(.bold), size: 30)]

        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
        if #available(iOS 15.0, *) {
            navigationItem.compactScrollEdgeAppearance = appearance
        }

        navigationController?.navigationBar.isTranslucent = true
    }

    private func configureCollectionView() {
        collectionView.collectionViewLayout = makeLayout()
        collectionView.register(
            UINib(nibName: OptionsCollectionCell.reuseIdentifier, bundle: nil),
            forCellWithReuseIdentifier: OptionsCollectionCell.reuseIdentifier
        )
        collectionView.dataSource = self
        collectionView.delegate = self
    }

    // MARK: - Layout

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        let rowHeight = max(1, Defaults.Layout.rowHeight.scaledByHeight())
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .absolute(rowHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .absolute(rowHeight)
            ),
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = Defaults.Layout.interGroupSpacing
        let inset = Defaults.Layout.horizontalInset
        section.contentInsets = NSDirectionalEdgeInsets(
            top: Defaults.Layout.sectionTopInset,
            leading: inset,
            bottom: Defaults.Layout.sectionBottomInset.scaledByHeight(),
            trailing: inset
        )
        return UICollectionViewCompositionalLayout(section: section)
    }
}

// MARK: - UICollectionViewDataSource

extension FeaturesViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        options.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: OptionsCollectionCell.reuseIdentifier,
            for: indexPath
        ) as? OptionsCollectionCell else {
            return UICollectionViewCell()
        }
        guard let option = options[safe: indexPath.item] else { return cell }
        let model = OptionsCollectionModel(
            title: option.title,
            description: option.description,
            icon: option.icon,
            heroImage: option.beforeAfter
        )
        cell.configHideIcon(model: model)
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension FeaturesViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let option = options[safe: indexPath.item] else { return }
        switch option {
        case .replace:
            NavigationManager.shared.showReplaceObjectPage()
        case .delete:
            let manager = GemeniPromptManager()
            manager.updateOption(.delete)
            NavigationManager.shared.showReplaceObjectPage(promptManager: manager, flowMode: .delete)
        default:
            NavigationManager.shared.showPageViewController(option: option)
        }
    }
}
