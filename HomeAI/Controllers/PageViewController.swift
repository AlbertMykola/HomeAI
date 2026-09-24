import UIKit

protocol PageStepDelegate: AnyObject {
    var completion: (() -> Void)? { get set }
    var canProceedToNextStep: Bool { get }
}

protocol PromptManagerHolder: AnyObject {
    var promptManager: GemeniPromptManager? { get set }
}

private struct Defaults {
    
    struct Text {
        static let notCompleted = "Not completed".localized
        static let messege = "Perform the necessary action to continue.".localized
        static let next = "Next".localized
        static let generate = "Generate".localized
    }

    struct Timing {
        static let autoAdvanceDelay: TimeInterval = 0.35
    }
}

class PageViewController: UIPageViewController {

    enum OBType: Int, CaseIterable {
        case addPhoto, room, style, color, surfaceMaterial
    }

    // Кроки будуються динамічно під selectedOption
    private var steps: [OBType] {
        switch selectedOption {
        case .garden:
            return [.addPhoto, .room]
        case .replace, .rearrange:
            return [.addPhoto]
        case .reference:
            return [.addPhoto, .addPhoto]
        case .newFlooring, .newWalls:
            return [.addPhoto, .surfaceMaterial]
        case .floolPlan:
            return [.addPhoto, .style]
        default:
            return [.addPhoto, .room, .style, .color]
        }
    }

    private let pageControl = UIPageControl()
    private let nextButton = UIButton(type: .system)
    var selectedOption: DesignOption = .interior
    
    private var promptManager = GemeniPromptManager()
    private var autoAdvanceWorkItem: DispatchWorkItem?

    private lazy var orderedViewControllers: [UIViewController] = {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        let ids: [String] = steps.map { step in
            switch step {
            case .addPhoto:
                return "AddPhotoViewController"
            case .room:
                return (selectedOption == .interior || selectedOption == .furnish) ? "RoomListViewController" : "TypeViewController"
            case .style:
                return "StyleListViewController"
            case .color:
                return "ColorListViewController"
            case .surfaceMaterial:
                return "SurfaceMaterialPickerViewController"
            }
        }

        let vcs = ids.compactMap { storyboard.instantiateViewController(withIdentifier: $0) }
        
        if selectedOption == .reference {
            var addPhotoCount = 0
            for vc in vcs {
                guard let addPhotoVC = vc as? AddPhotoViewController else { continue }
                addPhotoCount += 1
                addPhotoVC.referenceType = (addPhotoCount == 1) ? .currentRoom : .reference
            }
        }

        if let roomIndex = steps.firstIndex(of: .room) {
            if let roomVC = vcs[safe: roomIndex] as? RoomListViewController {
            }
            if let typeVC = vcs[safe: roomIndex] as? TypeViewController {
                typeVC.selectedOption = selectedOption
            }
        }

        if let styleIndex = steps.firstIndex(of: .style),
           let styleVC = vcs[safe: styleIndex] as? StyleListViewController {
            styleVC.selectedOption = selectedOption
        }

        return vcs
    }()

    private func wirePageFlowCallbacks() {
        for vc in orderedViewControllers {
            if let styleVC = vc as? StyleListViewController {
                styleVC.onProceedToNextStep = { [weak self] in
                    self?.proceedToNextStep()
                }
            }
            if let typeVC = vc as? TypeViewController {
                typeVC.onProceedToNextStep = { [weak self] in
                    self?.proceedToNextStep()
                }
            }
        }
    }

    func cancelPendingAutoAdvance() {
        autoAdvanceWorkItem?.cancel()
        autoAdvanceWorkItem = nil
    }

    private var proceedStates: [Bool] = []
    private var savedPrefersLargeTitles: Bool?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        dataSource = self
        delegate = self
        setupPageControl()
        setupNextButton()

        promptManager.updateOption(selectedOption)

        proceedStates = Array(repeating: false, count: orderedViewControllers.count)
        wirePageFlowCallbacks()

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
        
        if let firstVC = orderedViewControllers.first {
            setPageSafely(firstVC, animated: false)
        }

        pageControl.numberOfPages = orderedViewControllers.count
        pageControl.currentPage = 0

