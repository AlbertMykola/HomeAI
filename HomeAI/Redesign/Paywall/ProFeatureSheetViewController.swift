import UIKit

/// A/02 · P3 Pro feature: contextual upsell instead of the full paywall. Honest: ✕ from the first frame,
/// "Not now" returns the user where they were. See Pro plans → P1 with source=feature_<name>.
/// Layout: Paywall.storyboard.
final class ProFeatureSheetViewController: UIViewController {

    enum Feature: String {
        case watermark, hdExport = "4k", unlimitedEdits = "edits", aiDesigner = "assistant", proStyle = "style"

        var title: String {
            switch self {
            case .watermark: return "Share without watermark".localized
            case .hdExport: return "Export in 4K".localized
            case .unlimitedEdits: return "Unlimited edits".localized
            case .aiDesigner: return "AI designer is Pro".localized
            case .proStyle: return "Unlock every style".localized
            }
        }

        /// The benefit that matches the trigger goes first.
        var benefits: [String] {
            let all = ["No watermark on shared images", "4K HD export", "Unlimited redesigns and edits",
                       "All 20+ styles and tools"]
            let first: String
            switch self {
            case .watermark: first = all[0]
            case .hdExport: first = all[1]
            case .unlimitedEdits: first = all[2]
            case .aiDesigner: first = "Chat with your AI designer"
            case .proStyle: first = all[3]
            }
            return ([first] + all.filter { $0 != first }).prefix(4).map(\.localized)
        }
    }

    @IBOutlet private weak var heroView: UIView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private var benefitLabels: [UILabel]!
    @IBOutlet private var benefitRows: [UIStackView]!
    @IBOutlet private weak var priceLabel: UILabel!
    @IBOutlet private weak var seeButton: DSPrimaryButton!
    @IBOutlet private weak var seeLabel: UILabel!
    @IBOutlet private weak var notNowButton: UIButton!
    @IBOutlet private weak var contentStack: UIStackView!

    private var feature: Feature = .watermark
    private var placement = Constants.Keys.optionPlacememt
    private var onPurchase: (() -> Void)?

    static func present(_ feature: Feature, from presenter: UIViewController, placement: String = Constants.Keys.optionPlacememt,
                        onPurchase: (() -> Void)? = nil) {
        let vc = AppStoryboard.instantiate(ProFeatureSheetViewController.self)
        vc.feature = feature
        vc.placement = placement
        vc.onPurchase = onPurchase
        AmplitudeService.shared.logRedesignEvent("pro_feature_sheet", properties: ["feature": feature.rawValue])
        vc.loadViewIfNeeded()
        let contentSize = vc.contentStack.systemLayoutSizeFitting(
            CGSize(width: max(1, presenter.view.dsLayoutSize.width - 40), height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        // UIKit caps custom detents on short displays. The content remains scrollable
        // if the final sheet width or height is smaller than the presenter's viewport.
        DSSheet.present(vc, from: presenter, height: contentSize.height + 28)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = feature.title
        subtitleLabel.text = "This is a Pro feature. Pro also unlocks:".localized
        let benefits = feature.benefits
        benefitLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = benefits[$0] }
        seeLabel.text = "See Pro plans".localized
        notNowButton.setTitle("Not now".localized, for: .normal)
        priceLabel.text = AdaptyService.shared.cachedWeeklyPrice.map { String(format: "%@ / week · cancel anytime".localized, $0) }
            ?? "Cancel anytime".localized
        heroView.alpha = 0
        benefitRows.forEach { $0.alpha = 0 }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DS.Motion.enter(heroView, delay: 0, scale: 0.4, duration: 0.45, pop: true)
        benefitRows.sorted { $0.tag < $1.tag }.enumerated().forEach {
            DS.Motion.enter($1, delay: 0.15 + 0.06 * Double($0), dx: 16)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.seeButton.runShimmer() }
    }

    @IBAction private func didTapClose(_ sender: Any) {
        dismiss(animated: true)
    }

    @IBAction private func didTapSee(_ sender: Any) {
        let presenter = presentingViewController
        let feature = self.feature, placement = self.placement, onPurchase = self.onPurchase
        dismiss(animated: true) {
            guard let presenter else { return }
            presenter.present(ProPaywallViewController.make(placement: placement, source: "feature_\(feature.rawValue)",
                                                            onPurchase: onPurchase), animated: true)
        }
    }
}
