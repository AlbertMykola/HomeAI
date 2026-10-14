import UIKit

/// Two-column masonry (A/08 · I1): column width from the screen, height from `heightRatio`, gaps 13 / 12.
/// Items keep their height across filters, so batch updates make cards fly to their new places.
final class MasonryLayout: UICollectionViewLayout {

    var columns = 2
    var columnSpacing: CGFloat = 13
    var rowSpacing: CGFloat = 12
    var sideInset: CGFloat = 20
    /// Height / width for an item.
    var heightRatio: (IndexPath) -> CGFloat = { _ in 1.3 }

    private var cache: [UICollectionViewLayoutAttributes] = []
    private var contentHeight: CGFloat = 0
    private var preparedWidth: CGFloat = 0

    var columnWidth: CGFloat {
        guard let cv = collectionView else { return 170 }
        return floor((cv.bounds.width - sideInset * 2 - columnSpacing * CGFloat(columns - 1)) / CGFloat(columns))
    }

    override func prepare() {
        super.prepare()
        guard let cv = collectionView else { return }
        cache.removeAll()
        preparedWidth = cv.bounds.width
        let width = columnWidth
        var offsets = Array(repeating: CGFloat(0), count: columns)
        let count = cv.numberOfSections > 0 ? cv.numberOfItems(inSection: 0) : 0
        for item in 0..<count {
            let ip = IndexPath(item: item, section: 0)
            let column = offsets.firstIndex(of: offsets.min() ?? 0) ?? 0
            let height = round(width * heightRatio(ip))
            let x = sideInset + CGFloat(column) * (width + columnSpacing)
            let attrs = UICollectionViewLayoutAttributes(forCellWith: ip)
            attrs.frame = CGRect(x: x, y: offsets[column], width: width, height: height)
            cache.append(attrs)
            offsets[column] += height + rowSpacing
        }
        contentHeight = max(0, (offsets.max() ?? 0) - rowSpacing)
    }

    override var collectionViewContentSize: CGSize {
        CGSize(width: collectionView?.bounds.width ?? 0, height: contentHeight)
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        cache.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        cache.indices.contains(indexPath.item) ? cache[indexPath.item] : nil
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        newBounds.width != preparedWidth
    }

    // Inserted / removed cards scale 0.94 + fade, like the I1 entrance.
    override func initialLayoutAttributesForAppearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let attrs = super.initialLayoutAttributesForAppearingItem(at: itemIndexPath) ??
            layoutAttributesForItem(at: itemIndexPath)?.copy() as? UICollectionViewLayoutAttributes
        attrs?.alpha = 0
        attrs?.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        return attrs
    }

    override func finalLayoutAttributesForDisappearingItem(at itemIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let attrs = super.finalLayoutAttributesForDisappearingItem(at: itemIndexPath)
        attrs?.alpha = 0
        attrs?.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        return attrs
    }
}