        updateNextButtonState()
        setupNavBar()
        applyFeatureNavigationTitleToChildViewControllers()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if savedPrefersLargeTitles == nil {
            savedPrefersLargeTitles = navigationController?.navigationBar.prefersLargeTitles
        }
        navigationController?.navigationBar.prefersLargeTitles = false
        updateNavigationBarForCurrentPage()
        refreshProGenerationsBarButton()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard let navigationController,
              !navigationController.viewControllers.contains(self),
              let savedPrefersLargeTitles else { return }
        navigationController.navigationBar.prefersLargeTitles = savedPrefersLargeTitles
        self.savedPrefersLargeTitles = nil
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
        updateNavigationBarForCurrentPage()
        configureProGenerationsBarButton()
    }

    private func updateNavigationBarForCurrentPage() {
        let featureTitle = selectedOption.title
        navigationItem.title = featureTitle
        title = featureTitle
        navigationItem.largeTitleDisplayMode = .never
        applyFeatureNavigationTitleToChildViewControllers()
    }

    /// UINavigationController показує navigationItem видимого дочірнього VC PageViewController, не батьківського.
    private func applyFeatureNavigationTitleToChildViewControllers() {
        let featureTitle = selectedOption.title
        for vc in orderedViewControllers {
            vc.navigationItem.title = featureTitle
            vc.title = featureTitle
            vc.navigationItem.largeTitleDisplayMode = .never
        }
    }

    private func setupNextButton() {
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.setTitle(Defaults.Text.next, for: .normal)
        nextButton.setTitleColor(.black, for: .normal)
        nextButton.backgroundColor = Constants.Colors.yellowPremium
        nextButton.isHidden = true
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
        let title = isLastStep ? Defaults.Text.generate : Defaults.Text.next
        nextButton.setTitle(title, for: .normal)
        nextButton.isEnabled = proceedStates[safe: currentIndex] ?? false
        nextButton.alpha = nextButton.isEnabled ? 1.0 : 0.5
    }

    /// Programmatically go to the next step (used from modal flows like custom prompt)
    func proceedToNextStep() {
        guard let currentVC = viewControllers?.first,
              let currentIndex = orderedViewControllers.firstIndex(of: currentVC) else { return }
        guard proceedStates[safe: currentIndex] == true else { return }
        if isPageChangeUnsafe {
            scheduleAutoAdvanceIfNeeded(from: currentVC, index: currentIndex)
            return
        }
        advanceOrGenerate(from: currentIndex)
    }

    private func scheduleAutoAdvanceIfNeeded(from completedVC: UIViewController, index: Int) {
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
            self.advanceOrGenerate(from: index)
        }
        autoAdvanceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Defaults.Timing.autoAdvanceDelay, execute: workItem)
    }

    private func advanceOrGenerate(from currentIndex: Int) {
        autoAdvanceWorkItem?.cancel()
        autoAdvanceWorkItem = nil
        let nextIndex = currentIndex + 1
        if nextIndex < orderedViewControllers.count {
            let nextVC = orderedViewControllers[nextIndex]
            let didStart = setPageSafely(nextVC, animated: true) { [weak self] finished in
                guard let self, finished else { return }
                self.pageControl.currentPage = nextIndex
                self.updateNavigationBarForCurrentPage()
                self.updateNextButtonState()
            }
            if didStart {
                pageControl.currentPage = nextIndex
                updateNavigationBarForCurrentPage()
                updateNextButtonState()
            }
        } else {
            startGenerationWhenAllowed()
        }
    }

    private func startGenerationWhenAllowed() {
        let startGeneration = { [promptManager] in
            NavigationManager.shared.showProcessing(manager: promptManager)
        }
        if GenerationAccess.requestProcessingIfAllowed(presentingFrom: self, onPurchase: startGeneration) {
            startGeneration()
        }
    }

    private func showIncompleteAlert() {
        let alert = UIAlertController(title: Defaults.Text.notCompleted, message: Defaults.Text.messege, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Actions
    @objc private func nextButtonTapped() {
        guard !isPageChangeUnsafe else { return }
        guard let currentVC = viewControllers?.first,
              let currentIndex = orderedViewControllers.firstIndex(of: currentVC),
              proceedStates[safe: currentIndex] == true else {
            showIncompleteAlert()
            return
        }

        advanceOrGenerate(from: currentIndex)
    }
}

// MARK: - Swipe Logic
extension PageViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {

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
            updateNavigationBarForCurrentPage()
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
        updateNavigationBarForCurrentPage()
    }
}
