import UIKit

final class OptionsViewController: UIViewController {

    @IBOutlet weak private var collectionView: UICollectionView!
    @IBOutlet weak private var backgroundImageView: UIImageView!
    @IBOutlet weak private var gradientBlurView: GradientBlurView!

    private let cellScale: CGFloat = 0.8
    private let centerCellScale: CGFloat = 1.0
    private var didApplyInitialLayout = false

    private let dataSource: [OptionsCollectionModel] = DesignOption.models
    private let amplitude = AmplitudeService.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        amplitude.logEvent(.showOptions)
        configure()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Ensure initial scaling/alpha is applied even if layout happens before cells are visible.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.collectionView.layoutIfNeeded()
            self.transformCells()
            self.centerCellDidShow()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyLayoutIfNeeded()
    }

    private func configure() {
        
        collectionView.register(UINib(nibName: "OptionsCollectionCell", bundle: nil), forCellWithReuseIdentifier: "OptionsCollectionCell")
        collectionView.dataSource = self
        collectionView.delegate = self
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.estimatedItemSize = .zero
            layout.scrollDirection = .horizontal
            // Use a noticeable spacing; very small values can look like "no spacing" on some screens.
            layout.minimumLineSpacing = 16
            layout.minimumInteritemSpacing = 0
        }

        collectionView.contentInsetAdjustmentBehavior = .never

        collectionView.isPagingEnabled = false
        collectionView.decelerationRate = .fast
        collectionView.showsHorizontalScrollIndicator = false
        
        if !ApphudService.shared.hasActiveSubscription {
            let item = ProBadgeButton.makeBarButtonItem(target: self, action: #selector(didTapPro))
            navigationItem.rightBarButtonItem = item
        }

        // Initial positioning is done in `applyLayoutIfNeeded()` once bounds are final.
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
        if option == .reference {
            NavigationManager.shared.showAddPhoto()
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
}

// MARK: - UICollectionViewDelegateFlowLayout
extension OptionsViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Size is applied in `viewDidLayoutSubviews` to avoid 0-height bounds on first layout for some devices.
        let containerWidth = view.bounds.width
        let width = containerWidth * 0.65
        let height = max(1, collectionView.bounds.height * 0.8)
        return CGSize(width: width, height: height)
    }
}


// MARK: - Private Methods
private extension OptionsViewController {
    
    func applyLayoutIfNeeded() {
        // Prevent repeated invalidations; layout becomes correct after first pass.
        guard !didApplyInitialLayout else { return }
        // Ensure we have final bounds (esp. safe area) before sizing.
        guard collectionView.bounds.width > 0, collectionView.bounds.height > 0 else { return }
        
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        
        let containerWidth = view.bounds.width
        let cellWidth = containerWidth * 0.65
        let cellHeight = collectionView.bounds.height * 0.8
        
        layout.itemSize = CGSize(width: cellWidth, height: cellHeight)
        
        let insetX = max(0, (containerWidth - cellWidth) / 2.0)
        collectionView.contentInset = UIEdgeInsets(top: 0, left: insetX, bottom: 0, right: insetX)
        
        // Force layout pass before we scroll/transform.
        layout.invalidateLayout()
        collectionView.layoutIfNeeded()
        collectionView.performBatchUpdates(nil)
        
        // Ensure the first cell is centered with correct insets/spacings applied.
        if dataSource.isEmpty == false {
            collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .centeredHorizontally, animated: false)
        } else {
            collectionView.setContentOffset(CGPoint(x: -collectionView.contentInset.left, y: 0), animated: false)
        }
        collectionView.layoutIfNeeded()
        
        // If cells are not yet visible, wait for next layout pass.
        guard collectionView.visibleCells.isEmpty == false else { return }
        
        transformCells()
        centerCellDidShow()
        
        didApplyInitialLayout = true
    }

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
        gradientBlurView.startColor = model.startColor
        gradientBlurView.startLocationPercent = 0
        gradientBlurView.endLocationPercent = model.endLocationPercent
        view.backgroundColor = model.glassColor

        UIView.transition(with: backgroundImageView, duration: 0.5, options: [.transitionCrossDissolve], animations: {
            self.backgroundImageView.image = model.imageName
        }, completion: nil)

        print("Центральна клітинка:", centeredIndex, model)
    }
}
