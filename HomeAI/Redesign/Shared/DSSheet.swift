import UIKit

/// A sheet whose content lives in a scroll view and can't be measured from its root.
protocol DSSheetContentMeasuring: UIViewController {
    func sheetContentHeight(width: CGFloat) -> CGFloat
}

/// Bottom sheets of the redesign: system sheet, grabber, 38 pt corners, height fitted to the XIB content.
enum DSSheet {

    /// Figma's floating Share sheet: 8 pt screen inset, full rounded corners, no presenter scaling.
    @discardableResult static func presentFloating(_ vc: UIViewController, from presenter: UIViewController,
                                                   height: CGFloat) -> UIViewControllerTransitioningDelegate {
        // Unfolded Duo: in its pane like the other sheets (Figma Duo/L/06 R8).
        let pane = presenter.view.window.map { DSWideLayout.isWide($0.dsLayoutSize.width) } ?? false
        let transition = DSFloatingSheetTransition(height: height, pane: pane)
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

    /// Kept alive while a pane sheet is on screen (transitioningDelegate is weak).
    private static var paneTransitions = NSMapTable<UIViewController, UIViewControllerTransitioningDelegate>.weakToStrongObjects()

    static func present(_ vc: UIViewController, from presenter: UIViewController, height: CGFloat? = nil,
                        large: Bool = false) {
        // iPhone Duo unfolded (Figma Duo rules): the sheet sits at the bottom of its pane — the right column in
        // landscape, an iPhone-wide column in portrait — at iPhone size; the dim covers the whole screen.
        if let window = presenter.view.window, DSWideLayout.isWide(window.dsLayoutSize.width) {
            let transition = DSFloatingSheetTransition(height: large ? .greatestFiniteMagnitude : (height ?? 470), pane: true)
            paneTransitions.setObject(transition, forKey: vc)
            vc.modalPresentationStyle = .custom
            vc.transitioningDelegate = transition
            #if DEBUG
            if AppQA.enabled && AppQA.snapshot { presenter.present(vc, animated: false); return }
            #endif
            presenter.present(vc, animated: true)
            return
        }
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
    let pane: Bool
    init(height: CGFloat, pane: Bool = false) { self.height = height; self.pane = pane }

    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?,
                                source: UIViewController) -> UIPresentationController? {
        DSFloatingSheetPresentation(presentedViewController: presented, presenting: presenting, height: height, pane: pane)
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
    private let pane: Bool
    private let dim = AppStoryboard.component(SheetBackdropView.self)

    init(presentedViewController: UIViewController, presenting: UIViewController?, height: CGFloat, pane: Bool) {
        self.height = height
        self.pane = pane
        super.init(presentedViewController: presentedViewController, presenting: presenting)
        dim.backgroundColor = .black
        dim.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(close)))
    }

    /// Duo pane sheet: landscape → the right column (x 476…859, Figma 480…855); portrait → 376 pt centred.
    /// Content is laid out as an iPhone screen of the sheet's width.
    private var paneFrame: CGRect {
        guard let container = containerView else { return .zero }
        let b = container.bounds, safe = container.safeAreaInsets
        let landscape = b.width > b.height
        let width: CGFloat = landscape ? min(375, b.width - safe.right - b.midX - 8) : 376
        let x = landscape ? b.midX + 4 : (b.width - width) / 2
        let inset: CGFloat = 8
        let reference = CGSize(width: width, height: 852 * width / 393)
        if let root = presentedViewController.view as? DSAdaptiveRootView, root.referenceSizeOverride != reference {
            root.referenceSizeOverride = reference
            root.applyMetrics(size: reference)
        }
        let fittedHeight: CGFloat
        if height == .greatestFiniteMagnitude {
            fittedHeight = .greatestFiniteMagnitude
        } else if let measuring = presentedViewController as? DSSheetContentMeasuring {
            fittedHeight = measuring.sheetContentHeight(width: width)
        } else {
            fittedHeight = DSSheet.fittingHeight(of: presentedViewController, width: width)
        }
        let maxHeight = b.height - safe.top - 2 * inset
        // Like a system detent, the content height excludes the home-indicator area the sheet still covers.
        let h = min(max(fittedHeight, min(height * width / 393, maxHeight)) + safe.bottom, maxHeight)
        return CGRect(x: x, y: b.height - inset - h, width: width, height: h)
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        guard let container = containerView else { return .zero }
        if pane { return paneFrame }
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
        if pane, let view = presentedView {
            // Same grabber as the system sheets these replace on the unfolded Duo.
            let grabber = UIView()
            grabber.backgroundColor = UIColor.tertiaryLabel
            grabber.layer.cornerRadius = 2.5
            grabber.isUserInteractionEnabled = false
            grabber.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(grabber)
            NSLayoutConstraint.activate([
                grabber.topAnchor.constraint(equalTo: view.topAnchor, constant: 5),
                grabber.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                grabber.widthAnchor.constraint(equalToConstant: 36),
                grabber.heightAnchor.constraint(equalToConstant: 5)
            ])
        }
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
