//
//  PromptViewController.swift
//  HomeAI
//
//  Created by Mykola Albert on 16.12.2025.
//

import UIKit

private struct Defaults {
    struct Layout {
        static let tableBaseBottomInset: CGFloat = 100
        static let suggestionsHideOffset: CGFloat = 12
    }

    struct Text {
        static let headline = "Enter Custom Promt".localized
        static let placeholder = "Describe your design style idea...".localized
        static let clear = "Clear".localized
        static let examplePrompt = "Example Promt".localized
        static let next = "Next".localized
        
        // Метод для отримання промптів залежно від DesignOption
        static func promptList(for option: DesignOption) -> [String] {
            switch option {
            case .interior, .reference, .replace, .delete, .newWalls, .newFlooring,
                 .rearrange, .furnish, .floolPlan:
                return interiorPrompts
            case .exterior:
                return exteriorPrompts
            case .garden:
                return gardenPrompts
            }
        }
        
        // Interior prompts (також для reference та replace)
        private static let interiorPrompts = [
            "A calm interior with soft daylight, light walls, natural textures, simple furniture forms, cozy seating, subtle shadows, balanced composition, realistic materials, high detail, photorealistic render".localized,
            "A warm living space with evening lighting, layered lamps, textured fabrics, wooden surfaces, comfortable furniture arrangement, intimate atmosphere, realistic lighting, cinematic mood".localized,
            "A compact interior with smart layout, multifunctional furniture, light color palette, mirrors to enhance space, clean surfaces, practical design, realistic proportions".localized,
            "A spacious interior with high ceilings, large windows, flowing curtains, airy atmosphere, minimal decor, natural color harmony, soft light diffusion, wide-angle view".localized,
            "A cozy home interior with tactile materials, rounded furniture shapes, warm tones, ambient lighting, plants integrated into the space, lived-in feeling, photorealistic details".localized,
            "A refined interior with contrast between light and dark surfaces, elegant furniture, subtle metallic accents, controlled lighting, depth and shadows, realistic textures".localized,
            "A functional interior focused on comfort, ergonomic furniture placement, clear zoning, neutral tones with warm accents, natural and artificial light balance".localized,
            "An artistic interior with expressive lighting, sculptural furniture pieces, textured walls, layered materials, visual depth, mood-driven atmosphere".localized,
            "A modern residential interior with clean geometry, large open space, smooth surfaces, soft indirect lighting, minimal accessories, high realism".localized,
            "A welcoming interior with warm color palette, soft textiles, diffused daylight, balanced composition, cozy and comfortable mood, realistic home environment".localized
        ]
        
        // Exterior prompts
        private static let exteriorPrompts = [
            "Exterior view of a residential building with clear architectural structure, natural daylight, and realistic materials".localized,
            "House exterior with balanced proportions, well-defined facade elements, and soft natural lighting".localized,
            "Building exterior design featuring large windows, accurate scale, and detailed surface textures".localized,
            "Exterior visualization of a private house with realistic shadows, clean composition, and landscaped surroundings".localized,
            "Residential exterior showing material contrast, depth, and harmony with the environment".localized,
            "Architectural exterior rendering with neutral colors, realistic lighting, and high level of detail".localized,
            "Exterior view of a house with integrated outdoor space, natural light, and realistic environment".localized,
            "Building facade visualization focusing on geometry, depth, and material accuracy".localized,
            "Exterior design of a residential property with clear lines, natural proportions, and daylight conditions".localized,
            "Realistic exterior rendering of a building with attention to lighting, textures, and spatial balance".localized
        ]
        
        // Garden prompts
        private static let gardenPrompts = [
            "Garden exterior with well-planned pathways, natural greenery, and balanced outdoor composition".localized,
            "Outdoor garden area featuring landscaped plants, clear zoning, and natural daylight".localized,
            "Garden design with integrated seating areas, realistic vegetation, and harmonious proportions".localized,
            "Private garden visualization with natural materials, soft lighting, and detailed greenery".localized,
            "Garden space with defined walkways, layered planting, and realistic outdoor textures".localized,
            "Exterior garden view showing depth, natural shadows, and a calm atmosphere".localized,
            "Landscaped garden area with attention to scale, plant diversity, and spatial balance".localized,
            "Garden visualization with natural light, well-maintained greenery, and clear composition".localized,
            "Outdoor garden environment with realistic vegetation density and natural color balance".localized,
            "Garden design focusing on functionality, comfort, and harmony with the surroundings".localized
        ]
    }
}

