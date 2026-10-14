import UIKit

/// A/04 · W1-t Photo tips (sheet). Layout: PhotoTipsSheetViewController.xib.
final class PhotoTipsSheetViewController: UIViewController {

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var closeButton: DSPressableControl!
    @IBOutlet private var exampleLabels: [UILabel]!
    @IBOutlet private var tipLabels: [UILabel]!
    @IBOutlet private var tipRows: [UIView]!
    @IBOutlet private weak var gotItLabel: UILabel!
    @IBOutlet private weak var gotItButton: DSPrimaryButton!

    static func present(from presenter: UIViewController) {
        let vc = PhotoTipsSheetViewController(nibName: "PhotoTipsSheetViewController", bundle: .main)
        DSSheet.present(vc, from: presenter, height: 640)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "Get the best result".localized
        let examples = ["Wide & bright", "Too close / dark"]
        exampleLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = examples[$0].localized }
        let tips = ["Turn on the lights or shoot by day", "Step back, show the whole room",
                    "Hold the phone level, at chest height", "Clutter is fine, we'll handle it"]
        tipLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = tips[$0].localized }
        gotItLabel.text = "Got it".localized
        tipRows.forEach { $0.alpha = 0 }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tipRows.sorted { $0.tag < $1.tag }.enumerated().forEach {
            DS.Motion.enter($1, delay: 0.1 + Double($0) * 0.06, dx: 16)
        }
    }

    @IBAction private func didTapClose(_ sender: Any) {
        dismiss(animated: true)
    }
}
