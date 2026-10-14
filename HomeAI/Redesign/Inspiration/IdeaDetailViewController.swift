import UIKit

/// A/08 · I2 Detail (+ I2 · Saved): hero photo, tags, palette, Save / Try on my room.
/// Presented over the feed with `InspirationHeroTransition`. Layout: IdeaDetailViewController.xib.
final class IdeaDetailViewController: UIViewController {

    @IBOutlet private(set) weak var heroImageView: UIImageView!
    @IBOutlet private(set) weak var panelView: UIView!
    @IBOutlet private(set) weak var navView: UIView!
    @IBOutlet private(set) weak var aiTagView: UIView!
    @IBOutlet private weak var aiTagLabel: UILabel!
    @IBOutlet private weak var backButton: DSPressableControl!
    @IBOutlet private weak var navSaveControl: DSPressableControl!
    @IBOutlet private weak var shareButton: DSPressableControl!
    @IBOutlet private weak var panelStack: UIStackView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var tagsScrollView: UIScrollView!
    @IBOutlet private var tagChips: [DSChipControl]!
    @IBOutlet private weak var paletteView: UIStackView!
    @IBOutlet private weak var paletteTitleLabel: UILabel!
    @IBOutlet private var swatchControls: [DSPressableControl]!
    @IBOutlet private weak var saveControl: DSPressableControl!
    @IBOutlet private weak var saveIconView: UIImageView!
    @IBOutlet private weak var tryButton: DSPrimaryButton!
    @IBOutlet private weak var tryTitleLabel: UILabel!

    private(set) var idea: InspirationIdea!
    private var initialImage: UIImage?
    /// Tag tap → feed filter (room or style).
    var onTag: ((InspirationIdea.Room?, String?) -> Void)?
    /// Set by the transition: true while the hero zoom runs, so the entrance doesn't double up.
    var presentedWithZoom = false

    private var didRunEntrance = false

