import UIKit
import StoreKit

/// A/06 · R1 Result + editor panel (versions, tools, ask for a change). Layout: Result.storyboard.
final class ResultViewController: UIViewController, DSWideLayoutFullWidth {

    // photo
    @IBOutlet private weak var photoView: UIView!
    /// Phones / portrait: photo above the panel. Wide landscape (iPhone Duo unfolded): photo left, panel right.
    /// Both sets live in Result.storyboard; only their priorities swap.
    @IBOutlet private var stackedConstraints: [NSLayoutConstraint]!
    @IBOutlet private var sideBySideConstraints: [NSLayoutConstraint]!
    /// Unfolded portrait (Figma Duo/P/06): result on the upper half, the editor panel from the hinge down.
    @IBOutlet private var portraitConstraints: [NSLayoutConstraint]!
    /// Phone constraints that the portrait arrangement replaces (photo bottom, panel stack top).
    @IBOutlet private var portraitReleasedConstraints: [NSLayoutConstraint]!
    /// Drag the design out (wide windows only: there both photos are visible, so hold-to-compare is off).
    private lazy var dragInteraction = UIDragInteraction(delegate: self)
    /// Wide landscape: the "before" photo above the tools in the side panel.
    @IBOutlet private weak var pairOriginalImageView: UIImageView!
    @IBOutlet private weak var beforeChipLabel: UILabel!
    @IBOutlet private weak var resultImageView: UIImageView!
    @IBOutlet private weak var likeIconView: UIImageView!
    @IBOutlet private weak var originalImageView: UIImageView!
    @IBOutlet private weak var revealBlurView: UIVisualEffectView!
    @IBOutlet private weak var revealBandView: UIView!
    @IBOutlet private weak var revealBandTopConstraint: NSLayoutConstraint!
    @IBOutlet private weak var editDimView: UIView!
    @IBOutlet private weak var editLoaderView: UIView!
    @IBOutlet private weak var editSpinner: UIActivityIndicatorView!
    @IBOutlet private weak var editLoaderLabel: UILabel!
    // nav + overlays
    @IBOutlet private weak var navView: UIView!
    @IBOutlet private weak var backButton: DSPressableControl!
    @IBOutlet private weak var downloadButton: DSPressableControl!
    @IBOutlet private weak var shareButton: DSPressableControl!
    @IBOutlet private weak var moreButton: UIButton!
    @IBOutlet private weak var compareView: DSPressableControl!
    @IBOutlet private weak var compareLabel: UILabel!
    @IBOutlet private weak var versionBadgeView: UIView!
    @IBOutlet private weak var versionBadgeLabel: UILabel!
    // panel
    @IBOutlet private weak var panelView: UIView!
    @IBOutlet private weak var panelStack: UIStackView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var likeButton: DSPressableControl!
    @IBOutlet private weak var dislikeButton: DSPressableControl!
    @IBOutlet private weak var versionsCollectionView: UICollectionView!
    @IBOutlet private weak var toolsScrollView: UIScrollView!
    @IBOutlet private var toolControls: [DSPressableControl]!
    @IBOutlet private var toolLabels: [UILabel]!
    @IBOutlet private weak var askBarView: UIView!
    @IBOutlet private weak var askControl: DSPressableControl!
    @IBOutlet private weak var askIconView: UIImageView!
    @IBOutlet private weak var askPlaceholderLabel: UILabel!
    @IBOutlet private weak var micButton: DSPressableControl!
    // R6 typing
    @IBOutlet private weak var askPanelView: UIView!
    @IBOutlet private weak var askPanelBottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var askTitleLabel: UILabel!
    @IBOutlet private weak var askCostLabel: UILabel!
    @IBOutlet private weak var suggestionScrollView: UIScrollView!
    @IBOutlet private var suggestionChips: [DSChipControl]!
    @IBOutlet private weak var askFieldView: UIView!
    @IBOutlet private weak var askTextView: UITextView!
    @IBOutlet private weak var askTextPlaceholder: UILabel!
    @IBOutlet private weak var askFieldHeightConstraint: NSLayoutConstraint!
    @IBOutlet private weak var sendButton: DSPrimaryButton!
    // R6 voice
    @IBOutlet private weak var voicePanelView: UIView!
    @IBOutlet private weak var listeningLabel: UILabel!
    @IBOutlet private weak var waveView: UIView!
    @IBOutlet private var waveBars: [UIView]!
    @IBOutlet private var waveLayoutConstraints: [NSLayoutConstraint]!
    private lazy var waveGeometry = StoryboardGeometry(constraints: waveLayoutConstraints)
    @IBOutlet private weak var transcriptLabel: UILabel!
    @IBOutlet private weak var voiceCancelButton: DSPressableControl!
    @IBOutlet private weak var voiceDoneButton: DSPrimaryButton!
    @IBOutlet private weak var voicePulseView: UIView!
    @IBOutlet private weak var voiceTextButton: DSPressableControl!

    // MARK: Input

    var docID: String!
    var initialImage: UIImage?
    var reveal = false

    // MARK: State

    private enum VersionItem {
        case original(path: String)
        case version(ImageDoc, number: Int)
        case again
    }

    private var project: DesignProject?
    private var versions: [ImageDoc] = []
    private var items: [VersionItem] = []
    private var currentDoc: ImageDoc? { versions.first { $0.id == docID } }
    private var originalImage: UIImage?
    private var editRunner: GenerationRunner?
    private var didRunEntrance = false
    private var liked = false
    private var referenceLayout: DSReferenceLayout!
    private var askKeyboardEndFrame: CGRect?
    private let speech = SpeechInput()
    private let amplitude = AmplitudeService.shared

