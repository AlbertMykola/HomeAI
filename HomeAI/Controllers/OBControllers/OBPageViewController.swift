import UIKit

// MARK: - Onboarding child protocols

protocol OBPageChild: AnyObject {
    var obDelegate: OBPageChildDelegate? { get set }
    func obUseParentHorizontalViewport()
    /// Lays out the hero at its rest pose so the page can slide in without a constraint jump.
    func obPrepareHeroForAppearance()
    /// Freezes in-place hero motion so it does not fight the page-scroll animation.
    func obPauseHeroAnimation()
    /// Starts looping hero motion after the page is fully on screen.
    func obStartHeroAnimation()
    /// Shows a loading indicator on the primary action button (e.g. while Adapty checks subscription).
    func obSetActionLoading(_ loading: Bool)
}

extension OBPageChild {
    func obUseParentHorizontalViewport() {}
    func obPrepareHeroForAppearance() {}
    func obPauseHeroAnimation() {}
    func obStartHeroAnimation() {}
    func obSetActionLoading(_ loading: Bool) {}
}

protocol OBPageChildDelegate: AnyObject {
    func obChildRequestsNext(_ child: UIViewController)
    func obChildRequestsClose(_ child: UIViewController)
}

// MARK: - Onboarding pager

final class OBPageViewController: UIViewController, UIScrollViewDelegate, OBPageChildDelegate {

    private lazy var pages: [UIViewController] = {
        let vcs: [UIViewController] = [
            OnboardingPageViewController.make(page: .room),
            OnboardingPageViewController.make(page: .tools),
            OnboardingPageViewController.make(page: .words),
            AppStoryboard.instantiate(OnboardingGoalViewController.self)
        ]
        vcs.forEach { ($0 as? OBPageChild)?.obDelegate = self }
        return vcs
    }()

    @IBOutlet private weak var scrollView: UIScrollView!

    private(set) var currentIndex = OnboardingPreview.page
    private var lastLaidOutSize: CGSize = .zero
    private var lastLaidOutScrollSize: CGSize = .zero
    private var isProgrammaticScrolling = false
    private var pagingLocked = false
    private var didCompleteOnboarding = false
    private var lastReportedIndex: Int?

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        view.backgroundColor = .white
        view.accessibilityIdentifier = "onboarding.page.\(currentIndex)"
        scrollView.delegate = self

        attachPage(at: currentIndex)
        attachPage(at: currentIndex + 1)
        layoutPagesIfNeeded(force: true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        (pages[currentIndex] as? OBPageChild)?.obStartHeroAnimation()
        reportVisiblePage()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        (pages[currentIndex] as? OBPageChild)?.obPauseHeroAnimation()
    }

