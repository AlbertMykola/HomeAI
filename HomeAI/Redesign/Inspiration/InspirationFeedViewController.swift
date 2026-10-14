import UIKit

/// A/08 · I1 Inspiration feed (+ I1 · Skeleton). Tab root. Layout: InspirationFeedViewController.xib.
final class InspirationFeedViewController: UIViewController {

    @IBOutlet private weak var collectionView: UICollectionView!
    @IBOutlet private weak var headerView: UIView!
    @IBOutlet private weak var headerBackgroundView: UIView!
    @IBOutlet private weak var headerHairline: UIView!
    @IBOutlet private weak var largeTitleLabel: UILabel!
    @IBOutlet private weak var compactTitleLabel: UILabel!
    @IBOutlet private weak var searchButton: DSPressableControl!
    @IBOutlet private weak var searchBarView: UIStackView!
    @IBOutlet private weak var searchField: UITextField!
    @IBOutlet private weak var cancelSearchButton: UIButton!
    @IBOutlet private weak var roomScrollView: UIScrollView!
    @IBOutlet private var roomChips: [DSChipControl]!
    @IBOutlet private weak var suggestionScrollView: UIScrollView!
    @IBOutlet private var suggestionChips: [DSChipControl]!
    @IBOutlet private weak var skeletonView: UIView!
    @IBOutlet private var skeletonBlocks: [UIView]!
    @IBOutlet private weak var emptyStateView: UIStackView!
    @IBOutlet private weak var emptyTitleLabel: UILabel!
    @IBOutlet private weak var emptySubtitleLabel: UILabel!
    @IBOutlet private weak var offlineBannerView: UIView!
    @IBOutlet private weak var offlineLabel: UILabel!
    @IBOutlet private weak var offlineTopConstraint: NSLayoutConstraint!

    private static let pageSize = 12
    private static let ratios: [CGFloat] = [1.35, 1.0, 1.24, 1.18, 1.41, 1.06, 1.24, 1.0]

    private var allIdeas: [InspirationIdea] = []
    private var filtered: [InspirationIdea] = []
    private var visibleCount = 0
    private var room: InspirationIdea.Room = .all
    private var query = ""
    private var isSearching = false
    private var didRunEntrance = false
    private var isShowingSkeleton = true
    private let layout = MasonryLayout()
    private let transition = InspirationHeroTransition()

    private var shown: [InspirationIdea] { Array(filtered.prefix(visibleCount)) }

