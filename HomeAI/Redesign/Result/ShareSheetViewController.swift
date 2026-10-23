import UIKit
import MessageUI

/// A/06 · R8 Share & export (sheet): Before/After · Result · Story 9:16, "Made with Rehomely" mark, HD for Pro.
/// Layout: Result.storyboard.
final class ShareSheetViewController: UIViewController {

    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var closeButton: DSPressableControl!
    @IBOutlet private weak var contentScrollView: UIScrollView!
    @IBOutlet private weak var beforeLabel: UILabel!
    @IBOutlet private weak var afterLabel: UILabel!
    @IBOutlet private weak var previewWatermarkView: UIView!
    @IBOutlet private weak var previewWatermarkLabel: UILabel!
    @IBOutlet private weak var previewView: UIView!
    @IBOutlet private weak var beforeImageView: UIImageView!
    @IBOutlet private weak var afterImageView: UIImageView!
    @IBOutlet private weak var singleImageView: UIImageView!
    @IBOutlet private weak var formatView: UIView!
    @IBOutlet private weak var formatKnob: UIView!
    @IBOutlet private weak var formatKnobLeading: NSLayoutConstraint!
    @IBOutlet private var formatControls: [DSPressableControl]!
    @IBOutlet private var formatLabels: [UILabel]!
    @IBOutlet private weak var watermarkSwitch: UISwitch!
    @IBOutlet private weak var hdProBadge: UIView!
    @IBOutlet private weak var hdSwitch: UISwitch!
    @IBOutlet private var actionControls: [DSPressableControl]!
    @IBOutlet private var actionLabels: [UILabel]!
    @IBOutlet private weak var shareButton: DSPrimaryButton!
    @IBOutlet private weak var shareLabel: UILabel!

    private enum Format: Int { case beforeAfter, result, story }
    private var format: Format = .beforeAfter
    private var before: UIImage?
    private var after: UIImage!
    private lazy var storyImage: UIImage = Self.story(before: before, after: after)
    private let isPro = AdaptyService.shared.hasActiveSubscription
    private var referenceLayout: DSReferenceLayout!
    private var sheetTransition: UIViewControllerTransitioningDelegate?