    private enum Tool: Int { case style, paint, replace, remove, floor, furnish, layout }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        resultImageView.image = initialImage
        localize()
        configureVersions()
        configureCompareGestures()
        configureMoreMenu()
        configureAskPanel()
        reloadProject()
        if reveal { prepareReveal() }
        referenceLayout = DSReferenceLayout(root: view, prefix: "result.")
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(_:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    var dsUsesFullWidth: Bool { isWideWindow }

    private var isWideWindow: Bool {
        guard let window = navigationController?.view.window ?? view.window else { return false }
        let size = (navigationController?.view ?? view).bounds.size
        return DSWideLayout.isWide(size.width - window.safeAreaInsets.left - window.safeAreaInsets.right)
    }

    /// Wide landscape: photo left, panel right — unless the Duo is half folded (tabletop), then photo on the
    /// upper half and tools on the lower half.
    private var isSideBySide: Bool {
        let size = (navigationController?.view ?? view).bounds.size
        return isWideWindow && size.width > size.height && !isTabletop
    }
    private var isTabletop = false

    /// iPhone Duo hinge (iOS 27.1): half open = tabletop posture.
    private func observeHinge() {
        guard #available(iOS 27.1, *) else { return }
        let interaction = UIHingeInteraction { [weak self] _, update in
            guard let self else { return }
            let tabletop = update.hinge?.status == .partiallyOpen
            guard tabletop != self.isTabletop else { return }
            self.isTabletop = tabletop
            AmplitudeService.shared.logRedesignEvent("result_posture", properties: ["tabletop": tabletop])
            self.view.setNeedsLayout()
            UIView.animate(withDuration: DS.Motion.reduceMotion ? 0 : 0.45, delay: 0, usingSpringWithDamping: 0.9,
                           initialSpringVelocity: 0) { self.view.layoutIfNeeded() }
        }
        view.addInteraction(interaction)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let side = isSideBySide
        let low = UILayoutPriority(1), high = UILayoutPriority(999)
        // The photo is full-bleed black; next to the system rail (unfolded landscape) the app background shows.
        view.backgroundColor = side ? DS.Color.background : .black
        stackedConstraints.forEach { if $0.priority != (side ? low : high) { $0.priority = side ? low : high } }
        sideBySideConstraints.forEach { if $0.priority != (side ? high : low) { $0.priority = side ? high : low } }
        dragInteraction.isEnabled = side   // elsewhere a long press is hold-to-compare
        pairOriginalImageView.image = originalImageView.image
        pairOriginalImageView.isHidden = !side || originalImageView.image == nil
        beforeChipLabel.isHidden = pairOriginalImageView.isHidden
        let portrait = isWideWindow && !side
        portraitConstraints.forEach { $0.priority = portrait ? high : low }
        if !side { portraitReleasedConstraints.forEach { $0.priority = portrait ? low : high } }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let referenceLayout else { return }
        referenceLayout.apply(size: view.dsLayoutSize)
        fitAskPanelToKeyboard()
        textViewDidChange(askTextView)
        let scale = referenceLayout.scale
        if let layout = versionsCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.minimumLineSpacing = 12 * scale
            layout.sectionInset = UIEdgeInsets(top: 0, left: 20 * scale, bottom: 0, right: 20 * scale)
        }
        moreButton.imageView?.transform = CGAffineTransform(scaleX: scale, y: scale)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Let navigation commit its final window geometry before StoreKit creates a window.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            RatePrompt.requestAfterFirstGeneration(docID: self.docID, in: self.viewIfLoaded?.window?.windowScene)
        }
        guard !didRunEntrance else { return }
        didRunEntrance = true
        reveal ? runReveal() : runHints()
    }

    private func localize() {
        compareLabel.text = "Compare".localized
        compareView.accessibilityLabel = compareLabel.text
        askPlaceholderLabel.text = "Ask for a change…".localized
        editLoaderLabel.text = "Applying your change…".localized
        askTitleLabel.text = "Ask for a change".localized
        askTextPlaceholder.text = "Describe the change…".localized
        listeningLabel.text = "Listening…".localized
        let titles = ["Style", "Paint", "Replace", "Remove", "Floor", "Furnish", "Layout"]
        toolLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = titles[$0].localized }
        toolControls.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.accessibilityLabel = titles[$0].localized }
        let suggestions = ["Warmer light", "Add plants", "Darker floor", "Bigger rug", "Add art"]
        suggestionChips.sorted { $0.tag < $1.tag }.enumerated().forEach { index, chip in
            chip.subviews.first?.subviews.compactMap { $0 as? UILabel }.first?.text = suggestions[index].localized
        }
        editSpinner.color = .white
    }

    // MARK: Data

    private func reloadProject() {
        guard let found = ProjectStore.shared.project(containing: docID) else { return }
        project = found.project
        versions = found.versions
        items = []
        if let path = versions.first?.originalPath, FileManager.default.fileExists(atPath: path) {
            items.append(.original(path: path))
            if originalImage == nil {
                ThumbnailLoader.load(path: path, pointSize: CGSize(width: 1200, height: 1600)) { [weak self] image in
                    self?.originalImage = image
                    self?.originalImageView.image = image
                    self?.view.setNeedsLayout()
                }
            }
        }
        items += versions.enumerated().map { .version($1, number: $0 + 1) }
        items.append(.again)
        versionsCollectionView.reloadData()
        updateHeader()
        showCurrentVersionImage(animated: false)
    }

    private func versionNumber(of doc: ImageDoc) -> Int {
        (versions.firstIndex { $0.id == doc.id } ?? 0) + 1
    }

    private func updateHeader() {
        guard let project, let doc = currentDoc else { return }
        titleLabel.text = ProjectStore.shared.displayTitle(for: project, versions: versions)
        let n = versionNumber(of: doc)
        subtitleLabel.text = String(format: "Version %d · %@".localized, n, describe(doc))
        versionBadgeLabel.text = "V\(n)"
        versionBadgeView.accessibilityLabel = String(format: "Version %d".localized, n)
    }

    private func describe(_ doc: ImageDoc) -> String {
        if let note = ProjectStore.shared.note(for: doc.id) { return note }
        switch doc.designOption {
        case .interior?, .exterior?, .garden?, .floolPlan?, .reference?:
            return doc.savedDesignMode == .renovationDesign ? "More freedom".localized : "Keep structure".localized
        case .newWalls?: return String(format: "%@ walls".localized, doc.style ?? "")
        case .newFlooring?: return String(format: "%@ floor".localized, doc.style ?? "")
        case .replace?: return doc.objectToReplace.map { String(format: "Replaced with %@".localized, $0) } ?? "Replaced".localized
        case .delete?: return "Object removed".localized
        case .rearrange?: return "New layout".localized
        case .furnish?: return "Furnished".localized
        case nil: return ""
        }
    }

    private func showCurrentVersionImage(animated: Bool) {
        guard let doc = currentDoc else { return }
        let apply: (UIImage?) -> Void = { [weak self] image in
            guard let self, let image else { return }
            if animated {
                UIView.transition(with: self.resultImageView, duration: 0.25, options: .transitionCrossDissolve) {
                    self.resultImageView.image = image
                }
            } else {
                self.resultImageView.image = image
            }
        }
        if resultImageView.image == nil || animated {
            ThumbnailLoader.load(path: HistoryDocOpener.thumbnailPath(for: doc), pointSize: CGSize(width: 400, height: 600), completion: apply)
        }
        Task { @MainActor in
            if let full = try? await ImageHistoryService().loadImage(at: doc.storagePath), self.currentDoc?.id == doc.id {
                self.resultImageView.image = full
            }
        }
    }

    // MARK: Versions strip

    private func configureVersions() {

        versionsCollectionView.dataSource = self
        versionsCollectionView.delegate = self
    }

    private func select(doc: ImageDoc) {
        guard doc.id != docID else { return }
        docID = doc.id
        DS.Haptic.selection()
        versionsCollectionView.reloadData()
        updateHeader()
        showCurrentVersionImage(animated: true)
        liked = false
        updateLikeState()
    }

    // MARK: Original preview (hold photo) + comparison screen (tap)

    private func configureCompareGestures() {
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(handleHold(_:)))
        hold.minimumPressDuration = 0.12
        hold.delegate = self
        photoView.addGestureRecognizer(hold)
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapPhoto))
        tap.require(toFail: hold)
        tap.delegate = self
        photoView.addGestureRecognizer(tap)
        // Split View / iPhone Duo: drag the design out to Messages, Notes, Files…
        dragInteraction.isEnabled = false
        photoView.addInteraction(dragInteraction)
        observeHinge()
    }

    @objc private func handleHold(_ gesture: UILongPressGestureRecognizer) {
        guard originalImageView.image != nil, !isSideBySide else { return }
        switch gesture.state {
        case .began:
            DS.Haptic.light()
            UIView.animate(withDuration: 0.15) { self.originalImageView.alpha = 1 }
        case .ended, .cancelled, .failed:
            UIView.animate(withDuration: 0.2) { self.originalImageView.alpha = 0 }
        default:
            break
        }
    }

    @objc private func didTapPhoto() {
        if !askPanelView.isHidden {
            askTextView.resignFirstResponder()
            return
        }
        showComparison()
    }

    @IBAction private func didTapCompare(_ sender: Any) {
        if !askPanelView.isHidden { dismissAsk() }
        showComparison()
    }

    private func showComparison() {
        guard presentedViewController == nil else { return }
        guard let after = resultImageView.image else { return }
        let compare = AppStoryboard.instantiate(CompareViewController.self)
        compare.beforeImage = originalImageView.image ?? after
        compare.afterImage = after
        compare.modalPresentationStyle = .fullScreen
        compare.modalTransitionStyle = .crossDissolve
        present(compare, animated: true)
    }

    // MARK: Nav actions

    @IBAction private func didTapBack(_ sender: Any) {
        if let nav = navigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    @IBAction private func didTapDownload(_ sender: Any) {
        guard let image = resultImageView.image else { return }
        PhotoSaver.save(image) { outcome in
            switch outcome {
            case .saved:
                DS.Haptic.success()
                DSToastView.show("Saved to Photos".localized, style: .success, action: "Open".localized) {
                    if let url = URL(string: "photos-redirect://") { UIApplication.shared.open(url) }
                }
            case .denied:
                DS.Haptic.warning()
                DSToastView.show("Can't save · allow Photos access".localized, style: .warning, symbol: "photo",
                                 action: "Settings".localized) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            case .failed:
                ErrorReporter.report(message: "save to Photos failed", operation: "image_save")
                DS.Haptic.error()
                DSToastView.show("Couldn't save the image".localized, style: .warning, symbol: "exclamationmark.triangle")
            }
        }
    }

    @IBAction private func didTapShare(_ sender: Any) {
        guard let after = resultImageView.image else { return }
        ShareSheetViewController.present(from: self, before: originalImageView.image, after: after)
    }

    private func configureMoreMenu() {
        moreButton.showsMenuAsPrimaryAction = true
        moreButton.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        moreButton.menu = UIMenu(children: [UIDeferredMenuElement.uncached { [weak self] completion in
            completion(self?.moreMenuActions() ?? [])
        }])
    }

    private func moreMenuActions() -> [UIMenuElement] {
        let regenerate = UIAction(title: "Regenerate".localized, image: UIImage(systemName: "arrow.clockwise")) { [weak self] _ in
            self?.regenerate()
        }
        let rename = UIAction(title: "Rename".localized, image: UIImage(systemName: "pencil")) { [weak self] _ in
            self?.renameProject()
        }
        let report = UIAction(title: "Report a problem".localized, image: UIImage(systemName: "flag")) { [weak self] _ in
            guard let self else { return }
            SupportMail.compose(from: self, subject: "Report a problem".localized,
                                body: "Design \(self.docID ?? "")")
        }
        let delete = UIAction(title: String(format: "Delete V%d".localized, currentDoc.map(versionNumber(of:)) ?? 1),
                              image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
            self?.confirmDeleteVersion()
        }
        return [UIMenu(options: .displayInline, children: [regenerate, rename]),
                UIMenu(options: .displayInline, children: [report, delete])]
    }

    private func renameProject() {
        let alert = UIAlertController(title: "Rename project".localized, message: nil, preferredStyle: .alert)
        alert.addTextField { [weak self] field in
            field.text = self?.titleLabel.text
            field.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel))
        alert.addAction(UIAlertAction(title: "Save".localized, style: .default) { [weak self, weak alert] _ in
            guard let self, let text = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespaces), !text.isEmpty else { return }
            ProjectStore.shared.rename(projectContaining: self.docID, to: text)
            self.reloadProject()
        })
        present(alert, animated: true)
    }

    private func confirmDeleteVersion() {
        guard let doc = currentDoc else { return }
        let n = versionNumber(of: doc)
        let alert = UIAlertController(title: String(format: "Delete V%d?".localized, n),
                                      message: "This version will be removed from the project.".localized,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete".localized, style: .destructive) { [weak self] _ in
            self?.deleteVersion(doc)
        })
        present(alert, animated: true)
    }

    private func deleteVersion(_ doc: ImageDoc) {
        let remaining = versions.filter { $0.id != doc.id }
        Task { @MainActor in
            do {
                try await ProjectStore.shared.deleteVersion(docID: doc.id)
            } catch {
                ErrorReporter.report(error, operation: "project_delete_version")
                DSToastView.show("Couldn't delete the version".localized, style: .warning, symbol: "exclamationmark.triangle")
                return
            }
            guard let next = remaining.last else {
                self.didTapBack(self)
                return
            }
            self.docID = next.id
            self.reloadProject()
            self.showCurrentVersionImage(animated: true)
            DSToastView.show("Version deleted".localized, style: .info, symbol: "trash")
        }
    }

    // MARK: Feedback

    @IBAction private func didTapLike(_ sender: Any) {
        liked.toggle()
        DS.Haptic.light()
        updateLikeState()
        amplitude.logRedesignEvent("result_like", properties: ["liked": liked])
    }

    private func updateLikeState() {
        likeIconView.image = liked ? UIImage(systemName: "hand.thumbsup.fill") : UIImage(named: "figma_like")
        likeButton.backgroundColor = liked ? DS.Color.limeSoft : DS.Color.surface
    }

    @IBAction private func didTapDislike(_ sender: Any) {
        DS.Haptic.light()
        DislikeSheetViewController.present(from: self) { [weak self] reasons, details, retry, free in
            guard let self else { return }
            self.amplitude.logRedesignEvent("result_dislike", properties: ["reasons": reasons.joined(separator: ","),
                                                                           "retry": retry])
            DSToastView.show("Thanks — that helps".localized, style: .success)
            if retry { self.regenerate(free: free) }
        }
    }

    // MARK: Tools

    @IBAction private func didTapTool(_ sender: UIControl) {
        guard let tool = Tool(rawValue: sender.tag), let image = resultImageView.image else { return }
        amplitude.logRedesignEvent("result_tool", properties: ["tool": "\(tool)"])
        switch tool {
        case .style:
            guard let doc = currentDoc else { return }
            ChangeStyleSheetViewController.present(from: self, option: doc.designOption ?? .interior,
                                                   current: doc.style) { [weak self] style, keep, strength in
                self?.restyle(style: style, keepStructure: keep, strength: strength)
            }
        case .paint, .replace, .remove:
            let onApply: (GemeniPromptManager, String) -> Void = { [weak self] manager, note in
                self?.runEdit(manager: manager, note: note)
            }
            let editor: MaskEditorViewController
            switch tool {
            case .paint: editor = PaintEditorViewController.make(image: image, original: originalImage, onApply: onApply)
            case .replace: editor = ReplaceEditorViewController.make(image: image, original: originalImage, onApply: onApply)
            default: editor = RemoveEditorViewController.make(image: image, original: originalImage, onApply: onApply)
            }
            present(editor, animated: true)
        case .floor, .furnish, .layout:
            // A/07 T5 Floor, T6 Furnish, T8 Layout in edit mode: the current version is the photo, Apply → new version.
            let session = WizardSession(option: tool == .floor ? .newFlooring : tool == .furnish ? .furnish : .rearrange)
            session.photo = image
            if let room = currentDoc?.savedInteriorRoomType { session.detectedPlace = .room(room) }
            session.onResultEdit = { [weak self] manager in
                guard let self else { return }
                if let doc = self.currentDoc, let room = doc.savedInteriorRoomType, tool != .furnish {
                    manager.updateRoom(room)
                }
                self.runEdit(manager: manager, note: nil)
            }
            NavigationManager.shared.pushWizardStep(ToolStepFactory.make(session: session))
        }
    }

    // MARK: Edits (new versions)

    private func regenerate(free: Bool = false) {
        guard let doc = currentDoc else { return }
        let base = originalImage ?? resultImageView.image
        guard let base else { return }
        let manager = HistoryDocOpener.restoredManager(for: doc, baseImage: base)
        runEdit(manager: manager, note: nil, free: free)
    }

    private func restyle(style: WizardSession.Style, keepStructure: Bool, strength: Int) {
        guard let first = versions.first, let base = originalImage ?? resultImageView.image else { return }
        let manager = HistoryDocOpener.restoredManager(for: first, baseImage: base)
        switch style {
        case .interior(let s): manager.updateStyle(.interior(s))
        case .exterior(let s): manager.updateStyle(.exterior(s))
        case .garden(let g): manager.updateStyle(.garden(g.name))
        case .custom(let text): manager.updateCustomPrompt(text)
        }
        manager.updateDesignMode(keepStructure ? .structuralPreservation : .renovationDesign)
        let strengthNote = ["Apply the new style subtly, keeping most existing finishes.", "",
                            "Apply the new style boldly with clearly different finishes and decor."][max(0, min(2, strength))]
        manager.updateExtraDetails(strengthNote)
        runEdit(manager: manager, note: String(format: "%@ style".localized, style.title))
    }

    private func runEdit(manager: GemeniPromptManager, note: String?, free: Bool = false) {
        guard AIPhotoConsent.hasConsent else {
            AIPhotoConsent.run(from: self) { [weak self] in self?.runEdit(manager: manager, note: note, free: free) }
            return
        }
        guard NetworkMonitor.shared.isOnline else {
            OfflineGate.run(from: self) { [weak self] in self?.runEdit(manager: manager, note: note, free: free) }
            return
        }
        if !free, GenerationAccess.evaluate() == .requiresSubscription {
            OutOfCreditsSheetViewController.present(from: self, photo: resultImageView.image) { [weak self] in
                self?.runEdit(manager: manager, note: note)
            }
            return
        }
        let runner = GenerationRunner(promptManager: manager, baseDocID: docID)
        editRunner = runner
        setEditing(true)
        runner.onStateChange = { [weak self] state in
            guard let self else { return }
            switch state {
            case .succeeded(let outcome):
                if let note { ProjectStore.shared.setNote(note, for: outcome.docID) }
                self.setEditing(false)
                self.applyNewVersion(outcome)
            case .failed(let failure):
                self.setEditing(false)
                DS.Haptic.error()
                if case .photoNotSuitable = failure {
                    DSToastView.show("That change didn't work on this photo".localized, style: .warning,
                                     symbol: "exclamationmark.triangle")
                } else {
                    DSToastView.show("Something went wrong. Your credit is back.".localized, style: .error,
                                     symbol: "exclamationmark.triangle", action: "Retry".localized) { [weak self] in
                        self?.runEdit(manager: manager, note: note, free: free)
                    }
                }
            case .blocked:
                self.setEditing(false)
                GenerationAccess.requestProcessingIfAllowed(presentingFrom: self)
            default:
                break
            }
        }
        runner.start()
    }

    private func setEditing(_ editing: Bool) {
        panelView.isUserInteractionEnabled = !editing
        navView.isUserInteractionEnabled = !editing
        editing ? editSpinner.startAnimating() : editSpinner.stopAnimating()
        UIView.animate(withDuration: 0.25) {
            self.editDimView.alpha = editing ? 1 : 0
            self.editLoaderView.alpha = editing ? 1 : 0
            self.panelStack.alpha = editing ? 0.5 : 1
        }
    }

    private func applyNewVersion(_ outcome: GenerationRunner.Outcome) {
        let previousID = docID
        docID = outcome.docID
        reloadProject()
        resultImageView.alpha = 0.3
        resultImageView.image = outcome.model.image
        UIView.animate(withDuration: 0.95, delay: 0.05, options: .curveEaseInOut) { self.resultImageView.alpha = 1 }
        DS.Motion.enter(versionBadgeView, delay: 0.1, scale: 0.5, duration: 0.4, pop: true)
        DS.Haptic.success()
        let n = currentDoc.map(versionNumber(of:)) ?? versions.count
        DSToastView.show(String(format: "Saved as Version %d".localized, n), style: .success, action: "Undo".localized) {
            [weak self] in
            guard let self, let previousID, let doc = self.versions.first(where: { $0.id == previousID }) else { return }
            self.select(doc: doc)
        }
        DispatchQueue.main.async {
            if let index = self.items.firstIndex(where: { if case .version(let d, _) = $0 { return d.id == outcome.docID }; return false }) {
                self.versionsCollectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: .centeredHorizontally, animated: true)
            }
        }
    }

    // MARK: R6 · Ask for a change (typing)

    private func configureAskPanel() {
        askTextView.delegate = self
        askTextView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        askTextView.isScrollEnabled = false
        updateSendState()
        let drag = UIPanGestureRecognizer(target: self, action: #selector(handleAskDismissDrag(_:)))
        drag.maximumNumberOfTouches = 1
        drag.delegate = self
        askPanelView.addGestureRecognizer(drag)
    }

    @IBAction private func didTapAsk(_ sender: Any) {
        showAskPanel()
    }

    private func showAskPanel(focusKeyboard: Bool = true) {
        updateAskCost()
        askPanelView.isHidden = false
        askPanelView.alpha = 0
        fitAskPanelToKeyboard()
        view.layoutIfNeeded()
        UIView.animate(withDuration: 0.2) { self.askPanelView.alpha = 1 }
        if focusKeyboard { askTextView.becomeFirstResponder() }
        suggestionChips.sorted { $0.tag < $1.tag }.enumerated().forEach { DS.Motion.enter($1, delay: Double($0) * 0.05, dx: 24) }
    }

    #if DEBUG
    func previewAskForQA() {
        loadViewIfNeeded()
        showAskPanel(focusKeyboard: false)
    }
    #endif

    @objc private func dismissAsk() {
        askTextView.resignFirstResponder()
        // A hardware keyboard can resign without a keyboard-frame notification.
        hideAskPanel()
    }

    @objc private func handleAskDismissDrag(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .ended else { return }
        let translation = gesture.translation(in: askPanelView)
        let velocity = gesture.velocity(in: askPanelView)
        let distance = 80 * OnboardingLayout(size: view.dsLayoutSize).scale
        // A deliberate slow downward drag should dismiss just as reliably as a quick swipe.
        if translation.y > distance || velocity.y > 650 { dismissAsk() }
    }

    private func hideAskPanel() {
        UIView.animate(withDuration: 0.2) { self.askPanelView.alpha = 0 } completion: { _ in
            if !self.askTextView.isFirstResponder { self.askPanelView.isHidden = true }
        }
    }

    private func updateAskCost() {
        if AdaptyService.shared.hasActiveSubscription {
            askCostLabel.text = "Unlimited with Pro".localized
        } else {
            askCostLabel.text = String(format: "1 credit · %d left".localized, FreeGenerationManager.shared.remainingFreeGenerations)
        }
    }

    @IBAction private func didTapSuggestion(_ sender: UIControl) {
        let chip = sender as? DSChipControl
        let text = chip?.subviews.first?.subviews.compactMap { $0 as? UILabel }.first?.text ?? ""
        DS.Haptic.selection()
        askTextView.text = askTextView.text.isEmpty ? text : askTextView.text + ", " + text.lowercased()
        textViewDidChange(askTextView)
    }

    @IBAction private func didTapSend(_ sender: Any) {
        let text = askTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let image = resultImageView.image, let doc = currentDoc else { return }
        DS.Haptic.medium()
        askTextView.resignFirstResponder()
        hideAskPanel()
        askTextView.text = ""
        textViewDidChange(askTextView)
        let manager = HistoryDocOpener.restoredManager(for: doc, baseImage: image)
        manager.updateFreeEditRequest(text)
        runEdit(manager: manager, note: "“\(text)”")
    }

    private func updateSendState() {
        let empty = askTextView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        sendButton.inactive = empty
        sendButton.isUserInteractionEnabled = !empty
        askTextPlaceholder.isHidden = !askTextView.text.isEmpty
    }

    @discardableResult private func fitAskPanelToKeyboard() -> CGFloat {
        let keyboard = askKeyboardEndFrame.map { view.convert($0, from: nil) }
        let overlap = keyboard.map { $0.height > 0 ? max(0, view.bounds.maxY - $0.minY) : 0 } ?? 0
        // The background reaches the window bottom; the storyboard keeps its
        // content inside the panel's safe area. Lift the whole panel above the keyboard.
        let offset = -overlap
        if abs(askPanelBottomConstraint.constant - offset) > 0.1 { askPanelBottomConstraint.constant = offset }
        return overlap
    }

    @objc private func keyboardWillChange(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double else { return }
        askKeyboardEndFrame = frame
        let overlap = fitAskPanelToKeyboard()
        let hiding = overlap == 0 && !askTextView.isFirstResponder
        UIView.animate(withDuration: max(duration, 0.25), delay: 0, options: [.curveEaseOut]) {
            self.view.layoutIfNeeded()
            if hiding { self.askPanelView.alpha = 0 }
        } completion: { _ in
            if hiding && !self.askTextView.isFirstResponder { self.askPanelView.isHidden = true }
        }
    }

    // MARK: R6 · voice

    @IBAction private func didTapMic(_ sender: Any) {
        speech.requestAccess { [weak self] granted in
            guard let self else { return }
            guard granted else {
                DSToastView.show("Microphone is off".localized, style: .warning, symbol: "mic.slash",
                                 action: "Settings".localized, light: true) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                self.showAskPanel()
                return
            }
            self.startVoice()
        }
    }

    private func startVoice() {
        transcriptLabel.text = ""
        buildWave()
        voicePanelView.isHidden = false
        voicePanelView.transform = CGAffineTransform(translationX: 0, y: voicePanelView.bounds.height)
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
            self.voicePanelView.transform = .identity
        }
        startPulse()
        speech.onText = { [weak self] text in self?.transcriptLabel.text = text }
        speech.onLevel = { [weak self] level in self?.updateWave(level: level) }
        speech.onSilenceTimeout = { [weak self] in self?.didTapVoiceDone(self as Any) }
        do {
            try speech.start()
        } catch {
            ErrorReporter.report(error, operation: "speech_start", details: .init(extra: ["screen": "result"]))
            hideVoice()
            DSToastView.show("Couldn't start listening".localized, style: .warning, symbol: "mic.slash")
        }
    }

    @IBAction private func didTapVoiceCancel(_ sender: Any) {
        speech.stop()
        hideVoice()
    }

    @IBAction private func didTapVoiceDone(_ sender: Any) {
        let text = transcriptLabel.text ?? ""
        speech.stop()
        hideVoice()
        askTextView.text = text
        textViewDidChange(askTextView)
        showAskPanel()
    }

    @IBAction private func didTapVoiceKeyboard(_ sender: Any) {
        didTapVoiceDone(sender)
    }

    private func hideVoice() {
        voicePulseView.layer.removeAllAnimations()
        UIView.animate(withDuration: 0.25) {
            self.voicePanelView.transform = CGAffineTransform(translationX: 0, y: self.voicePanelView.bounds.height)
        } completion: { _ in
            self.voicePanelView.isHidden = true
            self.voicePanelView.transform = .identity
        }
    }

    private func startPulse() {
        guard !DS.Motion.reduceMotion else { return }
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1
        scale.toValue = 1.12
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        let group = CAAnimationGroup()
        group.animations = [scale, fade]
        group.duration = 1.2
        group.repeatCount = .infinity
        voicePulseView.layer.add(group, forKey: "pulse")
    }

    private func buildWave() {
        waveBars.sort { $0.tag < $1.tag }
        for (i, bar) in waveBars.enumerated() {
            bar.backgroundColor = i < 14 ? DS.Color.limeBottom : UIColor(white: 0.85, alpha: 1)
            bar.layer.cornerRadius = 2
        }
    }

    private func updateWave(level: CGFloat) {
        for (i, bar) in waveBars.enumerated() {
            let jitter = CGFloat.random(in: 0.5...1)
            let h = max(6, min(44, 6 + level * 38 * jitter * (i % 3 == 0 ? 1 : 0.8)))
            UIView.animate(withDuration: 0.1) {
                self.waveGeometry.setFrame(bar, CGRect(x: CGFloat(i) * 8.3, y: (44 - h) / 2, width: 4, height: h))
                self.waveView.layoutIfNeeded()
            }
        }
    }

    // MARK: Motion

    private func prepareReveal() {
        revealBlurView.alpha = 1
        resultImageView.alpha = 0.7
        resultImageView.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
        navView.alpha = 0
        compareView.alpha = 0
        versionBadgeView.alpha = 0
        panelView.transform = CGAffineTransform(translationX: 0, y: 360)
    }

    /// Reveal (2.4 s) per dev notes; Reduce Motion → crossfade 0.3 s.
    private func runReveal() {
        if DS.Motion.reduceMotion {
            UIView.animate(withDuration: 0.3) {
                self.revealBlurView.alpha = 0
                self.resultImageView.alpha = 1
                self.resultImageView.transform = .identity
                self.navView.alpha = 1
                self.compareView.alpha = 1
                self.versionBadgeView.alpha = 1
                self.panelView.transform = .identity
            }
            return
        }
        UIView.animate(withDuration: 1.1, delay: 0.2, options: .curveEaseInOut) {
            self.revealBlurView.alpha = 0
            self.resultImageView.alpha = 1
        }
        UIView.animate(withDuration: 1.4, delay: 0.2, usingSpringWithDamping: 0.9, initialSpringVelocity: 0) {
            self.resultImageView.transform = .identity
        }
        revealBandView.alpha = 1
        revealBandTopConstraint.constant = -120
        photoView.layoutIfNeeded()
        UIView.animate(withDuration: 1.2, delay: 0.3, options: .curveEaseInOut) {
            self.revealBandTopConstraint.constant = self.photoView.bounds.height
            self.photoView.layoutIfNeeded()
        } completion: { _ in self.revealBandView.alpha = 0 }
        UIView.animate(withDuration: 0.4, delay: 0.8) { self.navView.alpha = 1 }
        let panel = DS.Motion.gentleSpring(duration: 0.7)
        panel.addAnimations { self.panelView.transform = .identity }
        panel.startAnimation(afterDelay: 0.9)
        panelStack.arrangedSubviews.enumerated().forEach { DS.Motion.enter($1, delay: 1.0 + Double($0) * 0.06, dy: 10) }
        DS.Motion.enter(compareView, delay: 1.4, scale: 0.6, duration: 0.4, pop: true)
        DS.Motion.enter(versionBadgeView, delay: 1.5, scale: 0.6, duration: 0.4, pop: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { DS.Haptic.success() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in self?.runHints() }
    }

    /// Compare action pulse (first open only) and the sparkle in "Ask for a change".
    private func runHints() {
        guard !DS.Motion.reduceMotion else { return }
        let key = "redesign_compare_hint_shown"
        if !UserDefaults.standard.bool(forKey: key) {
            UserDefaults.standard.set(true, forKey: key)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let v = self?.compareView else { return }
                UIView.animate(withDuration: 0.25, animations: { v.transform = CGAffineTransform(scaleX: 1.06, y: 1.06) }) { _ in
                    UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0) { v.transform = .identity }
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self] in
            guard let icon = self?.askIconView else { return }
            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0
            spin.toValue = Double.pi
            spin.duration = 0.6
            let pulse = CAKeyframeAnimation(keyPath: "transform.scale")
            pulse.values = [1, 1.3, 1]
            pulse.duration = 0.6
            icon.layer.add(spin, forKey: "spin")
            icon.layer.add(pulse, forKey: "pulse")
        }
    }
}

