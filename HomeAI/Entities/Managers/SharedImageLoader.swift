import UIKit

final class SharedImageLoader {
    static let shared = SharedImageLoader()
    
    private let imageCache = NSCache<NSString, UIImage>()
    private let imageService = ImageStorageService()
    private var ongoingRequests: [String: [((UIImage?) -> Void)]] = [:]
    
    private init() {}
    
    func loadImage(path: String, completion: @escaping (UIImage?) -> Void) {
        if let cachedImage = imageCache.object(forKey: path as NSString) {
            completion(cachedImage)
            return
        }
        
        if ongoingRequests[path] != nil {
            ongoingRequests[path]?.append(completion)
            return
        } else {
            ongoingRequests[path] = [completion]
        }
        
        fetch(path: path, retriesLeft: 1) { [weak self] image in
            guard let self = self else { return }
            if let img = image {
                self.imageCache.setObject(img, forKey: path as NSString)
            } else if NetworkMonitor.shared.isOnline {
                self.reportFailure(path: path)
            }
            
            if let completions = self.ongoingRequests[path] {
                for cb in completions {
                    DispatchQueue.main.async {
                        cb(image)
                    }
                }
                self.ongoingRequests.removeValue(forKey: path)
            }
        }
    }

    /// One retry after a short pause: a single dropped connection shouldn't leave a blank card.
    private func fetch(path: String, retriesLeft: Int, completion: @escaping (UIImage?) -> Void) {
        imageService.fetchImage(path: path) { [weak self] image in
            guard let self, image == nil, retriesLeft > 0, NetworkMonitor.shared.isOnline else { return completion(image) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.fetch(path: path, retriesLeft: retriesLeft - 1, completion: completion)
            }
        }
    }

    /// Connection-level failures (host blocked or unreachable on this network, HOMEAI-R) aren't app bugs, so only
    /// a broken file or an unexpected error goes to Sentry, with the URL error attached.
    private func reportFailure(path: String) {
        let error = imageService.lastRemoteError(for: path)
        if let error, ServiceReachability.isUnreachableError(error) { return }
        // Catalog / inspiration image (not user content), so the file name is safe to send.
        var extra = ["file": (path as NSString).lastPathComponent]
        if let error {
            let ns = error as NSError
            extra["url_error"] = "\(ns.domain):\(ns.code)"
        } else {
            extra["url_error"] = "decode_failed"
        }
        ErrorReporter.report(message: "image download failed", operation: "image_download",
                             details: .init(provider: "firebase_storage", extra: extra))
    }
}
