import UIKit

final class OnboardingGoalViewController: UIViewController, OBPageChild {
    @IBOutlet private(set) weak var titleLabel: UILabel!
    @IBOutlet private(set) weak var subtitleLabel: UILabel!
    @IBOutlet private weak var stepper: OnboardingStepper!
    @IBOutlet private var options: [OnboardingGoalControl]!
    @IBOutlet private weak var contentTop: NSLayoutConstraint!
    @IBOutlet private weak var gridTop: NSLayoutConstraint!
    @IBOutlet private weak var cardHeight: NSLayoutConstraint!
    @IBOutlet private var horizontalInsets: [NSLayoutConstraint]!
    @IBOutlet private var rowStacks: [UIStackView]!
    @IBOutlet private weak var rows: UIStackView!
    @IBOutlet private weak var horizontalViewportView: OnboardingViewportView!
    @IBOutlet private var viewportSafeConstraints: [NSLayoutConstraint]!
    /// iPhone Duo unfolded, landscape (Figma Duo/L/01 · O4): dots, title and subtitle on a tinted left pane, the
    /// 2×2 grid in the right column. Sets in Onboarding.storyboard (phone 999 / split 1); iPhones unchanged.
    @IBOutlet private var phoneConstraints: [NSLayoutConstraint]!
    @IBOutlet private var splitConstraints: [NSLayoutConstraint]!
    @IBOutlet private var splitTextTrailing: [NSLayoutConstraint]!
    @IBOutlet private weak var splitPaneView: UIView!
    @IBOutlet private weak var splitPaneTrailing: NSLayoutConstraint!
    @IBOutlet private weak var splitGridLeading: NSLayoutConstraint!
    private lazy var layoutSwitch = DSLayoutSwitch(phone: phoneConstraints, unfolded: splitConstraints)
    private var isSplit: Bool {
        UIDevice.isFoldablePhone && view.bounds.width > view.bounds.height && DSWideLayout.isWide(view.bounds.width)
    }
    /// iPhone Duo unfolded, portrait (Figma Duo/P/01 · O4): the header centred above the hinge, the grid below it.
    private var isUnfoldedPortrait: Bool {
        UIDevice.isFoldablePhone && view.bounds.width <= view.bounds.height && DSWideLayout.isWide(view.bounds.width)
    }
    @objc private var horizontalViewportGuide: UILayoutGuide? {
        usesParentHorizontalViewport ? horizontalViewportView?.layoutMarginsGuide : nil
    }
    weak var obDelegate: OBPageChildDelegate?
    private var selectionWork: DispatchWorkItem?
    private(set) var selectedGoal: OnboardingGoal?
    private var didSubmit = false
    private var usesParentHorizontalViewport = false
    private var layoutSize: CGSize { usesParentHorizontalViewport ? view.bounds.size : view.dsLayoutSize }

    func obUseParentHorizontalViewport() {
        guard !usesParentHorizontalViewport else { return }
        usesParentHorizontalViewport = true
        if isViewLoaded {
            applyParentViewport()
            view.setNeedsLayout()
        }
    }

