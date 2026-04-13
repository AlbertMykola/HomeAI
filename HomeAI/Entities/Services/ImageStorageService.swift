import UIKit
import ImageIO

final class ImageStorageService {
    private let cache = NSCache<NSString, UIImage>()
    private let remoteImageBaseURL = URL(string: Constants.API.supabaseImagesBucket)
    private let firebaseStorageBaseURL = URL(string: "https://firebasestorage.googleapis.com/v0/b/\(Constants.API.firebaseStorageBucket)/o")
    private var tasks = NSMapTable<UIImageView, DispatchWorkItem>(keyOptions: .weakMemory, valueOptions: .strongMemory)

    init() {
        cache.countLimit = 0
        cache.totalCostLimit = 300 * 1024 * 1024
    }

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

        let resolvedSize = resolvedSizeForImageView(imageView, explicit: targetPointSize)

        var work: DispatchWorkItem!
        work = DispatchWorkItem { [weak self, weak imageView] in
            guard let self else { return }
            let image = self.loadImage(path: path, targetPointSize: resolvedSize)
            if let image = image {
                let bytes = self.byteCost(for: resolvedSize)
                self.cache.setObject(image, forKey: path as NSString, cost: bytes)
            }
            DispatchQueue.main.async {
                guard let imageView = imageView else { return }
                if let currentTask = self.tasks.object(forKey: imageView), currentTask === work {
                    imageView.image = image
                    completion?(image)
                    self.tasks.removeObject(forKey: imageView)
                }
            }
        }

