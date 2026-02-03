import UIKit
import QuartzCore

// MARK: - Layout config
public struct CarouselLayoutConfig {
    public var itemSize: CGSize
    public var itemContentInsets: NSDirectionalEdgeInsets
    public var sectionInsets: NSDirectionalEdgeInsets
    public var interGroupSpacing: CGFloat
    public var groupHeight: CGFloat
    public var orthogonalBehavior: UICollectionLayoutSectionOrthogonalScrollingBehavior
    public var repeatFactor: Int
    public var pixelsPerSecond: CGFloat

    public init(
        itemSize: CGSize,
        itemContentInsets: NSDirectionalEdgeInsets = .init(top: 0, leading: 6, bottom: 0, trailing: 6),
        sectionInsets: NSDirectionalEdgeInsets = .init(top: 0, leading: 16, bottom: 0, trailing: 16),
        interGroupSpacing: CGFloat = 0,
        groupHeight: CGFloat,
        orthogonalBehavior: UICollectionLayoutSectionOrthogonalScrollingBehavior = .continuous,
        repeatFactor: Int = 7,
        pixelsPerSecond: CGFloat = 30
    ) {
        self.itemSize = itemSize
        self.itemContentInsets = itemContentInsets
        self.sectionInsets = sectionInsets
        self.interGroupSpacing = interGroupSpacing
        self.groupHeight = groupHeight
        self.orthogonalBehavior = orthogonalBehavior
        self.repeatFactor = repeatFactor
        self.pixelsPerSecond = pixelsPerSecond
    }
}

// MARK: - Engine
public final class CarouselEngine<Item, Cell: UICollectionViewCell>: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {

    // Public API
    public typealias Selection = (_ row: Int, _ baseIndex: Int, _ item: Item) -> Void

    public let collectionView: UICollectionView

    private var baseRows: [[Item]] = []
    private var dupRows: [[Item]] = []
    private var phaseX: [CGFloat] = []

    private var layoutConfig: CarouselLayoutConfig
    private var registration: UICollectionView.CellRegistration<Cell, Item>

    private var displayLink: CADisplayLink?
    private var pixelsPerFrame: CGFloat = 0.5
    private var repeatFactor: Int = 7

    // Discovered inner orthogonal scrollers
    private var orthScrollers: [Int: UIScrollView] = [:]

    public var onSelect: Selection?

    // MARK: - Init
    public init(
        collectionView: UICollectionView,
        layoutConfig: CarouselLayoutConfig,
        cellRegistration: UICollectionView.CellRegistration<Cell, Item>,
        onSelect: Selection? = nil
    ) {
        self.collectionView = collectionView
        self.layoutConfig = layoutConfig
        self.registration = cellRegistration
        self.onSelect = onSelect
        super.init()
        setupCollection()
    }

    private func setupCollection() {
        collectionView.collectionViewLayout = makeLayout()
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.isScrollEnabled = false

        let scroll = collectionView as UIScrollView
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.contentInset.top = 0

        collectionView.isPrefetchingEnabled = true
    }
    // MARK: - Configure data
    // Заміна configure(rows:initialOffsets:)
    public func configure(rows: [[Item]], initialOffsets: [CGFloat]? = nil) {
        baseRows = rows

        // Вираховуємо repeatFactor проти видимої ширини (без побудови dupRows)
        collectionView.layoutIfNeeded()
        let visibleWidth = max(collectionView.bounds.width, UIScreen.main.bounds.width)
        let baseMax = rows.map { baseWidth(forCount: $0.count) }.max()
            ?? (layoutConfig.itemSize.width + layoutConfig.sectionInsets.leading + layoutConfig.sectionInsets.trailing)
        let need = Int(ceil(visibleWidth / max(baseMax, 1))) + 4
        repeatFactor = max(layoutConfig.repeatFactor, need)

        let generated = rows.enumerated().map { i, _ in CGFloat((i * 40) % 160) }
        phaseX = initialOffsets ?? generated

        orthScrollers.removeAll()
        collectionView.reloadData()

        let fps: CGFloat = 60
        pixelsPerFrame = layoutConfig.pixelsPerSecond / fps
        start()
    }