    private func applyParentViewport() {
        viewportSafeConstraints.forEach { $0.priority = .init(250) }
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }
    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        if usesParentHorizontalViewport { applyParentViewport() }
        titleLabel.text = "onboarding_goal_title".localized
        subtitleLabel.text = "onboarding_goal_subtitle".localized
        stepper.currentPage = 3
        for option in options {
            option.goal = OnboardingGoal.allCases[option.tag]
            option.addTarget(self, action: #selector(selectGoal(_:)), for: .touchUpInside)
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let split = isSplit
        _ = layoutSwitch.set(unfolded: split)
        splitPaneView.isHidden = !split
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let layout = OnboardingLayout(size: layoutSize)
        let split = isSplit
        let unfoldedPortrait = isUnfoldedPortrait
        let inset = unfoldedPortrait ? layout.value(20) : layout.inset(in: layoutSize.width, base: 20)
        horizontalInsets.forEach { $0.constant = inset }
        // Split: the left pane uses the larger Figma type (Duo/L/01 · O4: 42/47 title, 20/27 subtitle).
        titleLabel.font = layout.font(.semiBold, split ? 42 : 34)
        subtitleLabel.font = layout.font(.regular, split ? 20 : 16)
        let titleLine = layout.value(split ? 47 : 37.4), subtitleLine = layout.value(split ? 27 : 22.4)
        for (label, lineHeight, kern) in [(titleLabel!, titleLine, layout.value(split ? -0.42 : -0.34)), (subtitleLabel!, subtitleLine, CGFloat(0))] {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .left
            paragraph.minimumLineHeight = lineHeight
            paragraph.maximumLineHeight = lineHeight
            label.attributedText = NSAttributedString(string: label.text ?? "", attributes: [
                .font: label.font as Any, .foregroundColor: label.textColor as Any, .paragraphStyle: paragraph, .kern: kern
            ])
        }
        stepper.scale = layout.scale * (split ? 1.2 : 1)
        let closedDuo = UIDevice.isFoldablePhone && !DSWideLayout.isWide(layoutSize.width)
        // Closed Duo: no notch above the content (the status bar is on the right rail), so the stepper sits at 50.
        contentTop.constant = split ? 0 : closedDuo ? 44 : max(layout.value(42), layout.value(96) - view.safeAreaInsets.top)
        rowStacks.forEach { $0.spacing = layout.value(13) }
        rows.spacing = layout.value(13)
        // Closed iPhone Duo (Figma Duo/C/01 · O4): a 678 pt screen fits the 2×2 grid and the skip link when the
        // cards are 185 pt and the grid sits 43 pt in and ends 24 pt before the status rail (the title keeps its 20 pt inset). Other iPhones unchanged.
        options.forEach { $0.scale = layout.scale * (closedDuo ? 0.9 : unfoldedPortrait ? 0.86 : 1) }
        cardHeight.constant = closedDuo ? 185 : layout.value(unfoldedPortrait ? 174 : 206)
        rows.isLayoutMarginsRelativeArrangement = closedDuo || unfoldedPortrait
        // Unfolded portrait: 261 pt cards, 67 pt from the edges (the title keeps its 20 pt inset).
        rows.layoutMargins = closedDuo ? UIEdgeInsets(top: 0, left: 23, bottom: 0, right: 0)
            : unfoldedPortrait ? UIEdgeInsets(top: 0, left: 47, bottom: 0, right: 47) : .zero
        // Split: the panes meet at the hinge (window centre), not at this page's centre (the rail is beside it).
        let hinge = split ? view.window.map { $0.bounds.midX - view.bounds.midX } ?? 0 : 0
        if split {
            splitPaneTrailing.constant = hinge
            splitGridLeading.constant = hinge + 22
            splitTextTrailing.forEach { $0.constant = hinge - 24 }
        }
        let width = split ? view.bounds.width / 2 + hinge - 48 : layoutSize.width - inset * 2
        let titleHeight = titleLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        let subtitleHeight = subtitleLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        // The scroll content can grow for translations and short windows; the footer stays reachable.
        let headerBottom = layout.value(6 + 14 + 14) + titleHeight + subtitleHeight
        gridTop.constant = closedDuo ? 14 : max(layout.value(204) - headerBottom, layout.value(24))
        if unfoldedPortrait {
            let hinge = view.bounds.height / 2
            contentTop.constant = max(layout.value(20), (hinge - headerBottom) / 2 + layout.value(10) - view.safeAreaInsets.top)
            gridTop.constant = max(layout.value(24), hinge + layout.value(22) - view.safeAreaInsets.top - contentTop.constant - headerBottom)
        }
    }

    @objc private func selectGoal(_ sender: OnboardingGoalControl) {
        guard !didSubmit, let goal = sender.goal else { return }
        selectionWork?.cancel()
        selectedGoal = goal
        options.forEach { $0.isSelected = $0 === sender }
        DS.Haptic.selection()
        let work = DispatchWorkItem { [weak self] in self?.submit() }
        selectionWork = work
        // Long enough to see the selected tile, short enough to feel instant.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func submit() {
        guard !didSubmit, let selectedGoal else { return }
        didSubmit = true
        selectionWork = nil
        selectedGoal.save()
        if !OnboardingPreview.enabled || AppQA.enabled {
            AmplitudeService.shared.logRedesignEvent("onboarding_goal", properties: ["goal": selectedGoal.rawValue])
        }
        obDelegate?.obChildRequestsNext(self)
    }

    func obPauseHeroAnimation() {
        selectionWork?.cancel()
        selectionWork = nil
    }

    func obStartHeroAnimation() {
        // Returning by swipe must not leave a cancelled selected tile stuck.
        guard !didSubmit, selectedGoal != nil, selectionWork == nil else { return }
        selectedGoal = nil
        options.forEach { $0.isSelected = false }
    }

    func obSetActionLoading(_ loading: Bool) {
        view.isUserInteractionEnabled = !loading
    }
}

final class OnboardingGoalControl: DSPressableControl {
    var goal: OnboardingGoal? {
        didSet {
            icon.image = goal.flatMap { UIImage(named: $0.image) }
            title.text = goal?.title
            subtitle.text = goal?.subtitle
            accessibilityLabel = [goal?.title, goal?.subtitle].compactMap { $0 }.joined(separator: ", ")
            accessibilityIdentifier = "onboarding.goal.\(goal?.rawValue ?? "")"
        }
    }
    var scale: CGFloat = 1 { didSet { setNeedsLayout() } }
    @IBOutlet private weak var icon: UIImageView!
    @IBOutlet private weak var title: UILabel!
    @IBOutlet private weak var subtitle: UILabel!
    @IBOutlet private weak var badge: UIImageView!
    @IBOutlet private var animatedLayoutConstraints: [NSLayoutConstraint]!
    private lazy var geometry = StoryboardGeometry(constraints: animatedLayoutConstraints)

