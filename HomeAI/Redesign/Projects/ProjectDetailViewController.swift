import UIKit

/// A/10 · PR2 Project: A/B compare of any two versions (default Original vs current), versions timeline
/// (newest first, swipe to delete), Continue editing → R1, More (Rename, Duplicate, Share, Delete).
/// Layout: Projects.storyboard (+ ProjectVersionCell.xib).
final class ProjectDetailViewController: UIViewController {

    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var headerContainer: UIView!
    @IBOutlet private weak var compareView: UIView!
    @IBOutlet private weak var aImageView: UIImageView!
    @IBOutlet private weak var bImageView: UIImageView!
    @IBOutlet private weak var bClipView: UIView!
    @IBOutlet private weak var bClipWidthConstraint: NSLayoutConstraint!
    @IBOutlet private weak var dividerView: UIView!
    @IBOutlet private weak var handleView: UIView!
    @IBOutlet private weak var aLabel: UILabel!
    @IBOutlet private weak var bLabel: UILabel!
    @IBOutlet private weak var versionsTitleLabel: UILabel!
    @IBOutlet private weak var versionsHintLabel: UILabel!
    @IBOutlet private weak var navTitleLabel: UILabel!
    @IBOutlet private weak var navView: UIView!
    @IBOutlet private weak var moreButton: DSPressableControl!
    @IBOutlet private weak var continueButton: DSPrimaryButton!
    @IBOutlet private weak var continueLabel: UILabel!

    enum Item: Equatable {
        case version(ImageDoc, number: Int)
        case original(path: String, date: Date)

        static func == (l: Item, r: Item) -> Bool { l.key == r.key }

        var key: String {
            switch self {
            case .version(let doc, _): return doc.id
            case .original: return "original"
            }
        }

        var path: String {
            switch self {
            case .version(let doc, _): return doc.storagePath
            case .original(let path, _): return path
            }
        }

        var shortName: String {
            switch self {
            case .version(_, let n): return "V\(n)"
            case .original: return "Original".localized
            }
        }
    }

    private var projectID = ""
    private var lastDocID: String?
    var initialCover: UIImage?
    private var project: DesignProject?
    private var versions: [ImageDoc] = []
    private var items: [Item] = []
    /// [A, B]; a third pick replaces the oldest.
    private var picks: [Item] = []
    private var split: CGFloat = 0.5
    private var didRunEntrance = false

