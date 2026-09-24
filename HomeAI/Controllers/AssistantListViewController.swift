import UIKit

private struct Defaults {
    struct Colors {
        static let suggestionBackground = UIColor(named: "suggestion_background_color")
        static let startColor = UIColor(red: 62/255, green: 113/255, blue: 255/255, alpha: 1)
        static let endColor = UIColor(red: 68/255, green: 25/255, blue: 224/255, alpha: 1)
    }

    struct Layout {
        /// Одна колонка — рядки як у таблиці.
        static let columns: CGFloat = 1
        static let interItem: CGFloat = 0
        static let interGroup: CGFloat = 12
        static let sectionInset: CGFloat = 16
        static let sectionVertical: CGFloat = 6
        /// Базова висота «пігулки» на reference screen (852 pt), далі `scaledByHeight`.
        static let cellHeightBase: CGFloat = 88
        /// Відступи клітинки до `cardContainerView` у XIB (6 + 6).
        static let cellCardVerticalInset: CGFloat = 12
        /// Мін. внутрішні відступи картки (≥10 top/bottom у XIB).
        static let cardVerticalPadding: CGFloat = 20
        static let avatarHeightBase: CGFloat = 44
        static let chatPillHeightBase: CGFloat = 30
    }

    /// Вхідний показ рядків колекції (знизу вгору, швидко й без довгих пауз).
    struct AssistantEntrance {
        static let initialDelay: TimeInterval = 0.04
        static let stagger: TimeInterval = 0.055
        static let duration: TimeInterval = 0.34
        static let slideY: CGFloat = 22
        static let depthStep: CGFloat = 12
        static let startScale: CGFloat = 0.94
        static let maxLayoutRetries = 15
    }

    struct Text {
        static let headline = "Hi, There!👋"
        static let renovationAsisstant = "AI Renovation Assistant".localized
        static let description = "I'm Here to transform space  and bring your ideas to life".localized
        static let expertsHeadline = "Meet Your AI Experts:".localized
    }

    struct SuggestionItem {
        let text: String
        let assistantType: AssistantType
    }

    /// На екрані списку лише 4 «пігулки»: перша підказка кожного асистента (`AssistantType.listPreviewSuggestion`).
    static let suggestions: [SuggestionItem] = AssistantType.allCases.map {
        SuggestionItem(text: $0.listPreviewSuggestion, assistantType: $0)
    }
}

final class AssistantListViewController: UIViewController {

    @IBOutlet weak private var headlineLabel: UILabel!
    @IBOutlet weak private var descriptionLabel: UILabel!
    @IBOutlet weak private var renovationAsisstantLabel: UILabel!
    @IBOutlet weak private var gradientContainerView: UIView!
    @IBOutlet weak private var collectionView: UICollectionView!

    @IBOutlet private var xConstraintsCollection: [NSLayoutConstraint]!
//    @IBOutlet private var yConstraintsCollection: [NSLayoutConstraint]!
    
    // MARK: - Properties

