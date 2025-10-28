import UIKit

final class OptionsViewController: UIViewController {

    @IBOutlet weak private var collectionView: UICollectionView!
    @IBOutlet weak private var backgroundImageView: UIImageView!
    @IBOutlet weak private var gradientBlurView: GradientBlurView!

    private let cellScale: CGFloat = 0.8
    private let centerCellScale: CGFloat = 1.0

    private let dataSource: [OptionsCollectionModel] = DesignOption.models
    private let amplitude = AmplitudeService.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        amplitude.logEvent(.showOptions)
        configure()
    }

    private func configure() {
        
        collectionView.register(UINib(nibName: "OptionsCollectionCell", bundle: nil), forCellWithReuseIdentifier: "OptionsCollectionCell")

        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let screenWidth = UIScreen.main.bounds.width
            let cellWidth = screenWidth * 0.65
            let cellHeight = collectionView.bounds.height
            layout.estimatedItemSize = .zero
            layout.itemSize = CGSize(width: cellWidth, height: cellHeight)
            layout.scrollDirection = .horizontal
            layout.minimumLineSpacing = 2
            layout.minimumInteritemSpacing = 0

            let insetX = (view.bounds.width - cellWidth) / 2.0
            collectionView.contentInset = UIEdgeInsets(top: 0, left: insetX, bottom: 0, right: insetX)

            collectionView.contentInsetAdjustmentBehavior = .never
        }

        collectionView.isPagingEnabled = false
        collectionView.decelerationRate = .fast
        collectionView.showsHorizontalScrollIndicator = false
        
        if !ApphudService.shared.hasActiveSubscription {
            let item = ProBadgeButton.makeBarButtonItem(target: self, action: #selector(didTapPro))
            navigationItem.rightBarButtonItem = item
        }

        DispatchQueue.main.async { [weak self] in
            self?.collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .centeredHorizontally, animated: false)
            self?.transformCells()
            self?.centerCellDidShow()
        }
    }
    
    @objc private func didTapPro() {
        amplitude.logEvent(.pressPro)
        NavigationManager.shared.showPremium(placement: Constants.Keys.optionPlacememt)
    }
}

// MARK: - UICollectionViewDataSource
extension OptionsViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        dataSource.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "OptionsCollectionCell", for: indexPath) as? OptionsCollectionCell else {
            return UICollectionViewCell()
        }
        let item = dataSource[indexPath.item]
        cell.config(model: item)
        return cell
    }
}



// MARK: - UICollectionViewDelegate
extension OptionsViewController: UICollectionViewDelegate {

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        transformCells()
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        let cellWidthIncludingSpacing = layout.itemSize.width + layout.minimumLineSpacing

        let adjustedOffset = targetContentOffset.pointee.x + collectionView.contentInset.left
        let estimatedIndex = adjustedOffset / cellWidthIncludingSpacing
        let index = round(estimatedIndex)

        let clampedIndex = max(0, min(index, CGFloat(dataSource.count - 1)))

        targetContentOffset.pointee = CGPoint(x: clampedIndex * cellWidthIncludingSpacing - collectionView.contentInset.left, y: 0)
    }

    // Додано: Викликаємо centerCellDidShow() після завершення скролу (коли колекція зупиняється)
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        centerCellDidShow()
    }

    // Додано: Викликаємо centerCellDidShow() після завершення драггінгу зі швидкістю (для snapping)
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            centerCellDidShow()  // Якщо немає декелерації, оновлюємо відразу
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let option = DesignOption.allCases[indexPath.item]
        amplitude.logEvent(.selectOption(name: option.title))
        option == .reference ? NavigationManager.shared.showAddPhoto() : NavigationManager.shared.showPageViewController(option: option)
        
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension OptionsViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let screenWidth = UIScreen.main.bounds.width
        let width = screenWidth * 0.65
        let height = collectionView.bounds.height * 0.8
        return CGSize(width: width, height: height)
    }
}


// MARK: - Private Methods
private extension OptionsViewController {

    func transformCells() {
        let collectionViewCenter = view.convert(collectionView.center, to: collectionView)

        for cell in collectionView.visibleCells {
            let cellCenter = cell.center
            let distance = abs(collectionViewCenter.x - cellCenter.x)
            let maxDistance = collectionView.bounds.width / 2

            let normalizedDistance = min(distance / maxDistance, 1.0)
            let scale = centerCellScale - (centerCellScale - cellScale) * normalizedDistance

            cell.transform = CGAffineTransform(scaleX: scale, y: scale)
            cell.alpha = 0.6 + (0.4 * (1 - normalizedDistance))
        }
    }

    func centerCellDidShow() {
        let centerPoint = view.convert(collectionView.center, to: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: centerPoint) else { return }
        let centeredIndex = indexPath.item
        let model = dataSource[centeredIndex]

        gradientBlurView.endColor = model.glassColor
        gradientBlurView.startColor = .black.withAlphaComponent(0.05)
        view.backgroundColor = model.glassColor

        UIView.transition(with: backgroundImageView, duration: 0.5, options: [.transitionCrossDissolve], animations: {
            self.backgroundImageView.image = model.imageName
        }, completion: nil)

        print("Центральна клітинка:", centeredIndex, model)
    }
}
