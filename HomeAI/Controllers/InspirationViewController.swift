import UIKit
import Kingfisher

final class InspirationViewController: UIViewController {

    @IBOutlet weak var collectionView: UICollectionView!

    private var categories: [InspirationCategory] = []
    private var selectedSectionIndex: Int = 0

    // MARK: - Pagination
    private let perPage = 20
    private var visibleCountPerCategory: [Int] = []
    private var isLoadingMore = false

    override func viewDidLoad() {
        super.viewDidLoad()
        config()
        loadData()
    }

    private func config() {
        ["FilterInspirationCollectionViewCell", "InspirationCollectionViewCell"].forEach {
            collectionView.register(UINib(nibName: $0, bundle: nil), forCellWithReuseIdentifier: $0)
        }
        collectionView.collectionViewLayout = UICollectionViewCompositionalLayout.createFilterLayout()
        collectionView.dataSource = self
        collectionView.delegate = self

        collectionView.prefetchDataSource = self

        setupNavBar()
    }

    private func setupNavBar() {
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.title = Constants.Text.brand

        let ap = UINavigationBarAppearance()
        ap.configureWithTransparentBackground()
        ap.shadowColor = .clear
        ap.largeTitleTextAttributes = [.font: UIFont.geologica(.standard(.bold), size: 30)]

        navigationItem.standardAppearance = ap
        navigationItem.scrollEdgeAppearance = ap
        navigationItem.compactAppearance = ap
        if #available(iOS 15.0, *) {
            navigationItem.compactScrollEdgeAppearance = ap
        }

        navigationController?.navigationBar.isTranslucent = true
    }

    private func loadData() {
        do {
            let decoded = try InspirationDataProvider.shared.loadInspirationsFromBundle()

            let allItems = decoded.flatMap { $0.items }
            let allCategory = InspirationCategory(category: "All", items: allItems)

            categories = [allCategory] + decoded
            visibleCountPerCategory = categories.map { cat in
                min(perPage, cat.items.count)
            }

            selectedSectionIndex = 0

            collectionView.reloadData()

            let firstIndexPath = IndexPath(item: 0, section: 0)
            collectionView.selectItem(at: firstIndexPath, animated: false, scrollPosition: [])
            collectionView.reloadSections(IndexSet(integer: 1))

        } catch {
            print("Failed to load inspirations: \(error)")
        }
    }

    // MARK: - Retrieve already loaded image (cell / cache only, no network)
    private func retrieveImageForItem(at indexPath: IndexPath, completion: @escaping (UIImage?) -> Void) {
        if let cell = collectionView.cellForItem(at: indexPath) as? InspirationCollectionViewCell,
           let img = cell.currentImage {
            completion(img)
            return
        }

        let item = categories[selectedSectionIndex].items[indexPath.item]
        let key = item.image

        if let mem = ImageCache.default.retrieveImageInMemoryCache(forKey: key) {
            completion(mem)
            return
        }

        ImageCache.default.retrieveImageInDiskCache(forKey: key) { result in
            switch result {
            case .success(let img):
                completion(img)
            case .failure:
                completion(nil)
            }
        }
    }

    // MARK: - Pagination helpers
    private func loadMoreIfNeeded(triggerIndex: Int) {
        guard categories.indices.contains(selectedSectionIndex),
              !isLoadingMore else { return }

        let total = categories[selectedSectionIndex].items.count
        let visible = visibleCountPerCategory[selectedSectionIndex]

        // Якщо підходимо до кінця видимого діапазону — додаємо наступну сторінку
        if triggerIndex >= max(0, visible - 4), visible < total {
            loadMore()
        }
    }

    private func loadMore() {
        guard categories.indices.contains(selectedSectionIndex) else { return }
        let total = categories[selectedSectionIndex].items.count
        let currentVisible = visibleCountPerCategory[selectedSectionIndex]
        guard currentVisible < total else { return }

        isLoadingMore = true

        let nextVisible = min(currentVisible + perPage, total)
        let newIndexPaths = (currentVisible..<nextVisible).map { IndexPath(item: $0, section: 1) }
        visibleCountPerCategory[selectedSectionIndex] = nextVisible

        // Акуратне вставлення нових елементів
        collectionView.performBatchUpdates({
            collectionView.insertItems(at: newIndexPaths)
        }, completion: { [weak self] _ in
            self?.isLoadingMore = false
        })
    }

    @objc
    private func didTapPro() {
        NavigationManager.shared.showPremium(placement: Constants.Keys.optionPlacememt)
    }
}

