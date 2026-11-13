import UIKit
import ImageIO

final class ImageStorageService {
    private let cache = NSCache<NSString, UIImage>()
    private let remoteImageBaseURL = URL(string: Constants.API.supabaseImagesBucket)
    private let firebaseStorageBaseURL = URL(string: "https://firebasestorage.googleapis.com/v0/b/\(Constants.API.firebaseStorageBucket)/o")
    private var tasks = NSMapTable<UIImageView, DispatchWorkItem>(keyOptions: .weakMemory, valueOptions: .strongMemory)
    private let errorLock = NSLock()
    private var remoteErrors: [String: Error] = [:]
    /// Short-lived session: catalog images are small; a stuck host must not hold a cell for a minute.
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 40
        return URLSession(configuration: config)
    }()

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
        let scale = UIScreen.main.scale

        var work: DispatchWorkItem!
        work = DispatchWorkItem { [weak self, weak imageView] in
            guard let self else { return }
            let image = self.loadImage(path: path, targetPointSize: resolvedSize, scale: scale)
            if let image = image {
                let bytes = self.byteCost(for: resolvedSize, scale: scale)
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

        let scale = UIScreen.main.scale
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let image = self.loadImage(path: path, targetPointSize: .zero, scale: scale)
            if let image = image {
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
                DispatchQueue.main.async {
                    if let image {
                        continuation.resume(returning: image)
                    } else {
                        continuation.resume(throwing: NSError(domain: "image.load", code: -1))
                    }
                }
            }
        }
    }

    /// Why the last remote load of `path` failed (nil when it loaded, or never went to the network).
    /// With a fallback this is the primary host's error: that is the one worth fixing.
    func lastRemoteError(for path: String) -> RemoteImageError? {
        errorLock.lock()
        defer { errorLock.unlock() }
        return remoteErrors[path] as? RemoteImageError
    }

    private func recordRemoteResult(_ error: RemoteImageError?, for path: String) {
        errorLock.lock()
        remoteErrors[path] = error
        errorLock.unlock()
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

    private func byteCost(for size: CGSize, scale: CGFloat) -> Int {
        return Int(size.width * scale) * Int(size.height * scale) * 4
    }

    private func loadImage(path: String, targetPointSize: CGSize, scale: CGFloat) -> UIImage? {
        if let remoteURL = remoteURL(for: path) {
            if remoteURL.isFileURL {
                return loadLocalImage(at: remoteURL, targetPointSize: targetPointSize, scale: scale)
            }
            let primary = loadRemoteImage(at: remoteURL, targetPointSize: targetPointSize, scale: scale)
            if let image = primary.image {
                recordRemoteResult(nil, for: path)
                return image
            }
            // Supabase down (402 quota restriction, outage) or the file missing there: try the other copies.
            for fallbackURL in fallbackRemoteURLs(for: path, primaryURL: remoteURL) {
                if let image = loadRemoteImage(at: fallbackURL, targetPointSize: targetPointSize, scale: scale).image {
                    recordRemoteResult(nil, for: path)
                    return image
                }
            }
            recordRemoteResult(primary.error, for: path)
            return nil
        }

        let fileURL = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return loadLocalImage(at: fileURL, targetPointSize: targetPointSize, scale: scale)
        }

        return loadBundledImage(namedPath: path, targetPointSize: targetPointSize, scale: scale)
    }

    private func loadLocalImage(at fileURL: URL, targetPointSize: CGSize, scale: CGFloat) -> UIImage? {
        if targetPointSize == .zero {
            return UIImage(contentsOfFile: fileURL.path)
        }
        return downsample(imageAt: fileURL, to: targetPointSize, scale: scale) ?? UIImage(contentsOfFile: fileURL.path)
    }

    private func loadBundledImage(namedPath path: String, targetPointSize: CGSize, scale: CGFloat) -> UIImage? {
        let lastComponent = (path as NSString).lastPathComponent
        let baseName = (lastComponent as NSString).deletingPathExtension
        let ext = (lastComponent as NSString).pathExtension

        if let ext = ext.isEmpty ? nil : ext,
           let url = Bundle.main.url(forResource: baseName, withExtension: ext) {
            if targetPointSize == .zero {
                return UIImage(contentsOfFile: url.path)
            }
            return downsample(imageAt: url, to: targetPointSize, scale: scale)
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
    
    /// Other places the same catalog image may live, in order:
    /// - relative paths with folders also exist flat in Supabase ("template_suggestions/file.webp" -> "file.webp");
    /// - every Supabase catalog path is mirrored in Firebase Storage under the same path, so the catalog
    ///   survives a Supabase restriction (HOMEAI-R: the 402 quota block took every catalog image down).
    private func fallbackRemoteURLs(for path: String, primaryURL: URL) -> [URL] {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        if let parsed = URL(string: trimmed), let scheme = parsed.scheme, !scheme.isEmpty {
            return []
        }

        var urls: [URL] = []
        let fileName = (trimmed as NSString).lastPathComponent
        if fileName != trimmed, let supabaseBase = remoteImageBaseURL,
           let flat = supabaseDownloadURL(base: supabaseBase, fileName: fileName) {
            urls.append(flat)
        }
        if Self.provider(for: primaryURL) == "supabase",
           let mirror = firebaseDownloadURL(bucket: Constants.API.firebaseStorageBucket,
                                            objectPath: "\(Constants.API.supabaseStorageBucket)/\(trimmed)") {
            urls.append(mirror)
        }
        return urls.filter { $0.absoluteString != primaryURL.absoluteString }
    }

    /// "supabase" / "firebase_storage" / host — what goes into the error report's `provider`.
    static func provider(for url: URL) -> String {
        let host = url.host ?? ""
        if host.hasSuffix("supabase.co") { return "supabase" }
        if host.contains("firebasestorage") || host.contains("googleapis") { return "firebase_storage" }
        return host.isEmpty ? "unknown" : host
    }

    /// Synchronous on purpose: callers already run on a background queue. Unlike `Data(contentsOf:)`,
    /// this sees the HTTP status, so a 402 / 404 is reported as such instead of NSCocoaErrorDomain:256.
    private func loadRemoteImage(at url: URL, targetPointSize: CGSize, scale: CGFloat)
        -> (image: UIImage?, error: RemoteImageError?) {
        let provider = Self.provider(for: url)
        var result: Result<Data, RemoteImageError> = .failure(.init(provider: provider, kind: .noResponse))
        let done = DispatchSemaphore(value: 0)
        session.dataTask(with: url) { data, response, error in
            defer { done.signal() }
            if let error {
                result = .failure(.init(provider: provider, kind: .transport(error)))
            } else if let http = response as? HTTPURLResponse, !(200 ..< 300).contains(http.statusCode) {
                result = .failure(.init(provider: provider, kind: .httpStatus(http.statusCode)))
            } else if let data, !data.isEmpty {
                result = .success(data)
            }
        }.resume()
        done.wait()

        switch result {
        case .failure(let error):
            #if DEBUG
            print("[ImageStorageService] Failed to load remote image: \(url.absoluteString) error: \(error)")
            #endif
            return (nil, error)
        case .success(let data):
            guard let image = decode(data, targetPointSize: targetPointSize, scale: scale) else {
                return (nil, .init(provider: provider, kind: .decodeFailed))
            }
            return (image, nil)
        }
    }

    private func decode(_ data: Data, targetPointSize: CGSize, scale: CGFloat) -> UIImage? {
        do {
            if targetPointSize == .zero {
                return UIImage(data: data)
            }
            let cfData = data as CFData
            let options = [kCGImageSourceShouldCache: false] as CFDictionary
            guard let src = CGImageSourceCreateWithData(cfData, options) else { return UIImage(data: data) }
            let maxDimension = max(targetPointSize.width, targetPointSize.height) * scale
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
        }
    }

    private func downsample(imageAt url: URL, to pointSize: CGSize, scale: CGFloat) -> UIImage? {
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

/// Why a remote catalog image didn't load: which host, and HTTP status / transport error / bad bytes.
struct RemoteImageError: Error, CustomStringConvertible {
    enum Kind {
        case httpStatus(Int)
        case transport(Error)
        case decodeFailed
        case noResponse
    }

    let provider: String
    let kind: Kind

    var httpStatus: Int? {
        if case .httpStatus(let code) = kind { return code }
        return nil
    }

    /// Short, stable code for grouping: "http_402", "NSURLErrorDomain:-1001", "decode_failed".
    var code: String {
        switch kind {
        case .httpStatus(let status): return "http_\(status)"
        case .transport(let error):
            let ns = error as NSError
            return "\(ns.domain):\(ns.code)"
        case .decodeFailed: return "decode_failed"
        case .noResponse: return "no_response"
        }
    }

    var isUnreachable: Bool {
        if case .transport(let error) = kind { return ServiceReachability.isUnreachableError(error) }
        return false
    }

    var description: String { "\(provider) \(code)" }
}
