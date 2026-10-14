import UIKit

/// Floating glass tab bar (TabBar · active=…). Layout: DSTabBarView.xib.
final class DSTabBarView: DSNibView {

    @IBOutlet private weak var cardView: DSView!
    @IBOutlet private var itemControls: [DSPressableControl]!
    @IBOutlet private var highlightViews: [UIView]!
    @IBOutlet private var iconViews: [UIImageView]!
    @IBOutlet private var titleLabels: [UILabel]!

    var onSelect: ((Int) -> Void)?
    private(set) var selectedIndex = 0

    private static let symbols = ["plus.square", "square.grid.2x2", "folder", "person"]
    private static let selectedSymbols = ["plus.square.fill", "square.grid.2x2.fill", "folder.fill", "person.fill"]

    override func didLoadFromNib() {
        let titles = ["Create".localized, "Inspiration".localized, "Projects".localized, "Profile".localized]
        for (index, label) in sorted(titleLabels).enumerated() where titles.indices.contains(index) {
            label.text = titles[index]
            sorted(itemControls)[index].accessibilityLabel = titles[index]
        }
        setSelected(0, animated: false)
    }

    @IBAction private func didTapItem(_ sender: UIControl) {
        guard sender.tag != selectedIndex else {
            onSelect?(sender.tag)
            return
        }
        DS.Haptic.selection()
        setSelected(sender.tag, animated: true)
        onSelect?(sender.tag)
    }

    func setSelected(_ index: Int, animated: Bool) {
        selectedIndex = index
        let highlights = sorted(highlightViews)
        let icons = sorted(iconViews)
        let labels = sorted(titleLabels)
        let changes = {
            for i in highlights.indices {
                let active = i == index
                highlights[i].alpha = active ? 1 : 0
                highlights[i].transform = active ? .identity : CGAffineTransform(scaleX: 0.85, y: 0.85)
                icons[i].tintColor = active ? DS.Color.textPrimary : DS.Color.textSecondary
                labels[i].textColor = active ? DS.Color.textPrimary : DS.Color.textSecondary
                labels[i].font = DS.Font.geologica(active ? .semiBold : .medium, 10)
                icons[i].image = UIImage(systemName: active ? Self.selectedSymbols[i] : Self.symbols[i])
            }
        }
        guard animated, !DS.Motion.reduceMotion else { changes(); return }
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0,
                       options: [.allowUserInteraction], animations: changes)
        if icons.indices.contains(index) {
            let icon = icons[index]
            icon.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            UIView.animate(withDuration: 0.45, delay: 0.05, usingSpringWithDamping: 0.5, initialSpringVelocity: 0,
                           options: [.allowUserInteraction]) { icon.transform = .identity }
        }
    }

    /// Entrance: rises 24 pt with a spring (Home timeline, 0.3 s).
    func animateEntrance(delay: TimeInterval) {
        DS.Motion.enter(cardView, delay: delay, dy: 24, spring: true)
    }

    private func sorted<T: UIView>(_ views: [T]) -> [T] {
        views.sorted { $0.tag < $1.tag }
    }
}
