import UIKit

/// Base for every wizard step: custom nav bar, stepper, back / discard handling.
class WizardStepViewController: UIViewController {

    @IBOutlet weak var navBar: WizardNavBar!
    @IBOutlet weak var titleStack: UIStackView?

    var session: WizardSession!
    var step: WizardSession.Step { .photo }
    private var didConfigureStepper = false

    required override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    /// Builds a step from its XIB (named after the class).
    static func make(session: WizardSession) -> Self {
        let vc = Self(nibName: String(describing: self), bundle: .main)
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
            navBar.configure(step: session.index(of: step), total: session.steps.count, animated: animated)
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }

    // MARK: Nav bar (responder-chain actions from WizardNavBar.xib)

    @IBAction func didTapWizardBack(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    /// ✕ — W1 leaves right away, later steps confirm first (A/04 · Discard design?).
    @IBAction func didTapWizardClose(_ sender: Any) {
        guard step != .photo || session.photo != nil else {
            exitWizard()
            return
        }
        let alert = UIAlertController(title: "Discard this design?".localized,
                                      message: "Your photo and choices won't be saved.".localized,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Keep editing".localized, style: .cancel))
        alert.addAction(UIAlertAction(title: "Discard".localized, style: .destructive) { [weak self] _ in
            self?.exitWizard()
        })
        DS.Haptic.warning()
        present(alert, animated: true)
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
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    /// Fade + offset entrance helper (stagger in ms from the dev notes).
    func enter(_ views: [UIView?], from delay: TimeInterval, step: TimeInterval, dy: CGFloat = 10,
               dx: CGFloat = 0, scale: CGFloat = 1, spring: Bool = false) {
        for (i, v) in views.enumerated() {
            DS.Motion.enter(v, delay: delay + Double(i) * step, dy: dy, dx: dx, scale: scale, spring: spring)
        }
    }
}