    private let assistants: [AssistantType] = AssistantType.allCases
    private var addedGradient = false
    private var lastCollectionLayoutHeight: CGFloat = 0
    private var shouldDeferAssistantCellEntrance = true
    private var assistantEntranceRetryCount = 0

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLabels()
        setupCollectionView()
//        yConstraintsCollection.forEach { $0.scaleConstant() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard isMovingToParent else { return }
        shouldDeferAssistantCellEntrance = true
        assistantEntranceRetryCount = 0
        collectionView.reloadSections(IndexSet(integer: 0))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scheduleAssistantCellsEntranceAnimationIfNeeded()
    }

    private func scheduleAssistantCellsEntranceAnimationIfNeeded() {
        guard shouldDeferAssistantCellEntrance else { return }
        DispatchQueue.main.async { [weak self] in
            self?.runAssistantCellsEntranceAnimationIfPossible()
        }
    }

    private func runAssistantCellsEntranceAnimationIfPossible() {
        guard shouldDeferAssistantCellEntrance else { return }

        collectionView.layoutIfNeeded()

        let missingAnyCell = assistants.indices.contains { idx in
            collectionView.cellForItem(at: IndexPath(item: idx, section: 0)) == nil
        }

        if missingAnyCell {
            assistantEntranceRetryCount += 1
            if assistantEntranceRetryCount < Defaults.AssistantEntrance.maxLayoutRetries {
                DispatchQueue.main.async { [weak self] in
                    self?.runAssistantCellsEntranceAnimationIfPossible()
                }
            } else {
                shouldDeferAssistantCellEntrance = false
                revealAssistantCellsImmediately()
            }
            return
        }

        assistantEntranceRetryCount = 0
        shouldDeferAssistantCellEntrance = false

        let orderBottomFirst = Array((0..<assistants.count).sorted(by: >))
        let ent = Defaults.AssistantEntrance.self
        for (seq, itemIdx) in orderBottomFirst.enumerated() {
            guard let cell = collectionView.cellForItem(at: IndexPath(item: itemIdx, section: 0)) as? AsisstentCollectionViewCell else { continue }
            let delay = ent.initialDelay + Double(seq) * ent.stagger
            cell.animateEntrance(delay: delay, duration: ent.duration)
        }
    }

    private func revealAssistantCellsImmediately() {
        for i in 0..<assistants.count {
            guard let cell = collectionView.cellForItem(at: IndexPath(item: i, section: 0)) as? AsisstentCollectionViewCell else { continue }
            cell.resetEntranceAppearance()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let cvH = collectionView.bounds.height
        if cvH > 0, abs(cvH - lastCollectionLayoutHeight) > 0.5 {
            lastCollectionLayoutHeight = cvH
            applyLayout()
        }

        if !addedGradient {
            addedGradient = true
            setupGradients()
        }
    }

    // MARK: - Setup
    private func setupLabels() {
        headlineLabel.text = Defaults.Text.headline
        renovationAsisstantLabel.text = Defaults.Text.renovationAsisstant
        descriptionLabel.text = Defaults.Text.description
    }


    @objc private func suggestionTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index < Defaults.suggestions.count else { return }
        let item = Defaults.suggestions[index]
        NavigationManager.shared.showChat(assistantType: item.assistantType, initialMessage: item.text)
    }

    private func setupCollectionView() {
        collectionView.register(
            UINib(nibName: AsisstentCollectionViewCell.reuseIdentifier, bundle: nil),
            forCellWithReuseIdentifier: AsisstentCollectionViewCell.reuseIdentifier
        )
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
    }

    // MARK: - Layout

    /// Мінімальна висота рядка, щоб аватар/Chat не стискали «пігулку» на SE.
    private func minimumCellHeight() -> CGFloat {
        let layout = Defaults.Layout.self
        let cardContent = max(layout.avatarHeightBase, layout.chatPillHeightBase).scaledByHeight()
            + layout.cardVerticalPadding
        return floor(cardContent + layout.cellCardVerticalInset)
    }

    private func resolvedCellHeight() -> CGFloat {
        let scaledIdeal = floor(Defaults.Layout.cellHeightBase.scaledByHeight())
        let minHeight = minimumCellHeight()
        let cols = Defaults.Layout.columns
        let rows = max(1, ceil(CGFloat(assistants.count) / cols))

        let sectionPadding = Defaults.Layout.sectionVertical * 2
        let betweenRows = Defaults.Layout.interGroup * max(0, rows - 1)
        let verticalOverhead = sectionPadding + betweenRows
        let neededHeight = minHeight * rows + verticalOverhead

        let cvH = collectionView.bounds.height
        let fitsWithoutScroll = cvH > 0 && cvH + 0.5 >= neededHeight

        guard cvH > verticalOverhead else {
            collectionView.isScrollEnabled = false
            return max(minHeight, min(scaledIdeal, max(1, floor(cvH / rows))))
        }

        let maxCell = floor((cvH - verticalOverhead) / rows)
        if fitsWithoutScroll {
            collectionView.isScrollEnabled = false
            return max(minHeight, min(scaledIdeal, max(maxCell, 1)))
        }

        collectionView.isScrollEnabled = true
        return minHeight
    }

    private func applyLayout() {
        let cellH = max(1, resolvedCellHeight())
        collectionView.setCollectionViewLayout(
            makeLayout(cellHeight: cellH),
            animated: false
        )
    }

    private func makeLayout(cellHeight: CGFloat) -> UICollectionViewCompositionalLayout {
        let interGrp  = Defaults.Layout.interGroup
        let inset     = Defaults.Layout.sectionInset
        let vPad      = Defaults.Layout.sectionVertical
        let cols      = Int(Defaults.Layout.columns)

        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1 / CGFloat(cols)),
            heightDimension: .fractionalHeight(1)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(cellHeight))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = interGrp
        section.contentInsets = NSDirectionalEdgeInsets(
            top: vPad, leading: inset, bottom: vPad, trailing: inset
        )

        return UICollectionViewCompositionalLayout(section: section)
    }

    // MARK: - Gradient helpers

    private func setupGradients() {
        gradientContainerView.backgroundColor = .clear
        gradientContainerView.isUserInteractionEnabled = true
        gradientContainerView.setGradient(
            stops: [
                .init(percent: 0,   color: UIColor.systemBackground.withAlphaComponent(0)),
                .init(percent: 20,  color: UIColor.systemBackground.withAlphaComponent(0.5)),
                .init(percent: 100, color: UIColor.systemBackground)
            ],
            direction: .vertical
        )
        applyGradientToLabel(renovationAsisstantLabel,
                             start: Defaults.Colors.startColor,
                             end: Defaults.Colors.endColor)
    }

    private func applyGradientToLabel(_ label: UILabel, start: UIColor, end: UIColor) {
        guard label.bounds.width > 0, label.bounds.height > 0 else { return }
        let renderer = UIGraphicsImageRenderer(bounds: label.bounds)
        let image = renderer.image { ctx in
            let gradient = CAGradientLayer()
            gradient.colors = [start.cgColor, end.cgColor]
            gradient.startPoint = CGPoint(x: 0, y: 0.5)
            gradient.endPoint = CGPoint(x: 1, y: 0.5)
            gradient.frame = label.bounds
            gradient.render(in: ctx.cgContext)
        }
        label.textColor = UIColor(patternImage: image)
    }
}

// MARK: - UICollectionViewDataSource

extension AssistantListViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        assistants.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: AsisstentCollectionViewCell.reuseIdentifier,
            for: indexPath
        ) as? AsisstentCollectionViewCell else {
            return UICollectionViewCell()
        }
        guard let assistant = assistants[safe: indexPath.item] else { return cell }
        cell.configure(with: assistant)
        if shouldDeferAssistantCellEntrance {
            let tierFromBottom = assistants.count - 1 - indexPath.item
            let ent = Defaults.AssistantEntrance.self
            let slide = ent.slideY + CGFloat(tierFromBottom) * ent.depthStep
            cell.prepareForEntranceAppearance(slideY: slide, scale: ent.startScale)
        }
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension AssistantListViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let assistant = assistants[safe: indexPath.item] else { return }
        NavigationManager.shared.showChat(assistantType: assistant)
    }
}
