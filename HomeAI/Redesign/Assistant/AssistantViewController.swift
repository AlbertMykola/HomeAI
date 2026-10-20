import UIKit
import PhotosUI

/// A/09 · AI designer: A1 start (greeting + quick questions), A1 Attach, A2 typing / reply with idea cards.
/// Layout: Assistant.storyboard (+ AssistantUserCell / AssistantReplyCell / AssistantIdeaCell).
final class AssistantViewController: UIViewController {

    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var startScrollView: UIScrollView!
    @IBOutlet private weak var heroAvatarView: UIImageView!
    @IBOutlet private weak var greetingTitleLabel: UILabel!
    @IBOutlet private weak var greetingSubtitleLabel: UILabel!
    @IBOutlet private weak var tryAskingLabel: UILabel!
    @IBOutlet private var questionLabels: [UILabel]!
    @IBOutlet private var questionControls: [DSPressableControl]!
    @IBOutlet private weak var navView: UIView!
    @IBOutlet private weak var headerFadeView: UIView!
    @IBOutlet private weak var navTitleLabel: UILabel!
    @IBOutlet private weak var statusLabel: UILabel!
    @IBOutlet private weak var attachmentView: UIView!
    @IBOutlet private weak var attachmentImageView: UIImageView!
    @IBOutlet private weak var composerView: UIStackView!
    @IBOutlet private weak var composerBottomConstraint: NSLayoutConstraint!
    @IBOutlet private weak var fieldBox: UIView!
    @IBOutlet private weak var messageField: UITextField!
    @IBOutlet private weak var micButton: DSPressableControl!
    @IBOutlet private weak var micIconView: UIImageView!
    @IBOutlet private weak var sendButton: DSPrimaryButton!

    private let service = AssistantChatService()
    private let speech = SpeechInput()
    private var conversation = AssistantConversation()
    private var pendingImage: UIImage?
    private var isSending = false
    private var isListening = false
    private var didRunEntrance = false
    /// Messages already shown (no entrance animation when they come back on screen).
    private var presented = Set<String>()
    /// Reply that should type itself out on next display.
    private var revealID: String?