    // MARK: - Run loop
    public func start() {
        stop()
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    public func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func step() {
        guard !baseRows.isEmpty else { return }
        for (section, sv) in orthScrollers {
            let base = baseWidth(forCount: baseRows[section].count)
            guard base > 0 else { continue }

            var x = sv.contentOffset.x + pixelsPerFrame

            let minSafe = base * CGFloat((repeatFactor / 2) - 2)
            let maxSafe = base * CGFloat((repeatFactor / 2) + 2)
            if x > maxSafe { x -= base }
            if x < minSafe { x += base }

            if x >= base * CGFloat(repeatFactor - 1) { x -= base }
            if x < base { x += base }

            sv.setContentOffset(CGPoint(x: x, y: 0), animated: false)
        }
    }

    // MARK: - Layout
    private func makeLayout() -> UICollectionViewLayout {
        let provider: UICollectionViewCompositionalLayoutSectionProvider = { [weak self] sectionIndex, _ in
            guard let self else { return nil }

            let itemSize = NSCollectionLayoutSize(
                widthDimension: .absolute(self.layoutConfig.itemSize.width),
                heightDimension: .absolute(self.layoutConfig.itemSize.height)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = self.layoutConfig.itemContentInsets

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .absolute(self.layoutConfig.itemSize.width),
                heightDimension: .absolute(self.layoutConfig.groupHeight)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

            let section = NSCollectionLayoutSection(group: group)
            section.orthogonalScrollingBehavior = self.layoutConfig.orthogonalBehavior
            section.contentInsets = self.layoutConfig.sectionInsets
            section.interGroupSpacing = self.layoutConfig.interGroupSpacing

            return section
        }

        return UICollectionViewCompositionalLayout(sectionProvider: provider)
    }

    private func baseWidth(forCount count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        let side = layoutConfig.sectionInsets.leading + layoutConfig.sectionInsets.trailing
        let itemW = layoutConfig.itemSize.width
        let itemInsetsH = layoutConfig.itemContentInsets.leading + layoutConfig.itemContentInsets.trailing
        return CGFloat(count) * (itemW + itemInsetsH) + side
    }

    // MARK: - DataSource
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        baseRows.count
    }

    // Заміна collectionView(_:numberOfItemsInSection:)
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let baseCount = baseRows[section].count
        return max(baseCount * repeatFactor, baseCount)
    }


    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let base = baseRows[indexPath.section]
        let baseItem = base[indexPath.item % base.count]
        return collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: baseItem)
    }

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let row = indexPath.section
        let baseCount = baseRows[row].count
        guard baseCount > 0 else { return }
        let baseIndex = indexPath.item % baseCount
        let item = baseRows[row][baseIndex]
        onSelect?(row, baseIndex, item)
    }

    // MARK: - Discover inner orthogonal scrollers
    public func collectionView(_ cv: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard orthScrollers[indexPath.section] == nil else { return }
        var v: UIView? = cell
        while let s = v?.superview {
            if let sv = s as? UIScrollView, sv !== cv, String(describing: type(of: sv)).contains("Orthogon") {
                orthScrollers[indexPath.section] = sv
                sv.isScrollEnabled = false
                sv.showsHorizontalScrollIndicator = false
                sv.bounces = false
                sv.panGestureRecognizer.isEnabled = false

                let base = baseWidth(forCount: baseRows[indexPath.section].count)
                let centerX = base * CGFloat(repeatFactor / 2)
                let startPhase = (phaseX[safe: indexPath.section] ?? 0).truncatingRemainder(dividingBy: max(base, 1))
                sv.setContentOffset(CGPoint(x: centerX + startPhase, y: 0), animated: false)
                break
            }
            v = s
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