// MARK: - Versions collection

extension ResultViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Flow layout measures before the controller's didLayout callback. Cap to
        // its current viewport on that same pass, including the first resize.
        let scale = OnboardingLayout(size: view.dsLayoutSize).scale
        let section = (collectionViewLayout as? UICollectionViewFlowLayout)?.sectionInset ?? .zero
        let inset = collectionView.adjustedContentInset
        let availableHeight = max(1, collectionView.bounds.height - inset.top - inset.bottom - section.top - section.bottom)
        return CGSize(width: 56 * scale, height: min(74 * scale, availableHeight))
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ResultVersionCell.reuseID, for: indexPath)
        guard let cell = cell as? ResultVersionCell else { return cell }
        switch items[indexPath.item] {
        case .original(let path):
            cell.configure(title: "Original".localized, path: path, current: false)
        case .version(let doc, let number):
            cell.configure(title: "V\(number)", path: HistoryDocOpener.thumbnailPath(for: doc), current: doc.id == docID)
        case .again:
            cell.configureAgain(title: "Again".localized)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch items[indexPath.item] {
        case .original:
            DS.Haptic.light()
            UIView.animate(withDuration: 0.15) { self.originalImageView.alpha = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                UIView.animate(withDuration: 0.2) { self.originalImageView.alpha = 0 }
            }
        case .version(let doc, _):
            select(doc: doc)
        case .again:
            DS.Haptic.medium()
            regenerate()
        }
    }
}

