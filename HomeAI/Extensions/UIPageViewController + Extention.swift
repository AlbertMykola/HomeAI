import ObjectiveC
import UIKit

extension UIPageViewController {

    private enum PageTransitionKeys {
        static var depth: UInt8 = 0
        static var unlockWork: UInt8 = 0
        static var programmatic: UInt8 = 0
    }

    private var pageTransitionDepth: Int {
        get { objc_getAssociatedObject(self, &PageTransitionKeys.depth) as? Int ?? 0 }
        set { objc_setAssociatedObject(self, &PageTransitionKeys.depth, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var pageTransitionUnlockWorkItem: DispatchWorkItem? {
        get { objc_getAssociatedObject(self, &PageTransitionKeys.unlockWork) as? DispatchWorkItem }
        set { objc_setAssociatedObject(self, &PageTransitionKeys.unlockWork, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var isProgrammaticPageChange: Bool {
        get { objc_getAssociatedObject(self, &PageTransitionKeys.programmatic) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &PageTransitionKeys.programmatic, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var isPageTransitionLocked: Bool {
        pageTransitionDepth > 0
    }

    var isUserDrivenPagingInFlight: Bool {
        guard let scrollView = pagingScrollView else { return false }
        return scrollView.isDragging || scrollView.isDecelerating || scrollView.isTracking
    }

    /// UIKit asserts (`Duplicate states in queue`) if `setViewControllers(animated:)` runs during another
    /// page animation, a swipe, or while a modal covers the pager.
    var isPageChangeUnsafe: Bool {
        isPageTransitionLocked
            || isUserDrivenPagingInFlight
            || presentedViewController != nil
            || viewControllers?.first?.presentedViewController != nil
            || tabBarController?.presentedViewController != nil
    }

    private var pagingScrollView: UIScrollView? {
        view.subviews.first { $0 is UIScrollView } as? UIScrollView
    }

    func beginPageTransition() {
        pageTransitionDepth += 1
        pagingScrollView?.isScrollEnabled = false
        schedulePageTransitionUnlockTimeout()
    }

    func endPageTransition() {
        pageTransitionDepth = max(0, pageTransitionDepth - 1)
        if pageTransitionDepth == 0 {
            isProgrammaticPageChange = false
            cancelPageTransitionUnlockTimeout()
            pagingScrollView?.isScrollEnabled = true
        }
    }

    func endInteractivePageTransitionIfNeeded() {
        guard !isProgrammaticPageChange, isPageTransitionLocked else { return }
        endPageTransition()
    }

    @discardableResult
    func setPageSafely(
        _ viewController: UIViewController,
        direction: NavigationDirection = .forward,
        animated: Bool,
        completion: ((Bool) -> Void)? = nil
    ) -> Bool {
        if viewControllers?.first === viewController {
            completion?(true)
            return true
        }
        if animated, isPageChangeUnsafe {
            completion?(false)
            return false
        }

        if animated {
            isProgrammaticPageChange = true
            beginPageTransition()
            setViewControllers([viewController], direction: direction, animated: true) { [weak self] finished in
                guard let self else {
                    completion?(finished)
                    return
                }
                self.isProgrammaticPageChange = false
                self.endPageTransition()
                completion?(finished)
            }
        } else {
            setViewControllers([viewController], direction: direction, animated: false, completion: completion)
        }
        return true
    }

    private func schedulePageTransitionUnlockTimeout() {
        cancelPageTransitionUnlockTimeout()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.pageTransitionDepth > 0 else { return }
            self.pageTransitionDepth = 0
            self.isProgrammaticPageChange = false
            self.pagingScrollView?.isScrollEnabled = true
        }
        pageTransitionUnlockWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: work)
    }

    private func cancelPageTransitionUnlockTimeout() {
        pageTransitionUnlockWorkItem?.cancel()
        pageTransitionUnlockWorkItem = nil
    }
}
