import Foundation
import UIKit
import AudioToolbox

public enum AlertTimeout: Double {
    case low = 0.95
    case medium = 1.7
    case long = 2.5
}

extension UIViewController {
        
    func hapticVibration(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        if UIDevice.current.hasHapticFeedback {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.impactOccurred()
        } else {
            AudioServicesPlaySystemSound(1519)
        }
    }
    
    func hardHapticVibration() {
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
    }
    
    func presentHidingAlert(title: String?, message: String, timeOut: AlertTimeout = .low, completion: (() -> ())? = nil) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        DispatchQueue.main.async { [weak self] in
            self?.present(alertController, animated: true)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + timeOut.rawValue) {
            alertController.dismiss(animated: true)
            if let completion = completion {
                completion()
            }
        }
    }
}

extension UIDevice {
    
    // MARK: - Internal methods
    var hasHapticFeedback: Bool {
        guard let value = UIDevice.current.value(forKey: "_feedbackSupportLevel"),
            let resultValue = value as? Int else {
            return false
        }
        return resultValue == 2
    }
}