    static func make(projectID: String, lastDocID: String?) -> ProjectDetailViewController {
        let vc = AppStoryboard.instantiate(ProjectDetailViewController.self)
        vc.projectID = projectID
        vc.lastDocID = lastDocID
        return vc
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        versionsTitleLabel.text = "Versions".localized
        versionsHintLabel.text = "Pick two to compare".localized
        continueLabel.text = "Continue editing".localized
        headerContainer.removeFromSuperview()
        headerContainer.translatesAutoresizingMaskIntoConstraints = true

        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 76
        tableView.contentInset.bottom = 120
        bImageView.image = initialCover
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleCompare(_:)))
        compareView.addGestureRecognizer(pan)
        compareView.isAccessibilityElement = true
        compareView.accessibilityTraits = .adjustable
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: .projectsDidChange, object: nil)
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        if !didRunEntrance {
            tableView.alpha = 0
            continueButton.alpha = 0
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let width = tableView.bounds.width
        // A table header is measured before UIKit lays out its detached hierarchy.
        (headerContainer as? DSAdaptiveRootView)?.applyMetrics(size: view.dsLayoutSize)
        let size = headerContainer.systemLayoutSizeFitting(CGSize(width: width, height: 0),
                                                           withHorizontalFittingPriority: .required,
                                                           verticalFittingPriority: .fittingSizeLevel)
        if tableView.tableHeaderView == nil || headerContainer.frame.size != CGSize(width: width, height: size.height) {
            headerContainer.frame = CGRect(x: 0, y: 0, width: width, height: size.height)
            tableView.tableHeaderView = headerContainer
        }
        applySplit()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didRunEntrance else { return }
        didRunEntrance = true
        tableView.alpha = 1
        // Figma A/10 PR2: compare, then the timeline 60 ms later (y 12, 450 ms); CTA from below, shimmer at 1.6 s.
        DS.Motion.enter(compareView, delay: 0, dy: 12)
        DS.Motion.enter(versionsTitleLabel.superview, delay: 0.06, dy: 12)
        tableView.visibleCells.enumerated().forEach { DS.Motion.enter($1, delay: 0.11 + 0.06 * Double($0), dy: 12) }
        DS.Motion.enter(continueButton, delay: 0.3, dy: 24, spring: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in self?.continueButton.runShimmer() }
    }

    // MARK: Data

    @objc private func reload() {
        let all = ProjectStore.shared.allProjects()
        let match = all.first { $0.project.id == projectID }
            ?? lastDocID.flatMap { id in all.first { $0.project.versionIDs.contains(id) } }
        guard let match else {
            navigationController?.popViewController(animated: true)
            return
        }
        project = match.project
        projectID = match.project.id
        versions = match.versions
        lastDocID = versions.last?.id
        navTitleLabel.text = ProjectStore.shared.displayTitle(for: match.project, versions: match.versions)
        var list: [Item] = versions.enumerated().reversed().map { .version($1, number: $0 + 1) }
        if let first = versions.first, let path = first.originalPath, FileManager.default.fileExists(atPath: path) {
            list.append(.original(path: path, date: first.createdAt))
        }
        items = list
        picks = picks.filter { list.contains($0) }
        if picks.count < 2 {
            // Default: Original (or the oldest version) vs current.
            let a = list.last, b = list.first
            picks = [a, b].compactMap { $0 }
            if picks.count == 2, picks[0] == picks[1] { picks = [picks[0]] }
        }
        tableView.reloadData()
        loadCompareImages(animated: false)
    }

    private func slot(for item: Item) -> String? {
        guard let i = picks.firstIndex(of: item) else { return nil }
        return i == 0 ? "A" : "B"
    }

    private func loadCompareImages(animated: Bool) {
        aLabel.text = picks.first.map { "A · \($0.shortName)" }
        bLabel.text = picks.count > 1 ? "B · \(picks[1].shortName)" : nil
        bLabel.superview?.isHidden = picks.count < 2
        let paths = picks.map(\.path)
        DispatchQueue.global(qos: .userInitiated).async {
            let images = paths.map { UIImage(contentsOfFile: $0) }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let apply = {
                    self.aImageView.image = images.first ?? nil
                    self.bImageView.image = images.count > 1 ? images[1] : (images.first ?? nil)
                }
                animated ? UIView.transition(with: self.compareView, duration: 0.3, options: .transitionCrossDissolve,
                                             animations: apply) : apply()
            }
        }
    }

    // MARK: Compare slider (B on the right of the divider)

    @objc private func handleCompare(_ pan: UIPanGestureRecognizer) {
        let x = pan.location(in: compareView).x
        split = min(max(x / max(view.dsLayoutSize.width - 40, 1), 0.04), 0.96)
        if pan.state == .ended { UIAccessibility.post(notification: .layoutChanged, argument: nil) }
        applySplit()
        if pan.state == .began { DS.Haptic.selection() }
    }

    private func applySplit() {
        // The header lives in tableHeaderView, so use the known width (screen − 2 × 20) rather than bounds.
        let width = view.dsLayoutSize.width - 40
        bClipWidthConstraint.constant = width * (1 - split)
        compareView.accessibilityLabel = String(format: "Compare %@ and %@".localized, aLabel.text ?? "", bLabel.text ?? "")
    }

    // MARK: Picking A / B

    private func pick(_ item: Item) {
        guard !picks.contains(item) else { return }
        DS.Haptic.selection()
        if picks.count >= 2 { picks.removeFirst() }
        picks.append(item)
        for cell in tableView.visibleCells.compactMap({ $0 as? ProjectVersionCell }) {
            guard let ip = tableView.indexPath(for: cell) else { continue }
            let it = items[ip.row]
            cell.setSlot(slot(for: it), animated: it == item)
        }
        loadCompareImages(animated: true)
    }

    // MARK: Actions

    @IBAction private func didTapBack(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction private func didTapContinue(_ sender: Any) {
        guard let doc = versions.last else { return }
        NavigationManager.shared.showResult(docID: doc.id, image: nil, reveal: false)
    }

    @IBAction private func didTapMore(_ sender: Any) {
        guard let project else { return }
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Rename".localized, style: .default) { [weak self] _ in self?.rename() })
        sheet.addAction(UIAlertAction(title: "Duplicate".localized, style: .default) { [weak self] _ in
            guard let self else { return }
            ProjectStore.shared.duplicate(project: project, versions: self.versions)
            DSToastView.show("Project duplicated".localized, style: .success)
        })
        sheet.addAction(UIAlertAction(title: "Share".localized, style: .default) { [weak self] _ in
            guard let self, let image = self.versions.last.flatMap({ UIImage(contentsOfFile: $0.storagePath) }) else { return }
            let vc = UIActivityViewController(activityItems: [image], applicationActivities: nil)
            vc.popoverPresentationController?.sourceView = self.moreButton
            self.present(vc, animated: true)
        })
        sheet.addAction(UIAlertAction(title: "Delete project".localized, style: .destructive) { [weak self] _ in
            self?.confirmDeleteProject()
        })
        sheet.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel))
        sheet.popoverPresentationController?.sourceView = moreButton
        present(sheet, animated: true)
    }

    private func rename() {
        guard let project, let first = versions.first else { return }
        let alert = UIAlertController(title: "Rename project".localized, message: nil, preferredStyle: .alert)
        alert.addTextField { $0.text = self.navTitleLabel.text; $0.clearButtonMode = .whileEditing }
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel))
        alert.addAction(UIAlertAction(title: "Save".localized, style: .default) { _ in
            let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces) ?? ""
            guard !text.isEmpty else { return }
            ProjectStore.shared.rename(projectID: project.id, firstDocID: first.id, to: text)
        })
        present(alert, animated: true)
    }

    private func confirmDeleteProject() {
        guard let project else { return }
        let sheet = UIAlertController(title: "Delete this project?".localized,
                                      message: "All versions will be removed from this device. This can't be undone.".localized,
                                      preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Delete".localized, style: .destructive) { [weak self] _ in
            Task { @MainActor in
                try? await ProjectStore.shared.deleteProject(id: project.id, fallbackDocID: project.versionIDs.first ?? "")
                DSToastView.show("Project deleted".localized, style: .success)
                self?.navigationController?.popViewController(animated: true)
            }
        })
        sheet.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel))
        sheet.popoverPresentationController?.sourceView = moreButton
        present(sheet, animated: true)
    }

    private func subtitle(for item: Item) -> String {
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        switch item {
        case .version(let doc, _):
            let kind = doc.designOption?.title ?? "Design".localized
            return "\(kind) · \(doc.createdAt.projectRelativeString) \(formatter.string(from: doc.createdAt))"
        case .original(_, let date):
            return "\("Uploaded".localized) · \(date.projectRelativeString) \(formatter.string(from: date))"
        }
    }

    private func title(for item: Item) -> String {
        switch item {
        case .version(let doc, let n):
            let what = ProjectStore.shared.note(for: doc.id)
                ?? doc.style.flatMap { $0.isEmpty || $0 == "No Style" || $0 == "Custom" ? nil : $0 }
                ?? doc.projectTitle
            return "V\(n) · \(what)"
        case .original:
            return "\("Original".localized) · \("Your photo".localized)"
        }
    }
}

