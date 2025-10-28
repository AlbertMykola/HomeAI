import UIKit

@IBDesignable
extension UILabel {
    
    // Базова висота для масштабу, можна змінити у Interface Builder
    @IBInspectable var scaleFontByHeight: Bool {
        get {
            return false
        }
        set {
            if newValue {
                scaleFontKeepingFamily()
            }
        }
    }

    private func scaleFontKeepingFamily(baseHeight: CGFloat = 852) {
        let screenHeight = UIScreen.main.bounds.height
        guard let oldFont = self.font else { return }
        let oldSize = oldFont.pointSize
        let scaleFactor = screenHeight / baseHeight
        let newFontSize = oldSize * scaleFactor
        self.font = UIFont(descriptor: oldFont.fontDescriptor, size: newFontSize)
    }
}
