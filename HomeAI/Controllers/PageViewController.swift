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
        case .replace:
            return [.addPhoto]
        case .reference:
            return [.addPhoto, .addPhoto]
        case .newFlooring, .newWalls:
            return [.addPhoto, .surfaceMaterial]
        default:
            return [.addPhoto, .room, .style, .color]
        }
    }

    private let pageControl = UIPageControl()
    private let nextButton = UIButton(type: .system)
    var selectedOption: DesignOption = .interior
    
    private var promptManager = GemeniPromptManager()

    private lazy var orderedViewControllers: [UIViewController] = {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        let ids: [String] = steps.map { step in
            switch step {
            case .addPhoto:
                return "AddPhotoViewController"
            case .room:
                return selectedOption == .interior ? "RoomListViewController" : "TypeViewController"
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
            
            if let styleIndex = steps.firstIndex(of: .style),
               let styleVC = vcs[safe: styleIndex] as? StyleListViewController {
                styleVC.selectedOption = selectedOption
                styleVC.onProceedToNextStep = { [weak self] in
                    self?.proceedToNextStep()
                }
            }
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

        promptManager.updateOption(selectedOption)

        proceedStates = Array(repeating: false, count: orderedViewControllers.count)

        for (index, vc) in orderedViewControllers.enumerated() {
            if let delegateVC = vc as? PageStepDelegate {
                delegateVC.completion = { [weak self, weak delegateVC] in
                    guard let self, let delegateVC else { return }
                    self.proceedStates[index] = delegateVC.canProceedToNextStep
                    self.updateNextButtonState()
                }
            }
            if let holder = vc as? (any PromptManagerHolder) {
                holder.promptManager = promptManager
            }
        }
        
        if let first = orderedViewControllers.first {
            setViewControllers([first], direction: .forward, animated: false, completion: nil)
        }

        if let firstVC = orderedViewControllers.first {
            setViewControllers([firstVC], direction: .forward, animated: false, completion: nil)
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

        if !ApphudService.shared.hasActiveSubscription {
            let item = ProBadgeButton.makeBarButtonItem(target: self, action: #selector(didTapPro))
            navigationItem.rightBarButtonItem = item
        }
    }

    private func setupNextButton() {
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.setTitle(Defaults.Text.next, for: .normal)
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
        let title = isLastStep ? Defaults.Text.generate : Defaults.Text.next
        nextButton.setTitle(title, for: .normal)
        nextButton.isEnabled = proceedStates[currentIndex]
        nextButton.alpha = nextButton.isEnabled ? 1.0 : 0.5
    }

    /// Programmatically go to the next step (used from modal flows like custom prompt)
    func proceedToNextStep() {
        guard let currentVC = viewControllers?.first,
              let currentIndex = orderedViewControllers.firstIndex(of: currentVC) else { return }
        let nextIndex = currentIndex + 1
        if nextIndex < orderedViewControllers.count {
            setViewControllers([orderedViewControllers[nextIndex]], direction: .forward, animated: true, completion: nil)
            pageControl.currentPage = nextIndex
            updateNextButtonState()
        } else {
            if FreeGenerationManager.shared.canGenerateForFree || ApphudService.shared.hasActiveSubscription {
                NavigationManager.shared.showProcessing(manager: promptManager)
            } else {
                NavigationManager.shared.showPremium(placement: Constants.Keys.reachedLimit)
            }
        }
    }

    // MARK: - Actions
    @objc private func nextButtonTapped() {
        guard let currentVC = viewControllers?.first,
              let currentIndex = orderedViewControllers.firstIndex(of: currentVC),
              proceedStates[currentIndex] else {
            let alert = UIAlertController(title: Defaults.Text.notCompleted, message: Defaults.Text.messege, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        let nextIndex = currentIndex + 1

        if nextIndex < orderedViewControllers.count {
            setViewControllers([orderedViewControllers[nextIndex]], direction: .forward, animated: true, completion: nil)
            pageControl.currentPage = nextIndex
            updateNextButtonState()
        } else {
            FreeGenerationManager.shared.canGenerateForFree || ApphudService.shared.hasActiveSubscription ? NavigationManager.shared.showProcessing(manager: promptManager) : NavigationManager.shared.showPremium(placement: Constants.Keys.reachedLimit)
        }
    }
    
    @objc private func didTapPro() {
        NavigationManager.shared.showPremium(placement: Constants.Keys.optionPlacememt)
    }
}

// MARK: - Swipe Logic
extension PageViewController: UIPageViewControllerDataSource, UIPageViewControllerDelegate {

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