    static func make(idea: InspirationIdea, image: UIImage?) -> IdeaDetailViewController {
        let vc = IdeaDetailViewController(nibName: "IdeaDetailViewController", bundle: .main)
        vc.idea = idea
        vc.initialImage = image
        return vc
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        heroImageView.image = initialImage
        if initialImage == nil {
            CatalogImage.load(idea.image) { [weak self] image in self?.heroImageView.image = image }
        }
        aiTagLabel.text = String(format: "AI redesign · %@".localized, idea.style.localized)
        titleLabel.text = idea.title
        subtitleLabel.text = idea.subtitle
        paletteTitleLabel.text = "Palette".localized
        tryTitleLabel.text = "Try on my room".localized
        let tags = idea.tags
        tagChips.sorted { $0.tag < $1.tag }.enumerated().forEach { i, chip in
            chip.isHidden = i >= tags.count
            if i < tags.count { label(in: chip)?.text = tags[i] }
        }
        let colors = idea.palette
        swatchControls.sorted { $0.tag < $1.tag }.enumerated().forEach { i, swatch in
            swatch.isHidden = i >= colors.count
            guard i < colors.count else { return }
            swatch.backgroundColor = UIColor(hex: colors[i])
            swatch.accessibilityLabel = String(format: "Copy color %@".localized, "#" + colors[i])
        }
        applySaved(animated: false)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleDismissPan(_:)))
        pan.delegate = self
        view.addGestureRecognizer(pan)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didRunEntrance else { return }
        didRunEntrance = true
        if !presentedWithZoom, !DS.Motion.reduceMotion {
            // Hero settles 1.06 → 1 (slow spring).
            heroImageView.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
            UIView.animate(withDuration: 1.2, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0) {
                self.heroImageView.transform = .identity
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in self?.tryButton.runShimmer() }
    }

    /// Panel blocks stagger 60 ms (called by the transition once the panel is up).
    func animatePanelContent(delay: TimeInterval) {
        panelStack.arrangedSubviews.enumerated().forEach { i, v in
            DS.Motion.enter(v, delay: delay + Double(i) * 0.06, dy: 12)
        }
    }

    // MARK: Actions

    @IBAction private func didTapClose(_ sender: Any) {
        dismiss(animated: true)
    }

    @IBAction private func didTapSave(_ sender: Any) {
        let saved = IdeasStore.shared.toggle(idea)
        saved ? DS.Haptic.success() : DS.Haptic.light()
        applySaved(animated: true)
        guard saved else { return }
        DSToastView.show("Saved to Ideas".localized, style: .success, action: "View".localized, in: view,
                         topOffset: 60, duration: 2.0) { [weak self] in
            self?.dismiss(animated: true) {
                NavigationManager.shared.selectTab(.projects)
            }
        }
    }

    private func applySaved(animated: Bool) {
        let saved = IdeasStore.shared.isSaved(idea.id)
        let navIcon = navSaveControl.subviews.compactMap { $0 as? UIImageView }.first
        navIcon?.image = UIImage(systemName: saved ? "bookmark.fill" : "bookmark")
        navSaveControl.backgroundColor = saved ? DS.Color.lime : UIColor(named: "dsGlass")
        saveIconView.image = UIImage(systemName: saved ? "bookmark.fill" : "bookmark")
        saveControl.backgroundColor = saved ? .white : UIColor(named: "dsChip")
        saveControl.layer.borderWidth = saved ? 1.5 : 0
        saveControl.layer.borderColor = DS.Color.lime.cgColor
        let label = saved ? "Remove from Ideas".localized : "Save idea".localized
        navSaveControl.accessibilityLabel = label
        saveControl.accessibilityLabel = label
        guard animated, !DS.Motion.reduceMotion else { return }
        InspirationCardCell.pop(navSaveControl)
        InspirationCardCell.pop(saveControl)
    }

    @IBAction private func didTapShare(_ sender: Any) {
        guard let image = heroImageView.image else { return }
        let text = String(format: "%@ — made with Rehomely".localized, idea.title)
        let vc = UIActivityViewController(activityItems: [image, text], applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = shareButton
        present(vc, animated: true)
    }

    @IBAction private func didTapTag(_ sender: UIControl) {
        DS.Haptic.selection()
        let tag = sender.tag
        let room: InspirationIdea.Room? = tag == 1 ? idea.room : nil
        let style: String? = tag == 1 ? nil : (label(in: sender)?.text ?? idea.style)
        let onTag = self.onTag
        dismiss(animated: true) { onTag?(room, style) }
    }

    @IBAction private func didTapSwatch(_ sender: UIControl) {
        let palette = idea.palette
        guard palette.indices.contains(sender.tag) else { return }
        UIPasteboard.general.string = "#" + palette[sender.tag]
        DS.Haptic.light()
        DSToastView.show(String(format: "Color copied · #%@".localized, palette[sender.tag]), style: .success,
                         in: view, topOffset: 60, duration: 1.6)
    }

    @IBAction private func didTapTry(_ sender: Any) {
        AmplitudeService.shared.logRedesignEvent("inspiration_try", properties: ["style": idea.style,
                                                                                "room": idea.category])
        let idea = self.idea!
        dismiss(animated: true) {
            NavigationManager.shared.startDesign(option: idea.option) { session in
                session.applyInspiration(idea)
            }
        }
    }

    // MARK: Interactive dismiss (swipe down on the photo)

    @objc private func handleDismissPan(_ pan: UIPanGestureRecognizer) {
        let dy = max(0, pan.translation(in: view).y)
        let progress = min(dy / 300, 1)
        switch pan.state {
        case .changed:
            let scale = 1 - progress * 0.12
            view.transform = CGAffineTransform(translationX: 0, y: dy * 0.6).scaledBy(x: scale, y: scale)
            view.layer.cornerRadius = 34 * progress * 2
        case .ended, .cancelled:
            if dy > 120 || pan.velocity(in: view).y > 900 {
                dismiss(animated: true)
            } else {
                UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                    self.view.transform = .identity
                    self.view.layer.cornerRadius = 0
                }
            }
        default: break
        }
    }

    private func label(in view: UIView) -> UILabel? {
        if let l = view as? UILabel { return l }
        for sub in view.subviews { if let l = label(in: sub) { return l } }
        return nil
    }
}

extension IdeaDetailViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let v = pan.velocity(in: view)
        let onPhoto = pan.location(in: view).y < panelView.frame.minY
        return onPhoto && v.y > abs(v.x)
    }
}

// MARK: - Hero transition (card → 520 pt photo, panel springs up)

final class InspirationHeroTransition: NSObject, UIViewControllerTransitioningDelegate, UIViewControllerAnimatedTransitioning {

    /// Current on-screen card image for the presented idea (cells get reused).
    var sourceView: (() -> UIView?)?
    private var presenting = true

    func animationController(forPresented presented: UIViewController, presenting: UIViewController,
                             source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        self.presenting = true
        return self
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        presenting = false
        return self
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        presenting ? 0.55 : 0.45
    }