    override var childForStatusBarStyle: UIViewController? { pages[currentIndex] }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutPagesIfNeeded(force: false)
    }

    private func layoutPagesIfNeeded(force: Bool) {
        let size = view.dsLayoutSize
        guard size.width > 0, size.height > 0 else { return }
        let sizeChanged = lastLaidOutSize != size
        let scrollSizeChanged = lastLaidOutScrollSize != scrollView.bounds.size
        guard force || sizeChanged || scrollSizeChanged else { return }
        lastLaidOutSize = size
        lastLaidOutScrollSize = scrollView.bounds.size

        scrollView.contentSize = CGSize(width: size.width * CGFloat(pages.count), height: size.height)
        for (index, page) in pages.enumerated() where page.parent === self {
            page.view.frame = pageFrame(at: index)
        }
        // A Duo fold can resize the window during scrolling. Settle onto a complete page.
        let interruptedTransition = sizeChanged && isProgrammaticScrolling
        scrollView.setContentOffset(CGPoint(x: size.width * CGFloat(currentIndex), y: 0), animated: false)
        if interruptedTransition {
            // Restore the page identity and hero as well as touch handling after cancelling the scroll.
            settle(at: currentIndex)
        }
    }

    private func pageFrame(at index: Int) -> CGRect {
        // The storyboard scroll view still has its design size during viewDidLoad.
        // Use the parent's intended viewport before its first Auto Layout pass.
        let size = view.dsLayoutSize
        return CGRect(
            x: size.width * CGFloat(index),
            y: 0,
            width: size.width,
            height: size.height
        )
    }

    private func attachPage(at index: Int) {
        guard pages.indices.contains(index) else { return }
        let page = pages[index]
        guard page.parent !== self else { return }
        addChild(page)
        (page as? OBPageChild)?.obUseParentHorizontalViewport()
        // The pager owns child frames; decoded flexible masks would resize them
        // again when the scroll view leaves its storyboard design size.
        page.view.autoresizingMask = []
        page.view.frame = pageFrame(at: index)
        scrollView.addSubview(page.view)
        if let demo = page as? OnboardingPageViewController {
            demo.heroView.interactiveGestures.forEach { scrollView.panGestureRecognizer.require(toFail: $0) }
        }
        page.didMove(toParent: self)
        (page as? OBPageChild)?.obPrepareHeroForAppearance()
    }

    private func visibleIndex(from offset: CGPoint) -> Int {
        let width = max(scrollView.bounds.width, 1)
        let index = Int((offset.x / width).rounded())
        return min(max(index, 0), pages.count - 1)
    }

    private func settle(at index: Int) {
        let previous = currentIndex
        currentIndex = index
        view.accessibilityIdentifier = "onboarding.page.\(index)"
        setNeedsStatusBarAppearanceUpdate()
        isProgrammaticScrolling = false
        view.isUserInteractionEnabled = true
        if previous != index {
            (pages[previous] as? OBPageChild)?.obPauseHeroAnimation()
        }
        (pages[index] as? OBPageChild)?.obStartHeroAnimation()
        attachPage(at: index + 1)
        attachPage(at: index - 1)
        if view.window != nil { reportVisiblePage() }
    }

    private func reportVisiblePage() {
        guard lastReportedIndex != currentIndex else { return }
        lastReportedIndex = currentIndex
        guard !OnboardingPreview.enabled || AppQA.enabled else { return }
        AmplitudeService.shared.logRedesignEvent("onboarding_step", properties: ["step": currentIndex + 1])
    }

    // MARK: - OBPageChildDelegate

    func obChildRequestsNext(_ child: UIViewController) {
        guard !isProgrammaticScrolling, !didCompleteOnboarding, !pagingLocked else { return }
        guard let idx = pages.firstIndex(where: { $0 === child }) else { return }
        let next = idx + 1
        if next < pages.count {
            currentIndex = idx
            isProgrammaticScrolling = true
            view.accessibilityIdentifier = "onboarding.transitioning"
            view.isUserInteractionEnabled = false
            attachPage(at: next)
            (child as? OBPageChild)?.obPauseHeroAnimation()
            layoutPagesIfNeeded(force: true)
            let offset = CGPoint(x: scrollView.bounds.width * CGFloat(next), y: 0)
            scrollView.setContentOffset(offset, animated: true)
        } else {
            if OnboardingPreview.enabled {
                (child as? OBPageChild)?.obPauseHeroAnimation()
                // Preview completion is visible to UI tests without network calls or purchases.
                view.accessibilityIdentifier = "onboarding.completed"
                return
            }
            didCompleteOnboarding = true
            pagingLocked = true
            scrollView.isScrollEnabled = false
            view.isUserInteractionEnabled = false
            (child as? OBPageChild)?.obSetActionLoading(true)

            Task { @MainActor [weak self, weak child] in
                guard self != nil else { return }
                await Self.requestTrackingIfNeeded()
                (child as? OBPageChild)?.obSetActionLoading(false)

                if Constants.Debug.alwaysShowPaywallOnLaunch {
                    UserDefaultsManager.shared.saveValue(true, forKey: Constants.Keys.didShowOnboarding)
                    NavigationManager.shared.completeOnboarding()
                    return
                }
                // The paywall comes up at once and loads its products itself; Home is set up underneath it.
                // Adapty's first profile (up to 8 s) is checked meanwhile: a subscriber gets Home back.
                weak var paywall = NavigationManager.shared.completeOnboardingWithPaywall(placement: Constants.Keys.obPlacement)
                guard paywall != nil else { return }
                if await AdaptyService.shared.hasActiveSubscriptionWhenReady(), let paywall,
                   paywall.presentingViewController != nil {
                    paywall.dismiss(animated: true)
                }
            }
        }
    }

    func obChildRequestsClose(_ child: UIViewController) {
        dismiss(animated: true)
    }

    private static func requestTrackingIfNeeded() async {
        #if DEBUG
        if AppQA.enabled { return }
        #endif
        guard !UserDefaults.standard.bool(forKey: Constants.Keys.didLogTrackingPermission) else { return }
        await withCheckedContinuation { continuation in
            TrackingManager.requestPermission { status in
                AmplitudeService.shared.logEvent(.trackingPermission(granted: status == .authorized))
                UserDefaults.standard.set(true, forKey: Constants.Keys.didLogTrackingPermission)
                AppsFlyerService.shared.startReadySessionIfTrackingResolved()
                continuation.resume()
            }
        }
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        (pages[safe: currentIndex] as? OBPageChild)?.obPauseHeroAnimation()
        let upcoming = visibleIndex(from: scrollView.contentOffset)
        attachPage(at: upcoming + 1)
        attachPage(at: upcoming - 1)
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        settle(at: visibleIndex(from: scrollView.contentOffset))
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        settle(at: visibleIndex(from: scrollView.contentOffset))
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard !decelerate else { return }
        settle(at: visibleIndex(from: scrollView.contentOffset))
    }
}
