import UIKit
import FirebaseStorage
import ImageIO

final class ImageStorageService {
    private let storage = Storage.storage()
    private let cache = NSCache<NSString, UIImage>()
    // Прив’язуємо активні завантаження до конкретного imageView для можливості cancel на reuse
    private var tasks = NSMapTable<UIImageView, URLSessionDataTask>(keyOptions: .weakMemory, valueOptions: .strongMemory)

    init() {
        // Налаштування RAM-кешу (можна тюнити під проєкт)
        cache.countLimit = 0 // нехай керує лише totalCostLimit
        cache.totalCostLimit = 300 * 1024 * 1024 // ~300MB
    }

    // MARK: - Public API

    // Встановити зображення у ImageView за шляхом у Storage з плейсхолдером, кешем і downsampling
    @MainActor
    func setImage(
        on imageView: UIImageView,
        path: String,
        placeholder: UIImage? = nil,
        targetPointSize: CGSize? = nil,
        completion: ((UIImage?) -> Void)? = nil
    ) {
        imageView.image = placeholder
        cancel(on: imageView)

        if let cached = cache.object(forKey: path as NSString) {
            imageView.image = cached
            completion?(cached)
            return
        }

        let resolvedSize: CGSize = {
            if let s = targetPointSize, s != .zero { return s }
            let b = imageView.bounds.size
            if b != .zero { return b }
            let i = imageView.intrinsicContentSize
            return i == .zero ? CGSize(width: 1, height: 1) : i
        }()

        // Мережа + даунсемплінг на фоні
        let ref = storage.reference(withPath: path)
        ref.downloadURL { [weak self, weak imageView] url, _ in
            guard let self, let imageView, let url else { return }
            let task = URLSession.shared.dataTask(with: url) { [weak self, weak imageView] data, _, _ in
                guard let self, let imageView, let data = data else { return }

                let image: UIImage?
                if let tmpURL = self.writeTemp(data: data) {
                    image = self.downsample(imageAt: tmpURL, to: resolvedSize, scale: UIScreen.main.scale)
                    try? FileManager.default.removeItem(at: tmpURL)
                } else {
                    image = UIImage(data: data)
                }

                if let img = image {
                    let scale = UIScreen.main.scale
                    let bytes = Int(resolvedSize.width * scale) * Int(resolvedSize.height * scale) * 4
                    self.cache.setObject(img, forKey: path as NSString, cost: bytes)
                    DispatchQueue.main.async {
                        imageView.image = img
                        completion?(img)
                    }
                } else {
                    DispatchQueue.main.async { completion?(nil) }
                }
                self.tasks.removeObject(forKey: imageView)
            }
            self.tasks.setObject(task, forKey: imageView)
            task.resume()
        }
    }

    // Скасувати активне завантаження для конкретного ImageView (викликати у prepareForReuse)
    func cancel(on imageView: UIImageView) {
        tasks.object(forKey: imageView)?.cancel()
        tasks.removeObject(forKey: imageView)
    }

    // Пряме отримання UIImage (callback) — з кешем і URLSession
    func fetchImage(path: String, completion: @escaping (UIImage?) -> Void) {
        if let cached = cache.object(forKey: path as NSString) {
            completion(cached)
            return
        }
        let ref = storage.reference(withPath: path)
        ref.downloadURL { [weak self] url, _ in
            guard let self, let url else { completion(nil); return }
            URLSession.shared.dataTask(with: url) { data, _, _ in
                guard let data = data, let img = UIImage(data: data) else { completion(nil); return }
                let scale = UIScreen.main.scale
                let pxW = Int(img.size.width * scale)
                let pxH = Int(img.size.height * scale)
                let bytes = pxW * pxH * 4
                self.cache.setObject(img, forKey: path as NSString, cost: bytes)
                completion(img)
            }.resume()
        }
    }

    // Async/await варіант (зручний у в’ю‑моделях)
    func fetchImage(path: String) async throws -> UIImage {
        if let cached = cache.object(forKey: path as NSString) { return cached }
        let url = try await downloadURL(for: path)
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let img = UIImage(data: data) else { throw NSError(domain: "image.decode", code: -1) }
        let scale = UIScreen.main.scale
        let pxW = Int(img.size.width * scale)
        let pxH = Int(img.size.height * scale)
        let bytes = pxW * pxH * 4
        cache.setObject(img, forKey: path as NSString, cost: bytes)
        return img
    }

    // Async helper для downloadURL
    func downloadURL(for path: String) async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            storage.reference(withPath: path).downloadURL { url, err in
                if let err = err { cont.resume(throwing: err) }
                else if let url = url { cont.resume(returning: url) }
                else { cont.resume(throwing: NSError(domain: "image.url", code: -1)) }
            }
        }
    }

    // MARK: - Private helpers

    private func writeTemp(data: Data) -> URL? {
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent(UUID().uuidString + ".img")
        do { try data.write(to: url); return url } catch { return nil }
    }

    // WWDC‑рекомендоване downsampling через ImageIO
    private func downsample(imageAt url: URL, to pointSize: CGSize, scale: CGFloat = UIScreen.main.scale) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let src = CGImageSourceCreateWithURL(url as CFURL, imageSourceOptions) else { return nil }
        let maxDimensionInPixels = max(pointSize.width, pointSize.height) * scale
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, downsampleOptions) else { return nil }
        return UIImage(cgImage: cg)
    }
}
