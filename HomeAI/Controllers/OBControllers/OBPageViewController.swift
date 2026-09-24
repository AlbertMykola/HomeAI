import UIKit

// MARK: - Onboarding child protocols

protocol OBPageChild: AnyObject {
    var obDelegate: OBPageChildDelegate? { get set }
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
            WelcomeOBViewController(nibName: "WelcomeOBViewController", bundle: nil),
            OBExteriorViewController(nibName: "OBExteriorViewController", bundle: nil),
            GardenOBViewController(nibName: "GardenOBViewController", bundle: nil),
            RateOBViewController(nibName: "RateOBViewController", bundle: nil)
        ]
        vcs.forEach { ($0 as? OBPageChild)?.obDelegate = self }
        return vcs
    }()

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bounces = false
        scrollView.isDirectionalLockEnabled = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.clipsToBounds = true
        return scrollView
    }()

    private var currentIndex = 0
    private var lastLaidOutSize: CGSize = .zero
    private var isProgrammaticScrolling = false
    private var pagingLocked = false
    private var didCompleteOnboarding = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        scrollView.delegate = self
        view.addSubview(scrollView)

        attachPage(at: 0)
        attachPage(at: 1)
        layoutPagesIfNeeded(force: true)
        (pages[0] as? OBPageChild)?.obStartHeroAnimation()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutPagesIfNeeded(force: false)
    }

    private func layoutPagesIfNeeded(force: Bool) {
        let size = view.bounds.size
        guard size.width > 0, size.height > 0 else { return }
        let sizeChanged = lastLaidOutSize != size
        guard force || sizeChanged else { return }
        lastLaidOutSize = size

        scrollView.frame = view.bounds
        scrollView.contentSize = CGSize(width: size.width * CGFloat(pages.count), height: size.height)
        for (index, page) in pages.enumerated() where page.parent === self {
            page.view.frame = pageFrame(at: index)
        }
        if !isProgrammaticScrolling {
            scrollView.contentOffset = CGPoint(x: size.width * CGFloat(currentIndex), y: 0)
        }
    }

    private func pageFrame(at index: Int) -> CGRect {
        CGRect(
            x: view.bounds.width * CGFloat(index),
            y: 0,
            width: view.bounds.width,
            height: view.bounds.height
        )
    }

    private func attachPage(at index: Int) {
        guard pages.indices.contains(index) else { return }
        let page = pages[index]
        guard page.parent !== self else { return }
        addChild(page)
        page.view.frame = pageFrame(at: index)
        scrollView.addSubview(page.view)
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
        isProgrammaticScrolling = false
        view.isUserInteractionEnabled = true
        if previous != index {
            (pages[previous] as? OBPageChild)?.obPauseHeroAnimation()
        }
        (pages[index] as? OBPageChild)?.obStartHeroAnimation()
        attachPage(at: index + 1)
    }

    // MARK: - OBPageChildDelegate

    func obChildRequestsNext(_ child: UIViewController) {
        guard !isProgrammaticScrolling, !didCompleteOnboarding, !pagingLocked else { return }
        guard let idx = pages.firstIndex(where: { $0 === child }) else { return }
        let next = idx + 1
        if next < pages.count {
            currentIndex = idx
            isProgrammaticScrolling = true
            view.isUserInteractionEnabled = false
            attachPage(at: next)
            (child as? OBPageChild)?.obPauseHeroAnimation()
            layoutPagesIfNeeded(force: true)
            let offset = CGPoint(x: view.bounds.width * CGFloat(next), y: 0)
            scrollView.setContentOffset(offset, animated: true)
        } else {
            didCompleteOnboarding = true
            pagingLocked = true
            scrollView.isScrollEnabled = false
            view.isUserInteractionEnabled = false
            (child as? OBPageChild)?.obSetActionLoading(true)

            Task { @MainActor [weak self, weak child] in
                guard self != nil else { return }
                let hasSubscription = await AdaptyService.shared.hasActiveSubscriptionWhenReady()
                (child as? OBPageChild)?.obSetActionLoading(false)

                UserDefaultsManager.shared.saveValue(true, forKey: Constants.Keys.didShowOnboarding)
                NavigationManager.shared.completeOnboarding()

                if Constants.Debug.alwaysShowPaywallOnLaunch {
                    return
                }
                guard !hasSubscription else { return }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    NavigationManager.shared.showPremium(
                        placement: Constants.Keys.obPlacement,
                        origin: .inApp
                    )
                }
            }
        }
    }

    func obChildRequestsClose(_ child: UIViewController) {
        dismiss(animated: true)
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
