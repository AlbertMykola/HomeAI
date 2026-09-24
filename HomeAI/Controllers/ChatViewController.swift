import UIKit

private struct Defaults {
    struct Text {
        static let inputPlaceholder = "chat_input_placeholder".localized
        static let genericError     = "chat_error_generic".localized
    }
    struct Layout {
        /// Початкове значення constraint (відступ від низу view до низу контейнера).
        static let containerBottomDefault: CGFloat = 30
        /// Відступ першого рядка під прозорий navigation bar.
        static let tableTopExtra: CGFloat = 8
        /// Максимальна висота текстового поля (≈5 рядків).
        static let textViewMaxHeight: CGFloat = 120
        /// Зазор над полем вводу до останнього повідомлення.
        static let tableBottomGap: CGFloat = 12
        /// Чіпи-підказки: короткі затримки між стартами (анімації перекриваються — без «пауз» між елементами).
        static let suggestionChipInitialDelay: TimeInterval = 0.05
        static let suggestionChipStagger: TimeInterval = 0.07
        static let suggestionChipDuration: TimeInterval = 0.38
        /// Базовий зсув першого (найнижчого) чіпа — виїзд з-під зони вводу вгору.
        static let suggestionChipSlideY: CGFloat = 36
        /// Кожен наступний шар вище стартує ще нижче — візуальний «штабель» перед розкладкою.
        static let suggestionChipDepthStep: CGFloat = 18
        static let suggestionChipStartScale: CGFloat = 0.9
        /// Скільки «гасить» кожен рівень вище нижнього (нижній найнепрозоріший, верхні м’якші — глибина стеку).
        static let suggestionChipAlphaDropPerTier: CGFloat = 0.055
        static let suggestionChipMinAlpha: CGFloat = 0.78
    }
}

final class ChatViewController: UIViewController {

    private struct SavedNavigationBarAppearances {
        let standard: UINavigationBarAppearance
        let scrollEdge: UINavigationBarAppearance
        let compact: UINavigationBarAppearance
        let compactScrollEdge: UINavigationBarAppearance?

        init(bar: UINavigationBar) {
            standard = Self.copy(of: bar.standardAppearance)
            scrollEdge = Self.copy(of: bar.scrollEdgeAppearance ?? bar.standardAppearance)
            compact = Self.copy(of: bar.compactAppearance ?? bar.standardAppearance)
            compactScrollEdge = bar.compactScrollEdgeAppearance.map { Self.copy(of: $0) }
        }

        /// Знімок appearance через `NSCopying` (UIKit завжди повертає той самий підтип).
        private static func copy(of appearance: UINavigationBarAppearance) -> UINavigationBarAppearance {
            appearance.copy()
        }

