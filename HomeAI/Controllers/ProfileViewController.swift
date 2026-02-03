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

    private let imageRepo = ImageHistoryService()
    private let fileManager = FileManager.default
    private var historyObserver: NSObjectProtocol?
    private var pendingHistoryReload = false

    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
    }
    
    deinit {
        if let historyObserver {
            NotificationCenter.default.removeObserver(historyObserver)
        }
    }
    
    private func configure() {
        noDesignLabel.text = Defaults.Text.noDesign
        descriptionLabel.text = Defaults.Text.description
        
        collectionView.setCollectionViewLayout(makeInspirationGridLayout(), animated: false)

        collectionView.register(UINib(nibName: "InspirationCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "InspirationCollectionViewCell")
        setupNavBar()
        observeHistoryChanges()

        imageRepo.resetHistoryPaging()
        loadNextPage()
        updateEmptyState()
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

    private func makeInspirationGridLayout() -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5),
            heightDimension: .fractionalWidth(0.7)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalWidth(0.7)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item, item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 8, trailing: 8)

        return UICollectionViewCompositionalLayout(section: section)
    }

    private func loadNextPage() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            do {
                let page = try await imageRepo.fetchNextHistoryPage(pageSize: pageSize)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.items.append(contentsOf: page)
                    self.collectionView.reloadData()
                    self.updateEmptyState()
                }
            } catch {
                // TODO: лог/алерт
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isLoading = false
                if self.pendingHistoryReload {
                    self.reloadHistory()
                }
            }
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
        let path: String
        if fileManager.fileExists(atPath: doc.storagePath) {
            path = doc.storagePath
        } else if let previewPath = doc.previewPath, fileManager.fileExists(atPath: previewPath) {
            path = previewPath
        } else {
            path = doc.previewPath ?? doc.storagePath
        }
        cell.configure(storagePath: path, showsDeleteButton: true) { [weak self] in
            guard let self else { return }
            guard let currentIndex = self.items.firstIndex(where: { $0.id == doc.id }) else { return }
            let currentIndexPath = IndexPath(item: currentIndex, section: 0)
            self.confirmDeletion(at: currentIndexPath, completion: { _ in })
        }
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

        let option = doc.designOption ?? .interior
        var resolvedStyleName = doc.style
        var resolvedColorName = doc.colorName
        var canRegenerate = doc.canRegenerate && (doc.originalPath.flatMap { fileManager.fileExists(atPath: $0) } ?? false)
        
        let promptManager = GemeniPromptManager()
        promptManager.updateOption(option)
        promptManager.updateBaseImage(image)
        print("[Profile] Open detail with option:", option, "style:", doc.style ?? "nil", "color:", doc.colorName ?? "nil")
        
        switch option {
        case .interior:
            if let room = doc.savedInteriorRoomType {
                promptManager.updateRoom(room)
            } else {
                canRegenerate = false
            }
        case .exterior:
            if let building = doc.savedExteriorBuildingType {
                promptManager.updateExteriorType(building)
            } else {
                canRegenerate = false
            }
        case .garden:
            if let garden = doc.savedGardenType {
                promptManager.updateGardenType(garden)
            } else {
                canRegenerate = false
            }
        default:
            break
        }
        
        if let colorName = doc.colorName,
           let colorType = colorType(named: colorName) {
            promptManager.updateColor(colorType)
        } else {
            let randomColor = ColorType.allCases.randomElement() ?? .random
            promptManager.updateColor(randomColor)
            resolvedColorName = randomColor.name
        }
        
        if let saved = savedUnifiedStyle(for: option, doc: doc) {
            promptManager.updateStyle(saved.style)
            resolvedStyleName = saved.displayName
        } else if let random = randomUnifiedStyle(for: option) {
            promptManager.updateStyle(random.style)
            resolvedStyleName = random.displayName
        }
        
        let model = ImageDetailModel(
            previewsImage: nil,
            image: image,
            color: resolvedColorName ?? "Random",
            style: resolvedStyleName ?? "",
            option: option,
            canRegenerate: canRegenerate,
            storagePath: doc.storagePath,
            originalPath: doc.originalPath
        )
        
        guard let detailVC = NavigationManager.shared.showInspirationDetail(model: model, promptManager: promptManager) else { return }
        
        Task { [weak self, weak detailVC] in
            guard let self, let detailVC else { return }
            guard self.fileManager.fileExists(atPath: doc.storagePath) else { return }
            if let fullImage = try? await self.imageRepo.loadImage(at: doc.storagePath) {
                await MainActor.run {
                    detailVC.updateAfterImage(fullImage)
                }
            }
        }
        
        // Show "before" image whenever it's available in history (not only for regenerate-supported modes).
        if let originalPath = doc.originalPath, fileManager.fileExists(atPath: originalPath) {
            if canRegenerate {
                detailVC.startBeforeLoading()
            }
            Task {
                if let originalImage = try? await imageRepo.loadImage(at: originalPath) {
                    if canRegenerate {
                        // Keep promptManager in sync for regenerate flow
                        promptManager.updateBaseImage(originalImage)
                    }
                    await MainActor.run {
                        detailVC.updateBeforeImage(originalImage)
                    }
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, trailingSwipeActionsConfigurationForItemAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard items.indices.contains(indexPath.item) else { return nil }
        let title = NSLocalizedString("Delete", comment: "Delete history item action")
        let deleteAction = UIContextualAction(style: .destructive, title: title) { [weak self] _, _, completion in
            self?.confirmDeletion(at: indexPath, completion: completion)
        }
        deleteAction.image = UIImage(systemName: "trash")
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        configuration.performsFirstActionWithFullSwipe = true
        return configuration
    }
}

private extension ProfileViewController {
    func observeHistoryChanges() {
        guard historyObserver == nil else { return }
        historyObserver = NotificationCenter.default.addObserver(forName: .imageHistoryDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.handleHistoryUpdate()
        }
    }
    
    func handleHistoryUpdate() {
        reloadHistory()
    }
    
    func reloadHistory() {
        guard isViewLoaded else { return }
        guard !isLoading else {
            pendingHistoryReload = true
            return
        }
        pendingHistoryReload = false
        imageRepo.resetHistoryPaging()
        items.removeAll()
        collectionView.reloadData()
        updateEmptyState()
        loadNextPage()
    }
    
    func updateEmptyState() {
        let isEmpty = items.isEmpty
        collectionView.isHidden = isEmpty
        noDesignLabel.isHidden = !isEmpty
        descriptionLabel.isHidden = !isEmpty
    }
    
    func confirmDeletion(at indexPath: IndexPath, completion: @escaping (Bool) -> Void) {
        guard items.indices.contains(indexPath.item) else {
            completion(false)
            return
        }
        let title = NSLocalizedString("Delete design?", comment: "")
        let message = NSLocalizedString("This action will permanently remove the image from your history.", comment: "")
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: { _ in
            completion(false)
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Delete", comment: ""), style: .destructive, handler: { [weak self] _ in
            self?.deleteItem(at: indexPath, completion: completion)
        }))
        present(alert, animated: true)
    }
    
    func deleteItem(at indexPath: IndexPath, completion: @escaping (Bool) -> Void) {
        guard items.indices.contains(indexPath.item) else {
            completion(false)
            return
        }
        let doc = items[indexPath.item]
        Task {
            do {
                try await imageRepo.deleteImage(docId: doc.id)
                await MainActor.run { [weak self] in
                    guard let self else {
                        completion(true)
                        return
                    }
                    if self.items.indices.contains(indexPath.item), self.items[indexPath.item].id == doc.id {
                        self.items.remove(at: indexPath.item)
                        self.collectionView.deleteItems(at: [indexPath])
                    } else if let idx = self.items.firstIndex(where: { $0.id == doc.id }) {
                        self.items.remove(at: idx)
                        self.collectionView.deleteItems(at: [IndexPath(item: idx, section: 0)])
                    } else {
                        self.collectionView.reloadData()
                    }
                    self.updateEmptyState()
                    completion(true)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.showDeletionError(error.localizedDescription)
                    completion(false)
                }
            }
        }
    }
    
    func showDeletionError(_ message: String) {
        let alert = UIAlertController(
            title: NSLocalizedString("Unable to delete", comment: ""),
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    func colorType(named name: String) -> ColorType? {
        ColorType.allCases.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }
    
    func savedUnifiedStyle(for option: DesignOption, doc: ImageDoc) -> (style: UnifiedStyle, displayName: String)? {
        switch option {
        case .interior, .replace:
            if let style = doc.savedInteriorStyle {
                return (.interior(style), style.name)
            }
        case .exterior:
            if let style = doc.savedExteriorStyle {
                return (.exterior(style), style.name)
            }
        default:
            break
        }
        if let styleName = doc.style,
           let unified = unifiedStyle(named: styleName, option: option) {
            return (unified, styleName)
        }
        return nil
    }
    
    func randomUnifiedStyle(for option: DesignOption) -> (style: UnifiedStyle, displayName: String)? {
        switch option {
        case .interior, .replace:
            if let random = StyleInteriorType.allCases.randomElement() {
                return (.interior(random), random.name)
            }
        case .exterior:
            if let random = StyleExteriorType.allCases.randomElement() {
                return (.exterior(random), random.name)
            }
        default:
            break
        }
        return nil
    }
    
    func unifiedStyle(named name: String, option: DesignOption) -> UnifiedStyle? {
        switch option {
        case .interior:
            guard let style = StyleInteriorType.allCases.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { return nil }
            return .interior(style)
        case .exterior:
            guard let style = StyleExteriorType.allCases.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { return nil }
            return .exterior(style)
        default:
            return nil
        }
    }
}
