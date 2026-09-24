import UIKit

// MARK: - Defaults

private struct Defaults {

    struct Layout {
        static let primaryRowHeight: CGFloat = 107
        static let primarySectionTopInset: CGFloat = 10
        static let primaryInterGroupSpacing: CGFloat = 16
        static let primaryHorizontalInset: CGFloat = 16

        static let smartToolsSectionTopInset: CGFloat = 8
        static let smartToolsSectionBottomInset: CGFloat = 24
        static let smartToolsHorizontalInset: CGFloat = 16
        static let smartToolsInterItem: CGFloat = 12
        static let smartToolsHeaderHeight: CGFloat = 44
        /// Розмір `OBFeaturesCollectionViewCell` у макеті (@ 852), далі `scaledByHeight`.
        static let obFeatureCellWidth: CGFloat = 74
        static let obFeatureCellHeight: CGFloat = 87
        /// Відстань між рядом з 3 інструментами та карткою чату.
        static let smartToolsRowSpacing: CGFloat = 30
        /// Базова висота картки чату (pt @ 852), далі `scaledByHeight`.
        static let chatCellHeight: CGFloat = 85
    }

    struct Text {
        static let smartToolsTitle = "Smart tools".localized
        static let seeAll = "See all".localized
    }
}

// MARK: - OptionsViewController

final class OptionsViewController: UIViewController {

    // MARK: - Properties

    @IBOutlet var constraintsCollection: [NSLayoutConstraint]!
    
    @IBOutlet weak private var collectionView: UICollectionView!

    private let amplitude = AmplitudeService.shared

    private enum Section: Int, CaseIterable {
        case primary
        case smartTools
    }

    /// Великі картки: інтер’єр, екстер’єр, сад.
    private static let primaryOptions: [DesignOption] = [.interior, .exterior, .garden]
    /// Горизонтальний ряд: 4 «фічі»; останнім елементом секції є картка чату (`OptionsChatCollectionViewCell`).
    private static let smartToolOptions: [DesignOption] = [.reference, .replace, .delete, .newFlooring]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        amplitude.logEvent(.showOptions)
        configureCollectionView()
        constraintsCollection.forEach { $0.scaleConstant() }
    }

    // MARK: - Setup

    private func configureCollectionView() {
        collectionView.clipsToBounds = false
        collectionView.collectionViewLayout = makeCompositionalLayout()
        collectionView.register(UINib(nibName: OptionsCollectionCell.reuseIdentifier, bundle: nil), forCellWithReuseIdentifier: OptionsCollectionCell.reuseIdentifier)
        collectionView.register(UINib(nibName: OBFeaturesCollectionViewCell.reuseIdentifier, bundle: nil),
            forCellWithReuseIdentifier: OBFeaturesCollectionViewCell.reuseIdentifier)
        collectionView.register(UINib(nibName: OptionsChatCollectionViewCell.reuseIdentifier, bundle: nil),
            forCellWithReuseIdentifier: OptionsChatCollectionViewCell.reuseIdentifier)
        collectionView.register(
            SmartToolsSectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: SmartToolsSectionHeaderView.reuseIdentifier
        )
        collectionView.dataSource = self
        collectionView.delegate = self
    }

    // MARK: - Layout

    private func makeCompositionalLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { sectionIndex, environment in
            guard let section = Section(rawValue: sectionIndex) else { return nil }
            switch section {
            case .primary:
                return Self.primarySectionLayout()
            case .smartTools:
                return Self.smartToolsSectionLayout(containerWidth: environment.container.effectiveContentSize.width)
            }
        }
    }

    private static func primarySectionLayout() -> NSCollectionLayoutSection {
        let rowHeight = Defaults.Layout.primaryRowHeight.scaledByHeight()
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),heightDimension: .absolute(rowHeight))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),heightDimension: .absolute(rowHeight)),subitems: [item])
        let sectionLayout = NSCollectionLayoutSection(group: group)
        sectionLayout.interGroupSpacing = Defaults.Layout.primaryInterGroupSpacing
        let inset = Defaults.Layout.primaryHorizontalInset
        sectionLayout.contentInsets = NSDirectionalEdgeInsets(top: Defaults.Layout.primarySectionTopInset,leading: inset,bottom: 0,trailing: inset)
        return sectionLayout
    }

    private static func smartToolsSectionLayout(containerWidth: CGFloat) -> NSCollectionLayoutSection {
        let inset = Defaults.Layout.smartToolsHorizontalInset
        let interItem = Defaults.Layout.smartToolsInterItem
        let itemCount: CGFloat = CGFloat(smartToolOptions.count)
        guard itemCount > 0 else {
            let chatHeight = max(1, floor(Defaults.Layout.chatCellHeight.scaledByHeight()))
            let chatItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(chatHeight))
            let chatItem = NSCollectionLayoutItem(layoutSize: chatItemSize)
            let chatGroup = NSCollectionLayoutGroup.horizontal(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(chatHeight)),
                subitems: [chatItem]
            )
            let headerHeight = max(1, floor(Defaults.Layout.smartToolsHeaderHeight.scaledByHeight()))
            let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(headerHeight))
            let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
            let sectionLayout = NSCollectionLayoutSection(group: chatGroup)
            sectionLayout.boundarySupplementaryItems = [header]
            return sectionLayout
        }

        let availableWidth = max(0, containerWidth - inset * 2)
        let topHeight = max(1, floor(Defaults.Layout.obFeatureCellHeight.scaledByHeight()))
        // Ширина клітинки: рівномірно по 4 стовпці, але не більше висоти —
        // XIB має width==height на зображенні, тому надширокі клітинки ламають layout на iPad.
        let computedWidth = floor((availableWidth - interItem * (itemCount - 1)) / itemCount)
        let topCellWidth = max(1, min(computedWidth, topHeight))

        let topItemSize = NSCollectionLayoutSize(
            widthDimension: .absolute(topCellWidth),
            heightDimension: .absolute(topHeight)
        )
        let topItem = NSCollectionLayoutItem(layoutSize: topItemSize)
        let topGroupWidth = topCellWidth * itemCount + interItem * (itemCount - 1)
        let topGroup = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .absolute(topGroupWidth), heightDimension: .absolute(topHeight)),
            subitems: Array(repeating: topItem, count: Int(itemCount))
        )
        topGroup.interItemSpacing = .fixed(interItem)

        let rowSpacing = floor(Defaults.Layout.smartToolsRowSpacing.scaledByHeight())
        let chatHeight = max(1, floor(Defaults.Layout.chatCellHeight.scaledByHeight()))
        let chatItemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(chatHeight))
        let chatItem = NSCollectionLayoutItem(layoutSize: chatItemSize)
        let chatGroup = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(chatHeight)),subitems: [chatItem])

        let combinedHeight = topHeight + rowSpacing + chatHeight
        let combined = NSCollectionLayoutGroup.vertical(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1),heightDimension: .absolute(combinedHeight)),subitems: [topGroup, chatGroup])
        combined.interItemSpacing = .fixed(rowSpacing)

        let headerHeight = max(1, floor(Defaults.Layout.smartToolsHeaderHeight.scaledByHeight()))
        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .absolute(headerHeight))
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)

        let bottomInset = floor(Defaults.Layout.smartToolsSectionBottomInset.scaledByHeight())
        let sectionLayout = NSCollectionLayoutSection(group: combined)
        sectionLayout.boundarySupplementaryItems = [header]
        sectionLayout.contentInsets = NSDirectionalEdgeInsets(
            top: Defaults.Layout.smartToolsSectionTopInset,leading: inset,bottom: bottomInset,trailing: inset)
        return sectionLayout
    }

    // MARK: - Navigation (через NavigationManager)
    private func open(option: DesignOption, logSelection: Bool = true) {
        if logSelection {
            amplitude.logEvent(.selectOption(name: option.title))
        }
        if option == .reference {
            NavigationManager.shared.showPageViewController(option: option)
        } else if option == .replace {
            NavigationManager.shared.showReplaceObjectPage()
        } else if option == .delete {
            let manager = GemeniPromptManager()
            manager.updateOption(.delete)
            NavigationManager.shared.showReplaceObjectPage(promptManager: manager, flowMode: .delete)
        } else {
            NavigationManager.shared.showPageViewController(option: option)
        }
    }

    private func openOverflowSmartTools() {
        amplitude.logEvent(.selectOption(name: Constants.Keys.amplitudeSeeAllSmartToolsOption))
        NavigationManager.shared.showFeaturesViewController()
    }

    /// Чат з AI з екрана Options (через NavigationManager).
    private func openChatAssistant() {
        amplitude.logEvent(.selectOption(name: Constants.Keys.amplitudeChatAssistantOption))
        NavigationManager.shared.showAssistantList()
    }
}

