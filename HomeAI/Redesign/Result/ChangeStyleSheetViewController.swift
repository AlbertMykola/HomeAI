import UIKit

/// A/06 · R7 Change style: styles, strength, structure and a duration-only generation action.
/// Layout: Result.storyboard.
final class ChangeStyleSheetViewController: UIViewController {

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var closeButton: DSPressableControl!
    @IBOutlet private weak var collectionView: UICollectionView!
    @IBOutlet private weak var seeAllButton: UIButton!
    @IBOutlet private weak var strengthView: UIView!
    @IBOutlet private weak var strengthKnob: UIView!
    @IBOutlet private weak var strengthKnobLeading: NSLayoutConstraint!
    @IBOutlet private var strengthControls: [DSPressableControl]!
    @IBOutlet private var strengthLabels: [UILabel]!
    @IBOutlet private weak var keepTitleLabel: UILabel!
    @IBOutlet private weak var keepSubtitleLabel: UILabel!
    @IBOutlet private weak var keepSwitch: UISwitch!
    @IBOutlet private weak var restyleButton: DSPrimaryButton!
    @IBOutlet private weak var restyleLabel: UILabel!

    private var option: DesignOption = .interior
    private var currentStyleName: String?
    private var styles: [WizardSession.Style] = []
    private var showAll = false
    private var selected: WizardSession.Style?
    private var strength = 1
    private var onRestyle: ((WizardSession.Style, Bool, Int) -> Void)?

    static func present(from presenter: UIViewController, option: DesignOption, current: String?,
                        onRestyle: @escaping (WizardSession.Style, Bool, Int) -> Void) {
        let vc = AppStoryboard.instantiate(ChangeStyleSheetViewController.self)
        vc.option = option
        vc.currentStyleName = current
        vc.onRestyle = onRestyle
        DSSheet.present(vc, from: presenter, height: 660)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "Change style".localized
        subtitleLabel.text = "Same room, new look".localized
        keepTitleLabel.text = "Keep room structure".localized
        keepSubtitleLabel.text = "Walls, windows and layout stay".localized
        let titles = ["Subtle", "Balanced", "Bold"]
        strengthLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = titles[$0].localized }
        restyleLabel.text = "Restyle".localized + " · " + String(format: "About %d s".localized, 30)