extension ResultViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateSendState()
        let scale = max(0.1, referenceLayout?.scale ?? 1)
        let fitting = textView.sizeThatFits(CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude)).height + 12 * scale
        let height = min(max(52 * scale, fitting), 112 * scale)
        if abs(askFieldHeightConstraint.constant - height) > 0.1 { askFieldHeightConstraint.constant = height }
        textView.isScrollEnabled = fitting > 112 * scale
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            didTapSend(textView)
            return false
        }
        return (textView.text as NSString).replacingCharacters(in: range, with: text).count <= 300
    }
}

/// Request the system rating once, when the first successfully generated image is shown.
@MainActor
enum RatePrompt {
    private static let pendingKey = "redesign_first_generation_review_doc"
    private static let requestedKey = "redesign_first_generation_review_requested"
    static var storage: UserDefaults {
        #if DEBUG
        if AppQA.enabled { return UserDefaults(suiteName: "com.albert.apps.design.ai.qa.review")! }
        #endif
        return .standard
    }

    static func recordSuccessfulGeneration(docID: String, defaults: UserDefaults? = nil) {
        let defaults = defaults ?? storage
        guard !defaults.bool(forKey: requestedKey), defaults.string(forKey: pendingKey) == nil else { return }
        defaults.set(docID, forKey: pendingKey)
    }

