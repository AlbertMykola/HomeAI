import UIKit

class ReplaceObjectPageViewController: UIPageViewController {
    
    enum FlowMode {
        case replace
        case delete
    }

    enum StepType: Int, CaseIterable {
        case addPhoto, objectSelection
    }

    private var steps: [StepType] = [.addPhoto, .objectSelection]

    private let pageControl = UIPageControl()
    private let nextButton = UIButton(type: .system)
    
    var promptManager: GemeniPromptManager = GemeniPromptManager()
    var flowMode: FlowMode = .replace

    private lazy var orderedViewControllers: [UIViewController] = {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        let ids: [String] = steps.map { step in
            switch step {
            case .addPhoto:
                return "AddPhotoViewController"
            case .objectSelection:
                return "ObjectSelectionViewController"
            }
        }

        let vcs = ids.compactMap { storyboard.instantiateViewController(withIdentifier: $0) }
        
        if let addPhotoIndex = steps.firstIndex(of: .addPhoto),
           let addPhotoVC = vcs[safe: addPhotoIndex] as? AddPhotoViewController {
            addPhotoVC.promptManager = promptManager
        }
        
        if let objectSelectionIndex = steps.firstIndex(of: .objectSelection),
           let objectSelectionVC = vcs[safe: objectSelectionIndex] as? ObjectSelectionViewController {
            objectSelectionVC.promptManager = promptManager
            objectSelectionVC.showsGenerateButton = false
            objectSelectionVC.requiresPromptInput = (flowMode == .replace)
        }
        
        return vcs
    }()

    private var proceedStates: [Bool] = []

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        dataSource = self
        delegate = self
        setupPageControl()
        setupNextButton()

        // Оновлюємо опцію, якщо вона ще не встановлена
        switch flowMode {
        case .replace:
            if promptManager.designOption != .replace {
                promptManager.updateOption(.replace)
            }
        case .delete:
            if promptManager.designOption != .delete {
                promptManager.updateOption(.delete)
            }
        }

        proceedStates = Array(repeating: false, count: orderedViewControllers.count)

        for (index, vc) in orderedViewControllers.enumerated() {
            if let delegateVC = vc as? PageStepDelegate {
                delegateVC.completion = { [weak self] in
                    self?.proceedStates[index] = true
                    self?.updateNextButtonState()
                }
            }
            if let holder = vc as? (any PromptManagerHolder) {
                holder.promptManager = promptManager
            }
        }
        
        if let first = orderedViewControllers.first {
            setViewControllers([first], direction: .forward, animated: false, completion: nil)
            applyNavFromChild(first)
        }

        pageControl.numberOfPages = orderedViewControllers.count
        pageControl.currentPage = 0

        updateNextButtonState()
        if !ApphudService.shared.hasActiveSubscription {
            let item = ProBadgeButton.makeBarButtonItem(target: self, action: #selector(didTapPro))
            navigationItem.rightBarButtonItem = item
        }

        setupNavBar()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        nextButton.layer.cornerRadius = nextButton.frame.height / 2
        nextButton.layer.masksToBounds = true
    }

    // MARK: - Private Functions
    private func setupPageControl() {
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageControl.numberOfPages = orderedViewControllers.count
        pageControl.currentPage = 0
        pageControl.pageIndicatorTintColor = .lightGray
        pageControl.currentPageIndicatorTintColor = .systemGreen
        view.addSubview(pageControl)
        NSLayoutConstraint.activate([
            pageControl.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
    
    private func setupNavBar() {
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.title = Constants.Text.brand

        let ap = UINavigationBarAppearance()
        ap.configureWithTransparentBackground()
        ap.shadowColor = .clear
        ap.largeTitleTextAttributes = [.font: UIFont.geologica(.standard(.bold), size: 30)]

        navigationItem.standardAppearance = ap
        navigationItem.scrollEdgeAppearance = ap
        navigationItem.compactAppearance = ap
        if #available(iOS 15.0, *) {
            navigationItem.compactScrollEdgeAppearance = ap
        }

        navigationController?.navigationBar.isTranslucent = true
        if !ApphudService.shared.hasActiveSubscription {
            let item = ProBadgeButton.makeBarButtonItem(target: self, action: #selector(didTapPro))
            navigationItem.rightBarButtonItem = item
        }
    }

    private func applyNavFromChild(_ vc: UIViewController) {
        navigationItem.title = vc.navigationItem.title
        navigationItem.largeTitleDisplayMode = .always
    }

    private func setupNextButton() {
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.setTitle("Next".localized, for: .normal)
        nextButton.setTitleColor(.black, for: .normal)
        nextButton.backgroundColor = Constants.Colors.yellowPremium
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
        view.addSubview(nextButton)

        NSLayoutConstraint.activate([
            nextButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            nextButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 165),
            nextButton.heightAnchor.constraint(equalToConstant: 54)
        ])
    }
    
    private func updateNextButtonState() {
        guard let currentVC = viewControllers?.first,
              let currentIndex = orderedViewControllers.firstIndex(of: currentVC) else { return }
        nextButton.isEnabled = proceedStates[currentIndex]
        nextButton.alpha = nextButton.isEnabled ? 1.0 : 0.5
    }

    // MARK: - Actions
    @objc private func nextButtonTapped() {
        guard let currentVC = viewControllers?.first,
              let currentIndex = orderedViewControllers.firstIndex(of: currentVC) else {
            return
        }
        
        // Перевіряємо, чи це ObjectSelectionViewController і чи можна перейти далі
        if let objectSelectionVC = currentVC as? ObjectSelectionViewController {
            if !objectSelectionVC.prepareForGeneration() {
                return
            }
        }
        
        guard proceedStates[currentIndex] else {
            let alert = UIAlertController(title: "Not completed".localized, message: "Perform the necessary action to continue.".localized, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK".localized, style: .default))
            present(alert, animated: true)
            return
        }

        let nextIndex = currentIndex + 1

        if nextIndex < orderedViewControllers.count {
            setViewControllers([orderedViewControllers[nextIndex]], direction: .forward, animated: true, completion: nil)
            navigationItem.title = orderedViewControllers[nextIndex].navigationItem.title
            pageControl.currentPage = nextIndex
            updateNextButtonState()
        } else {
            // Перехід до генерації
            if GenerationAccess.requestProcessingIfAllowed(presentingFrom: self) {
                NavigationManager.shared.showProcessing(manager: promptManager)
            }
        }
    }
    
    @objc private func didTapPro() {
        NavigationManager.shared.showPremium(placement: Constants.Keys.optionPlacememt)
    }
}

// MARK: - Swipe Logic
extension ReplaceObjectPageViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let index = orderedViewControllers.firstIndex(of: viewController), index > 0 else { return nil }
        return orderedViewControllers[index - 1]
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let index = orderedViewControllers.firstIndex(of: viewController),
              proceedStates[index],
              index < orderedViewControllers.count - 1 else { return nil }
        return orderedViewControllers[index + 1]
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed, let visibleVC = pageViewController.viewControllers?.first, let index = orderedViewControllers.firstIndex(of: visibleVC) {
            pageControl.currentPage = index
            updateNextButtonState()
        }
    }
}

// MARK: - Safe index helper
private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
