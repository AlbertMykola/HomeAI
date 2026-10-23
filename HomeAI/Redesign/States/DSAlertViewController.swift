import UIKit

/// A/12 Generic error alert / Discard edits alert: dim fades 0.25 s, the card scales 1.12 → 1 with a 0.3 s fade.
/// Layout: States.storyboard.
final class DSAlertViewController: UIViewController {

    struct Action {
        enum Style { case cancel, primary, destructive }
        let title: String
        let style: Style
        var handler: (() -> Void)?
    }

    @IBOutlet private weak var dimView: UIView!
    @IBOutlet private weak var cardView: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var messageLabel: UILabel!
    @IBOutlet private var buttons: [DSPressableControl]!
    @IBOutlet private var buttonLabels: [UILabel]!
    // iPhone Duo unfolded, landscape (Figma Duo/L/12): the card centres in the pane it belongs to, never on the
    // hinge; the dim still covers the whole screen. Sets authored in States.storyboard (phone 999 / panes 1).
    @IBOutlet private var phoneConstraints: [NSLayoutConstraint]!
    @IBOutlet private var leftPaneConstraints: [NSLayoutConstraint]!
    @IBOutlet private var rightPaneConstraints: [NSLayoutConstraint]!

    private var alertTitle = ""
    private var message: String?
    private var actions: [Action] = []
    private var pane: DSPane = .right

    /// `source`: the view the alert is about (its pane hosts the card on the unfolded Duo). Defaults to the
    /// presenter's own pane, or the controls pane (right) for a full-width screen.
    static func show(from presenter: UIViewController, title: String, message: String?, actions: [Action],
                     source: UIView? = nil) {
        let vc = AppStoryboard.instantiate(DSAlertViewController.self)
        vc.alertTitle = title
        vc.message = message
        vc.actions = Array(actions.prefix(2))
        vc.pane = DSPane.of(source ?? presenter.view, default: .right)
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        presenter.present(vc, animated: false)
    }

    /// "Something went wrong" with Cancel / Retry (dev note: no technical texts; log error_shown with the code).
    static func showGenericError(from presenter: UIViewController, code: String, retry: @escaping () -> Void) {
        AmplitudeService.shared.logRedesignEvent("error_shown", properties: ["code": code])
        show(from: presenter, title: "Something went wrong".localized,
             message: "We couldn't load this. Check your connection and try again.".localized,
             actions: [Action(title: "Cancel".localized, style: .cancel),
                       Action(title: "Retry".localized, style: .primary, handler: retry)])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = alertTitle
        messageLabel.text = message
        messageLabel.isHidden = message == nil
        let sorted = buttons.sorted { $0.tag < $1.tag }
        let labels = buttonLabels.sorted { $0.tag < $1.tag }
        for (i, button) in sorted.enumerated() {
            guard i < actions.count else { button.isHidden = true; continue }
            let action = actions[i]
            labels[i].text = action.title
            switch action.style {
            case .cancel:
                button.backgroundColor = UIColor(named: "dsChip")
                labels[i].textColor = DS.Color.textPrimary
            case .primary:
                button.backgroundColor = DS.Color.lime
                labels[i].textColor = .black
            case .destructive:
                button.backgroundColor = UIColor(hex: "FF3B30").withAlphaComponent(0.12)
                labels[i].textColor = UIColor(hex: "FF3B30")
            }
            button.accessibilityLabel = action.title
        }
        dimView.alpha = 0
        cardView.alpha = 0
        cardView.transform = CGAffineTransform(scaleX: 1.12, y: 1.12)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let inPane = dsWantsWideLandscape
        let sets: [([NSLayoutConstraint], Bool)] = [
            (phoneConstraints, !inPane), (leftPaneConstraints, inPane && pane == .left),
            (rightPaneConstraints, inPane && pane == .right)
        ]
        sets.forEach { set, _ in set.forEach { $0.priority = UILayoutPriority(1) } }
        sets.filter(\.1).forEach { set, _ in set.forEach { $0.priority = UILayoutPriority(999) } }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.25) { self.dimView.alpha = 1 }
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.cardView.alpha = 1
            self.cardView.transform = .identity
        }
        UIAccessibility.post(notification: .screenChanged, argument: titleLabel)
    }

    @IBAction private func didTapButton(_ sender: UIControl) {
        let handler = actions.indices.contains(sender.tag) ? actions[sender.tag].handler : nil
        UIView.animate(withDuration: 0.2, animations: {
            self.dimView.alpha = 0
            self.cardView.alpha = 0
            self.cardView.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }, completion: { _ in
            self.dismiss(animated: false) { handler?() }
        })
    }
}
