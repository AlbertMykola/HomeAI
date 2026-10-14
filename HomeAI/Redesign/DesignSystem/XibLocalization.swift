import UIKit

/// XIB texts are English design copy; xibgen writes each one as a `locKey` runtime attribute too,
/// so the nib shows the translation from Localizable.strings as soon as it loads. Code may still set its own text.
extension UILabel {
    @IBInspectable var locKey: String? {
        get { nil }
        set { if let newValue { text = newValue.localized } }
    }
}

extension UIButton {
    @IBInspectable var locKey: String? {
        get { nil }
        set { if let newValue { setTitle(newValue.localized, for: .normal) } }
    }
}