// MARK: - UICollectionViewDataSource
extension OptionsViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        Section.allCases.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .primary:
            return Self.primaryOptions.count
        case .smartTools:
            return Self.smartToolOptions.count + 1
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UICollectionViewCell()
        }
        switch section {
        case .primary:
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: OptionsCollectionCell.reuseIdentifier,for: indexPath) as? OptionsCollectionCell else {
                return UICollectionViewCell()
            }
            guard let option = Self.primaryOptions[safe: indexPath.item] else { return cell }
            cell.config(model: option.model)
            return cell

        case .smartTools:
            if indexPath.item < Self.smartToolOptions.count {
                guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: OBFeaturesCollectionViewCell.reuseIdentifier,for: indexPath) as? OBFeaturesCollectionViewCell else {
                    return UICollectionViewCell()
                }
                let option = Self.smartToolOptions[indexPath.item]
                cell.configureStatic(title: option.title, icon: option.icon)
                return cell
            }
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: OptionsChatCollectionViewCell.reuseIdentifier,for: indexPath) as? OptionsChatCollectionViewCell else {
                return UICollectionViewCell()
            }
            return cell
        }
    }

    func collectionView(_ collectionView: UICollectionView,viewForSupplementaryElementOfKind kind: String,at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader,
              let section = Section(rawValue: indexPath.section),
              section == .smartTools,
              let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind,withReuseIdentifier: SmartToolsSectionHeaderView.reuseIdentifier,for: indexPath) as? SmartToolsSectionHeaderView else {
            return UICollectionReusableView()
        }
        header.configure(title: Defaults.Text.smartToolsTitle, seeAllTitle: Defaults.Text.seeAll)
        header.onSeeAll = { [weak self] in
            self?.openOverflowSmartTools()
        }
        return header
    }
}

// MARK: - UICollectionViewDelegate
extension OptionsViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let section = Section(rawValue: indexPath.section) else { return }
        switch section {
        case .primary:
            guard let option = Self.primaryOptions[safe: indexPath.item] else { return }
            open(option: option)
        case .smartTools:
            if indexPath.item < Self.smartToolOptions.count {
                open(option: Self.smartToolOptions[indexPath.item])
            } else {
                openChatAssistant()
            }
        }
    }
}