    override func viewDidLoad() {
        super.viewDidLoad()
        largeTitleLabel.text = "Inspiration".localized
        compactTitleLabel.text = "Inspiration".localized
        searchField.placeholder = "Search styles".localized
        searchField.delegate = self
        searchField.returnKeyType = .search
        searchField.clearButtonMode = .whileEditing
        searchField.addTarget(self, action: #selector(searchChanged), for: .editingChanged)
        cancelSearchButton.setTitle("Cancel".localized, for: .normal)
        emptyTitleLabel.text = "Nothing found".localized
        emptySubtitleLabel.text = "Try another style or room".localized
        offlineLabel.text = "Offline. Showing saved ideas.".localized
        roomChips.sorted { $0.tag < $1.tag }.forEach { chip in
            let room = InspirationIdea.Room(rawValue: chip.tag)
            label(in: chip)?.text = room?.title
        }
        suggestionChips.forEach { label(in: $0)?.text = label(in: $0)?.text?.localized }

        layout.heightRatio = { [weak self] ip in
            guard let idea = self?.shown[safe: ip.item] else { return 1.3 }
            let hash = idea.id.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
            return Self.ratios[hash % Self.ratios.count]
        }
        collectionView.collectionViewLayout = layout
        collectionView.register(UINib(nibName: "InspirationCardCell", bundle: nil),
                                forCellWithReuseIdentifier: InspirationCardCell.reuseID)
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.keyboardDismissMode = .onDrag

        NotificationCenter.default.addObserver(self, selector: #selector(savedIdeasChanged),
                                               name: .savedIdeasDidChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(networkChanged),
                                               name: .networkStatusDidChange, object: nil)
        startSkeleton()
        loadFeed()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        updateOfflineState(animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didRunEntrance else { return }
        didRunEntrance = true
        // Figma A/08 I1 timeline: title 0 ms (y 12), chips from 60 ms every 40 ms (x 16), all 450 ms ease-out.
        DS.Motion.enter(largeTitleLabel, delay: 0, dy: 12)
        DS.Motion.enter(searchButton, delay: 0, dy: 12)
        roomChips.sorted { $0.tag < $1.tag }.enumerated().forEach { i, chip in
            DS.Motion.enter(chip, delay: 0.06 + Double(i) * 0.04, dx: 16)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let top = headerView.frame.maxY + 12
        let bottom = view.safeAreaInsets.bottom + 24
        if collectionView.contentInset.top != top || collectionView.contentInset.bottom != bottom {
            let atTop = collectionView.contentOffset.y <= -collectionView.contentInset.top + 1
            collectionView.contentInset = UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
            collectionView.verticalScrollIndicatorInsets = UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
            if atTop { collectionView.contentOffset.y = -top }
        }
    }

    // MARK: Data

    private func loadFeed() {
        let started = Date()
        DispatchQueue.global(qos: .userInitiated).async {
            let ideas = InspirationFeed.load()
            // Skeleton shows at least 300 ms so it never blinks.
            let wait = max(0, 0.3 - Date().timeIntervalSince(started))
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in
                guard let self else { return }
                self.allIdeas = ideas
                self.applyFilter(animated: false)
                self.hideSkeleton()
            }
        }
    }

    private func applyFilter(animated: Bool, keepCount: Bool = false) {
        let old = shown
        filtered = allIdeas.filter { (room == .all || $0.room == room) && $0.matches(query) }
        if !NetworkMonitor.shared.isOnline {
            let saved = Set(IdeasStore.shared.savedIDs)
            let cached = filtered.filter { saved.contains($0.id) }
            if !cached.isEmpty { filtered = cached }
        }
        visibleCount = min(keepCount ? max(visibleCount, Self.pageSize) : Self.pageSize, filtered.count)
        updateEmptyState()
        guard animated, !old.isEmpty, view.window != nil else {
            collectionView.reloadData()
            return
        }
        let new = shown
        let oldIDs = old.map(\.id), newIDs = new.map(\.id)
        let deletes = oldIDs.enumerated().filter { !newIDs.contains($0.element) }.map { IndexPath(item: $0.offset, section: 0) }
        let inserts = newIDs.enumerated().filter { !oldIDs.contains($0.element) }.map { IndexPath(item: $0.offset, section: 0) }
        let moves = newIDs.enumerated().compactMap { i, id -> (IndexPath, IndexPath)? in
            guard let from = oldIDs.firstIndex(of: id) else { return nil }
            return (IndexPath(item: from, section: 0), IndexPath(item: i, section: 0))
        }
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut, .allowUserInteraction]) {
            self.collectionView.performBatchUpdates {
                self.collectionView.deleteItems(at: deletes)
                self.collectionView.insertItems(at: inserts)
                moves.forEach { self.collectionView.moveItem(at: $0.0, to: $0.1) }
            }
        }
    }

    private func updateEmptyState() {
        let empty = filtered.isEmpty && !allIdeas.isEmpty
        if empty, !query.isEmpty {
            emptyTitleLabel.text = String(format: "Nothing for “%@”".localized, query)
        } else {
            emptyTitleLabel.text = "Nothing found".localized
        }
        emptyStateView.isHidden = !empty
    }

    /// Next page when the user is 2 screens from the end.
    private func loadMoreIfNeeded() {
        guard visibleCount < filtered.count else { return }
        let remaining = collectionView.contentSize.height - collectionView.contentOffset.y - collectionView.bounds.height
        guard remaining < collectionView.bounds.height * 2 else { return }
        let next = min(visibleCount + Self.pageSize, filtered.count)
        let paths = (visibleCount..<next).map { IndexPath(item: $0, section: 0) }
        visibleCount = next
        UIView.performWithoutAnimation {
            collectionView.insertItems(at: paths)
        }
    }

    private func drop(_ idea: InspirationIdea) {
        guard NetworkMonitor.shared.isOnline, let i = allIdeas.firstIndex(of: idea) else { return }
        allIdeas.remove(at: i)
        applyFilter(animated: true, keepCount: true)
    }

    // MARK: Skeleton

