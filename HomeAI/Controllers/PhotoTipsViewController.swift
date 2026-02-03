import UIKit

private struct Defaults {
    struct Text {
        static let info = "Info".localized
        static let tips = "Tips".localized
        static let badExample = "Bad Example:".localized
        static let goodExample = "Good Example:".localized
    }
}

final class PhotoTipsViewController: UIViewController {

    @IBOutlet weak private var infoLabel: UILabel!
    @IBOutlet weak private var descriptionLabel: UILabel!
    @IBOutlet weak private var tipsLabel: UILabel!
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    var designOption: DesignOption = .interior
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureCollectionView()
    }
    
    private func setupUI() {
        infoLabel.text = Defaults.Text.info
        tipsLabel.text = Defaults.Text.tips
        descriptionLabel.text = designOption.tipsDescription
    }
    
    private func configureCollectionView() {
        collectionView.register(
            UINib(nibName: "PhotoTipsExampleCollectionCell", bundle: nil),
            forCellWithReuseIdentifier: PhotoTipsExampleCollectionCell.reuseIdentifier
        )
        
        collectionView.register(
            SectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: SectionHeaderView.reuseIdentifier
        )
        
        // Use compositional layout for vertical scrolling with horizontal sections
        collectionView.collectionViewLayout = createLayout()
        
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = true
    }
    
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            guard let self = self else { return nil }
            
            // Item size
            let itemWidth = CGFloat(163).scaledByHeight()
            let itemHeight = CGFloat(114).scaledByHeight()
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .absolute(itemWidth),
                heightDimension: .absolute(itemHeight)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            
            // Group size (horizontal group)
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .absolute(itemWidth),
                heightDimension: .absolute(itemHeight)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            
            // Section with orthogonal scrolling (horizontal scrolling within vertical collection)
            let section = NSCollectionLayoutSection(group: group)
            section.orthogonalScrollingBehavior = .continuous
            section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 24, trailing: 16)
            section.interGroupSpacing = 12
            
            // Section header
            let headerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(44)
            )
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            section.boundarySupplementaryItems = [header]
            
            return section
        }
        
        return layout
    }
}

// MARK: - UICollectionViewDataSource
extension PhotoTipsViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2 // 0 - Bad Example, 1 - Good Example
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return designOption.badExample.count
        } else {
            return designOption.goodExample.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PhotoTipsExampleCollectionCell.reuseIdentifier,
            for: indexPath
        ) as? PhotoTipsExampleCollectionCell else {
            return UICollectionViewCell()
        }
        
        let isGoodExample = indexPath.section == 1
        let model: PhotoTipsModel
        
        if isGoodExample {
            model = designOption.goodExample[indexPath.item]
        } else {
            model = designOption.badExample[indexPath.item]
        }
        
        cell.configure(with: model, isGoodExample: isGoodExample)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader,
              let header = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: SectionHeaderView.reuseIdentifier,
                for: indexPath
              ) as? SectionHeaderView else {
            return UICollectionReusableView()
        }
        
        let title = indexPath.section == 0 ? Defaults.Text.badExample : Defaults.Text.goodExample
        header.configure(title: title)
        return header
    }
}

// MARK: - UICollectionViewDelegate
extension PhotoTipsViewController: UICollectionViewDelegate {
    // Delegate methods can be added here if needed
}
