import UIKit

/// A/09 · A1 Attach: Take a photo / Choose from library / From my projects (sheet, rows stagger 50 ms).
/// Layout: AssistantAttachSheetViewController.xib.
final class AssistantAttachSheetViewController: UIViewController {

    enum Source: Int { case camera, library, projects }

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private var optionLabels: [UILabel]!
    @IBOutlet private var optionRows: [DSPressableControl]!
    @IBOutlet private weak var projectsHintLabel: UILabel!

    private var onPick: ((Source) -> Void)?

    static func present(from presenter: UIViewController, onPick: @escaping (Source) -> Void) {
        let vc = AssistantAttachSheetViewController(nibName: "AssistantAttachSheetViewController", bundle: .main)
        vc.onPick = onPick
        DSSheet.present(vc, from: presenter, height: 330)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "Add a photo".localized
        subtitleLabel.text = "Show me the room you want to change".localized
        let titles = ["Take a photo", "Choose from library", "From my projects"]
        optionLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = titles[$0].localized }
        projectsHintLabel.text = "Use a room you already redesigned".localized
        optionRows.forEach { $0.alpha = 0 }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        optionRows.sorted { $0.tag < $1.tag }.enumerated().forEach {
            DS.Motion.enter($1, delay: 0.05 * Double($0), dy: 10)
        }
    }

    @IBAction private func didTapOption(_ sender: UIControl) {
        guard let source = Source(rawValue: sender.tag) else { return }
        let onPick = self.onPick
        dismiss(animated: true) { onPick?(source) }
    }

    @IBAction private func didTapClose(_ sender: Any) {
        dismiss(animated: true)
    }
}

/// A/09 History: previous conversations, newest first; swipe to delete. Layout: AssistantHistoryViewController.xib.
final class AssistantHistoryViewController: UIViewController {

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var emptyLabel: UILabel!

    private var items: [AssistantConversation] = []
    private var onSelect: ((AssistantConversation?) -> Void)?

    /// `nil` → new chat.
    static func present(from presenter: UIViewController, onSelect: @escaping (AssistantConversation?) -> Void) {
        let vc = AssistantHistoryViewController(nibName: "AssistantHistoryViewController", bundle: .main)
        vc.onSelect = onSelect
        DSSheet.present(vc, from: presenter)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "History".localized
        items = AssistantStore.shared.conversations()
        emptyLabel.text = "No conversations yet".localized
        emptyLabel.isHidden = !items.isEmpty
        tableView.register(UINib(nibName: "AssistantHistoryCell", bundle: nil),
                           forCellReuseIdentifier: AssistantHistoryCell.reuseID)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 72
    }

    @IBAction private func didTapNewChat(_ sender: Any) {
        let onSelect = self.onSelect
        dismiss(animated: true) { onSelect?(nil) }
    }
}

extension AssistantHistoryViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { items.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AssistantHistoryCell.reuseID, for: indexPath)
        (cell as? AssistantHistoryCell)?.configure(items[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = items[indexPath.row]
        let onSelect = self.onSelect
        DS.Haptic.selection()
        dismiss(animated: true) { onSelect?(item) }
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "Delete".localized) { [weak self] _, _, done in
            guard let self else { return done(false) }
            AssistantStore.shared.delete(self.items[indexPath.row])
            self.items.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            self.emptyLabel.isHidden = !self.items.isEmpty
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }
}

/// History row. Layout: AssistantHistoryCell.xib.
final class AssistantHistoryCell: UITableViewCell {
    static let reuseID = "AssistantHistoryCell"

    @IBOutlet private weak var thumbImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        backgroundColor = .clear
    }

    func configure(_ conversation: AssistantConversation) {
        titleLabel.text = conversation.title
        subtitleLabel.text = conversation.updatedAt.projectRelativeString
        let file = conversation.messages.compactMap(\.imageFile).last
        thumbImageView.image = AssistantStore.shared.image(named: file) ?? UIImage(named: "clay_assistant")
        thumbImageView.contentMode = file == nil ? .scaleAspectFit : .scaleAspectFill
    }
}

/// "From my projects": latest version of each project (PR1 grid in selection mode).
/// Layout: AssistantProjectPickerViewController.xib.
final class AssistantProjectPickerViewController: UIViewController {

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var collectionView: UICollectionView!
    @IBOutlet private weak var emptyLabel: UILabel!

    private var projects: [(project: DesignProject, versions: [ImageDoc])] = []
    private var onPick: ((UIImage) -> Void)?

    static func present(from presenter: UIViewController, onPick: @escaping (UIImage) -> Void) {
        let vc = AssistantProjectPickerViewController(nibName: "AssistantProjectPickerViewController", bundle: .main)
        vc.onPick = onPick
        DSSheet.present(vc, from: presenter, large: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "From my projects".localized
        emptyLabel.text = "No projects yet".localized
        projects = ProjectStore.shared.allProjects()
        emptyLabel.isHidden = !projects.isEmpty
        collectionView.register(UINib(nibName: "HomeProjectCell", bundle: nil), forCellWithReuseIdentifier: "HomeProjectCell")
        collectionView.dataSource = self
        collectionView.delegate = self
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        let w = floor((collectionView.bounds.width - 40 - 13) / 2)
        if layout.itemSize.width != w {
            layout.itemSize = CGSize(width: w, height: w + 54)
            layout.invalidateLayout()
        }
    }

    @IBAction private func didTapClose(_ sender: Any) {
        dismiss(animated: true)
    }
}

extension AssistantProjectPickerViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { projects.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "HomeProjectCell", for: indexPath)
        let project = projects[indexPath.item]
        (cell as? HomeProjectCell)?.configure(project: project.project, versions: project.versions)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let doc = projects[indexPath.item].versions.last else { return }
        DS.Haptic.selection()
        Task { @MainActor [weak self] in
            guard let image = try? await ImageHistoryService().loadImage(at: doc.storagePath) else {
                DSToastView.show("Couldn't open this design".localized, style: .warning)
                return
            }
            let onPick = self?.onPick
            self?.dismiss(animated: true) { onPick?(image) }
        }
    }
}