        collectionView.dataSource = self
        collectionView.delegate = self
        loadStyles()
        updateRestyle()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let metrics = OnboardingLayout(size: view.dsAdaptiveReferenceSize)
            let w = floor((collectionView.bounds.width - metrics.value(24)) / 3)
            let size = CGSize(width: w, height: w + metrics.value(24))
            if layout.itemSize != size {
                layout.itemSize = size
                layout.minimumLineSpacing = metrics.value(14)
            }
        }
        applyStrength(animated: false)
    }

    private func loadStyles() {
        let all: [WizardSession.Style]
        switch option {
        case .exterior:
            all = StyleExteriorType.allCases.filter { $0 != .noStyle && $0 != .custom }.map { .exterior($0) }
        case .garden:
            all = GardenType.allCases.filter { $0 != .noStyle && $0 != .custom }.map { .garden($0) }
        default:
            let first: [StyleInteriorType] = [.japanese, .modern, .scandinavian, .wabiSabi, .industrial, .bohemian]
            all = (first + StyleInteriorType.allCases.filter { !first.contains($0) && $0 != .noStyle && $0 != .custom })
                .map { .interior($0) }
        }
        styles = showAll ? all : Array(all.prefix(6))
        // Current style first.
        if let name = currentStyleName, let i = styles.firstIndex(where: { $0.title == name }) {
            styles.insert(styles.remove(at: i), at: 0)
        }
        seeAllButton.setTitle(showAll ? "Show fewer".localized : String(format: "See all %d styles".localized, all.count),
                              for: .normal)
        collectionView.reloadData()
    }

    private func imagePath(for style: WizardSession.Style) -> String? {
        switch style {
        case .interior(let s): return s.image
        case .exterior(let s): return s.image
        case .garden(let g): return g.icon
        case .custom: return nil
        }
    }

    @IBAction private func didTapSeeAll(_ sender: Any) {
        showAll.toggle()
        loadStyles()
        if let sheet = sheetPresentationController {
            sheet.animateChanges { sheet.detents = showAll ? [.large()] : sheet.detents }
        }
    }

    @IBAction private func didTapStrength(_ sender: UIControl) {
        strength = sender.tag
        DS.Haptic.selection()
        applyStrength(animated: true)
    }

    private func applyStrength(animated: Bool) {
        let inset = OnboardingLayout(size: view.dsAdaptiveReferenceSize).value(3)
        let width = (strengthView.bounds.width - 2 * inset) / 3
        let labels = strengthLabels.sorted { $0.tag < $1.tag }
        let changes = {
            self.strengthKnobLeading.constant = inset + width * CGFloat(self.strength)
            for (i, l) in labels.enumerated() {
                l.font = DS.Font.geologica(i == self.strength ? .semiBold : .medium, l.font.pointSize)
                l.textColor = i == self.strength ? DS.Color.textPrimary : DS.Color.textSecondary
            }
            self.strengthView.layoutIfNeeded()
        }
        animated ? UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0,
                                  animations: changes) : changes()
    }

    private func updateRestyle() {
        restyleButton.inactive = selected == nil
        restyleButton.isUserInteractionEnabled = selected != nil
    }

    @IBAction private func didTapRestyle(_ sender: Any) {
        guard let selected else { return }
        DS.Haptic.medium()
        let onRestyle = self.onRestyle
        let keep = keepSwitch.isOn
        let strength = self.strength
        dismiss(animated: true) { onRestyle?(selected, keep, strength) }
    }

    @IBAction private func didTapClose(_ sender: Any) {
        dismiss(animated: true)
    }
}

extension ChangeStyleSheetViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { styles.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ChangeStyleCell.reuseID, for: indexPath)
        if let cell = cell as? ChangeStyleCell {
            let style = styles[indexPath.item]
            cell.configure(title: style.title, imagePath: imagePath(for: style),
                           current: style.title == currentStyleName, selected: style == selected)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let style = styles[indexPath.item]
        guard style.title != currentStyleName else { return }
        selected = style
        DS.Haptic.selection()
        collectionView.reloadData()
        updateRestyle()
        restyleButton.pulse()
    }
}

/// R7 style thumbnail 104 r18 with "Current" tag / lime selection. Layout: ChangeStyleCell.xib.
final class ChangeStyleCell: DSAdaptiveCollectionViewCell {
    static let reuseID = "ChangeStyleCell"

    @IBOutlet private weak var thumbImageView: UIImageView!
    @IBOutlet private weak var ringView: UIView!
    @IBOutlet private weak var checkView: UIView!
    @IBOutlet private weak var currentTag: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    private var path: String?

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbImageView.image = nil
    }

    func configure(title: String, imagePath: String?, current: Bool, selected: Bool) {
        titleLabel.text = title
        titleLabel.font = DS.Font.geologica(selected ? .semiBold : .regular, titleLabel.font.pointSize)
        (currentTag.subviews.first as? UILabel)?.text = "Current".localized
        currentTag.isHidden = !current
        UIView.animate(withDuration: 0.25) {
            self.ringView.alpha = selected ? 1 : 0
            self.checkView.alpha = selected ? 1 : 0
        }
        path = imagePath
        if let imagePath {
            CatalogImage.load(imagePath) { [weak self] image in
                guard self?.path == imagePath else { return }
                self?.thumbImageView.image = image
            }
        }
        isAccessibilityElement = true
        accessibilityLabel = current ? String(format: "%@, current".localized, title) : title
        accessibilityTraits = selected ? [.button, .selected] : .button
    }
}