// MARK: - DataSource
extension InspirationViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return categories.count
        } else {
            guard categories.indices.contains(selectedSectionIndex) else { return 0 }
            let total = categories[selectedSectionIndex].items.count
            let visible = visibleCountPerCategory.indices.contains(selectedSectionIndex)
            ? visibleCountPerCategory[selectedSectionIndex]
            : min(perPage, total)
            return min(visible, total)
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        if indexPath.section == 0 {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "FilterInspirationCollectionViewCell",
                for: indexPath
            ) as? FilterInspirationCollectionViewCell else {
                return UICollectionViewCell()
            }
            let isSelected = indexPath.item == selectedSectionIndex
            let title = categories[indexPath.item].category
            cell.config(title: title)
            cell.isSelected = isSelected
            return cell

        } else {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "InspirationCollectionViewCell",
                for: indexPath
            ) as? InspirationCollectionViewCell else {
                return UICollectionViewCell()
            }
            let item = categories[selectedSectionIndex].items[indexPath.item]
            cell.configure(storagePath: item.image)
            return cell
        }
    }
}

// MARK: - Delegate
extension InspirationViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        if indexPath.section == 0 {
            guard indexPath.item != selectedSectionIndex else { return }

            let previousIndex = selectedSectionIndex
            selectedSectionIndex = indexPath.item

            if let previousCell = collectionView.cellForItem(at: IndexPath(item: previousIndex, section: 0)) as? FilterInspirationCollectionViewCell {
                previousCell.isSelected = false
            }

            if let newCell = collectionView.cellForItem(at: indexPath) as? FilterInspirationCollectionViewCell {
                newCell.isSelected = true
            }

            collectionView.reloadSections(IndexSet(integer: 1))
        } else {
            let item = categories[selectedSectionIndex].items[indexPath.item]
            retrieveImageForItem(at: indexPath) { [weak self] image in
                guard let self, let image else { return }
                NavigationManager.shared.showInspirationDetail(
                    model: ImageDetailModel(
                        previewsImage: nil,
                        image: image,
                        color: item.colorName,
                        style: item.style,
                        option: .exterior
                    ),
                    promptManager: nil
                )
            }
        }
    }

    // Тригеримо підвантаження, коли показуємо останні елементи сторінки
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard indexPath.section == 1 else { return }
        loadMoreIfNeeded(triggerIndex: indexPath.item)
    }
}

// MARK: - Prefetching
extension InspirationViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        guard categories.indices.contains(selectedSectionIndex) else { return }
        let visible = visibleCountPerCategory.indices.contains(selectedSectionIndex)
        ? visibleCountPerCategory[selectedSectionIndex]
        : min(perPage, categories[selectedSectionIndex].items.count)

        // Якщо префетчимо елементи близько до кінця — завчасно підвантажуємо наступну сторінку
        if indexPaths.contains(where: { $0.section == 1 && $0.item >= max(0, visible - 4) }) {
            loadMore()
        }
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) { }
}

// MARK: - Layout helper (без змін)
extension UICollectionViewCompositionalLayout {

    static func createFilterLayout() -> UICollectionViewLayout {
        _ = UIScreen.main.bounds.width
        return UICollectionViewCompositionalLayout { sectionIndex, _ in
            if sectionIndex == 0 {
                let chipHeight: CGFloat = 50

                let itemSize = NSCollectionLayoutSize(
                    widthDimension: .estimated(60),
                    heightDimension: .absolute(chipHeight)
                )
                let item = NSCollectionLayoutItem(layoutSize: itemSize)

                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .estimated(60),
                    heightDimension: .absolute(chipHeight)
                )
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = 8
                section.orthogonalScrollingBehavior = .continuous
                section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
                return section
            } else {
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: .fractionalWidth(0.7))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)

                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalWidth(0.7))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item, item])

                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 8, trailing: 8)
                return section
            }
        }
    }
}
