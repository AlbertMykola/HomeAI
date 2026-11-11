import UIKit

/// SF Symbols in image views are rasterized on the main thread when their screen first lays out (~15 ms per icon
/// in the iOS 27 simulator, every time). A screen with ~20 icons held the push from Home for ~0.3 s.
/// `offload(in:)` draws them on a background queue instead, keeps a same-size empty placeholder meanwhile (so the
/// layout doesn't move), and caches the bitmaps for the rest of the session.
enum SymbolPrerender {

    /// Main thread only.
    private static var cache: [String: UIImage] = [:]
    private static let queue = DispatchQueue(label: "rehomely.symbol-prerender", qos: .userInitiated)

    /// Call from viewDidLoad, before the first layout.
    static func offload(in root: UIView) {
        let scale = UIScreen.main.scale
        var jobs: [(imageView: UIImageView, symbol: UIImage, key: String)] = []
        visit(root) { imageView in
            guard let image = imageView.image, image.isSymbolImage, image.renderingMode != .alwaysOriginal else { return }
            let symbol = imageView.preferredSymbolConfiguration.flatMap { image.applyingSymbolConfiguration($0) } ?? image
            guard symbol.size.width > 0, symbol.size.height > 0 else { return }
            let key = cacheKey(for: symbol, scale: scale)
            if let cached = cache[key] {
                imageView.image = cached
                return
            }
            imageView.image = placeholder(like: symbol, scale: scale)
            jobs.append((imageView, symbol, key))
        }
        guard !jobs.isEmpty else { return }
        let work = jobs.map { (symbol: $0.symbol, key: $0.key) }
        queue.async {
            var rendered: [String: UIImage] = [:]
            for item in work where rendered[item.key] == nil {
                rendered[item.key] = bitmap(of: item.symbol, scale: scale)
            }
            DispatchQueue.main.async {
                rendered.forEach { cache[$0.key] = $0.value }
                for job in jobs {
                    guard let image = rendered[job.key], job.imageView.image?.isSymbolImage == false else { continue }
                    job.imageView.image = image
                }
            }
        }
    }

    private static func visit(_ view: UIView, _ body: (UIImageView) -> Void) {
        if let imageView = view as? UIImageView { body(imageView) }
        view.subviews.forEach { visit($0, body) }
    }

    /// The symbol's description without the object address (name, size, configuration).
    private static func cacheKey(for symbol: UIImage, scale: CGFloat) -> String {
        let description = symbol.description.replacingOccurrences(of: #"0x[0-9a-fA-F]+"#, with: "", options: .regularExpression)
        return "\(description)@\(scale)"
    }

    /// Same size and alignment as the symbol, transparent.
    private static func placeholder(like symbol: UIImage, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let empty = UIGraphicsImageRenderer(size: symbol.size, format: format).image { _ in }
        return finishing(empty, like: symbol)
    }

    /// The symbol drawn into a template bitmap: the image view's tint still colours it.
    private static func bitmap(of symbol: UIImage, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let drawn = UIGraphicsImageRenderer(size: symbol.size, format: format).image { _ in
            symbol.withTintColor(.black, renderingMode: .alwaysOriginal).draw(at: .zero)
        }
        return finishing(drawn, like: symbol)
    }

    private static func finishing(_ image: UIImage, like symbol: UIImage) -> UIImage {
        var result = image.withRenderingMode(.alwaysTemplate).withAlignmentRectInsets(symbol.alignmentRectInsets)
        if let baseline = symbol.baselineOffsetFromBottom { result = result.withBaselineOffset(fromBottom: baseline) }
        return result
    }
}
