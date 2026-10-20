import UIKit
import ImageIO

/// Downsampled, cached thumbnails for local history files.
enum ThumbnailLoader {

    private static let cache = NSCache<NSString, UIImage>()
    private static let queue = DispatchQueue(label: "ThumbnailLoader", qos: .userInitiated, attributes: .concurrent)

    static func load(path: String, pointSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        let key = "\(path)#\(Int(pointSize.width))x\(Int(pointSize.height))" as NSString
        if let cached = cache.object(forKey: key) {
            completion(cached)
            return
        }
        let scale = UIScreen.main.scale
        queue.async {
            let image = downsample(url: URL(fileURLWithPath: path), maxPixel: max(pointSize.width, pointSize.height) * scale * 1.4)
            if let image { cache.setObject(image, forKey: key) }
            DispatchQueue.main.async { completion(image) }
        }
    }

    private static func downsample(url: URL, maxPixel: CGFloat) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options) else { return nil }
        let thumbOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ] as CFDictionary
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions) else { return nil }
        return UIImage(cgImage: cg)
    }
}

extension ImageDoc {
    /// "Living room", "Facade", … — what the project is about.
    var projectTitle: String {
        if let room = savedInteriorRoomType { return room.name }
        if let building = savedExteriorBuildingType { return building.name }
        if let garden = savedGardenType { return garden.name }
        return designOption?.title ?? "Design".localized
    }
}

extension Date {
    /// "Today", "Yesterday", "12 Oct".
    var projectRelativeString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return "Today".localized }
        if calendar.isDateInYesterday(self) { return "Yesterday".localized }
        let f = DateFormatter()
        f.locale = AppLocalization.locale
        f.setLocalizedDateFormatFromTemplate("d MMM")
        return f.string(from: self)
    }
}

/// Bundled asset first (names in enums carry a ".png" suffix), remote/shared loader as fallback.
enum CatalogImage {
    static func load(_ path: String, completion: @escaping (UIImage?) -> Void) {
        #if DEBUG
        if AppQA.enabled { completion(AppQA.photo); return }
        #endif
        let base = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
        if let local = UIImage(named: base) ?? UIImage(named: path) {
            completion(local)
            return
        }
        SharedImageLoader.shared.loadImage(path: path, completion: completion)
    }
}