    static func present(from presenter: UIViewController, before: UIImage?, after: UIImage) {
        let vc = AppStoryboard.instantiate(ShareSheetViewController.self)
        vc.before = before
        vc.after = after
        vc.sheetTransition = DSSheet.presentFloating(vc, from: presenter, height: 659)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        titleLabel.text = "Share your redesign".localized
        shareLabel.text = "Share".localized
        beforeLabel.text = "Before".localized
        afterLabel.text = "After".localized
        previewWatermarkLabel.text = "Made with Rehomely".localized
        let formats = ["Before / After", "Result", "Story 9:16"]
        formatLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = formats[$0].localized }
        let actions = ["Save", "Copy", "Messages", "More"]
        actionLabels.sorted { $0.tag < $1.tag }.enumerated().forEach { $1.text = actions[$0].localized }
        beforeImageView.image = before ?? after
        afterImageView.image = after
        singleImageView.image = after
        hdProBadge.isHidden = isPro
        hdSwitch.isHidden = !isPro
        hdProBadge.isUserInteractionEnabled = true
        hdProBadge.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapPro)))
        watermarkSwitch.isOn = !isPro
        watermarkSwitch.addTarget(self, action: #selector(updatePreviewWatermark), for: .valueChanged)
        if before == nil { format = .result }
        applyFormat(animated: false)
        referenceLayout = DSReferenceLayout(root: view, prefix: "share.")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // In a Duo pane the sheet is an iPhone-wide column: scale to its own width, not the unfolded window.
        let window = view.window?.dsLayoutSize ?? presentingViewController?.view.dsLayoutSize ?? UIScreen.main.bounds.size
        let size = DSWideLayout.isWide(window.width) ? CGSize(width: view.bounds.width, height: 852 * view.bounds.width / 393) : window
        referenceLayout?.apply(size: size)
        let inset = 3 * max(0.1, referenceLayout?.scale ?? 1)
        formatKnobLeading.constant = inset + (formatView.bounds.width - 2 * inset) / 3 * CGFloat(format.rawValue)
    }

    @IBAction private func didTapFormat(_ sender: UIControl) {
        guard let f = Format(rawValue: sender.tag), f != format else { return }
        format = f
        DS.Haptic.selection()
        applyFormat(animated: true)
    }

    private func applyFormat(animated: Bool) {
        let labels = formatLabels.sorted { $0.tag < $1.tag }
        let changes = {
            let scale = max(0.1, self.referenceLayout?.scale ?? 1)
            let inset = 3 * scale
            self.formatKnobLeading.constant = inset + (self.formatView.bounds.width - 2 * inset) / 3 * CGFloat(self.format.rawValue)
            labels.enumerated().forEach { i, l in
                l.font = DS.Font.geologica(i == self.format.rawValue ? .semiBold : .medium, 14 * scale)
                l.textColor = i == self.format.rawValue ? DS.Color.textPrimary : DS.Color.textSecondary
            }
            self.singleImageView.isHidden = self.format == .beforeAfter
            self.beforeImageView.superview?.isHidden = self.format != .beforeAfter
            self.singleImageView.image = self.format == .story ? self.storyImage : self.after
            self.singleImageView.contentMode = self.format == .story ? .scaleAspectFit : .scaleAspectFill
            self.beforeLabel.superview?.isHidden = self.format != .beforeAfter
            self.afterLabel.superview?.isHidden = self.format != .beforeAfter
            self.updatePreviewWatermark()
            self.formatView.layoutIfNeeded()
        }
        animated ? UIView.animate(withDuration: 0.3, animations: changes) : changes()
    }

    @objc private func updatePreviewWatermark() {
        previewWatermarkView.isHidden = !watermarkSwitch.isOn
    }

    @objc private func didTapPro() {
        // A/02 P3: contextual upsell for the watermark instead of the full paywall.
        let presenter = presentingViewController
        dismiss(animated: true) {
            guard let presenter else { return }
            ProFeatureSheetViewController.present(.watermark, from: presenter, placement: Constants.Keys.shareImagePlacement)
        }
    }

    // MARK: Export

    private func renderedImage() -> UIImage {
        let pro = isPro && hdSwitch.isOn
        let base: UIImage
        switch format {
        case .result:
            base = after
        case .beforeAfter:
            base = Self.sideBySide(before ?? after, after)
        case .story:
            base = storyImage
        }
        return PhotoSaver.exportImage(base, pro: pro, watermark: watermarkSwitch.isOn)
    }

    private static func sideBySide(_ a: UIImage, _ b: UIImage) -> UIImage {
        let h: CGFloat = 1600
        let w1 = a.size.width / a.size.height * h, w2 = b.size.width / b.size.height * h
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: w1 + w2 + 8, height: h), format: format).image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: w1 + w2 + 8, height: h))
            a.draw(in: CGRect(x: 0, y: 0, width: w1, height: h))
            b.draw(in: CGRect(x: w1 + 8, y: 0, width: w2, height: h))
        }
    }

    private static func story(before: UIImage?, after: UIImage) -> UIImage {
        let size = CGSize(width: 1080, height: 1920)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let half = CGRect(x: 0, y: 0, width: size.width, height: size.height / 2)
            func drawFill(_ image: UIImage, in rect: CGRect) {
                let r = max(rect.width / image.size.width, rect.height / image.size.height)
                let s = CGSize(width: image.size.width * r, height: image.size.height * r)
                ctx.cgContext.saveGState()
                ctx.cgContext.clip(to: rect)
                image.draw(in: CGRect(x: rect.midX - s.width / 2, y: rect.midY - s.height / 2, width: s.width, height: s.height))
                ctx.cgContext.restoreGState()
            }
            if let before {
                drawFill(before, in: half.insetBy(dx: 0, dy: 2))
                drawFill(after, in: half.offsetBy(dx: 0, dy: size.height / 2).insetBy(dx: 0, dy: 2))
            } else {
                drawFill(after, in: CGRect(origin: .zero, size: size))
            }
        }
    }

    // MARK: Actions

    @IBAction private func didTapQuickAction(_ sender: UIControl) {
        let image = renderedImage()
        switch sender.tag {
        case 0:
            PhotoSaver.save(image) { outcome in
                DSToastView.show(outcome == .saved ? "Saved to Photos".localized : "Couldn't save the image".localized,
                                 style: outcome == .saved ? .success : .warning)
            }
        case 1:
            UIPasteboard.general.image = image
            DS.Haptic.success()
            DSToastView.show("Copied".localized, style: .success, symbol: "doc.on.doc")
        case 2 where MFMessageComposeViewController.canSendAttachments():
            let compose = MFMessageComposeViewController()
            compose.messageComposeDelegate = self
            if let data = image.jpegData(compressionQuality: 0.9) {
                compose.addAttachmentData(data, typeIdentifier: "public.jpeg", filename: "rehomely.jpg")
            }
            present(compose, animated: true)
        default:
            didTapShare(sender)
        }
        AmplitudeService.shared.logRedesignEvent("share_action", properties: ["action": sender.tag, "format": format.rawValue])
    }

    @IBAction private func didTapShare(_ sender: Any) {
        let activity = UIActivityViewController(activityItems: [renderedImage()], applicationActivities: nil)
        activity.completionWithItemsHandler = { type, completed, _, _ in
            guard completed else { return }
            AmplitudeService.shared.logRedesignEvent("share_complete", properties: ["channel": type?.rawValue ?? "unknown",
                                                                                   "format": self.format.rawValue])
        }
        activity.popoverPresentationController?.sourceView = shareButton
        present(activity, animated: true)
    }

    @IBAction private func didTapClose(_ sender: Any) {
        dismiss(animated: true)
    }
}

extension ShareSheetViewController: MFMessageComposeViewControllerDelegate {
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true)
    }
}
