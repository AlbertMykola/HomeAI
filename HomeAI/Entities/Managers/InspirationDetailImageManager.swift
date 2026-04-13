import UIKit
import Photos

final class InspirationDetailImageManager {

    private struct Text {
        static let saved = "Saved".localized
        static let error = "Error".localized
        static let message = "Image saved to photo gallery".localized
    }

    func saveToGallery(image: UIImage, storagePath: String?, from viewController: UIViewController) {
        guard ApphudService.shared.hasActiveSubscription else {
            NavigationManager.shared.showPremium(placement: Constants.Keys.saveImagePlacement)
            return
        }

        PHPhotoLibrary.shared().performChanges({
            if let storagePath,
               FileManager.default.fileExists(atPath: storagePath) {
                let url = URL(fileURLWithPath: storagePath)
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
            } else {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        }) { success, error in
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: success ? Text.saved : Text.error,
                    message: success ? Text.message : (error?.localizedDescription ?? "Unknown error"),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                viewController.present(alert, animated: true)
            }
        }
    }

    func share(image: UIImage, from viewController: UIViewController) {
        guard ApphudService.shared.hasActiveSubscription else {
            NavigationManager.shared.showPremium(placement: Constants.Keys.shareImagePlacement)
            return
        }

        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = viewController.view
        viewController.present(activityVC, animated: true)
    }
}
