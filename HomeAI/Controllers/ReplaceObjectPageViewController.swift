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
    private var autoAdvanceWorkItem: DispatchWorkItem?

    private enum Defaults {
        static let autoAdvanceDelay: TimeInterval = 0.35
        static let next = "Next".localized
        static let generate = "Generate".localized
        static let remove = "Remove".localized
    }

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
                delegateVC.completion = { [weak self, weak delegateVC] in
                    guard let self, let delegateVC else { return }
                    guard self.proceedStates.indices.contains(index) else { return }
                    self.proceedStates[index] = delegateVC.canProceedToNextStep
                    self.updateNextButtonState()
                    self.scheduleAutoAdvanceIfNeeded(from: vc, index: index)
                }
            }
            if let holder = vc as? (any PromptManagerHolder) {
                holder.promptManager = promptManager
            }
        }
        
        if let first = orderedViewControllers.first {
            setPageSafely(first, animated: false)
            applyNavFromChild(first)
        }

        pageControl.numberOfPages = orderedViewControllers.count
        pageControl.currentPage = 0

        updateNextButtonState()
        setupNavBar()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshProGenerationsBarButton()
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
        configureProGenerationsBarButton()
    }

    private func applyNavFromChild(_ vc: UIViewController) {
        navigationItem.title = vc.navigationItem.title
        navigationItem.largeTitleDisplayMode = .always
    }

    private func setupNextButton() {
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.setTitle(Defaults.next, for: .normal)
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
        let isLastStep = currentIndex == orderedViewControllers.count - 1
        let lastStepTitle = flowMode == .delete ? Defaults.remove : Defaults.generate
        nextButton.setTitle(isLastStep ? lastStepTitle : Defaults.next, for: .normal)
        nextButton.isHidden = currentIndex == 0
        nextButton.isEnabled = proceedStates[safe: currentIndex] ?? false
        nextButton.alpha = nextButton.isEnabled ? 1.0 : 0.5
    }
    
    private func scheduleAutoAdvanceIfNeeded(from completedVC: UIViewController, index: Int) {
        guard index == 0 else { return }
        guard viewControllers?.first === completedVC else { return }
        guard proceedStates.indices.contains(index), proceedStates[index] else { return }

        autoAdvanceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self, weak completedVC] in
            guard let self, let completedVC else { return }
            guard self.viewControllers?.first === completedVC else { return }
            guard self.proceedStates.indices.contains(index), self.proceedStates[index] else { return }
            if self.isPageChangeUnsafe {
                self.scheduleAutoAdvanceIfNeeded(from: completedVC, index: index)
                return
            }
            self.advanceFromAddPhotoStep()
        }
        autoAdvanceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Defaults.autoAdvanceDelay, execute: workItem)
    }

    private func cancelPendingAutoAdvance() {
        autoAdvanceWorkItem?.cancel()
        autoAdvanceWorkItem = nil
    }

    private func advanceFromAddPhotoStep() {
        autoAdvanceWorkItem?.cancel()
        autoAdvanceWorkItem = nil
        guard orderedViewControllers.count > 1 else { return }
        let nextVC = orderedViewControllers[1]
        let didStart = setPageSafely(nextVC, animated: true) { [weak self] finished in
            guard let self, finished else { return }
            self.applyNavFromChild(nextVC)
            self.pageControl.currentPage = 1
            self.updateNextButtonState()
        }
        if didStart {
            applyNavFromChild(nextVC)
            pageControl.currentPage = 1
            updateNextButtonState()
        }
    }

    // MARK: - Actions
    @objc private func nextButtonTapped() {
        guard !isPageChangeUnsafe else { return }
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
        
        guard proceedStates[safe: currentIndex] == true else {
            let alert = UIAlertController(title: "Not completed".localized, message: "Perform the necessary action to continue.".localized, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK".localized, style: .default))
            present(alert, animated: true)
            return
        }

        let nextIndex = currentIndex + 1

        if nextIndex < orderedViewControllers.count {
            let nextVC = orderedViewControllers[nextIndex]
            let didStart = setPageSafely(nextVC, animated: true) { [weak self] finished in
                guard let self, finished else { return }
                self.navigationItem.title = nextVC.navigationItem.title
                self.pageControl.currentPage = nextIndex
                self.updateNextButtonState()
            }
            if didStart {
                navigationItem.title = nextVC.navigationItem.title
                pageControl.currentPage = nextIndex
                updateNextButtonState()
            }
        } else {
            if GenerationAccess.requestProcessingIfAllowed(presentingFrom: self) {
                NavigationManager.shared.showProcessing(manager: promptManager)
            }
        }
    }
}

// MARK: - Swipe Logic
extension ReplaceObjectPageViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard !isPageTransitionLocked else { return nil }
        guard let index = orderedViewControllers.firstIndex(of: viewController), index > 0 else { return nil }
        return orderedViewControllers[index - 1]
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard !isPageTransitionLocked else { return nil }
        guard let index = orderedViewControllers.firstIndex(of: viewController),
              proceedStates[safe: index] == true,
              index < orderedViewControllers.count - 1 else { return nil }
        return orderedViewControllers[index + 1]
    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if isPageTransitionLocked {
            endInteractivePageTransitionIfNeeded()
        }
        if completed, let visibleVC = pageViewController.viewControllers?.first, let index = orderedViewControllers.firstIndex(of: visibleVC) {
            pageControl.currentPage = index
            navigationItem.title = visibleVC.navigationItem.title
            updateNextButtonState()
        }
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        willTransitionTo pendingViewControllers: [UIViewController]
    ) {
        cancelPendingAutoAdvance()
        if !isPageTransitionLocked {
            beginPageTransition()
        }
    }
}