class PromptViewController: UIViewController {

    @IBOutlet weak private var tableView: UITableView!
    @IBOutlet weak private var textView: UITextView!
    @IBOutlet weak private var clearButtton: UIButton!
    @IBOutlet weak private var headlineLabel: UILabel!
    
    @IBOutlet weak private var nextButton: UIButton!
    
    var promptManager: GemeniPromptManager?
    var onSelectPrompt: ((String) -> Void)?
    var onCancelPrompt: (() -> Void)?
    var showSuggestions: Bool = true // Чи показувати список саджестів
    var initialPrompt: String? // Початковий текст промпту для редагування
    
    private var didCompletePrompt = false
    
    private var promptList: [String] {
        let option = promptManager?.designOption ?? .interior
        return Defaults.Text.promptList(for: option)
    }
    
    private lazy var placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = Defaults.Text.placeholder
        label.textColor = UIColor.placeholderText
        label.font = UIFont.systemFont(ofSize: 16)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    
    private var selectedPromptIndex: Int?
    private var isKeyboardVisible = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
        observeKeyboard()
        setupDismissKeyboardOnOutsideTap()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if placeholderLabel.superview == nil {
            setupPlaceholder()
        }
        
        // Оновлюємо placeholder та кнопку після layout (якщо текст вже встановлено)
        updatePlaceholderVisibility()
        updateNextButtonState()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        focusTextViewIfNeeded()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isBeingDismissed, !didCompletePrompt else { return }
        onCancelPrompt?()
    }
    
    private func configure() {
        navigationItem.title = nil
        
        // Приховуємо список саджестів, якщо showSuggestions = false
        if showSuggestions {
            headlineLabel?.text = Defaults.Text.examplePrompt
        } else {
            headlineLabel?.text = Defaults.Text.headline
            tableView?.isHidden = true
        }
        headlineLabel?.isHidden = false
        
        guard let tableView = tableView else { return }
        tableView.register(UINib(nibName: "SuggestionTableViewCell", bundle: nil), forCellReuseIdentifier: "SuggestionTableViewCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.keyboardDismissMode = .interactive
        tableView.tintColor = .label
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: Defaults.Layout.tableBaseBottomInset, right: 0)
        tableView.verticalScrollIndicatorInsets.bottom = Defaults.Layout.tableBaseBottomInset
        updateSuggestionsVisibility(animated: false)
        
        guard let textView = textView else { return }
        textView.layer.cornerRadius = 12
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.separator.cgColor
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.delegate = self
        
        // Встановлюємо початковий текст, якщо він є
        if let initialPrompt = initialPrompt, !initialPrompt.isEmpty {
            textView.text = initialPrompt
        } else {
            textView.text = ""
        }
        
        clearButtton?.setTitle(Defaults.Text.clear, for: .normal)
        nextButton?.setTitle(Defaults.Text.next, for: .normal)
        nextButton.cornerRadius = nextButton.frame.height / 2
        
        updatePlaceholderVisibility()
        updateNextButtonState()
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done".localized, style: .done, target: self, action: #selector(doneTapped))
    }
    
    private func focusTextViewIfNeeded() {
        guard let textView else { return }
        DispatchQueue.main.async {
            textView.becomeFirstResponder()
        }
    }
    
    private func observeKeyboard() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillChangeFrame(_ note: Notification) {
        guard
            let endFrame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
            let duration = note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
            let curveRaw = note.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else { return }
        
        let screenHeight = view.window?.bounds.height ?? UIScreen.main.bounds.height
        let keyboardVisible = endFrame.minY < screenHeight - 1
        guard keyboardVisible != isKeyboardVisible else { return }
        isKeyboardVisible = keyboardVisible
        
        let options = UIView.AnimationOptions(rawValue: curveRaw << 16)
        updateSuggestionsVisibility(animated: true, duration: duration, options: options)
    }
    
    private var suggestionsViews: [UIView] {
        guard showSuggestions else { return [] }
        return [headlineLabel, tableView].compactMap { $0 }
    }
    
    private func updateSuggestionsVisibility(
        animated: Bool,
        duration: TimeInterval = 0.25,
        options: UIView.AnimationOptions = [.curveEaseInOut]
    ) {
        guard showSuggestions else {
            tableView?.isHidden = true
            headlineLabel?.isHidden = false
            headlineLabel?.alpha = 1
            headlineLabel?.transform = .identity
            return
        }
        
        let shouldShow = !isKeyboardVisible
        let views = suggestionsViews
        let hiddenTransform = CGAffineTransform(translationX: 0, y: Defaults.Layout.suggestionsHideOffset)
        
        if shouldShow {
            views.forEach { $0.isHidden = false }
        }
        
        let applyState = {
            views.forEach { view in
                view.alpha = shouldShow ? 1 : 0
                view.transform = shouldShow ? .identity : hiddenTransform
                view.isUserInteractionEnabled = shouldShow
            }
        }
        
        guard animated else {
            applyState()
            if !shouldShow {
                views.forEach { $0.isHidden = true }
            }
            return
        }
        
        if shouldShow {
            views.forEach {
                $0.alpha = 0
                $0.transform = hiddenTransform
            }
        }
        
        UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
            applyState()
            self.view.layoutIfNeeded()
        }, completion: { _ in
            if !shouldShow {
                views.forEach { $0.isHidden = true }
            }
        })
    }
    
    private func setupDismissKeyboardOnOutsideTap() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboardFromBackgroundTap))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }
    
    @objc private func dismissKeyboardFromBackgroundTap() {
        guard textView?.isFirstResponder == true else { return }
        view.endEditing(true)
    }
    
    private func setupPlaceholder() {
        guard let textView = textView else { return }
        
        textView.addSubview(placeholderLabel)
        
        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: textView.textContainerInset.top),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: textView.textContainerInset.left + 5),
            placeholderLabel.trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: -(textView.textContainerInset.right + 5)),
        ])
        
        updatePlaceholderVisibility()
    }
    
    private func updatePlaceholderVisibility() {
        let isEmpty = textView?.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
        placeholderLabel.isHidden = !isEmpty
        updateNextButtonState()
    }
    
    private func updateNextButtonState() {
        let hasText = !(textView?.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        nextButton?.isEnabled = hasText
        nextButton?.alpha = hasText ? 1.0 : 0.5
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func doneTapped() {
        guard let textView = textView else { return }
        let prompt = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        
        didCompletePrompt = true
        promptManager?.updateCustomPrompt(prompt)
        onSelectPrompt?(prompt)
        dismiss(animated: true)
    }
    
    @IBAction func clearAction(_ sender: UIButton) {
        guard let textView else { return }
        textView.text = ""
        selectedPromptIndex = nil
        tableView?.reloadData()
        updatePlaceholderVisibility()
    }
    
    
    @IBAction private func nextAction(_ sender: UIButton) {
        guard let textView = textView else { return }
        let prompt = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        
        didCompletePrompt = true
        promptManager?.updateCustomPrompt(prompt)
        onSelectPrompt?(prompt)
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDataSource
extension PromptViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return showSuggestions ? promptList.count : 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "SuggestionTableViewCell", for: indexPath) as? SuggestionTableViewCell else {
            return UITableViewCell()
        }
        guard let prompt = promptList[safe: indexPath.row] else { return cell }
        cell.configure(suggestion: prompt)
        cell.selectionStyle = .none
        cell.tintColor = .label
        return cell
    }
}

// MARK: - UITableViewDelegate
extension PromptViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let textView = textView else { return }
        
        selectedPromptIndex = indexPath.row
        guard let prompt = promptList[safe: indexPath.row] else { return }
        textView.text = prompt
        updatePlaceholderVisibility()
        textView.becomeFirstResponder()
    }
}

// MARK: - UITextViewDelegate
extension PromptViewController: UITextViewDelegate {
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // Якщо натиснуто Enter (Return), закриваємо клавіатуру
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        return true
    }
    
    func textViewDidChange(_ textView: UITextView) {
        updatePlaceholderVisibility()
        
        if let selectedIndex = selectedPromptIndex {
            let indexPath = IndexPath(row: selectedIndex, section: 0)
            if let cell = tableView.cellForRow(at: indexPath) {
                cell.contentView.backgroundColor = .clear
            }
            selectedPromptIndex = nil
        }
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        updatePlaceholderVisibility()
    }
}

// MARK: - UIGestureRecognizerDelegate
extension PromptViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view is UIControl {
            return false
        }
        if let textView, touch.view?.isDescendant(of: textView) == true {
            return false
        }
        if let tableView, touch.view?.isDescendant(of: tableView) == true {
            return false
        }
        return true
    }
}