        tasks.setObject(work, forKey: imageView)
        DispatchQueue.global(qos: .userInitiated).async(execute: work)
    }

    func cancel(on imageView: UIImageView) {
        tasks.object(forKey: imageView)?.cancel()
        tasks.removeObject(forKey: imageView)
    }

    func fetchImage(path: String, completion: @escaping (UIImage?) -> Void) {
        if let cached = cache.object(forKey: path as NSString) {
            completion(cached)
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let image = self.loadImage(path: path, targetPointSize: .zero)
            if let image = image {
                let scale = UIScreen.main.scale
                let pxW = Int(image.size.width * scale)
                let pxH = Int(image.size.height * scale)
                self.cache.setObject(image, forKey: path as NSString, cost: pxW * pxH * 4)
            }
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }

    func fetchImage(path: String) async throws -> UIImage {
        if let cached = cache.object(forKey: path as NSString) {
            return cached
        }
        return try await withCheckedThrowingContinuation { continuation in
            fetchImage(path: path) { image in
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: NSError(domain: "image.load", code: -1))
                }
            }
        }
    }

    // MARK: - Helpers

    private func resolvedSizeForImageView(_ imageView: UIImageView, explicit: CGSize?) -> CGSize {
        if let explicit, explicit != .zero { return explicit }
        let bounds = imageView.bounds.size
        if bounds != .zero { return bounds }
        let intrinsic = imageView.intrinsicContentSize
        if intrinsic != .zero { return intrinsic }
        return CGSize(width: 1, height: 1)
    }

    private func byteCost(for size: CGSize) -> Int {
        let scale = UIScreen.main.scale
        return Int(size.width * scale) * Int(size.height * scale) * 4
    }

    private func loadImage(path: String, targetPointSize: CGSize) -> UIImage? {
        if let remoteURL = remoteURL(for: path) {
            if let image = loadRemoteImage(at: remoteURL, targetPointSize: targetPointSize) {
                return image
            }
            if let fallbackURL = fallbackRemoteURL(for: path, primaryURL: remoteURL) {
                return loadRemoteImage(at: fallbackURL, targetPointSize: targetPointSize)
            }
            return nil
        }

        let fileURL = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            if targetPointSize == .zero {
                return UIImage(contentsOfFile: fileURL.path)
            }
            if let downsampled = downsample(imageAt: fileURL, to: targetPointSize, scale: UIScreen.main.scale) {
                return downsampled
            }
            return UIImage(contentsOfFile: fileURL.path)
        }

        return loadBundledImage(namedPath: path, targetPointSize: targetPointSize)
    }

    private func loadBundledImage(namedPath path: String, targetPointSize: CGSize) -> UIImage? {
        let lastComponent = (path as NSString).lastPathComponent
        let baseName = (lastComponent as NSString).deletingPathExtension
        let ext = (lastComponent as NSString).pathExtension

        if let ext = ext.isEmpty ? nil : ext,
           let url = Bundle.main.url(forResource: baseName, withExtension: ext) {
            if targetPointSize == .zero {
                return UIImage(contentsOfFile: url.path)
            }
            return downsample(imageAt: url, to: targetPointSize, scale: UIScreen.main.scale)
        }

        return UIImage(named: baseName) ?? UIImage(named: lastComponent) ?? UIImage(named: path)
    }
    
    private func remoteURL(for path: String) -> URL? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        if let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty {
            if scheme == "gs" {
                let bucket = url.host ?? Constants.API.firebaseStorageBucket
                let objectPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                return firebaseDownloadURL(bucket: bucket, objectPath: objectPath)
            }
            if scheme == "file" {
                // Treat as local file URL
                return url
            }
            return url
        }
        
        if trimmed.hasPrefix("/") {
            return nil
        }
        
        // Check if it's a Supabase path (simple filename or path without scheme)
        if let supabaseBase = remoteImageBaseURL {
            // If it's a simple filename or a path (contains / but not a full URL)
            if isSimpleFilename(trimmed) || (trimmed.contains("/") && !trimmed.contains("://")) {
                return supabaseDownloadURL(base: supabaseBase, fileName: trimmed)
            }
        }
        
        return firebaseDownloadURL(bucket: Constants.API.firebaseStorageBucket, objectPath: trimmed)
    }
    
    private func fallbackRemoteURL(for path: String, primaryURL: URL) -> URL? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // Fallback applies only to relative paths that include folders,
        // e.g. "template_suggestions/file.webp" -> "file.webp".
        if let parsed = URL(string: trimmed), let scheme = parsed.scheme, !scheme.isEmpty {
            return nil
        }
        let fileName = (trimmed as NSString).lastPathComponent
        guard fileName != trimmed else { return nil }
        guard let supabaseBase = remoteImageBaseURL,
              let fallback = supabaseDownloadURL(base: supabaseBase, fileName: fileName),
              fallback.absoluteString != primaryURL.absoluteString else {
            return nil
        }
        return fallback
    }
    
    private func loadRemoteImage(at url: URL, targetPointSize: CGSize) -> UIImage? {
        do {
            let data = try Data(contentsOf: url)
            if targetPointSize == .zero {
                return UIImage(data: data)
            }
            let cfData = data as CFData
            let options = [kCGImageSourceShouldCache: false] as CFDictionary
            guard let src = CGImageSourceCreateWithData(cfData, options) else { return UIImage(data: data) }
            let maxDimension = max(targetPointSize.width, targetPointSize.height) * UIScreen.main.scale
            let downsampleOptions = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension
            ] as CFDictionary
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(src, 0, downsampleOptions) else {
                return UIImage(data: data)
            }
            return UIImage(cgImage: cgImage)
        } catch {
            #if DEBUG
            print("[ImageStorageService] Failed to load remote image: \(url.absoluteString) error: \(error)")
            #endif
            return nil
        }
    }

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

private extension ImageStorageService {
    func isSimpleFilename(_ path: String) -> Bool {
        return !path.contains("/") && path.contains(".")
    }
    
    func supabaseDownloadURL(base: URL, fileName: String) -> URL? {
        let encoded = fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileName
        let baseString = base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(baseString)/\(encoded)")
    }
    
    func firebaseDownloadURL(bucket: String, objectPath: String) -> URL? {
        guard !bucket.isEmpty else { return nil }
        let trimmed = objectPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmed.isEmpty else { return nil }
        let allowed = CharacterSet.urlPathAllowed
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: allowed) ?? trimmed
        let slashEncoded = encoded.replacingOccurrences(of: "/", with: "%2F")
        let baseString: String
        if let firebaseBaseURL = firebaseStorageBaseURL?.absoluteString {
            baseString = firebaseBaseURL.hasSuffix("/o") ? "\(firebaseBaseURL)/" : firebaseBaseURL
        } else {
            baseString = "https://firebasestorage.googleapis.com/v0/b/\(bucket)/o/"
        }
        return URL(string: "\(baseString)\(slashEncoded)?alt=media")
    }
}
