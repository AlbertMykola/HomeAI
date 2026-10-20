import UIKit

final class OnboardingPageViewController: UIViewController, OBPageChild {
    enum Page: Int {
        case room, tools, words
        var title: String { "onboarding_\(self)_title".localized }
        var subtitle: String { "onboarding_\(self)_subtitle".localized }
    }

    @IBOutlet private(set) weak var heroView: OnboardingHeroView!
    @IBOutlet private weak var panelView: UIView!
    @IBOutlet private(set) weak var titleLabel: UILabel!
    @IBOutlet private(set) weak var subtitleLabel: UILabel!
    @IBOutlet private weak var stepper: OnboardingStepper!
    @IBOutlet private(set) weak var nextButton: DSPrimaryButton!
    @IBOutlet private weak var nextLabel: UILabel!
    @IBOutlet private weak var panelHeight: NSLayoutConstraint!
    @IBOutlet private weak var titleHeight: NSLayoutConstraint!
    @IBOutlet private weak var subtitleHeight: NSLayoutConstraint!
    @IBOutlet private weak var stepHeight: NSLayoutConstraint!
    @IBOutlet private weak var buttonGap: NSLayoutConstraint!
    @IBOutlet private weak var panelTopPadding: NSLayoutConstraint!
    @IBOutlet private weak var titleTop: NSLayoutConstraint!
    @IBOutlet private weak var subtitleTop: NSLayoutConstraint!
    @IBOutlet private weak var buttonBottom: NSLayoutConstraint!
    @IBOutlet private weak var buttonHeight: NSLayoutConstraint!
    @IBOutlet private var horizontalInsets: [NSLayoutConstraint]!
    @IBOutlet private weak var horizontalViewportView: OnboardingViewportView!
    @IBOutlet private var viewportSafeConstraints: [NSLayoutConstraint]!
    @objc private var horizontalViewportGuide: UILayoutGuide? {
        usesParentHorizontalViewport ? horizontalViewportView?.layoutMarginsGuide : nil
    }

    private(set) var page: Page = .room
    weak var obDelegate: OBPageChildDelegate?
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

    static func make(page: Page) -> OnboardingPageViewController {
        let identifier = page == .tools ? "OnboardingTools" : page == .words ? "OnboardingWords" : "OnboardingPageViewController"
        let controller = AppStoryboard.instantiate(OnboardingPageViewController.self, identifier: identifier)
        controller.page = page
        return controller
    }

    required init?(coder: NSCoder) { super.init(coder: coder) }

    override var preferredStatusBarStyle: UIStatusBarStyle { page == .tools ? .darkContent : .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        if usesParentHorizontalViewport { applyParentViewport() }
        view.clipsToBounds = true
        titleLabel.text = page.title
        subtitleLabel.text = page.subtitle
        nextLabel.text = "ob_continue".localized
        nextLabel.textColor = .black
        nextButton.accessibilityLabel = nextLabel.text
        nextButton.accessibilityIdentifier = "onboarding.continue"
        stepper.currentPage = page.rawValue
        heroView.configure(page: page)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let layout = OnboardingLayout(size: layoutSize)
        let s = layout.scale
        let inset = layout.inset(in: layoutSize.width)
        horizontalInsets.forEach { $0.constant = inset }
        // Reset to the design constants before scaling: repeated layout must be idempotent.
        let scaledConstraints: [(NSLayoutConstraint, CGFloat)] = [
            (panelTopPadding, 28), (titleTop, 14), (subtitleTop, 14), (buttonBottom, 10), (buttonHeight, 56),
            (stepHeight, 6), (buttonGap, 16)
        ]
        for (constraint, base) in scaledConstraints {
            constraint.constant = base
            constraint.scaleConstant(height: layout.referenceHeight)
        }
        buttonBottom.constant = max(layout.value(10), layout.value(44) - view.safeAreaInsets.bottom)
        titleLabel.font = layout.font(.semiBold, 30)
        subtitleLabel.font = layout.font(.regular, 15)
        style(titleLabel, lineHeight: layout.value(33.6), kern: -0.3 * s)
        style(subtitleLabel, lineHeight: layout.value(21))
        nextLabel.font = layout.font(.semiBold, 17)
        panelView.layer.cornerRadius = layout.value(34)
        panelView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        stepper.scale = s
        // Auto Layout rounds the two edges to device pixels. Measure conservatively
        // so a word at the wrap boundary cannot lose a line after that rounding.
        let width = floor(layoutSize.width - inset * 2)
        let titleSize = titleLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let subtitleSize = subtitleLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        // UILabel's intrinsic height can lag behind an attributed font/width change during resize.
        titleHeight.constant = ceil(titleSize.height)
        subtitleHeight.constant = ceil(subtitleSize.height)
        let contentHeight = layout.value(28 + 6 + 14 + 14 + 16 + 56) + titleHeight.constant + subtitleHeight.constant + buttonBottom.constant + view.safeAreaInsets.bottom
        panelHeight.constant = max(layout.value(300) + max(0, view.safeAreaInsets.bottom - layout.value(34)), contentHeight)
        heroView.panelTop = view.bounds.height - panelHeight.constant
        heroView.layoutScale = s
    }

    private func style(_ label: UILabel, lineHeight: CGFloat, kern: CGFloat = 0) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
        label.attributedText = NSAttributedString(string: label.text ?? "", attributes: [
            .font: label.font as Any, .foregroundColor: label.textColor as Any,
            .paragraphStyle: paragraph, .kern: kern
        ])
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        obPauseHeroAnimation()
    }

    func obPrepareHeroForAppearance() { heroView?.prepare() }
    func obPauseHeroAnimation() { heroView?.pause() }
    func obStartHeroAnimation() { heroView?.start() }

    @IBAction private func nextAction(_ sender: UIControl) {
        DS.Haptic.light()
        obDelegate?.obChildRequestsNext(self)
    }

}
