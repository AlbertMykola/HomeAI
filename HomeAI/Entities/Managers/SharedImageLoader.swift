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
        
        imageService.fetchImage(path: path) { [weak self] image in
            guard let self = self else { return }
            if let img = image {
                self.imageCache.setObject(img, forKey: path as NSString)
            } else if NetworkMonitor.shared.isOnline {
                // Catalog / inspiration image (not user content), so the file name is safe to send.
                ErrorReporter.report(message: "image download failed", operation: "image_download",
                                     details: .init(provider: "firebase_storage",
                                                    extra: ["file": (path as NSString).lastPathComponent]))
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
}
