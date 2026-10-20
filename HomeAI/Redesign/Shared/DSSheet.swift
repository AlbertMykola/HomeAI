import UIKit

/// Bottom sheets of the redesign: system sheet, grabber, 38 pt corners, height fitted to the XIB content.
enum DSSheet {

    /// Figma's floating Share sheet: 8 pt screen inset, full rounded corners, no presenter scaling.
    @discardableResult static func presentFloating(_ vc: UIViewController, from presenter: UIViewController,
                                                   height: CGFloat) -> UIViewControllerTransitioningDelegate {
        let transition = DSFloatingSheetTransition(height: height)
        vc.modalPresentationStyle = .custom
        vc.transitioningDelegate = transition
        #if DEBUG
        let animated = !(AppQA.enabled && AppQA.snapshot)
        #else
        let animated = true
        #endif
        presenter.present(vc, animated: animated)
        return transition
    }

    static func present(_ vc: UIViewController, from presenter: UIViewController, height: CGFloat? = nil,
                        large: Bool = false) {
        vc.modalPresentationStyle = .pageSheet
        if let sheet = vc.sheetPresentationController {
            if large {
                sheet.detents = [.large()]
            } else if #available(iOS 16.0, *), let height {
                sheet.detents = [.custom { [weak presenter] context in
                    guard let presenter else { return min(height, context.maximumDetentValue) }
                    let scale = OnboardingLayout(size: presenter.view.window?.dsLayoutSize ?? presenter.view.dsLayoutSize).scale
                    return min(height * scale, context.maximumDetentValue)
                }]
            } else {
                sheet.detents = [.medium(), .large()]
            }
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = OnboardingLayout(size: presenter.view.window?.dsLayoutSize ?? presenter.view.dsLayoutSize).value(38)
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        #if DEBUG
        if AppQA.enabled && AppQA.snapshot { presenter.present(vc, animated: false); return }
        #endif
        presenter.present(vc, animated: true)
    }

    /// Height the storyboard content needs at the presenter's width.
    static func fittingHeight(of vc: UIViewController, width: CGFloat) -> CGFloat {
        vc.loadViewIfNeeded()
        let size = vc.view.systemLayoutSizeFitting(CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
                                                   withHorizontalFittingPriority: .required,
                                                   verticalFittingPriority: .fittingSizeLevel)
        return size.height
    }
}

private final class DSFloatingSheetTransition: NSObject, UIViewControllerTransitioningDelegate {
    let height: CGFloat
    init(height: CGFloat) { self.height = height }

    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?,
                                source: UIViewController) -> UIPresentationController? {
        DSFloatingSheetPresentation(presentedViewController: presented, presenting: presenting, height: height)
    }
    func animationController(forPresented presented: UIViewController, presenting: UIViewController,
                             source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        DSFloatingSheetAnimator(presenting: true)
    }
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        DSFloatingSheetAnimator(presenting: false)
    }
}

private final class DSFloatingSheetPresentation: UIPresentationController, UIGestureRecognizerDelegate {
    private let height: CGFloat
    private let dim = AppStoryboard.component(SheetBackdropView.self)

