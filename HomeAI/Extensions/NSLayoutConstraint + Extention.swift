import UIKit

extension NSLayoutConstraint {

    func scaleConstant(baseHeight: CGFloat = 852, height: CGFloat? = nil) {
        let screenHeight = height ?? UIScreen.main.bounds.height
        let scaleFactor = screenHeight / baseHeight
        self.constant *= scaleFactor
    }
    
    func scaleConstantByWidth(baseWidth: CGFloat = 393) {
        let screenWidth = UIScreen.main.bounds.width
        let scaleFactor = screenWidth / baseWidth
        self.constant *= scaleFactor
    }
}