extension ProjectDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ProjectVersionCell.reuseID, for: indexPath)
        let item = items[indexPath.row]
        let thumbPath: String
        switch item {
        case .version(let doc, _): thumbPath = HistoryDocOpener.thumbnailPath(for: doc)
        case .original(let path, _): thumbPath = path
        }
        (cell as? ProjectVersionCell)?.configure(title: title(for: item), subtitle: subtitle(for: item),
                                                 thumbPath: thumbPath, slot: slot(for: item))
        (cell as? ProjectVersionCell)?.onSlot = { [weak self] in self?.pick(item) }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        pick(items[indexPath.row])
    }

    /// Swipe left → Delete (not the Original).
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard case .version(let doc, _) = items[indexPath.row] else { return nil }
        let delete = UIContextualAction(style: .destructive, title: "Delete".localized) { [weak self] _, _, done in
            Task { @MainActor in
                do {
                    try await ProjectStore.shared.deleteVersion(docID: doc.id, inProject: self?.projectID)
                    done(true)
                } catch {
                    done(false)
                }
            }
        }
        delete.image = UIImage(systemName: "trash")
        return UISwipeActionsConfiguration(actions: [delete])
    }
}

/// PR2 version row: thumb 52, "V3 · Sage walls", "Paint · Today 14:20", compare slot (empty / A black / B lime).
/// Layout: ProjectVersionCell.xib.
final class ProjectVersionCell: DSAdaptiveTableViewCell {
    static let reuseID = "ProjectVersionCell"

    @IBOutlet private weak var boxView: UIView!
    @IBOutlet private weak var thumbImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var slotControl: DSPressableControl!
    @IBOutlet private weak var slotLabel: UILabel!

    var onSlot: (() -> Void)?
    private var path: String?

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        backgroundColor = .clear
    }

    func configure(title: String, subtitle: String, thumbPath: String, slot: String?) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        path = thumbPath
        thumbImageView.image = nil
        let side = OnboardingLayout(size: dsAdaptiveReferenceSize).value(52)
        ThumbnailLoader.load(path: thumbPath, pointSize: CGSize(width: side, height: side)) { [weak self] image in
            guard self?.path == thumbPath else { return }
            self?.thumbImageView.image = image
        }
        setSlot(slot, animated: false)
    }

    func setSlot(_ slot: String?, animated: Bool) {
        let changes = {
            self.boxView.backgroundColor = slot == nil ? DS.Color.surface : DS.Color.limeSoft
            self.boxView.layer.borderWidth = slot == nil ? 0 : 1.5
            self.boxView.layer.borderColor = DS.Color.lime.cgColor
            self.slotLabel.text = slot
            self.slotLabel.textColor = slot == "A" ? DS.Color.background : .black
            self.slotControl.backgroundColor = slot == "A" ? DS.Color.textPrimary : (slot == "B" ? DS.Color.lime : .clear)
            self.slotControl.layer.borderWidth = slot == nil ? 1.5 : 0
            self.slotControl.layer.borderColor = UIColor(hex: "C7C7CC").cgColor
        }
        accessibilityTraits = slot == nil ? .button : [.button, .selected]
        animated ? UIView.animate(withDuration: 0.25, animations: changes) : changes()
        if animated, slot != nil, !DS.Motion.reduceMotion { InspirationCardCell.pop(slotControl) }
    }

    @IBAction private func didTapSlot(_ sender: Any) {
        onSlot?()
    }
}