        func restore(on bar: UINavigationBar) {
            bar.standardAppearance = standard
            bar.scrollEdgeAppearance = scrollEdge
            bar.compactAppearance = compact
            if #available(iOS 15.0, *) {
                bar.compactScrollEdgeAppearance = compactScrollEdge
            }
        }
    }

    // MARK: - Outlets

    @IBOutlet weak private var tableView: UITableView!
    @IBOutlet weak private var previewImageView: UIImageView!
    @IBOutlet weak private var gradientContainerView: UIView!
    @IBOutlet weak private var messageContainerView: UIView!
    @IBOutlet weak private var messageTextView: UITextView!
    @IBOutlet weak private var sendButtonView: UIView!
    @IBOutlet weak private var sendIconImageView: UIImageView!
    @IBOutlet weak private var messageContainerBottom: NSLayoutConstraint!

    @IBOutlet var sparklesCollectionImages: [UIImageView]!
    @IBOutlet var chatContainerViews: [UIView]!
    
    @IBOutlet var suggestionCollectionLabel: [UILabel]!
    
    
    // MARK: - State

    var assistantType: AssistantType = .interiorDesigner
    /// Якщо задано — одразу відправляється після відкриття чату (саджест).
    var initialMessage: String?

    private let chatService  = AssistantChatService()
    private var items:   [ChatItem]    = []
    private var history: [ChatMessage] = []
    private var isSending = false
    private var gradientConfigured = false
    /// Поточна висота клавіатури (0 коли схована). Зберігається щоб `viewDidLayoutSubviews` міг синхронізувати inset.
    private var currentKeyboardExtra: CGFloat = 0

    private weak var placeholderLabel: UILabel?
    private var placeholderTopConstraint: NSLayoutConstraint?
    private weak var suggestionChipsStackView: UIStackView?
    private var didRunSuggestionChipEntrance = false
    private var savedNavigationBarAppearances: SavedNavigationBarAppearances?
    /// Чи тримати скрол приклеєним до низу (нові повідомлення / клавіатура). Скидається при свайпі вгору.
    private var sticksToBottom = true
    private var isUserDraggingTable = false
    private var scrollToBottomWorkItem: DispatchWorkItem?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        previewImageView.image = UIImage(named: assistantType.backgroundImage)

        suggestionChipsStackView = chatContainerViews.first?.superview as? UIStackView

        setupTableView()
        setupInput()
        observeKeyboard()
        setupDismissKeyboardOnOutsideTap()
        seedInitialItems()
        setupQuickSuggestions()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if savedNavigationBarAppearances == nil, let nav = navigationController {
            savedNavigationBarAppearances = SavedNavigationBarAppearances(bar: nav.navigationBar)
        }
        applyTransparentNavigationBarForChat()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard isMovingFromParent else { return }
        if let nav = navigationController {
            savedNavigationBarAppearances?.restore(on: nav.navigationBar)
        }
        savedNavigationBarAppearances = nil
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.syncTableContentInsets(keyboardExtra: self.currentKeyboardExtra)
            self.applyScrollPositionForCurrentMode(animated: false)
            self.animateSuggestionChipsEntranceIfNeeded()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        sendButtonView.layer.cornerRadius = sendButtonView.bounds.width / 2

        syncInputVerticalAlignment()

        // Оновлюємо inset при кожному layout (може змінитись висота контейнера через зростання UITextView)
        syncTableContentInsets(keyboardExtra: currentKeyboardExtra)

        guard !gradientConfigured else { return }
        gradientContainerView.layoutIfNeeded()
        let b = gradientContainerView.bounds
        guard b.width > 1, b.height > 1 else { return }
        gradientConfigured = true

        gradientContainerView.backgroundColor = .clear
        gradientContainerView.setGradient(
            stops: [
                .init(percent: 0,   color: UIColor.systemBackground.withAlphaComponent(0)),
                .init(percent: 20,  color: UIColor.systemBackground.withAlphaComponent(0.5)),
                .init(percent: 100, color: UIColor.systemBackground.withAlphaComponent(1))
            ],
            direction: .vertical
        )
    }

    private func applyTransparentNavigationBarForChat() {
        guard let navBar = navigationController?.navigationBar else { return }
        navigationItem.title = nil
        navigationItem.largeTitleDisplayMode = .never

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear

        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
        if #available(iOS 15.0, *) {
            navBar.compactScrollEdgeAppearance = appearance
        }
        navBar.isTranslucent = true
        navBar.backgroundColor = .clear
        navBar.setBackgroundImage(UIImage(), for: .default)
        navBar.shadowImage = UIImage()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Setup

    private func setupTableView() {
        tableView.register(
            UINib(nibName: AssistentTableViewCell.reuseIdentifier, bundle: nil),
            forCellReuseIdentifier: AssistentTableViewCell.reuseIdentifier
        )
        tableView.register(
            UINib(nibName: AssistentMessageTableViewCell.reuseIdentifier, bundle: nil),
            forCellReuseIdentifier: AssistentMessageTableViewCell.reuseIdentifier
        )
        tableView.register(
            UINib(nibName: UserMessageTableViewCell.reuseIdentifier, bundle: nil),
            forCellReuseIdentifier: UserMessageTableViewCell.reuseIdentifier
        )
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 88
        tableView.keyboardDismissMode = .interactive
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.contentInset = .zero
        tableView.scrollIndicatorInsets = .zero
    }

    private func setupInput() {
        messageContainerView.layer.cornerRadius = 22
        messageContainerView.layer.borderWidth = 1
        messageContainerView.layer.borderColor = UIColor.separator.cgColor
        messageContainerView.backgroundColor = UIColor.secondarySystemBackground
        messageContainerView.clipsToBounds = true

        messageTextView.delegate = self
        messageTextView.font = UIFont.systemFont(ofSize: 14)
        messageTextView.backgroundColor = .clear
        messageTextView.isScrollEnabled = false
        messageTextView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        messageTextView.textContainer.lineFragmentPadding = 0
        messageTextView.returnKeyType = .default

        addPlaceholder()

        let tap = UITapGestureRecognizer(target: self, action: #selector(sendTapped))
        sendButtonView.addGestureRecognizer(tap)
        updateSendButtonEnabled()
    }

    private func syncInputVerticalAlignment() {
        guard messageTextView.bounds.height > 0 else { return }

        let font = messageTextView.font ?? UIFont.systemFont(ofSize: 14)
        let isMultiLine: Bool = {
            if messageTextView.text.contains("\n") { return true }
            let contentHeight = messageTextView.sizeThatFits(
                CGSize(width: messageTextView.bounds.width, height: .greatestFiniteMagnitude)
            ).height
            return contentHeight > font.lineHeight * 1.5
        }()

        let verticalInset: CGFloat
        if isMultiLine {
            verticalInset = 0
        } else {
            verticalInset = max(0, floor((messageTextView.bounds.height - font.lineHeight) / 2))
        }

        messageTextView.textContainerInset = UIEdgeInsets(
            top: verticalInset,
            left: 0,
            bottom: verticalInset,
            right: 0
        )
        placeholderTopConstraint?.constant = verticalInset
        placeholderLabel?.font = font
    }

    /// Чат ще без user-повідомлень і без префілу зі списку.
    private func canOfferQuickSuggestionChips() -> Bool {
        if let pre = initialMessage?.trimmingCharacters(in: .whitespacesAndNewlines), !pre.isEmpty {
            return false
        }
        return !history.contains { $0.role == .user }
    }

    private func isMessageInputEmpty() -> Bool {
        messageTextView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Саджести: немає тексту в полі, клавіатура схована, ще не було user-повідомлень.
    private func shouldShowQuickSuggestionChips() -> Bool {
        canOfferQuickSuggestionChips()
            && isMessageInputEmpty()
            && !messageTextView.isFirstResponder
    }

    private func updateSuggestionChipsVisibility(animated: Bool) {
        if shouldShowQuickSuggestionChips() {
            guard !areSuggestionChipsVisible else { return }
            showSuggestionChipsStackIfNeeded()
            presentSuggestionChipsRestingState()
            didRunSuggestionChipEntrance = true
        } else if areSuggestionChipsVisible {
            hideSuggestionChips(animated: animated)
        }
    }

    private func presentSuggestionChipsRestingState() {
        let texts = assistantType.chatSuggestions
        let count = min(chatContainerViews.count, texts.count)
        guard count > 0 else { return }

        let orderedBottomToTop = Array(chatContainerViews.prefix(count)).sorted { a, b in
            let fa = a.convert(a.bounds, to: view)
            let fb = b.convert(b.bounds, to: view)
            return fa.maxY > fb.maxY
        }

        for (tier, container) in orderedBottomToTop.enumerated() {
            container.isHidden = false
            container.isUserInteractionEnabled = true
            container.alpha = suggestionChipRestingAlpha(tierFromBottom: tier)
            container.transform = .identity
        }
    }

    private var areSuggestionChipsVisible: Bool {
        suggestionChipsStackView?.isHidden == false
    }

    private func hideSuggestionChips(animated: Bool) {
        chatContainerViews.forEach { container in
            container.isUserInteractionEnabled = false
        }
        suggestionChipsStackView?.isUserInteractionEnabled = false

        let finalizeHide = {
            self.chatContainerViews.forEach { container in
                container.alpha = 1
                container.transform = .identity
            }
            self.suggestionChipsStackView?.isHidden = true
        }

        guard animated, areSuggestionChipsVisible else {
            chatContainerViews.forEach {
                $0.alpha = 0
                $0.transform = .identity
            }
            finalizeHide()
            return
        }

        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            options: [.curveEaseIn],
            animations: {
                self.chatContainerViews.forEach {
                    $0.alpha = 0
                    $0.transform = CGAffineTransform(translationX: 0, y: 12)
                }
            },
            completion: { _ in finalizeHide() }
        )
    }

    private func showSuggestionChipsStackIfNeeded() {
        guard shouldShowQuickSuggestionChips() else {
            hideSuggestionChips(animated: false)
            return
        }

        suggestionChipsStackView?.isHidden = false
        suggestionChipsStackView?.isUserInteractionEnabled = true
    }

    private func setupQuickSuggestions() {
        let texts = assistantType.chatSuggestions
        let accent = assistantType.ringColor

        zip(suggestionCollectionLabel, texts).forEach { label, text in
            label.text = text
        }

        sparklesCollectionImages.forEach { $0.tintColor = accent }

        guard canOfferQuickSuggestionChips() else {
            hideSuggestionChips(animated: false)
            return
        }

        hideSuggestionChips(animated: false)

        let slideY = Defaults.Layout.suggestionChipSlideY
        for (idx, container) in chatContainerViews.enumerated() {
            if idx >= texts.count {
                container.isHidden = true
                container.isUserInteractionEnabled = false
                continue
            }
            container.isHidden = false
            container.tag = idx
            container.isUserInteractionEnabled = true
            container.alpha = 0
            container.transform = Self.suggestionChipHiddenTransform(slideY: slideY)

            container.gestureRecognizers?
                .filter { $0 is UITapGestureRecognizer }
                .forEach { container.removeGestureRecognizer($0) }
            let tap = UITapGestureRecognizer(target: self, action: #selector(suggestionChipTapped(_:)))
            container.addGestureRecognizer(tap)
        }
    }

    /// Чіпи з’являються знизу вгору: найнижчий (найближче до поля) першим; вищі стартують «глибше» в штабелі й м’якші за альфу — як у референсному відео.
    private func animateSuggestionChipsEntranceIfNeeded() {
        guard !didRunSuggestionChipEntrance else { return }

        guard shouldShowQuickSuggestionChips() else {
            didRunSuggestionChipEntrance = true
            return
        }

        didRunSuggestionChipEntrance = true
        showSuggestionChipsStackIfNeeded()

        let texts = assistantType.chatSuggestions
        let count = min(chatContainerViews.count, texts.count)
        guard count > 0 else { return }

        view.layoutIfNeeded()

        let candidates = Array(chatContainerViews.prefix(count))
        let orderedBottomToTop = candidates.sorted { a, b in
            let fa = a.convert(a.bounds, to: view)
            let fb = b.convert(b.bounds, to: view)
            return fa.maxY > fb.maxY
        }

        let baseSlide = Defaults.Layout.suggestionChipSlideY
        let depthStep = Defaults.Layout.suggestionChipDepthStep
        for (tier, container) in orderedBottomToTop.enumerated() {
            container.alpha = 0
            let slide = baseSlide + CGFloat(tier) * depthStep
            container.transform = Self.suggestionChipHiddenTransform(slideY: slide)
        }

        let stagger = Defaults.Layout.suggestionChipStagger
        let duration = Defaults.Layout.suggestionChipDuration
        let initialDelay = Defaults.Layout.suggestionChipInitialDelay

        for (tier, container) in orderedBottomToTop.enumerated() {
            let targetAlpha = suggestionChipRestingAlpha(tierFromBottom: tier)
            UIView.animate(
                withDuration: duration,
                delay: initialDelay + Double(tier) * stagger,
                usingSpringWithDamping: 0.86,
                initialSpringVelocity: 0.35,
                options: [.curveEaseOut, .allowUserInteraction],
                animations: {
                    container.alpha = targetAlpha
                    container.transform = .identity
                }
            )
        }
    }

    /// Нижній ряд найконтрастніший; вище — поступово легший (ефект «віддалення» під час руху вгору).
    private func suggestionChipRestingAlpha(tierFromBottom: Int) -> CGFloat {
        let raw = 1.0 - CGFloat(tierFromBottom) * Defaults.Layout.suggestionChipAlphaDropPerTier
        return max(Defaults.Layout.suggestionChipMinAlpha, raw)
    }

    private static func suggestionChipHiddenTransform(slideY: CGFloat) -> CGAffineTransform {
        let s = Defaults.Layout.suggestionChipStartScale
        return CGAffineTransform(translationX: 0, y: slideY).scaledBy(x: s, y: s)
    }

    private func dismissQuickSuggestionChipsIfNeeded() {
        guard areSuggestionChipsVisible else { return }
        hideSuggestionChips(animated: true)
    }

    @objc private func suggestionChipTapped(_ gesture: UITapGestureRecognizer) {
        guard shouldShowQuickSuggestionChips(), areSuggestionChipsVisible else { return }
        guard let idx = gesture.view?.tag else { return }
        let texts = assistantType.chatSuggestions
        guard texts.indices.contains(idx) else { return }
        sendMessage(texts[idx])
    }

    private func addPlaceholder() {
        let label = UILabel()
        label.text = Defaults.Text.inputPlaceholder
        label.font = messageTextView.font
        label.textColor = UIColor.placeholderText
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        messageTextView.addSubview(label)

        let top = label.topAnchor.constraint(equalTo: messageTextView.topAnchor)
        placeholderTopConstraint = top
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: messageTextView.leadingAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: messageTextView.trailingAnchor),
            top
        ])
        placeholderLabel = label
        syncInputVerticalAlignment()
    }

    private func seedInitialItems() {
        items   = [.header, .assistant(assistantType.chatGreeting)]
        history = [.init(role: .assistant, text: assistantType.chatGreeting)]
        tableView.reloadData()
        DispatchQueue.main.async { [weak self] in
            self?.applyScrollPositionForCurrentMode(animated: false)
        }

        if let msg = initialMessage, !msg.isEmpty {
            // Невелика затримка, щоб таблиця встигла відрендеритись
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.sendMessage(msg)
            }
        }
    }

    // MARK: - Keyboard

    private func observeKeyboard() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil
        )
    }

    @objc private func keyboardWillChangeFrame(_ note: Notification) {
        guard
            let endFrame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
            let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
            let curveRaw = note.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else { return }

        let keyboardH = max(0, view.bounds.height - endFrame.minY)
        currentKeyboardExtra = keyboardH

        let options = UIView.AnimationOptions(rawValue: curveRaw << 16)
        UIView.animate(withDuration: duration, delay: 0, options: options) {
            self.messageContainerBottom.constant = Defaults.Layout.containerBottomDefault + keyboardH
            self.syncTableContentInsets(keyboardExtra: keyboardH)
            self.view.layoutIfNeeded()
        } completion: { _ in
            if self.sticksToBottom {
                self.applyScrollPositionForCurrentMode(animated: true)
            }
            if keyboardH > 0 {
                self.updateSuggestionChipsVisibility(animated: true)
            }
        }
    }

    @objc private func keyboardWillHide(_ note: Notification) {
        let duration = (note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        currentKeyboardExtra = 0
        UIView.animate(withDuration: duration) {
            self.messageContainerBottom.constant = Defaults.Layout.containerBottomDefault
            self.syncTableContentInsets(keyboardExtra: 0)
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.updateSuggestionChipsVisibility(animated: true)
        }
    }

    private func tableTopContentInset() -> CGFloat {
        view.safeAreaInsets.top + Defaults.Layout.tableTopExtra
    }

    private func tableBottomContentInset(keyboardExtra: CGFloat) -> CGFloat {
        let containerH = messageContainerView.bounds.height
        guard containerH > 0 else { return 0 }
        return Defaults.Layout.containerBottomDefault
            + keyboardExtra
            + containerH
            + Defaults.Layout.tableBottomGap
    }

    /// Top — під navigation bar; bottom — над полем вводу / клавіатурою.
    private func syncTableContentInsets(keyboardExtra: CGFloat) {
        let newTop = tableTopContentInset()
        let newBottom = tableBottomContentInset(keyboardExtra: keyboardExtra)

        var inset = tableView.contentInset
        let oldBottom = inset.bottom
        let topChanged = abs(inset.top - newTop) > 0.5
        let bottomChanged = abs(oldBottom - newBottom) > 0.5
        guard topChanged || bottomChanged else { return }

        inset.top = newTop
        inset.bottom = newBottom
        tableView.contentInset = inset
        tableView.verticalScrollIndicatorInsets = inset

        if sticksToBottom {
            applyScrollPositionForCurrentMode(animated: false)
        } else if bottomChanged {
            let delta = newBottom - oldBottom
            tableView.contentOffset.y += delta
        }
    }

    private func minScrollOffsetY() -> CGFloat {
        -tableView.adjustedContentInset.top
    }

    private func maxScrollOffsetY() -> CGFloat {
        let inset = tableView.adjustedContentInset
        return max(
            minScrollOffsetY(),
            tableView.contentSize.height - tableView.bounds.height + inset.bottom
        )
    }

    /// Offset так, щоб низ останньої клітинки був над полем вводу (точніше за contentSize).
    private func bottomContentOffsetY() -> CGFloat {
        tableView.layoutIfNeeded()
        guard tableView.numberOfRows(inSection: 0) > 0 else {
            return minScrollOffsetY()
        }

        let lastRow = tableView.numberOfRows(inSection: 0) - 1
        let lastRect = tableView.rectForRow(at: IndexPath(row: lastRow, section: 0))
        let inset = tableView.adjustedContentInset
        let targetY = lastRect.maxY - tableView.bounds.height + inset.bottom
        return min(max(minScrollOffsetY(), targetY), maxScrollOffsetY())
    }

    private func isScrolledNearBottom(threshold: CGFloat = 80) -> Bool {
        tableView.layoutIfNeeded()
        return tableView.contentOffset.y >= bottomContentOffsetY() - threshold
    }

    private func applyScrollPositionForCurrentMode(animated: Bool) {
        guard sticksToBottom else { return }
        performScrollToBottom(animated: animated)
    }

    // MARK: - Send

    @objc private func sendTapped() {
        sendCurrentText()
    }

    private func sendCurrentText() {
        let text = messageTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard sendMessage(text) else { return }
        messageTextView.text = ""
        textViewDidChange(messageTextView)
    }

    @discardableResult
    private func sendMessage(_ text: String) -> Bool {
        guard !isSending else { return false }
        guard AdaptyService.shared.hasActiveSubscription else {
            AmplitudeService.shared.logEvent(.assistantChatMessage(
                assistant: assistantType.name,
                message: text,
                status: "blocked_paywall"
            ))
            NavigationManager.shared.showPremium(placement: Constants.Keys.optionPlacememt)
            return false
        }

        AmplitudeService.shared.logEvent(.assistantChatMessage(
            assistant: assistantType.name,
            message: text,
            status: "sent"
        ))

        sticksToBottom = true
        appendUser(text: text)
        appendTyping()

        isSending = true
        updateSendButtonEnabled()

        Task { [weak self] in
            guard let self else { return }
            do {
                let reply = try await chatService.send(
                    assistant: assistantType,
                    history: history,
                    userText: text
                )
                await MainActor.run {
                    self.replaceTypingWith(text: reply)
                    self.isSending = false
                    self.updateSendButtonEnabled()
                }
            } catch {
                await MainActor.run {
                    self.replaceTypingWith(text: Defaults.Text.genericError)
                    self.isSending = false
                    self.updateSendButtonEnabled()
                }
            }
        }
        return true
    }

    // MARK: - Items

    private func appendUser(text: String) {
        dismissQuickSuggestionChipsIfNeeded()
        history.append(.init(role: .user, text: text))
        items.append(.user(text))
        let indexPath = IndexPath(row: items.count - 1, section: 0)
        insertTableRows(at: [indexPath], scrollToBottom: true)
    }

    private func appendTyping() {
        items.append(.typing)
        let indexPath = IndexPath(row: items.count - 1, section: 0)
        insertTableRows(at: [indexPath], scrollToBottom: true)
    }

    private func replaceTypingWith(text: String) {
        if let idx = items.firstIndex(where: { if case .typing = $0 { return true } else { return false } }) {
            items[idx] = .assistant(text)
            history.append(.init(role: .assistant, text: text))
            let indexPath = IndexPath(row: idx, section: 0)
            CATransaction.begin()
            CATransaction.setCompletionBlock { [weak self] in
                self?.applyScrollPositionForCurrentMode(animated: true)
            }
            tableView.reloadRows(at: [indexPath], with: .fade)
            CATransaction.commit()
        } else {
            history.append(.init(role: .assistant, text: text))
            items.append(.assistant(text))
            let indexPath = IndexPath(row: items.count - 1, section: 0)
            insertTableRows(at: [indexPath], scrollToBottom: true)
        }
    }

    private func insertTableRows(at indexPaths: [IndexPath], scrollToBottom: Bool) {
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            guard let self, scrollToBottom, self.sticksToBottom else { return }
            self.applyScrollPositionForCurrentMode(animated: true)
        }
        tableView.insertRows(at: indexPaths, with: .fade)
        CATransaction.commit()
    }

    private func scrollToBottom(animated: Bool) {
        guard sticksToBottom, !items.isEmpty else { return }

        scrollToBottomWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.applyScrollPositionForCurrentMode(animated: animated)
        }
        scrollToBottomWorkItem = work
        DispatchQueue.main.async(execute: work)
    }

    private func performScrollToBottom(animated: Bool) {
        guard sticksToBottom, tableView.numberOfRows(inSection: 0) > 0 else { return }
        tableView.layoutIfNeeded()
        setTableContentOffset(bottomContentOffsetY(), animated: animated)
    }

    private func setTableContentOffset(_ targetY: CGFloat, animated: Bool) {
        let clampedY = min(max(targetY, minScrollOffsetY()), maxScrollOffsetY())
        tableView.setContentOffset(CGPoint(x: 0, y: clampedY), animated: animated)
    }

    // MARK: - Helpers

    private func updateSendButtonEnabled() {
        let hasText = !messageTextView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let active  = hasText && !isSending
        sendButtonView.alpha = active ? 1.0 : 0.4
        sendButtonView.isUserInteractionEnabled = active
    }

    private func setupDismissKeyboardOnOutsideTap() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboardFromBackgroundTap))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboardFromBackgroundTap() {
        guard messageTextView.isFirstResponder else { return }
        view.endEditing(true)
    }

    /// Не перехоплювати тап по полю вводу, send і видимих чіпах-підказках.
    private func touchFallsOnInputChrome(_ touch: UITouch) -> Bool {
        let point = touch.location(in: view)
        let chromeBars = [messageContainerView, sendButtonView].compactMap { $0 }
        for v in chromeBars {
            let rect = v.convert(v.bounds, to: view)
            if rect.contains(point) { return true }
        }
        if let stack = suggestionChipsStackView, !stack.isHidden {
            let rect = stack.convert(stack.bounds, to: view)
            if rect.contains(point) { return true }
        }
        return false
    }
}