    override func awakeFromNib() {
        super.awakeFromNib()
        hapticOnPress = false
        pressedScale = 0.97
        [icon!, title!, subtitle!, badge!].forEach { $0.isUserInteractionEnabled = false }
        icon.contentMode = .scaleAspectFit
        title.numberOfLines = 2
        subtitle.numberOfLines = 2
        title.textColor = .black
        subtitle.textColor = DS.Color.textTertiary
        badge.tintColor = .black
        updateSelection()
    }

    override var isSelected: Bool { didSet { updateSelection() } }

    private func updateSelection() {
        backgroundColor = isSelected ? DS.Color.limeSoft : DS.Color.surface
        layer.borderColor = DS.Color.lime.cgColor
        layer.borderWidth = isSelected ? 2 : 0
        badge.isHidden = !isSelected
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let s = scale
        layer.cornerRadius = 28 * s
        geometry.setFrame(icon, CGRect(x: 16 * s, y: 16 * s, width: 88 * s, height: 88 * s))
        title.font = DS.Font.geologica(.semiBold, 17 * s)
        subtitle.font = DS.Font.geologica(.regular, 13 * s)
        let width = bounds.width - 32 * s
        let titleSize = title.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let subtitleSize = subtitle.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let subtitleY = bounds.height - 18 * s - subtitleSize.height
        geometry.setFrame(subtitle, CGRect(x: 16 * s, y: subtitleY, width: width, height: subtitleSize.height))
        geometry.setFrame(title, CGRect(x: 16 * s, y: subtitleY - 4 * s - titleSize.height, width: width, height: titleSize.height))
        geometry.setFrame(badge, CGRect(x: bounds.width - 36 * s, y: 14 * s, width: 22 * s, height: 22 * s))
    }
}
