import UIKit

extension UIImage {
    var generationPixelSize: CGSize {
        if let cgImage {
            return CGSize(width: cgImage.width, height: cgImage.height)
        }
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    func normalizedForGeneration(maxLongEdge: CGFloat = Constants.Generation.maxImageLongEdge) -> UIImage {
        guard size.width > 0, size.height > 0 else { return self }

        let longEdge = max(size.width, size.height)
        let resizeScale = min(1, maxLongEdge / longEdge)
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