    /// Shimmer left → right 1.2 s (#ECECEC → #F5F5F5) + opacity pulse 1 → 0.45 → 1 (1.4 s, phase-shifted).
    private func startSkeleton() {
        skeletonView.isHidden = false
        guard !DS.Motion.reduceMotion else { return }
        view.layoutIfNeeded()
        for block in skeletonBlocks {
            let shimmer = CAGradientLayer()
            shimmer.frame = block.bounds
            shimmer.cornerRadius = block.layer.cornerRadius
            shimmer.startPoint = CGPoint(x: 0, y: 0.5)
            shimmer.endPoint = CGPoint(x: 1, y: 0.5)
            let base = UIColor(hex: "ECECEC").cgColor, light = UIColor(hex: "F5F5F5").cgColor
            shimmer.colors = [base, light, base]
            let sweep = CABasicAnimation(keyPath: "locations")
            sweep.fromValue = [-1.0, -0.5, 0.0]
            sweep.toValue = [1.0, 1.5, 2.0]
            sweep.duration = 1.2
            sweep.repeatCount = .infinity
            shimmer.add(sweep, forKey: "shimmer")
            block.layer.addSublayer(shimmer)
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 1
            pulse.toValue = 0.45
            pulse.duration = 0.7
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            pulse.timeOffset = Double(block.tag % 6) * 0.18
            pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            block.layer.add(pulse, forKey: "pulse")
        }
    }

    private func hideSkeleton() {
        guard isShowingSkeleton else { return }
        isShowingSkeleton = false
        UIView.animate(withDuration: 0.25, animations: { self.skeletonView.alpha = 0 }) { _ in
            self.skeletonView.isHidden = true
            self.skeletonBlocks.forEach { $0.layer.removeAllAnimations() }
        }
        collectionView.layoutIfNeeded()
        // Cards column by column from 140 ms, 60 ms apart: fade + y 12 + scale 0.94 → 1 (bouncy spring).
        let cells = collectionView.visibleCells.sorted {
            $0.frame.minX != $1.frame.minX ? $0.frame.minX < $1.frame.minX : $0.frame.minY < $1.frame.minY
        }
        cells.enumerated().forEach { i, cell in
            DS.Motion.enterBouncy(cell, delay: 0.14 + Double(i) * 0.06, dy: 12, scale: 0.94)
        }
    }

    // MARK: Header

    private func updateHeader() {
        let y = collectionView.contentOffset.y + collectionView.contentInset.top
        let p = min(max(y / 40, 0), 1)
        let bg = min(max(y / 12, 0), 1)
        headerBackgroundView.alpha = bg
        headerHairline.alpha = bg
        guard !isSearching else { return }
        largeTitleLabel.alpha = 1 - p
        largeTitleLabel.transform = CGAffineTransform(translationX: 0, y: -8 * p)
        compactTitleLabel.alpha = p
    }

    @IBAction private func didTapRoom(_ sender: UIControl) {
        guard let new = InspirationIdea.Room(rawValue: sender.tag), new != room else { return }
        room = new
        DS.Haptic.selection()
        roomChips.forEach { $0.setChipSelected($0.tag == sender.tag, animated: true) }
        applyFilter(animated: true)
        scrollToTop()
    }

    /// Opens the feed with a filter (I2 tags).
    func applyTag(room newRoom: InspirationIdea.Room?, style: String?) {
        if let newRoom {
            room = newRoom
            roomChips.forEach { $0.setChipSelected($0.tag == newRoom.rawValue, animated: true) }
            if isSearching { endSearch(clear: true) } else { applyFilter(animated: true) }
        } else if let style {
            if !isSearching { beginSearch(focus: false) }
            searchField.text = style
            searchChanged()
        }
        scrollToTop()
    }

    private func scrollToTop() {
        collectionView.setContentOffset(CGPoint(x: 0, y: -collectionView.contentInset.top), animated: true)
    }

    // MARK: Search

    @IBAction private func didTapSearch(_ sender: Any) {
        beginSearch(focus: true)
    }

    @IBAction private func didTapCancelSearch(_ sender: Any) {
        endSearch(clear: true)
    }

    @IBAction private func didTapSuggestion(_ sender: UIControl) {
        DS.Haptic.selection()
        searchField.text = label(in: sender)?.text
        searchField.resignFirstResponder()
        searchChanged()
    }

    @objc private func searchChanged() {
        query = searchField.text ?? ""
        suggestionChips.forEach {
            $0.setChipSelected(label(in: $0)?.text?.lowercased() == query.lowercased(), animated: true)
        }
        applyFilter(animated: true)
    }

    private func beginSearch(focus: Bool) {
        guard !isSearching else { return }
        isSearching = true
        searchBarView.isHidden = false
        suggestionScrollView.isHidden = false
        searchButton.isUserInteractionEnabled = false
        suggestionScrollView.alpha = 0
        UIView.animate(withDuration: 0.25) {
            self.largeTitleLabel.alpha = 0
            self.compactTitleLabel.alpha = 0
            self.searchButton.alpha = 0
            self.searchBarView.alpha = 1
            self.roomScrollView.alpha = 0
            self.suggestionScrollView.alpha = 1
        } completion: { _ in
            if self.isSearching { self.searchButton.isHidden = true }
        }
        suggestionChips.sorted { $0.tag < $1.tag }.enumerated().forEach { i, chip in
            DS.Motion.enter(chip, delay: Double(i) * 0.03, dx: 30)
        }
        if focus { searchField.becomeFirstResponder() }
    }