// MARK: - UIGestureRecognizerDelegate

extension ChatViewController: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard messageTextView.isFirstResponder else { return false }
        return !touchFallsOnInputChrome(touch)
    }
}

// MARK: - UITableViewDataSource / Delegate

extension ChatViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard sticksToBottom, indexPath.row == items.count - 1 else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.sticksToBottom else { return }
            self.performScrollToBottom(animated: false)
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let item = items[safe: indexPath.row] else { return UITableViewCell() }
        switch item {
        case .header:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: AssistentTableViewCell.reuseIdentifier, for: indexPath
            ) as? AssistentTableViewCell ?? AssistentTableViewCell()
            cell.configure(with: assistantType)
            return cell

        case .assistant(let text):
            let cell = tableView.dequeueReusableCell(
                withIdentifier: AssistentMessageTableViewCell.reuseIdentifier, for: indexPath
            ) as? AssistentMessageTableViewCell ?? AssistentMessageTableViewCell()
            cell.configure(text: text, type: assistantType)
            return cell

        case .user(let text):
            let cell = tableView.dequeueReusableCell(
                withIdentifier: UserMessageTableViewCell.reuseIdentifier, for: indexPath
            ) as? UserMessageTableViewCell ?? UserMessageTableViewCell()
            cell.configure(text: text)
            return cell

        case .typing:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: AssistentMessageTableViewCell.reuseIdentifier, for: indexPath
            ) as? AssistentMessageTableViewCell ?? AssistentMessageTableViewCell()
            cell.configureTyping(type: assistantType)
            return cell
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isUserDraggingTable = true
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard isUserDraggingTable else { return }
        if !isScrolledNearBottom() {
            sticksToBottom = false
        }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            finishTableDragTracking()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        finishTableDragTracking()
    }

    private func finishTableDragTracking() {
        isUserDraggingTable = false
        updateSticksToBottomFromScrollPosition()
    }

    private func updateSticksToBottomFromScrollPosition() {
        sticksToBottom = isScrolledNearBottom()
    }
}