    init(presentedViewController: UIViewController, presenting: UIViewController?, height: CGFloat) {
        self.height = height
        super.init(presentedViewController: presentedViewController, presenting: presenting)
        dim.backgroundColor = .black
        dim.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(close)))
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        guard let container = containerView else { return .zero }
        let scale = OnboardingLayout(size: container.dsLayoutSize).scale
        let inset = 8 * scale
        let safeWidth = container.dsLayoutSize.width
        let width = min(safeWidth - 2 * inset, 560)
        let available = container.bounds.height - container.safeAreaInsets.top - 2 * inset
        let h = min(height * scale, available)
        return CGRect(x: container.safeAreaInsets.left + (safeWidth - width) / 2,
                      y: container.bounds.height - inset - h, width: width, height: h)
    }

    override func presentationTransitionWillBegin() {
        guard let container = containerView else { return }
        dim.frame = container.bounds; dim.alpha = 0
        container.insertSubview(dim, at: 0)
        presentedView?.layer.cornerCurve = .continuous
        presentedView?.layer.cornerRadius = 38 * OnboardingLayout(size: container.bounds.size).scale
        presentedView?.clipsToBounds = true
        let pan = UIPanGestureRecognizer(target: self, action: #selector(drag(_:)))
        pan.delegate = self
        presentedView?.addGestureRecognizer(pan)
        if let coordinator = presentedViewController.transitionCoordinator {
            coordinator.animate { _ in self.dim.alpha = 0.3 }
        } else { dim.alpha = 0.3 }
    }

    override func dismissalTransitionWillBegin() {
        if let coordinator = presentedViewController.transitionCoordinator {
            coordinator.animate { _ in self.dim.alpha = 0 }
        } else { dim.alpha = 0 }
    }

    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        guard let container = containerView, let view = presentedView else { return }
        let rect = frameOfPresentedViewInContainerView
        view.bounds.size = rect.size
        view.center = CGPoint(x: rect.midX, y: rect.midY)
        view.layer.cornerRadius = 38 * OnboardingLayout(size: container.bounds.size).scale
        dim.frame = container.bounds
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer, let view = presentedView else { return false }
        let velocity = pan.velocity(in: view)
        let scale = OnboardingLayout(size: containerView?.bounds.size ?? view.bounds.size).scale
        return pan.location(in: view).y < 44 * scale && velocity.y > abs(velocity.x)
    }

    @objc private func close() { presentedViewController.dismiss(animated: true) }

    @objc private func drag(_ pan: UIPanGestureRecognizer) {
        guard let view = presentedView else { return }
        let y = max(0, pan.translation(in: view).y)
        switch pan.state {
        case .changed:
            view.transform = CGAffineTransform(translationX: 0, y: y)
            dim.alpha = 0.3 * max(0, 1 - y / max(1, view.bounds.height))
        case .ended:
            if y > view.bounds.height * 0.2 || pan.velocity(in: view).y > 900 { close(); return }
            fallthrough
        case .cancelled:
            UIView.animate(withDuration: DS.Motion.reduceMotion ? 0.1 : 0.3, delay: 0, usingSpringWithDamping: 0.85,
                           initialSpringVelocity: 0, options: .allowUserInteraction) {
                view.transform = .identity; self.dim.alpha = 0.3
            }
        default: break
        }
    }
}

private final class DSFloatingSheetAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let presenting: Bool
    init(presenting: Bool) { self.presenting = presenting }
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        DS.Motion.reduceMotion ? 0.15 : (presenting ? 0.55 : 0.25)
    }
    func animateTransition(using context: UIViewControllerContextTransitioning) {
        let key: UITransitionContextViewControllerKey = presenting ? .to : .from
        guard let vc = context.viewController(forKey: key) else { context.completeTransition(false); return }
        let view = vc.view!
        if presenting {
            context.containerView.addSubview(view)
            view.frame = context.finalFrame(for: vc)
            if DS.Motion.reduceMotion { view.alpha = 0 }
            else { view.transform = CGAffineTransform(translationX: 0, y: context.containerView.bounds.height - (view.center.y - view.bounds.height / 2)) }
        }
        UIView.animate(withDuration: context.isAnimated ? transitionDuration(using: context) : 0,
                       delay: 0, usingSpringWithDamping: presenting ? 0.75 : 1, initialSpringVelocity: 0,
                       options: [.allowUserInteraction, .beginFromCurrentState]) {
            if self.presenting { view.transform = .identity; view.alpha = 1 }
            else if DS.Motion.reduceMotion { view.alpha = 0 }
            else { view.transform = CGAffineTransform(translationX: 0, y: context.containerView.bounds.height - (view.center.y - view.bounds.height / 2)) }
        } completion: { _ in
            context.completeTransition(!context.transitionWasCancelled)
        }
    }
}