    func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        presenting ? present(ctx) : dismiss(ctx)
    }

    private func present(_ ctx: UIViewControllerContextTransitioning) {
        guard let detail = ctx.viewController(forKey: .to) as? IdeaDetailViewController,
              let toView = ctx.view(forKey: .to) else { ctx.completeTransition(false); return }
        let container = ctx.containerView
        toView.frame = ctx.finalFrame(for: detail)
        container.addSubview(toView)
        toView.layoutIfNeeded()

        let source = sourceView?()
        guard let source, !DS.Motion.reduceMotion else {
            toView.alpha = 0
            UIView.animate(withDuration: 0.3, animations: { toView.alpha = 1 }) { _ in ctx.completeTransition(true) }
            return
        }
        detail.presentedWithZoom = true
        let backdrop = UIView(frame: container.bounds)
        backdrop.backgroundColor = .white
        backdrop.alpha = 0
        container.insertSubview(backdrop, belowSubview: toView)

        let snapshot = UIImageView(image: detail.heroImageView.image ?? (source as? UIImageView)?.image)
        snapshot.contentMode = .scaleAspectFill
        snapshot.clipsToBounds = true
        snapshot.layer.cornerRadius = 20
        snapshot.layer.cornerCurve = .continuous
        snapshot.frame = source.convert(source.bounds, to: container)
        container.addSubview(snapshot)
        source.alpha = 0

        toView.backgroundColor = .clear
        detail.heroImageView.alpha = 0
        let chrome: [UIView] = [detail.navView, detail.aiTagView]
        chrome.forEach { $0.alpha = 0 }
        detail.panelView.transform = CGAffineTransform(translationX: 0, y: detail.panelView.bounds.height)
        let heroFrame = detail.heroImageView.convert(detail.heroImageView.bounds, to: container)

        let zoom = UIViewPropertyAnimator(duration: 0.55, dampingRatio: 0.86) {
            snapshot.frame = heroFrame
            snapshot.layer.cornerRadius = 0
            backdrop.alpha = 1
        }
        zoom.addCompletion { _ in
            detail.heroImageView.alpha = 1
            toView.backgroundColor = .white
            snapshot.removeFromSuperview()
            backdrop.removeFromSuperview()
            source.alpha = 1
            ctx.completeTransition(!ctx.transitionWasCancelled)
        }
        zoom.startAnimation()
        let panel = UIViewPropertyAnimator(duration: 0.45, dampingRatio: 0.82) {
            detail.panelView.transform = .identity
        }
        panel.startAnimation(afterDelay: 0.08)
        detail.animatePanelContent(delay: 0.14)
        UIView.animate(withDuration: 0.3, delay: 0.25) { chrome.forEach { $0.alpha = 1 } }
    }

    private func dismiss(_ ctx: UIViewControllerContextTransitioning) {
        guard let detail = ctx.viewController(forKey: .from) as? IdeaDetailViewController,
              let fromView = ctx.view(forKey: .from) else { ctx.completeTransition(false); return }
        let container = ctx.containerView
        let target = sourceView?()
        let targetFrame = target.map { $0.convert($0.bounds, to: container) }
        guard let target, let targetFrame, container.bounds.intersects(targetFrame), !DS.Motion.reduceMotion else {
            UIView.animate(withDuration: 0.3, animations: {
                fromView.alpha = 0
                fromView.transform = fromView.transform.translatedBy(x: 0, y: 40)
            }) { _ in ctx.completeTransition(!ctx.transitionWasCancelled) }
            return
        }
        let snapshot = UIImageView(image: detail.heroImageView.image)
        snapshot.contentMode = .scaleAspectFill
        snapshot.clipsToBounds = true
        snapshot.layer.cornerCurve = .continuous
        snapshot.frame = detail.heroImageView.convert(detail.heroImageView.bounds, to: container)
        container.addSubview(snapshot)
        detail.heroImageView.alpha = 0
        target.alpha = 0

        let animator = UIViewPropertyAnimator(duration: 0.45, dampingRatio: 0.88) {
            snapshot.frame = targetFrame
            snapshot.layer.cornerRadius = 20
            fromView.alpha = 0
            detail.panelView.transform = CGAffineTransform(translationX: 0, y: detail.panelView.bounds.height)
        }
        animator.addCompletion { _ in
            target.alpha = 1
            snapshot.removeFromSuperview()
            ctx.completeTransition(!ctx.transitionWasCancelled)
        }
        animator.startAnimation()
    }
}
