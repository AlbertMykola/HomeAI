import UIKit

/// Base for every wizard step: custom nav bar, stepper, back / discard handling.
class WizardStepViewController: UIViewController, DSWideLayoutFullWidth {

    @IBOutlet weak var navBar: WizardNavBar!
    @IBOutlet weak var titleStack: UIStackView?
    /// iPhone Duo unfolded, landscape: the room photo stays visible on the right while you choose
    /// (room / style / final steps; layouts in Wizard.storyboard, priorities swapped here).
    @IBOutlet weak var previewPaneView: UIView?
    @IBOutlet weak var previewImageView: UIImageView?
    @IBOutlet var listOnlyConstraints: [NSLayoutConstraint]?
    @IBOutlet var splitConstraints: [NSLayoutConstraint]?
    private var showsPreview = false

    var dsUsesFullWidth: Bool { previewPaneView != nil && wantsPreview }

    private var wantsPreview: Bool {
        guard let window = view.window else { return false }
        let size = (navigationController?.view ?? view).bounds.size
        return DSWideLayout.isWide(size.width - window.safeAreaInsets.left - window.safeAreaInsets.right)
            && size.width > size.height
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        guard let pane = previewPaneView else { return }
        previewImageView?.image = session.photo
        let preview = wantsPreview
        guard preview != showsPreview else { return }
        showsPreview = preview
        listOnlyConstraints?.forEach { $0.priority = UILayoutPriority(preview ? 1 : 999) }
        splitConstraints?.forEach { $0.priority = UILayoutPriority(preview ? 999 : 1) }
        pane.isHidden = !preview
    }

    var session: WizardSession!
    var step: WizardSession.Step { .photo }
    private var didConfigureStepper = false

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    /// Loads a step from its editable storyboard scene.
    static func make(session: WizardSession) -> Self {
        let vc = AppStoryboard.instantiate(Self.self)
        vc.session = session
        vc.hidesBottomBarWhenPushed = true
        return vc
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.hidesBackButton = true
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        if !didConfigureStepper {
            didConfigureStepper = true
            // Edit from Result is a single screen: no stepper.
            navBar.configure(step: session.index(of: step), total: session.isResultEdit ? 0 : session.steps.count,
                             animated: animated)
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .default }

    // MARK: Nav bar (responder-chain actions from Wizard.storyboard)

    @IBAction func didTapWizardBack(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    /// ✕ — W1 leaves right away, later steps confirm first (A/04 · Discard design?).
    @IBAction func didTapWizardClose(_ sender: Any) {
        guard !session.isResultEdit, step != .photo || session.photo != nil else {
            exitWizard()
            return
        }
        DS.Haptic.warning()
        DSAlertViewController.show(from: self, title: "Discard this design?".localized,
                                   message: "Your photo and choices won't be saved.".localized, actions: [
            .init(title: "Keep editing".localized, style: .cancel),
            .init(title: "Discard".localized, style: .destructive) { [weak self] in self?.exitWizard() }
        ])
    }

    func exitWizard() {
        guard let nav = navigationController else { return }
        if let first = nav.viewControllers.firstIndex(where: { $0 is WizardStepViewController }), first > 0 {
            nav.popToViewController(nav.viewControllers[first - 1], animated: true)
        } else {
            nav.popToRootViewController(animated: true)
        }
    }

    // MARK: Flow

    func goToNextStep() {
        let steps = session.steps
        guard let i = steps.firstIndex(of: step), i + 1 < steps.count else { return }
        push(steps[i + 1])
    }

    /// Jump back to a previous step if it's in the stack (W4 summary chips), keeping the rest of the state.
    func returnTo(_ target: WizardSession.Step) {
        guard let nav = navigationController else { return }
        if let vc = nav.viewControllers.first(where: { ($0 as? WizardStepViewController)?.step == target }) {
            nav.popToViewController(vc, animated: true)
        }
    }

    private func push(_ step: WizardSession.Step) {
        let vc: WizardStepViewController
        switch step {
        case .photo: vc = WizardPhotoViewController.make(session: session)
        case .room: vc = WizardRoomViewController.make(session: session)
        case .style: vc = WizardStyleViewController.make(session: session)
        case .final: vc = WizardFinalViewController.make(session: session)
        case .tool: vc = ToolStepFactory.make(session: session)
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: Generation (W4 and every A/07 tool)

    /// Offline / credits checks, then G1. `configure` fills the prompt manager right before starting.
    func generate(styleTitle: String?, configure: @escaping (GemeniPromptManager) -> Void) {
        view.endEditing(true)
        guard AIPhotoConsent.hasConsent else {
            AIPhotoConsent.run(from: self) { [weak self] in self?.generate(styleTitle: styleTitle, configure: configure) }
            return
        }
        guard NetworkMonitor.shared.isOnline else {
            // A/12 Offline · full screen: comes back here by itself when the network returns.
            OfflineGate.run(from: self) { [weak self] in self?.generate(styleTitle: styleTitle, configure: configure) }
            return
        }
        let start = { [weak self] in
            guard let self else { return }
            configure(self.session.promptManager)
            self.launchGeneration(styleTitle: styleTitle)
        }
        switch GenerationAccess.evaluate() {
        case .allowed:
            DS.Haptic.medium()
            start()
        case .requiresSubscription:
            OutOfCreditsSheetViewController.present(from: self, photo: session.photo, onUnlocked: start)
        case .dailyLimitExceeded:
            GenerationAccess.requestProcessingIfAllowed(presentingFrom: self)
        }
    }

    private func launchGeneration(styleTitle: String?) {
        let session = self.session!
        NavigationManager.shared.showGeneration(manager: session.promptManager, sourcePhoto: session.photo,
                                                styleTitle: styleTitle, onChangePhoto: {
            // "Change photo" from G3/G4 → W1 again; the rest of the settings is kept.
            session.photo = nil
            NavigationManager.shared.pushWizardStep(WizardPhotoViewController.make(session: session))
        }, onEditRequest: {
            // A/12 Content blocked → back to the last settings step (W4 / tool) with everything kept.
            let last: WizardStepViewController = session.steps.last == .tool
                ? ToolStepFactory.make(session: session) : WizardFinalViewController.make(session: session)
            NavigationManager.shared.pushWizardStep(last)
        })
        // Drop the wizard behind the generation screen so collapsing (⌄) lands where the user started.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let nav = self?.navigationController,
                  let first = nav.viewControllers.firstIndex(where: { $0 is WizardStepViewController }), first > 0 else { return }
            nav.setViewControllers(Array(nav.viewControllers[..<first]), animated: false)
        }
    }

    /// The generation CTA shows duration; entitlement and credit checks happen in generate().
    func costLine(seconds: Int = 30) -> String {
        String(format: "About %d s".localized, seconds)
    }

    /// Fade + offset entrance helper (stagger in ms from the dev notes).
    func enter(_ views: [UIView?], from delay: TimeInterval, step: TimeInterval, dy: CGFloat = 10,
               dx: CGFloat = 0, scale: CGFloat = 1, spring: Bool = false) {
        for (i, v) in views.enumerated() {
            DS.Motion.enter(v, delay: delay + Double(i) * step, dy: dy, dx: dx, scale: scale, spring: spring)
        }
    }
}