// MARK: - UITextViewDelegate

extension ChatViewController: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        // Placeholder
        placeholderLabel?.isHidden = !textView.text.isEmpty
        syncInputVerticalAlignment()

        // Auto-grow: вмикаємо scroll тільки коли перевищено maxHeight
        let fitsHeight = textView.sizeThatFits(
            CGSize(width: textView.bounds.width, height: .greatestFiniteMagnitude)
        ).height
        let shouldScroll = fitsHeight > Defaults.Layout.textViewMaxHeight
        if textView.isScrollEnabled != shouldScroll {
            textView.isScrollEnabled = shouldScroll
        }

        UIView.animate(withDuration: 0.15) {
            self.messageContainerView.setNeedsLayout()
            self.messageContainerView.layoutIfNeeded()
            self.view.layoutIfNeeded()
        } completion: { _ in
            if self.sticksToBottom {
                self.applyScrollPositionForCurrentMode(animated: false)
            }
        }

        updateSendButtonEnabled()
        updateSuggestionChipsVisibility(animated: true)
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        updateSuggestionChipsVisibility(animated: true)
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        updateSuggestionChipsVisibility(animated: true)
    }

    func textView(_ textView: UITextView,
                  shouldChangeTextIn range: NSRange,
                  replacementText text: String) -> Bool {
        // Return без Shift — відправка
        if text == "\n" {
            sendCurrentText()
            return false
        }
        return true
    }
}
