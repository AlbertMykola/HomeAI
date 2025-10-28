
import UIKit

// MARK: - Onboarding child protocols

protocol OBPageChild: AnyObject {
    var obDelegate: OBPageChildDelegate? { get set }
}

protocol OBPageChildDelegate: AnyObject {
    func obChildRequestsNext(_ child: UIViewController)
    func obChildRequestsClose(_ child: UIViewController)
}

// MARK: - Onboarding PageViewController

final class OBPageViewController: UIPageViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate, OBPageChildDelegate {

    private enum ObType: CaseIterable {
        case welcome, design, rate
        var id: String {
            switch self {
            case .welcome: return "WelcomeOBViewController"
            case .design:  return "DesignOBViewController"
            case .rate:    return "RateOBViewController"
            }
        }
    }

    private lazy var pages: [UIViewController] = {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let vcs = ObType.allCases.compactMap { sb.instantiateViewController(withIdentifier: $0.id) }
        vcs.forEach { (vc) in (vc as? OBPageChild)?.obDelegate = self }
        return vcs
    }()

    private let pageControl = UIPageControl()
    private var pagingLocked = false

    override func viewDidLoad() {
        super.viewDidLoad()
        dataSource = self
        delegate   = self
        setViewControllers([pages[0]], direction: .forward, animated: false, completion: nil)
        setupPageControl()
    }

    private func setupPageControl() {
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.numberOfPages = pages.count
        pageControl.currentPage = 0
        view.addSubview(pageControl)
        NSLayoutConstraint.activate([
            pageControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    // Тимчасове блокування перегортання
    private func lockPaging(_ lock: Bool) {
        pagingLocked = lock
        dataSource = lock ? nil : self // простий спосіб вимкнути swipe на PageVC
        pageControl.isUserInteractionEnabled = !lock
    }

    // MARK: - OBPageChildDelegate

    func obChildRequestsNext(_ child: UIViewController) {
        guard let idx = pages.firstIndex(of: child) else { return }
        let next = idx + 1
        if next < pages.count {
            setViewControllers([pages[next]], direction: .forward, animated: true, completion: nil)
            pageControl.currentPage = next
        } else {
            // Останній екран: блокуємо свайп і перемикаємо root
            lockPaging(true) // вимкнути свайп під час показу [StackOverflow принцип: set dataSource = nil або вимкнути scroll][web:6]
            UserDefaultsManager.shared.saveValue(true, forKey: Constants.Keys.didShowOnboarding) // позначити OB як пройдений [web:7]
            NavigationManager.shared.completeOnboarding() // 1) міняємо root на TabBar [web:7]
            DispatchQueue.main.async {
                // 2) показуємо Paywall вже з нового root як inApp, щоб повернутись туди ж [web:22]
                NavigationManager.shared.showPremium(placement: Constants.Keys.obPlacement, origin: .inApp)
            }
        }
    }


    func obChildRequestsClose(_ child: UIViewController) {
        dismiss(animated: true)
    }

    // MARK: - UIPageViewControllerDataSource

    func pageViewController(_ pvc: UIPageViewController, viewControllerBefore vc: UIViewController) -> UIViewController? {
        guard let i = pages.firstIndex(of: vc), i > 0 else { return nil }
        return pages[i - 1]
    }

    func pageViewController(_ pvc: UIPageViewController, viewControllerAfter vc: UIViewController) -> UIViewController? {
        guard let i = pages.firstIndex(of: vc), i < pages.count - 1 else { return nil }
        return pages[i + 1]
    }

    // MARK: - UIPageViewControllerDelegate

    func pageViewController(_ pvc: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed, let visible = viewControllers?.first, let i = pages.firstIndex(of: visible) {
            pageControl.currentPage = i
        }
    }
}
