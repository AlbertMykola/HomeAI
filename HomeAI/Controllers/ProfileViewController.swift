import UIKit

private struct Defaults {
    
    struct Text {
        static let noDesign = "No design yet".localized
        static let description = "Start transform your space".localized
        static let startCreating = "Start creating".localized
        static let settings = "Settings".localized
        static let deleteDesignTitle = "Delete design?".localized
        static let deleteDesignMessage = "This action will permanently remove the image from your history.".localized
        static let delete = "Delete".localized
        static let cancel = "Cancel".localized
        static let unableToDelete = "Unable to delete".localized
        static let ok = "OK".localized
    }

    /// UICollectionView часто не тригерить системний collapse large title — лише `largeTitleDisplayMode`, без перебудови appearance.
    struct NavBarLargeTitleScroll {
        static let collapseYOffset: CGFloat = 56
        /// Трохи вище нуля: після згортання offset біля верху може бути > 0.
        static let expandYOffset: CGFloat = 16
    }
}

final class ProfileViewController: UIViewController {

    @IBOutlet private weak var noDesignLabel: UILabel!
    @IBOutlet private weak var descriptionLabel: UILabel!
    @IBOutlet private weak var collectionView: UICollectionView!

    @IBOutlet private weak var createButton: UIButton!
    
    
    private var items: [ImageDoc] = []
    private var isLoading = false
    private let pageSize = 20

    private let imageRepo = ImageHistoryService()
    private let fileManager = FileManager.default
    private var historyObserver: NSObjectProtocol?
    private var pendingHistoryReload = false
    private var didInstallNavigationBarAppearance = false
    /// Відповідає поточному `largeTitleDisplayMode` (.always vs .never); без цього скрол постійно перемальовує бар.
    private var navLargeTitleExpanded = true

    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        installNavigationBarAppearanceIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        syncNavLargeTitleWithScrollPosition(animated: false)
    }
    

    
    private func configure() {
        noDesignLabel.text = Defaults.Text.noDesign
        descriptionLabel.text = Defaults.Text.description
        configureCreateButton()
        
        collectionView.setCollectionViewLayout(makeInspirationGridLayout(), animated: false)

        collectionView.register(UINib(nibName: "InspirationCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "InspirationCollectionViewCell")
        collectionView.contentInsetAdjustmentBehavior = .automatic
        collectionView.alwaysBounceVertical = true
        setupNavBarItems()
        observeHistoryChanges()

        imageRepo.resetHistoryPaging()
        loadNextPage()
        updateEmptyState()
    }

    private func configureCreateButton() {
        let titleColor = UIColor.black
        if var config = createButton.configuration {
            config.title = Defaults.Text.startCreating
            config.baseForegroundColor = titleColor
            if var attributed = config.attributedTitle {
                attributed.foregroundColor = titleColor
                config.attributedTitle = attributed
            } else {
                var attributed = AttributedString(Defaults.Text.startCreating)
                attributed.foregroundColor = titleColor
                config.attributedTitle = attributed
            }
            createButton.configuration = config
        } else {
            createButton.setTitle(Defaults.Text.startCreating, for: .normal)
        }
        createButton.setTitleColor(titleColor, for: .normal)
        createButton.tintColor = titleColor
        createButton.buttonColor = titleColor
    }
    
    
    
    private func setupNavBarItems() {
        navigationItem.title = Constants.Text.brand

        let gear = UIImage(systemName: "gearshape")
        let settingsItem = UIBarButtonItem(image: gear, style: .plain, target: self, action: #selector(didTapSettings))
        settingsItem.accessibilityLabel = Defaults.Text.settings
        navigationItem.rightBarButtonItem = settingsItem
    }

    /// Один раз на екран — повторне створення appearance у scroll ламало inset і зависало UI.
    private func installNavigationBarAppearanceIfNeeded() {
        guard let navBar = navigationController?.navigationBar else { return }
        guard !didInstallNavigationBarAppearance else { return }
        didInstallNavigationBarAppearance = true

        navBar.prefersLargeTitles = true
        navBar.isTranslucent = true

        let brandLargeFont = UIFont.geologica(.standard(.bold), size: 30)
        let brandInlineFont = UIFont.geologica(.standard(.semiBold), size: 17)
        let inlineTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: brandInlineFont,
            .foregroundColor: UIColor.label
        ]
        let largeTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: brandLargeFont,
            .foregroundColor: UIColor.label
        ]

        let standard = UINavigationBarAppearance()
        standard.configureWithTransparentBackground()
        standard.shadowColor = .clear
        standard.titleTextAttributes = inlineTitleAttributes

        let scrollEdge = UINavigationBarAppearance()
        scrollEdge.configureWithTransparentBackground()
        scrollEdge.shadowColor = .clear
        scrollEdge.largeTitleTextAttributes = largeTitleAttributes
        scrollEdge.titleTextAttributes = inlineTitleAttributes

        navBar.standardAppearance = standard
        navBar.scrollEdgeAppearance = scrollEdge
        navBar.compactAppearance = standard
        if #available(iOS 15.0, *) {
            navBar.compactScrollEdgeAppearance = scrollEdge
        }

        navigationItem.standardAppearance = standard
        navigationItem.scrollEdgeAppearance = scrollEdge
        navigationItem.compactAppearance = standard
        if #available(iOS 15.0, *) {
            navigationItem.compactScrollEdgeAppearance = scrollEdge
        }
    }

    /// Лише `largeTitleDisplayMode` — без нових `UINavigationBarAppearance` (інакше можливі цикли layout/inset).
    private func syncNavLargeTitleWithScrollPosition(animated: Bool) {
        guard collectionView.bounds.height > 1 else { return }
        let y = collectionView.contentOffset.y
        updateNavLargeTitleForContentOffset(y, animated: animated)
    }

    private func updateNavLargeTitleForContentOffset(_ y: CGFloat, animated: Bool) {
        let collapseAt = Defaults.NavBarLargeTitleScroll.collapseYOffset
        let expandBelow = Defaults.NavBarLargeTitleScroll.expandYOffset

        let nextExpanded: Bool
        if y > collapseAt {
            nextExpanded = false
        } else if y < expandBelow {
            nextExpanded = true
        } else {
            nextExpanded = navLargeTitleExpanded
        }

        guard nextExpanded != navLargeTitleExpanded else { return }
        navLargeTitleExpanded = nextExpanded

        let mode: UINavigationItem.LargeTitleDisplayMode = nextExpanded ? .always : .never
        guard navigationItem.largeTitleDisplayMode != mode else { return }

        let updates = {
            self.navigationItem.largeTitleDisplayMode = mode
            self.navigationController?.navigationBar.setNeedsLayout()
        }
        if animated {
            updates()
        } else {
            UIView.performWithoutAnimation {
                updates()
                self.navigationController?.navigationBar.layoutIfNeeded()
            }
        }
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
                    self.syncNavLargeTitleWithScrollPosition(animated: false)
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
    
    @IBAction private func createAction(_ sender: UIButton) {
        guard let tabBarController else { return }
        tabBarController.selectedIndex = 0
        if let nav = tabBarController.viewControllers?.first as? UINavigationController {
            nav.popToRootViewController(animated: false)
        }
    }
    
    @objc private func didTapSettings() {
        NavigationManager.shared.settings()
    }
    
    deinit {
        if let historyObserver {
            NotificationCenter.default.removeObserver(historyObserver)
        }
    }
}

