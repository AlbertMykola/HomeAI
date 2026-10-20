import UIKit

extension CGFloat {
    
    func scaledByHeight(baseHeight: CGFloat = 852, height: CGFloat? = nil) -> CGFloat {
        let screenHeight = height ?? UIScreen.main.bounds.height
        let scaleFactor = screenHeight / baseHeight
        return self * scaleFactor
    }
    
    func scaledByWidth(baseWidth: CGFloat = 393) -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let scaleFactor = screenWidth / baseWidth
        return self * scaleFactor
    }
}
