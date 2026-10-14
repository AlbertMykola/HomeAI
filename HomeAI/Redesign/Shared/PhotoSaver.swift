import UIKit
import Photos

/// Saves a design to Photos (add-only access). Free: 1080 px + "Made with Rehomely" mark; Pro: full size, no mark.
enum PhotoSaver {

    enum Outcome { case saved, denied, failed }

    static func save(_ image: UIImage, completion: @escaping (Outcome) -> Void) {
        let output = exportImage(image, pro: AdaptyService.shared.hasActiveSubscription, watermark: nil)
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { completion(.denied) }
                return
            }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: output)
            }, completionHandler: { ok, _ in
                DispatchQueue.main.async { completion(ok ? .saved : .failed) }
            })
        }
    }

    /// Free exports are capped at 1080 px; the mark is on by default for free and optional for Pro.
    static func exportImage(_ image: UIImage, pro: Bool, watermark: Bool?) -> UIImage {
        let addMark = watermark ?? !pro
        let maxSide: CGFloat = pro ? 4096 : 1080
        let longest = max(image.size.width * image.scale, image.size.height * image.scale)
        let ratio = min(1, maxSide / longest)
        let size = CGSize(width: (image.size.width * image.scale * ratio).rounded(),
                          height: (image.size.height * image.scale * ratio).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
            guard addMark else { return }
            let text = "Made with \(Constants.Text.brand)" as NSString
            let fontSize = max(14, size.width * 0.028)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.geologica(.standard(.semiBold), size: fontSize),
                .foregroundColor: UIColor.white.withAlphaComponent(0.92)
            ]
            let textSize = text.size(withAttributes: attrs)
            let pad = fontSize * 0.7
            let rect = CGRect(x: size.width - textSize.width - pad * 3, y: size.height - textSize.height - pad * 3,
                              width: textSize.width + pad * 2, height: textSize.height + pad)
            UIColor.black.withAlphaComponent(0.35).setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2).fill()
            text.draw(at: CGPoint(x: rect.minX + pad, y: rect.minY + pad / 2), withAttributes: attrs)
        }
    }
}