// MARK: - UICollectionViewDataSource
extension ProfileViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "InspirationCollectionViewCell",for: indexPath) as? InspirationCollectionViewCell else {
            return UICollectionViewCell()
        }
        guard let doc = items[safe: indexPath.item] else { return cell }
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

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === collectionView else { return }
        updateNavLargeTitleForContentOffset(scrollView.contentOffset.y, animated: false)
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let threshold = 6
        if indexPath.item >= items.count - threshold, !isLoading, imageRepo.canLoadMore {
            loadNextPage()
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let doc = items[safe: indexPath.item] else { return }
        let cell = collectionView.cellForItem(at: indexPath) as? InspirationCollectionViewCell
        guard let image = cell?.currentImage else { return }

        let option = doc.designOption ?? .interior
        var resolvedStyleName = doc.style
        var resolvedColorName = doc.colorName
        var canRegenerate = doc.canRegenerate && (doc.originalPath.flatMap { fileManager.fileExists(atPath: $0) } ?? false)
        
        let promptManager = GemeniPromptManager()
        promptManager.updateOption(option)
        promptManager.updateBaseImage(image)
        if let mode = doc.savedDesignMode {
            promptManager.updateDesignMode(mode)
        }
        if let material = doc.savedSurfaceMaterial {
            promptManager.updateSurfaceMaterial(material)
        }
        if let surfaceCustomPrompt = doc.surfaceCustomPrompt,
           !surfaceCustomPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            promptManager.updateSurfaceCustomPrompt(surfaceCustomPrompt)
        }
        if let objectToReplace = doc.objectToReplace,
           !objectToReplace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            promptManager.updateObjectToReplace(objectToReplace)
        }
        if let replaceMode = doc.savedReplaceMode {
            promptManager.updateReplaceMode(replaceMode)
        }
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
        case .rearrange:
            if let subOption = doc.savedRearrangeSubOption {
                promptManager.updateRearrangeSubOption(subOption)
                resolvedStyleName = subOption.displayTitle
            } else {
                canRegenerate = false
            }
        default:
            break
        }
        
        // Для `.rearrange` стиль/колір не використовуються у промпті,
        // а резолвенний стиль уже містить displayTitle підрежиму — нічого не підмінюємо.
        if option != .rearrange {
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
        let title = Defaults.Text.delete
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
        createButton.isHidden = !isEmpty

        if isEmpty {
            navLargeTitleExpanded = true
            guard navigationItem.largeTitleDisplayMode != .always else { return }
            UIView.performWithoutAnimation {
                navigationItem.largeTitleDisplayMode = .always
                navigationController?.navigationBar.layoutIfNeeded()
            }
        }
    }
    
    func confirmDeletion(at indexPath: IndexPath, completion: @escaping (Bool) -> Void) {
        guard items.indices.contains(indexPath.item) else {
            completion(false)
            return
        }
        let alert = UIAlertController(
            title: Defaults.Text.deleteDesignTitle,
            message: Defaults.Text.deleteDesignMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: Defaults.Text.cancel, style: .cancel, handler: { _ in
            completion(false)
        }))
        alert.addAction(UIAlertAction(title: Defaults.Text.delete, style: .destructive, handler: { [weak self] _ in
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
            title: Defaults.Text.unableToDelete,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: Defaults.Text.ok, style: .default))
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
