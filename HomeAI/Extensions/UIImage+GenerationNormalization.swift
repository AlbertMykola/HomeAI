import UIKit

extension UIImage {
    var generationPixelSize: CGSize {
        if let cgImage {
            return CGSize(width: cgImage.width, height: cgImage.height)
        }
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    /// Long edge a picked photo is kept at: generation sends at most `maxImageLongEdge`, every screen shows it smaller.
    static let pickedPhotoLongEdge: CGFloat = 2_048

    /// A picked or captured photo, made small enough to work with. Call it OFF the main thread, right after picking:
    /// a camera photo is 12–48 MP, and decoding and redrawing that on the main thread (every screen that shows it,
    /// normalizedForGeneration at Generate) froze iPhone 13/14 for 3–4 s (Sentry App Hangs) and took up to ~190 MB.
    func preparedForEditing() -> UIImage {
        normalizedForGeneration(maxLongEdge: Self.pickedPhotoLongEdge)
    }

    /// `preparedForEditing()` on a background queue; `completion` runs on the main queue.
    static func prepareForEditing(_ image: UIImage, completion: @escaping (UIImage) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let prepared = image.preparedForEditing()
            DispatchQueue.main.async { completion(prepared) }
        }
    }

    func normalizedForGeneration(maxLongEdge: CGFloat = Constants.Generation.maxImageLongEdge) -> UIImage {
        guard size.width > 0, size.height > 0 else { return self }

        let longEdge = max(size.width, size.height)
        let resizeScale = min(1, maxLongEdge / longEdge)
        // Already a 1x, upright bitmap within the limit (e.g. prepared when picked): redrawing it would only cost
        // main-thread time.
        if resizeScale == 1, scale == 1, imageOrientation == .up, cgImage != nil { return self }
        let targetSize = CGSize(
            width: max(1, (size.width * resizeScale).rounded()),
            height: max(1, (size.height * resizeScale).rounded())
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
