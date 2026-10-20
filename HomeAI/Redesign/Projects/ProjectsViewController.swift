import UIKit

/// A/10 · PR1 Projects tab: Designs (projects grid, select mode, delete confirm) · Ideas (saved from Inspiration),
/// PR3 empty states. Layout: Projects.storyboard.
final class ProjectsViewController: UIViewController {

    @IBOutlet private weak var collectionView: UICollectionView!
    @IBOutlet private weak var headerView: UIView!
    @IBOutlet private weak var headerBackgroundView: UIView!
    @IBOutlet private weak var largeTitleLabel: UILabel!
    @IBOutlet private weak var selectButton: DSPressableControl!
    @IBOutlet private weak var selectLabel: UILabel!
    @IBOutlet private weak var segmentView: UIView!
    @IBOutlet private weak var segmentKnob: UIView!
    @IBOutlet private weak var segmentKnobLeading: NSLayoutConstraint!
    @IBOutlet private var segmentControls: [DSPressableControl]!
    @IBOutlet private var segmentLabels: [UILabel]!
    @IBOutlet private weak var emptyStateView: UIStackView!
    @IBOutlet private weak var emptyIconView: UIImageView!
    @IBOutlet private weak var emptyTitleLabel: UILabel!
    @IBOutlet private weak var emptySubtitleLabel: UILabel!
    @IBOutlet private weak var emptyPrimaryButton: DSPrimaryButton!
    @IBOutlet private weak var emptyPrimaryLabel: UILabel!
    @IBOutlet private weak var emptyGhostButton: UIButton!
    @IBOutlet private weak var actionBarView: UIView!
    @IBOutlet private var actionControls: [DSPressableControl]!
    @IBOutlet private var actionLabels: [UILabel]!

    private enum Segment: Int { case designs, ideas }

    private var segment: Segment = .designs
    private var designs: [(project: DesignProject, versions: [ImageDoc])] = []
    private var ideas: [InspirationIdea] = []
    private var selecting = false
    private var selectedIDs = Set<String>()
    private var didRunEntrance = false
    private var needsReload = false
    private let ideaTransition = InspirationHeroTransition()

