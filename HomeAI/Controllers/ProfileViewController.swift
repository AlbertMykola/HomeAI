import UIKit

private struct Defaults {
    
    struct Text {
        static let noDesign = "No design yet".localized
        static let description = "Start transform your space ".localized
    }
}

final class ProfileViewController: UIViewController {

    @IBOutlet private weak var noDesignLabel: UILabel!
    @IBOutlet private weak var descriptionLabel: UILabel!
    @IBOutlet private weak var collectionView: UICollectionView!

    private var items: [ImageDoc] = []
    private var isLoading = false
    private let pageSize = 20

    private let imageRepo = FirebaseImageService()

    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
    }
    
    private func configure() {
        noDesignLabel.text = Defaults.Text.noDesign
        descriptionLabel.text = Defaults.Text.description
        
        collectionView.setCollectionViewLayout(makeTwoColumnSquareLayout(spacing: 12), animated: false)

        collectionView.register(UINib(nibName: "InspirationCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "InspirationCollectionViewCell")
        setupNavBar()

        imageRepo.resetHistoryPaging()
        loadNextPage()
        setupNavBar()
    }
    
    
    
    private func setupNavBar() {
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.title = Constants.Text.brand

        let ap = UINavigationBarAppearance()
        ap.configureWithTransparentBackground()        // прозорий фон [Apple]
        ap.shadowColor = .clear                        // без нижньої лінії
        ap.largeTitleTextAttributes = [.font: UIFont.geologica(.standard(.bold), size: 30)]

        navigationItem.standardAppearance = ap         // звичайний стан [Apple]
        navigationItem.scrollEdgeAppearance = ap       // коли контент торкає верх [Apple]
        navigationItem.compactAppearance = ap          // компактний режим [Apple]
        if #available(iOS 15.0, *) {
            navigationItem.compactScrollEdgeAppearance = ap // компакт + scroll edge [Apple]
        }

        navigationController?.navigationBar.isTranslucent = true
        
        let gear = UIImage(systemName: "gearshape")
        let settingsItem = UIBarButtonItem(image: gear, style: .plain, target: self, action: #selector(didTapSettings))
        settingsItem.accessibilityLabel = NSLocalizedString("Settings", comment: "Open settings")
        navigationItem.rightBarButtonItem = settingsItem
    }

    private func makeTwoColumnSquareLayout(spacing: CGFloat = 12) -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .fractionalHeight(1.0))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = .init(top: spacing/2, leading: spacing/2, bottom: spacing/2, trailing: spacing/2)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalWidth(0.5))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item, item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .init(top: spacing, leading: spacing, bottom: spacing, trailing: spacing)

        return UICollectionViewCompositionalLayout(section: section)
    }

    private func loadNextPage() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            do {
                let page = try await imageRepo.fetchNextHistoryPage(pageSize: pageSize)
                items.append(contentsOf: page)
                await MainActor.run {
                    collectionView.reloadData()
                    collectionView.isHidden = items.isEmpty
                }
            } catch {
                // TODO: лог/алерт
            }
            isLoading = false
        }
    }
    
    @objc private func didTapSettings() {
        NavigationManager.shared.settings()
    }
}

// MARK: - UICollectionViewDataSource
extension ProfileViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "InspirationCollectionViewCell",for: indexPath) as! InspirationCollectionViewCell
        let doc = items[indexPath.item]
        let path = doc.previewPath ?? doc.storagePath
        cell.configure(storagePath: path)
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension ProfileViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let threshold = 6
        if indexPath.item >= items.count - threshold, !isLoading, imageRepo.canLoadMore {
            loadNextPage()
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let doc = items[indexPath.item]
        let cell = collectionView.cellForItem(at: indexPath) as? InspirationCollectionViewCell
        guard let image = cell?.currentImage else { return }

        NavigationManager.shared.showInspirationDetail(model: ImageDetailModel(previewsImage: nil, image: image, color: doc.colorName ?? "Random", style: doc.style ?? "", option: .exterior), promptManager: nil)
    }
}
