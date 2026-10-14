import UIKit

/// A/06 · R9 "What went wrong?" — multi-select reasons, optional details, free retry.
/// Layout: DislikeSheetViewController.xib.
final class DislikeSheetViewController: UIViewController {

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var closeButton: DSPressableControl!
    @IBOutlet private weak var reasonsStack: UIStackView!
    @IBOutlet private var reasonChips: [DSChipControl]!
    @IBOutlet private weak var detailsField: UITextField!
    @IBOutlet private weak var freeRetryView: UIView!
    @IBOutlet private weak var freeRetryLabel: UILabel!
    @IBOutlet private weak var sendRetryButton: DSPrimaryButton!
    @IBOutlet private weak var sendRetryLabel: UILabel!
    @IBOutlet private weak var justSendButton: UIButton!

    private static let reasons = ["Changed my room layout", "Doesn't look realistic", "Wrong style",
                                  "Weird objects or artifacts", "Ignored my request", "Other"]
    private static let freeRetryKey = "redesign_free_retry_used_on"
    private var selected = Set<Int>()
    private var onSend: (([String], String, Bool, Bool) -> Void)?

    static func present(from presenter: UIViewController, onSend: @escaping ([String], String, Bool, Bool) -> Void) {
        let vc = DislikeSheetViewController(nibName: "DislikeSheetViewController", bundle: .main)
        vc.onSend = onSend
        DSSheet.present(vc, from: presenter, height: 560)
    }

    /// One free retry per day (dev notes R9 §3).
    private var freeRetryAvailable: Bool {
        guard let last = UserDefaults.standard.object(forKey: Self.freeRetryKey) as? Date else { return true }
        return !Calendar.current.isDateInToday(last)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "What went wrong?".localized
        subtitleLabel.text = "Your answer trains the next version".localized
        detailsField.placeholder = "Tell us more (optional)".localized
        detailsField.delegate = self
        freeRetryLabel.text = "We'll regenerate this one for free".localized
        freeRetryView.isHidden = !freeRetryAvailable
        sendRetryLabel.text = freeRetryAvailable ? "Send & try again".localized : "Send & try again · 1 credit".localized
        justSendButton.setTitle("Just send feedback".localized, for: .normal)
        reasonChips.sorted { $0.tag < $1.tag }.enumerated().forEach { index, chip in
            chip.subviews.first?.subviews.compactMap { $0 as? UILabel }.first?.text = Self.reasons[index].localized
        }
        updateButtons()
    }

    @IBAction private func didTapReason(_ sender: UIControl) {
        guard let chip = sender as? DSChipControl else { return }
        if selected.contains(chip.tag) { selected.remove(chip.tag) } else { selected.insert(chip.tag) }
        DS.Haptic.selection()
        chip.setChipSelected(selected.contains(chip.tag), animated: true)
        updateButtons()
    }

    private func updateButtons() {
        let ready = !selected.isEmpty
        sendRetryButton.inactive = !ready
        sendRetryButton.isUserInteractionEnabled = ready
        justSendButton.isEnabled = ready
    }

    private func finish(retry: Bool) {
        let reasons = selected.sorted().map { Self.reasons[$0] }
        let details = detailsField.text ?? ""
        let free = retry && freeRetryAvailable
        if free { UserDefaults.standard.set(Date(), forKey: Self.freeRetryKey) }
        let onSend = self.onSend
        dismiss(animated: true) { onSend?(reasons, details, retry, free) }
    }

    @IBAction private func didTapSendRetry(_ sender: Any) { finish(retry: true) }
    @IBAction private func didTapJustSend(_ sender: Any) { finish(retry: false) }
    @IBAction private func didTapClose(_ sender: Any) { dismiss(animated: true) }
}

extension DislikeSheetViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