    override func viewDidLoad() {
        super.viewDidLoad()
        largeTitleLabel.text = "Projects".localized
        selectLabel.text = "Select".localized
        let segTitles = ["Designs", "Ideas"]
        segmentLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = segTitles[$0].localized }
        let actions = ["Share", "Duplicate", "Delete"]
        actionLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = actions[$0].localized }
        emptyGhostButton.setTitle("Browse inspiration".localized, for: .normal)


        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.allowsMultipleSelection = false

        NotificationCenter.default.addObserver(self, selector: #selector(dataChanged), name: .projectsDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dataChanged), name: .savedIdeasDidChange, object: nil)
        reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        if needsReload { reloadData() }
        if !didRunEntrance {
            [largeTitleLabel, selectButton, segmentKnob, emptyIconView, emptyTitleLabel,
             emptySubtitleLabel, emptyPrimaryButton, emptyGhostButton].forEach { $0?.alpha = 0 }
            segmentControls.forEach { $0.alpha = 0 }
            collectionView.alpha = 0
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if selecting { setSelecting(false) }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applySegment(index: segment.rawValue, labels: segmentLabels, knobLeading: segmentKnobLeading,
                     container: segmentView, count: 2, animated: false)
        let metrics = OnboardingLayout(size: view.dsAdaptiveReferenceSize)
        let top = headerView.frame.maxY + metrics.value(4)
        let bottom = view.safeAreaInsets.bottom + metrics.value(24)
        if collectionView.contentInset.top != top || collectionView.contentInset.bottom != bottom {
            let atTop = collectionView.contentOffset.y <= -collectionView.contentInset.top + 1
            collectionView.contentInset = UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
            collectionView.verticalScrollIndicatorInsets = collectionView.contentInset
            if atTop { collectionView.contentOffset.y = -top }
        }
        updateItemSize()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didRunEntrance else { return }
        didRunEntrance = true
        // Figma A/10 PR1: title y 12 at 0 ms, segments x 16 from 60 ms (40 ms apart),
        // cards from 140 ms every 60 ms (scale 0.94 → 1 bouncy).
        DS.Motion.enter(largeTitleLabel, delay: 0, dy: 12)
        DS.Motion.enter(selectButton, delay: 0, dy: 12)
        segmentControls.sorted { $0.tag < $1.tag }.enumerated().forEach {
            DS.Motion.enter($1, delay: 0.06 + 0.04 * Double($0), dx: 16)
        }
        DS.Motion.enter(segmentKnob, delay: 0.06, dx: 16)
        animateCards(from: 0.14)
        collectionView.alpha = 1
        animateEmptyState()
    }

    private func updateItemSize() {
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        let metrics = OnboardingLayout(size: view.dsLayoutSize)
        let w = floor((collectionView.bounds.width - metrics.value(40 + 13)) / 2)
        let h = segment == .designs ? round(w * 200 / 170) + metrics.value(46) : round(w * 230 / 170)
        let size = CGSize(width: w, height: h)
        guard layout.itemSize != size else { return }
        layout.itemSize = size
        layout.minimumLineSpacing = metrics.value(segment == .designs ? 18 : 13)
        layout.minimumInteritemSpacing = metrics.value(13)
        layout.sectionInset = UIEdgeInsets(top: 0, left: metrics.value(20), bottom: 0, right: metrics.value(20))
        layout.invalidateLayout()
    }

    // MARK: Data

    @objc private func dataChanged() {
        if view.window == nil { needsReload = true; return }
        reloadData()
    }

    private func reloadData() {
        needsReload = false
        designs = ProjectStore.shared.allProjects()
        ideas = IdeasStore.shared.savedIdeas()
        selectedIDs = selectedIDs.filter { id in designs.contains { $0.project.id == id } }
        collectionView.reloadData()
        updateEmptyState()
        updateHeader()
    }

    private var isEmpty: Bool { segment == .designs ? designs.isEmpty : ideas.isEmpty }

    private func updateEmptyState() {
        emptyStateView.isHidden = !isEmpty
        selectButton.isHidden = segment == .ideas || designs.isEmpty
        switch segment {
        case .designs:
            emptyIconView.image = UIImage(named: "clay_interior")
            emptyTitleLabel.text = "Your redesigns will live here".localized
            emptySubtitleLabel.text = "Every design and edit is saved as a version, so you can always go back.".localized
            emptyPrimaryLabel.text = "Redesign a room".localized
            emptyPrimaryButton.isHidden = false
        case .ideas:
            emptyIconView.image = UIImage(named: "clay_reference")
            emptyTitleLabel.text = "Save ideas from Inspiration".localized
            emptySubtitleLabel.text = "Tap the bookmark on any idea and it will wait for you here.".localized
            emptyPrimaryButton.isHidden = true
        }
    }

    private func animateEmptyState() {
        guard isEmpty else { return }
        // PR3: illustration fades in at 140 ms and floats ±4 pt (3 s loop); text and buttons 60 ms apart.
        DS.Motion.enter(emptyIconView, delay: 0.14, duration: 0.45)
        if !DS.Motion.reduceMotion {
            let float = CABasicAnimation(keyPath: "transform.translation.y")
            float.fromValue = 0
            float.toValue = -4
            float.duration = 1.5
            float.autoreverses = true
            float.repeatCount = .infinity
            float.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            float.beginTime = CACurrentMediaTime() + 0.8
            emptyIconView.layer.add(float, forKey: "float")
        }
        [emptyTitleLabel, emptySubtitleLabel, emptyPrimaryButton, emptyGhostButton].enumerated().forEach {
            DS.Motion.enter($1, delay: 0.2 + 0.06 * Double($0), dy: 12)
        }
    }

    private func animateCards(from delay: TimeInterval) {
        collectionView.layoutIfNeeded()
        let cells = collectionView.indexPathsForVisibleItems.sorted().compactMap { collectionView.cellForItem(at: $0) }
        cells.enumerated().forEach { DS.Motion.enterBouncy($1, delay: delay + 0.06 * Double($0), dy: 12, scale: 0.94) }
    }

    private func updateHeader() {
        largeTitleLabel.text = selecting
            ? String(format: "%d selected".localized, selectedIDs.count)
            : "Projects".localized
        selectLabel.text = selecting ? "Done".localized : "Select".localized
        actionControls.forEach { $0.dimmed = selecting && selectedIDs.isEmpty }
        actionControls.forEach { $0.isUserInteractionEnabled = !selectedIDs.isEmpty }
    }

    // MARK: Segments

    @IBAction private func didTapSegment(_ sender: UIControl) {
        guard let new = Segment(rawValue: sender.tag), new != segment else { return }
        DS.Haptic.selection()
        if selecting { setSelecting(false) }
        segment = new
        applySegment(index: segment.rawValue, labels: segmentLabels, knobLeading: segmentKnobLeading,
                     container: segmentView, count: 2, animated: true)
        updateItemSize()
        UIView.transition(with: collectionView, duration: 0.25, options: .transitionCrossDissolve) {
            self.collectionView.reloadData()
        }
        updateEmptyState()
        animateEmptyState()
    }

    // MARK: Select mode

    @IBAction private func didTapSelect(_ sender: Any) {
        setSelecting(!selecting)
    }

    private func setSelecting(_ on: Bool) {
        selecting = on
        if !on { selectedIDs.removeAll() }
        DS.Haptic.light()
        let cells = collectionView.indexPathsForVisibleItems.sorted().compactMap { collectionView.cellForItem(at: $0) as? ProjectCell }
        cells.enumerated().forEach { i, cell in
            cell.setSelecting(on, animated: true, delay: 0.03 * Double(i))
            if !on { cell.setChosen(false, animated: false) }
        }
        let tabs = tabBarController as? TabBarController
        if on {
            tabs?.setTabBarHiddenForSelection(true, animated: true)
            actionBarView.isHidden = false
            actionBarView.alpha = 0
            actionBarView.transform = CGAffineTransform(translationX: 0, y: 30)
            DS.Motion.animate(0.45, delay: 0.1) { self.actionBarView.alpha = 1 }
            UIViewPropertyAnimator(duration: 0.45, dampingRatio: 0.75) { self.actionBarView.transform = .identity }
                .startAnimation(afterDelay: 0.1)
        } else {
            UIView.animate(withDuration: 0.25, animations: {
                self.actionBarView.alpha = 0
                self.actionBarView.transform = CGAffineTransform(translationX: 0, y: 30)
            }, completion: { _ in self.actionBarView.isHidden = true })
            tabs?.setTabBarHiddenForSelection(false, animated: true)
        }
        UIView.transition(with: largeTitleLabel, duration: 0.2, options: .transitionCrossDissolve) { self.updateHeader() }
    }

    private var selectedProjects: [(project: DesignProject, versions: [ImageDoc])] {
        designs.filter { selectedIDs.contains($0.project.id) }
    }

    @IBAction private func didTapAction(_ sender: UIControl) {
        let items = selectedProjects
        guard !items.isEmpty else { return }
        switch sender.tag {
        case 0: share(items, from: sender)
        case 1:
            items.forEach { ProjectStore.shared.duplicate(project: $0.project, versions: $0.versions) }
            DS.Haptic.success()
            DSToastView.show(items.count == 1 ? "Project duplicated".localized
                             : String(format: "%d projects duplicated".localized, items.count), style: .success)
            setSelecting(false)
        default: confirmDelete(items, from: sender)
        }
    }

    private func share(_ items: [(project: DesignProject, versions: [ImageDoc])], from source: UIView) {
        let images = items.compactMap { $0.versions.last.flatMap { UIImage(contentsOfFile: $0.storagePath) } }
        guard !images.isEmpty else { return }
        let vc = UIActivityViewController(activityItems: images, applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = source
        present(vc, animated: true)
    }

    /// PR1 · Delete confirm: system action sheet, destructive; cards shrink 0.9 + fade 0.25 s, then a toast.
    private func confirmDelete(_ items: [(project: DesignProject, versions: [ImageDoc])], from source: UIView) {
        let title = items.count == 1 ? "Delete this project?".localized
            : String(format: "Delete %d projects?".localized, items.count)
        let sheet = UIAlertController(title: title,
                                      message: "All versions will be removed from this device. This can't be undone.".localized,
                                      preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Delete".localized, style: .destructive) { [weak self] _ in
            self?.delete(items)
        })
        sheet.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel))
        sheet.popoverPresentationController?.sourceView = source
        present(sheet, animated: true)
    }

    private func delete(_ items: [(project: DesignProject, versions: [ImageDoc])]) {
        let ids = Set(items.map(\.project.id))
        let paths = designs.enumerated().filter { ids.contains($0.element.project.id) }.map { IndexPath(item: $0.offset, section: 0) }
        UIView.animate(withDuration: 0.25, animations: {
            paths.compactMap { self.collectionView.cellForItem(at: $0) }.forEach {
                $0.alpha = 0
                $0.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }
        }, completion: { _ in
            Task { @MainActor in
                for item in items {
                    try? await ProjectStore.shared.deleteProject(id: item.project.id,
                                                                 fallbackDocID: item.project.versionIDs.first ?? "")
                }
                self.designs.removeAll { ids.contains($0.project.id) }
                self.selectedIDs.removeAll()
                self.collectionView.performBatchUpdates { self.collectionView.deleteItems(at: paths) }
                self.setSelecting(false)
                self.updateEmptyState()
                DS.Haptic.success()
                DSToastView.show(items.count == 1 ? "Project deleted".localized
                                 : String(format: "%d projects deleted".localized, items.count), style: .success)
            }
        })
    }

    // MARK: Rename (context menu)

    private func rename(_ item: (project: DesignProject, versions: [ImageDoc])) {
        let alert = UIAlertController(title: "Rename project".localized, message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.text = ProjectStore.shared.displayTitle(for: item.project, versions: item.versions)
            field.clearButtonMode = .whileEditing
            field.autocapitalizationType = .sentences
        }
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel))
        alert.addAction(UIAlertAction(title: "Save".localized, style: .default) { _ in
            let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces) ?? ""
            guard !text.isEmpty, let first = item.versions.first else { return }
            ProjectStore.shared.rename(projectID: item.project.id, firstDocID: first.id, to: text)
        })
        present(alert, animated: true)
    }

    // MARK: Empty state actions

    @IBAction private func didTapEmptyPrimary(_ sender: Any) {
        NavigationManager.shared.startDesign(option: .interior)
    }

    @IBAction private func didTapBrowse(_ sender: Any) {
        (tabBarController as? TabBarController)?.select(.inspiration)
    }

    // MARK: Open

    private func openProject(at index: Int, from cell: ProjectCell?) {
        let item = designs[index]
        DS.Haptic.light()
        let vc = ProjectDetailViewController.make(projectID: item.project.id, lastDocID: item.versions.last?.id)
        vc.initialCover = cell?.coverImageView.image
        navigationController?.pushViewController(vc, animated: true)
    }

    private func openIdea(at index: Int) {
        let idea = ideas[index]
        let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? InspirationCardCell
        let detail = IdeaDetailViewController.make(idea: idea, image: cell?.image)
        detail.onTag = { [weak self] room, style in
            (self?.tabBarController as? TabBarController)?.select(.inspiration)
            let nav = (self?.tabBarController?.selectedViewController as? UINavigationController)
            (nav?.viewControllers.first as? InspirationFeedViewController)?.applyTag(room: room, style: style)
        }
        ideaTransition.sourceView = { [weak self] in
            guard let self, let i = self.ideas.firstIndex(of: idea) else { return nil }
            return (self.collectionView.cellForItem(at: IndexPath(item: i, section: 0)) as? InspirationCardCell)?.photoImageView
        }
        detail.modalPresentationStyle = .custom
        detail.transitioningDelegate = ideaTransition
        present(detail, animated: true)
    }
}