    static func consumeRequest(for docID: String, defaults: UserDefaults? = nil) -> Bool {
        let defaults = defaults ?? storage
        guard !defaults.bool(forKey: requestedKey), defaults.string(forKey: pendingKey) == docID else { return false }
        defaults.set(true, forKey: requestedKey)
        defaults.removeObject(forKey: pendingKey)
        return true
    }

    static func requestAfterFirstGeneration(docID: String, in scene: UIWindowScene?) {
        guard let scene, scene.activationState == .foregroundActive,
              consumeRequest(for: docID) else { return }
        #if DEBUG
        if AppQA.enabled {
            AppQA.record("rating_prompt_requested", properties: [
                "doc_id": docID, "scene_bounds": "\(scene.coordinateSpace.bounds)",
                "screen_bounds": "\(scene.screen.bounds)", "scene_role": scene.session.role.rawValue
            ])
            guard ProcessInfo.processInfo.arguments.contains("--qa-system-review") else { return }
        }
        #endif
        if #available(iOS 18.0, *) {
            AppStore.requestReview(in: scene)
        } else {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
}

extension ResultViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let drag = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = drag.velocity(in: askPanelView)
        let movement = abs(velocity.x) + abs(velocity.y) > 10 ? velocity : drag.translation(in: askPanelView)
        return movement.y > abs(movement.x)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var current = touch.view
        while let view = current, view !== askPanelView {
            if view is UITextView || view is UIControl { return false }
            current = view.superview
        }
        return true
    }
}

extension ResultViewController: UIDragInteractionDelegate {
    func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: UIDragSession) -> [UIDragItem] {
        guard let image = resultImageView.image else { return [] }
        AmplitudeService.shared.logRedesignEvent("result_dragged", properties: [:])
        let item = UIDragItem(itemProvider: NSItemProvider(object: image))
        item.localObject = image
        return [item]
    }
}