    private func endSearch(clear: Bool) {
        isSearching = false
        searchField.resignFirstResponder()
        if clear {
            searchField.text = ""
            query = ""
            suggestionChips.forEach { $0.setChipSelected(false, animated: false) }
            applyFilter(animated: true)
        }
        searchButton.isHidden = false
        searchButton.isUserInteractionEnabled = true
        UIView.animate(withDuration: 0.25, animations: {
            self.searchButton.alpha = 1
            self.searchBarView.alpha = 0
            self.roomScrollView.alpha = 1
            self.suggestionScrollView.alpha = 0
        }, completion: { _ in
            self.searchBarView.isHidden = true
            self.suggestionScrollView.isHidden = true
        })
        UIView.animate(withDuration: 0.25) { self.updateHeader() }
    }

    // MARK: Saved / offline

    private func toggleSave(_ idea: InspirationIdea, cell: InspirationCardCell?) {
        let saved = IdeasStore.shared.toggle(idea)
        DS.Haptic.light()
        cell?.setSaved(saved, animated: true)
    }

    @objc private func savedIdeasChanged() {
        for case let cell as InspirationCardCell in collectionView.visibleCells {
            guard let ip = collectionView.indexPath(for: cell), let idea = shown[safe: ip.item] else { continue }
            cell.setSaved(IdeasStore.shared.isSaved(idea.id), animated: false)
        }
    }

    @objc private func networkChanged() {
        updateOfflineState(animated: true)
        applyFilter(animated: true)
    }

    private func updateOfflineState(animated: Bool) {
        let offline = !NetworkMonitor.shared.isOnline
        guard offline == offlineBannerView.isHidden else { return }
        offlineBannerView.isHidden = false
        let changes = { self.offlineBannerView.alpha = offline ? 1 : 0
            self.offlineBannerView.transform = offline ? .identity : CGAffineTransform(translationX: 0, y: -60)
            self.headerView.alpha = offline ? 0 : 1 }
        if offline {
            offlineBannerView.alpha = 0
            offlineBannerView.transform = CGAffineTransform(translationX: 0, y: -60)
        }
        let done = { (_: Bool) in self.offlineBannerView.isHidden = !offline }
        if animated {
            UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0,
                           animations: changes, completion: done)
        } else {
            changes(); done(true)
        }
    }

    // MARK: Detail

    private func openDetail(at indexPath: IndexPath) {
        guard let idea = shown[safe: indexPath.item] else { return }
        let cell = collectionView.cellForItem(at: indexPath) as? InspirationCardCell
        let detail = IdeaDetailViewController.make(idea: idea, image: cell?.image)
        detail.onTag = { [weak self] room, style in self?.applyTag(room: room, style: style) }
        transition.sourceView = { [weak self] in
            guard let self, let i = self.shown.firstIndex(of: idea),
                  let cell = self.collectionView.cellForItem(at: IndexPath(item: i, section: 0)) as? InspirationCardCell
            else { return nil }
            return cell.photoImageView
        }
        detail.modalPresentationStyle = .custom
        detail.transitioningDelegate = transition
        DS.Haptic.light()
        present(detail, animated: true)
    }

    private func label(in view: UIView) -> UILabel? {
        if let l = view as? UILabel { return l }
        for sub in view.subviews { if let l = label(in: sub) { return l } }
        return nil
    }
}

extension InspirationFeedViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        visibleCount
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: InspirationCardCell.reuseID, for: indexPath)
        guard let card = cell as? InspirationCardCell, let idea = shown[safe: indexPath.item] else { return cell }
        card.configure(idea: idea, saved: IdeasStore.shared.isSaved(idea.id))
        card.onBookmark = { [weak self, weak card] in self?.toggleSave(idea, cell: card) }
        card.onImageFailed = { [weak self] in self?.drop(idea) }
        return card
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        openDetail(at: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return }
        UIView.animate(withDuration: 0.15) { cell.transform = CGAffineTransform(scaleX: 0.97, y: 0.97) }
    }

    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return }
        UIView.animate(withDuration: 0.2) { cell.transform = .identity }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === collectionView else { return }
        updateHeader()
        loadMoreIfNeeded()
    }
}

extension InspirationFeedViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