extension ProjectsViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        segment == .designs ? designs.count : ideas.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch segment {
        case .designs:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ProjectCell.reuseID, for: indexPath)
            let item = designs[indexPath.item]
            (cell as? ProjectCell)?.configure(project: item.project, versions: item.versions, selecting: selecting,
                                              selected: selectedIDs.contains(item.project.id))
            return cell
        case .ideas:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: InspirationCardCell.reuseID, for: indexPath)
            let idea = ideas[indexPath.item]
            if let card = cell as? InspirationCardCell {
                card.configure(idea: idea, saved: true)
                card.onBookmark = { [weak self] in
                    DS.Haptic.light()
                    IdeasStore.shared.toggle(idea)
                    guard let self, let i = self.ideas.firstIndex(of: idea) else { return }
                    self.ideas.remove(at: i)
                    self.collectionView.performBatchUpdates {
                        self.collectionView.deleteItems(at: [IndexPath(item: i, section: 0)])
                    }
                    self.updateEmptyState()
                    self.animateEmptyState()
                }
            }
            return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch segment {
        case .designs:
            let cell = collectionView.cellForItem(at: indexPath) as? ProjectCell
            guard selecting else { return openProject(at: indexPath.item, from: cell) }
            let id = designs[indexPath.item].project.id
            let chosen = !selectedIDs.contains(id)
            if chosen { selectedIDs.insert(id) } else { selectedIDs.remove(id) }
            DS.Haptic.selection()
            cell?.setChosen(chosen, animated: true)
            updateHeader()
        case .ideas:
            openIdea(at: indexPath.item)
        }
    }

    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return }
        UIView.animate(withDuration: 0.15) { cell.transform = CGAffineTransform(scaleX: 0.97, y: 0.97) }
    }

    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return }
        UIView.animate(withDuration: 0.2) { cell.transform = .identity }
    }

    /// Long tap → Rename, Duplicate, Share, Delete.
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        guard segment == .designs, !selecting else { return nil }
        let item = designs[indexPath.item]
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            UIMenu(children: [
                UIAction(title: "Rename".localized, image: UIImage(systemName: "pencil")) { _ in self?.rename(item) },
                UIAction(title: "Duplicate".localized, image: UIImage(systemName: "square.on.square")) { _ in
                    ProjectStore.shared.duplicate(project: item.project, versions: item.versions)
                    DSToastView.show("Project duplicated".localized, style: .success)
                },
                UIAction(title: "Share".localized, image: UIImage(systemName: "square.and.arrow.up")) { _ in
                    guard let self else { return }
                    self.share([item], from: collectionView.cellForItem(at: indexPath) ?? self.view)
                },
                UIAction(title: "Delete".localized, image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                    guard let self else { return }
                    self.confirmDelete([item], from: collectionView.cellForItem(at: indexPath) ?? self.view)
                }
            ])
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let y = scrollView.contentOffset.y + scrollView.contentInset.top
        headerBackgroundView.alpha = min(max(y / 12, 0), 1)
    }
}