    static func make(conversation: AssistantConversation? = nil) -> AssistantViewController {
        let vc = AppStoryboard.instantiate(AssistantViewController.self)
        if let conversation { vc.conversation = conversation }
        return vc
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navTitleLabel.text = "AI designer".localized
        statusLabel.text = "Online".localized
        greetingTitleLabel.text = "Hi! I'm your AI designer".localized
        greetingSubtitleLabel.text = "Send a photo of your room or ask anything about colors, layout and furniture.".localized
        tryAskingLabel.text = "Try asking".localized
        sortedQuestionLabels.enumerated().forEach { $1.text = questions[$0] }
        messageField.placeholder = "Ask about your space…".localized
        messageField.delegate = self
        messageField.returnKeyType = .send
        messageField.addTarget(self, action: #selector(fieldChanged), for: .editingChanged)

        // Composer rides on the keyboard (layout guide isn't available in IB for iOS 15).
        composerBottomConstraint.isActive = false
        composerView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -4).isActive = true


        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 140
        tableView.keyboardDismissMode = .interactive
        tableView.contentInsetAdjustmentBehavior = .never
        presented = Set(conversation.messages.map(\.id))
        updateMode(animated: false)
        updateComposer()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        guard !didRunEntrance else { return }
        navView.alpha = 0
        composerView.alpha = 0
        if conversation.messages.isEmpty {
            heroAvatarView.alpha = 0
            greetingTitleLabel.alpha = 0
            greetingSubtitleLabel.alpha = 0
            tryAskingLabel.alpha = 0
            questionControls.forEach { $0.alpha = 0 }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isListening { stopListening(send: false) }
        AssistantStore.shared.save(conversation)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let metrics = OnboardingLayout(size: view.dsAdaptiveReferenceSize)
        let top = navView.frame.maxY + metrics.value(14)
        if tableView.contentInset.top != top {
            tableView.contentInset.top = top
            tableView.contentInset.bottom = metrics.value(12)
            scrollToBottom(animated: false)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didRunEntrance else { return }
        didRunEntrance = true
        runEntrance()
    }

    // MARK: Quick questions (personalised by the latest project)

    private var sortedQuestionLabels: [UILabel] { questionLabels.sorted { $0.tag < $1.tag } }

    private lazy var questions: [String] = {
        var list = ["What color goes with a grey sofa?", "How to make a small room feel bigger?",
                    "Ideas for a cozy bedroom", "Which rug size for my living room?"].map(\.localized)
        if let doc = ProjectStore.shared.allProjects().first?.versions.last, doc.savedInteriorRoomType != nil {
            let room = doc.projectTitle.lowercased()
            list[2] = String(format: "Ideas for a cozy %@".localized, room)
            if let style = doc.style, !style.isEmpty, style != "No Style", style != "Custom" {
                list[0] = String(format: "What decor suits a %@ %@?".localized, style.lowercased(), room)
            }
        }
        return list
    }()

    @IBAction private func didTapQuestion(_ sender: UIControl) {
        guard questions.indices.contains(sender.tag) else { return }
        send(text: questions[sender.tag], source: "suggestion")
    }

    // MARK: Entrance (Figma A/09 A1: nav fade · avatar pop 0.6 → 1 then floats ±5 pt / 2 s ·
    // title 110, subtitle 170, "Try asking" 230, questions 290 + 60 ms, composer 530 ms; y 12, 450 ms)

    private func runEntrance() {
        DS.Motion.animate(0.3) { self.navView.alpha = 1 }
        guard conversation.messages.isEmpty else {
            DS.Motion.enter(composerView, delay: 0.1, dy: 12)
            return
        }
        if !DS.Motion.reduceMotion {
            heroAvatarView.alpha = 0
            heroAvatarView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
            DS.Motion.animate(0.15, delay: 0.05) { self.heroAvatarView.alpha = 1 }
            DS.Motion.animate(0.4, delay: 0.05, timing: DS.Motion.easeOutBack, {
                self.heroAvatarView.transform = .identity
            }, completion: { [weak self] in self?.startAvatarFloat() })
        } else {
            DS.Motion.enter(heroAvatarView, delay: 0, duration: 0.2)
        }
        DS.Motion.enter(greetingTitleLabel, delay: 0.11, dy: 12)
        DS.Motion.enter(greetingSubtitleLabel, delay: 0.17, dy: 12)
        DS.Motion.enter(tryAskingLabel, delay: 0.23, dy: 12)
        questionControls.sorted { $0.tag < $1.tag }.enumerated().forEach {
            DS.Motion.enter($1, delay: 0.29 + 0.06 * Double($0), dy: 12)
        }
        DS.Motion.enter(composerView, delay: 0.53, dy: 12)
    }

    private func startAvatarFloat() {
        guard !DS.Motion.reduceMotion else { return }
        let float = CABasicAnimation(keyPath: "transform.translation.y")
        float.fromValue = 0
        float.toValue = -5
        float.duration = 1.0
        float.autoreverses = true
        float.repeatCount = .infinity
        float.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        float.beginTime = CACurrentMediaTime() + 0.35
        heroAvatarView.layer.add(float, forKey: "float")
    }

    // MARK: Mode (A1 start ↔ A2 chat)

    private func updateMode(animated: Bool) {
        let chatting = !conversation.messages.isEmpty
        guard startScrollView.isHidden != chatting || tableView.isHidden == chatting else { return }
        if !animated {
            startScrollView.isHidden = chatting
            tableView.isHidden = !chatting
            return
        }
        tableView.isHidden = false
        UIView.animate(withDuration: 0.25, animations: {
            self.startScrollView.alpha = chatting ? 0 : 1
            self.startScrollView.transform = chatting ? CGAffineTransform(translationX: 0, y: -24) : .identity
        }, completion: { _ in
            self.startScrollView.isHidden = chatting
            self.startScrollView.alpha = 1
            self.startScrollView.transform = .identity
        })
    }

    // MARK: Composer

    @objc private func fieldChanged() {
        updateComposer()
    }

    private func updateComposer() {
        let hasText = !(messageField.text ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        let canSend = (hasText || pendingImage != nil) && !isListening
        guard sendButton.isHidden == canSend else { return }
        UIView.performWithoutAnimation {
            sendButton.isHidden = !canSend
            micButton.isHidden = canSend
            fieldBox.layoutIfNeeded()
        }
        if canSend { InspirationCardCell.pop(sendButton) }
    }

    @IBAction private func didTapSend(_ sender: Any) {
        send(text: messageField.text ?? "", source: "typed")
    }

    @IBAction private func didTapAttach(_ sender: Any) {
        view.endEditing(true)
        AssistantAttachSheetViewController.present(from: self) { [weak self] source in
            switch source {
            case .camera: self?.openCamera()
            case .library: self?.openLibrary()
            case .projects:
                guard let self else { return }
                AssistantProjectPickerViewController.present(from: self) { [weak self] image in self?.attach(image) }
            }
        }
    }

    @IBAction private func didTapRemoveAttachment(_ sender: Any) {
        attach(nil)
    }

    private func attach(_ image: UIImage?) {
        pendingImage = image
        attachmentImageView.image = image
        if image != nil {
            attachmentView.isHidden = false
            DS.Motion.enter(attachmentView, delay: 0, scale: 0.8, duration: 0.35, pop: true)
        } else {
            UIView.animate(withDuration: 0.2, animations: { self.attachmentView.alpha = 0 }) { _ in
                self.attachmentView.isHidden = true
                self.attachmentView.alpha = 1
            }
        }
        updateComposer()
    }

    private func openCamera() {
        CameraViewController.requestAccess(from: self, onLibrary: { [weak self] in self?.openLibrary() }) { [weak self] granted in
            guard let self, granted else { return }
            let camera = AppStoryboard.instantiate(CameraViewController.self)
            camera.onCapture = { [weak self] image in self?.attach(image) }
            camera.modalPresentationStyle = .fullScreen
            self.present(camera, animated: true)
        }
    }

    private func openLibrary() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    // MARK: Voice (R6-style dictation into the field)

    @IBAction private func didTapMic(_ sender: Any) {
        if isListening { stopListening(send: true); return }
        speech.requestAccess { [weak self] granted in
            guard let self else { return }
            guard granted else {
                // A/12: "Microphone is off · Settings" and focus on the text field.
                DSToastView.show("Microphone is off".localized, style: .warning, symbol: "mic.slash",
                                 action: "Settings".localized) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
                self.messageField.becomeFirstResponder()
                return
            }
            self.startListening()
        }
    }

    private func startListening() {
        speech.onText = { [weak self] text in self?.messageField.text = text }
        speech.onSilenceTimeout = { [weak self] in self?.stopListening(send: true) }
        do {
            try speech.start()
        } catch {
            DSToastView.show("Couldn't start listening".localized, style: .warning, symbol: "mic.slash")
            return
        }
        isListening = true
        DS.Haptic.medium()
        micIconView.image = UIImage(systemName: "waveform")
        micButton.backgroundColor = DS.Color.lime
        fieldBox.layer.borderColor = DS.Color.lime.cgColor
        fieldBox.layer.borderWidth = 1.5
        messageField.placeholder = "Listening…".localized
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1
        pulse.toValue = 1.12
        pulse.duration = 0.6
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        micButton.layer.add(pulse, forKey: "pulse")
    }

    private func stopListening(send shouldSend: Bool) {
        speech.stop()
        isListening = false
        micButton.layer.removeAnimation(forKey: "pulse")
        micIconView.image = UIImage(systemName: "mic")
        micButton.backgroundColor = DS.Color.card
        fieldBox.layer.borderWidth = 0
        messageField.placeholder = "Ask about your space…".localized
        updateComposer()
        if shouldSend, !(messageField.text ?? "").isEmpty { send(text: messageField.text ?? "", source: "voice") }
    }

    // MARK: Sending

    private func send(text raw: String, source: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isSending, !text.isEmpty || pendingImage != nil else { return }
        if AssistantStore.requiresProForChat, !AdaptyService.shared.hasActiveSubscription {
            NavigationManager.shared.showPremium(placement: Constants.Keys.optionPlacememt)
            return
        }
        guard NetworkMonitor.shared.isOnline else {
            OfflineGate.run(from: self) { [weak self] in self?.send(text: raw, source: source) }
            return
        }
        AmplitudeService.shared.logRedesignEvent("assistant_message", properties: [
            "source": source, "has_photo": pendingImage != nil, "length": text.count
        ])
        DS.Haptic.light()
        var user = AssistantMessage(role: .user, text: text)
        if let image = pendingImage { user.imageFile = AssistantStore.shared.storeImage(image) }
        let image = pendingImage
        messageField.text = ""
        attach(nil)
        conversation.messages.append(user)
        request(for: user, image: image)
    }

    private func request(for user: AssistantMessage, image: UIImage?) {
        isSending = true
        let history = conversation.messages
            .filter { $0.state == .done && $0.id != user.id }
            .map { AssistantChatService.Turn(isUser: $0.role == .user, text: $0.text) }
        let typing = AssistantMessage(role: .assistant, text: "", state: .typing)
        conversation.messages.append(typing)
        updateMode(animated: true)
        reloadAndScroll()

        Task { [weak self] in
            guard let self else { return }
            do {
                let reply = try await self.service.send(systemPrompt: AssistantStore.systemPrompt, history: history,
                                                        userText: user.text, image: image)
                let parsed = AssistantStore.parse(reply)
                await MainActor.run { self.finish(typingID: typing.id, text: parsed.text, ideas: parsed.ideas) }
            } catch {
                await MainActor.run { self.fail(userID: user.id, typingID: typing.id) }
            }
        }
    }

    private func finish(typingID: String, text: String, ideas: [AssistantIdea]) {
        isSending = false
        guard let i = conversation.messages.firstIndex(where: { $0.id == typingID }) else { return }
        conversation.messages[i].text = text
        conversation.messages[i].ideas = ideas
        conversation.messages[i].state = .done
        revealID = typingID
        AssistantStore.shared.save(conversation)
        let ip = IndexPath(row: i, section: 0)
        if let cell = tableView.cellForRow(at: ip) as? AssistantReplyCell {
            configure(cell, at: ip)
            relayout()
        } else {
            reloadAndScroll()
        }
    }

    private func fail(userID: String, typingID: String) {
        isSending = false
        DS.Haptic.error()
        conversation.messages.removeAll { $0.id == typingID }
        if let i = conversation.messages.firstIndex(where: { $0.id == userID }) {
            conversation.messages[i].state = .failed
        }
        tableView.reloadData()
    }

    private func retry(_ messageID: String) {
        guard !isSending, let i = conversation.messages.firstIndex(where: { $0.id == messageID }) else { return }
        conversation.messages[i].state = .done
        let message = conversation.messages[i]
        tableView.reloadRows(at: [IndexPath(row: i, section: 0)], with: .none)
        request(for: message, image: AssistantStore.shared.image(named: message.imageFile))
    }

    // MARK: Ideas → G1 (1 credit)

    private func apply(_ idea: AssistantIdea, from replyID: String) {
        AmplitudeService.shared.logRedesignEvent("assistant_apply_idea", properties: ["style": idea.style])
        // The photo of the closest user message above this reply.
        let index = conversation.messages.firstIndex { $0.id == replyID } ?? conversation.messages.count
        let photo = conversation.messages[..<index].reversed().compactMap { AssistantStore.shared.image(named: $0.imageFile) }.first
        guard let photo else {
            // No room photo yet → wizard with this style (W3 skipped).
            NavigationManager.shared.startDesign(option: .interior) { session in
                session.presetStyle(idea.interiorStyle.map { .interior($0) } ?? .custom(idea.prompt))
            }
            return
        }
        guard NetworkMonitor.shared.isOnline else {
            OfflineGate.run(from: self) { [weak self] in self?.apply(idea, from: replyID) }
            return
        }
        let start = {
            let manager = GemeniPromptManager()
            manager.updateOption(.interior)
            manager.updateBaseImage(photo.normalizedForGeneration())
            manager.updateCustomPrompt(idea.prompt.isEmpty ? idea.title : idea.prompt)
            manager.updateDesignMode(.structuralPreservation)
            NavigationManager.shared.showGeneration(manager: manager, sourcePhoto: photo, styleTitle: idea.title)
        }
        switch GenerationAccess.evaluate() {
        case .allowed:
            DS.Haptic.medium()
            start()
        case .requiresSubscription:
            OutOfCreditsSheetViewController.present(from: self, photo: photo, onUnlocked: start)
        case .dailyLimitExceeded:
            GenerationAccess.requestProcessingIfAllowed(presentingFrom: self)
        }
    }

    // MARK: Nav

    @IBAction private func didTapBack(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction private func didTapHistory(_ sender: Any) {
        view.endEditing(true)
        AssistantStore.shared.save(conversation)
        AssistantHistoryViewController.present(from: self) { [weak self] picked in
            guard let self else { return }
            self.conversation = picked ?? AssistantConversation()
            self.presented = Set(self.conversation.messages.map(\.id))
            self.revealID = nil
            self.isSending = false
            self.tableView.reloadData()
            self.updateMode(animated: true)
            if self.conversation.messages.isEmpty { self.runEntrance() }
            self.scrollToBottom(animated: false)
        }
    }

    // MARK: Table helpers

    private func reloadAndScroll() {
        tableView.reloadData()
        tableView.layoutIfNeeded()
        scrollToBottom(animated: true)
    }

    private var isNearBottom: Bool {
        let bottom = tableView.contentSize.height + tableView.contentInset.bottom - tableView.bounds.height
        return tableView.contentOffset.y >= bottom - 80
    }

    /// Row grows while the answer types out; follow it only if the user is at the bottom.
    private func relayout() {
        let follow = isNearBottom
        UIView.performWithoutAnimation {
            tableView.beginUpdates()
            tableView.endUpdates()
        }
        if follow { scrollToBottom(animated: false) }
    }

    private func scrollToBottom(animated: Bool) {
        let rows = tableView.numberOfRows(inSection: 0)
        guard rows > 0 else { return }
        tableView.scrollToRow(at: IndexPath(row: rows - 1, section: 0), at: .bottom, animated: animated)
    }

    private func configure(_ cell: AssistantReplyCell, at indexPath: IndexPath) {
        let message = conversation.messages[indexPath.row]
        let reveal = revealID == message.id
        if reveal { revealID = nil }
        cell.onGrow = { [weak self] in self?.relayout() }
        cell.onApply = { [weak self] idea in self?.apply(idea, from: message.id) }
        cell.configure(message, reveal: reveal)
    }
}

extension AssistantViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        conversation.messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = conversation.messages[indexPath.row]
        switch message.role {
        case .user:
            let cell = tableView.dequeueReusableCell(withIdentifier: AssistantUserCell.reuseID, for: indexPath)
            (cell as? AssistantUserCell)?.configure(message, image: AssistantStore.shared.image(named: message.imageFile))
            (cell as? AssistantUserCell)?.onRetry = { [weak self] in self?.retry(message.id) }
            return cell
        case .assistant:
            let cell = tableView.dequeueReusableCell(withIdentifier: AssistantReplyCell.reuseID, for: indexPath)
            if let reply = cell as? AssistantReplyCell { configure(reply, at: indexPath) }
            return cell
        }
    }

    /// New bubbles: user slides up 12 pt + fade; assistant follows 110 ms later (450 ms, ease-out).
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let message = conversation.messages[indexPath.row]
        guard !presented.contains(message.id) else { return }
        presented.insert(message.id)
        DS.Motion.enter(cell.contentView, delay: message.role == .assistant ? 0.11 : 0, dy: 12)
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath,
                   point: CGPoint) -> UIContextMenuConfiguration? {
        let message = conversation.messages[indexPath.row]
        guard message.role == .assistant, message.state == .done, !message.text.isEmpty else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            UIMenu(children: [
                UIAction(title: "Copy".localized, image: UIImage(systemName: "doc.on.doc")) { _ in
                    UIPasteboard.general.string = message.text
                    DSToastView.show("Copied".localized, style: .success)
                },
                UIAction(title: "Share".localized, image: UIImage(systemName: "square.and.arrow.up")) { _ in
                    let vc = UIActivityViewController(activityItems: [message.text], applicationActivities: nil)
                    self?.present(vc, animated: true)
                }
            ])
        }
    }
}

extension AssistantViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        send(text: textField.text ?? "", source: "typed")
        return false
    }
}

extension AssistantViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            DispatchQueue.main.async { self?.attach(object as? UIImage) }
        }
    }
}
