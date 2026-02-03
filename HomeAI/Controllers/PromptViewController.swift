//
//  PromptViewController.swift
//  HomeAI
//
//  Created by Mykola Albert on 16.12.2025.
//

import UIKit

private struct Defaults {
    struct Text {
        static let headline = "Enter Custom Promt".localized
        static let placeholder = "Describe your design style idea...".localized
        static let clear = "Clear".localized
        static let examplePrompt = "Example Promt".localized
        static let next = "Next".localized
        
        // Метод для отримання промптів залежно від DesignOption
        static func promptList(for option: DesignOption) -> [String] {
            switch option {
            case .interior, .reference, .replace, .delete, .newWalls, .newFlooring:
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
    var showSuggestions: Bool = true // Чи показувати список саджестів
    var initialPrompt: String? // Початковий текст промпту для редагування
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
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
    
    private func configure() {
        title = Defaults.Text.headline
        
        // Приховуємо список саджестів, якщо showSuggestions = false
        if showSuggestions {
            headlineLabel?.text = Defaults.Text.examplePrompt
            headlineLabel?.isHidden = false
        } else {
            headlineLabel?.isHidden = true
            tableView?.isHidden = true
        }
        
        guard let tableView = tableView else { return }
        tableView.register(UINib(nibName: "SuggestionTableViewCell", bundle: nil), forCellReuseIdentifier: "SuggestionTableViewCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 100, right: 0)
        tableView.isHidden = !showSuggestions
        
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
        
        promptManager?.updateCustomPrompt(prompt)
        onSelectPrompt?(prompt)
        dismiss(animated: true)
    }
    
    @IBAction func clearAction(_ sender: UIButton) {
        guard let textView = textView else { return }
        textView.text = ""
        selectedPromptIndex = nil
        tableView?.reloadData()
        updatePlaceholderVisibility()
    }
    
    
    @IBAction private func nextAction(_ sender: UIButton) {
        guard let textView = textView else { return }
        let prompt = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "SuggestionTableViewCell", for: indexPath) as! SuggestionTableViewCell
        let prompt = promptList[indexPath.row]
        cell.configure(suggestion: prompt)
        
        cell.selectionStyle = .none
        
//        if let selectedIndex = selectedPromptIndex, selectedIndex == indexPath.row {
//            cell.contentView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
//        } else {
//            cell.contentView.backgroundColor = .clear
//        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension PromptViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let textView = textView else { return }
        
        if let previous = selectedPromptIndex {
            let prevIndexPath = IndexPath(row: previous, section: 0)
            if let prevCell = tableView.cellForRow(at: prevIndexPath) {
//                prevCell.contentView.backgroundColor = .clear
            }
        }
        
        selectedPromptIndex = indexPath.row
        let prompt = promptList[indexPath.row]
        textView.text = prompt
        updatePlaceholderVisibility()
        
        if let cell = tableView.cellForRow(at: indexPath) {
//            cell.contentView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.1)
        }
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
