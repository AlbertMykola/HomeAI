import UIKit

@IBDesignable
class CustomFontLabel: UILabel {

    @IBInspectable var fontName: String = "" {
        didSet {
            setFont()
        }
    }

    @IBInspectable var fontSize: CGFloat = 17.0 {
        didSet {
            setFont()
        }
    }

    @IBInspectable var baseHeight: CGFloat = 852 {
        didSet {
            scaleFontKeepingFamily()
        }
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        setFont()
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        setFont()
    }

    private func setFont() {
        guard !fontName.isEmpty else { return }
        
        if let customFont = UIFont(name: fontName, size: fontSize) {
            font = customFont
        } else {
            font = UIFont.systemFont(ofSize: fontSize)
        }
        scaleFontKeepingFamily()  // Масштабуємо після встановлення шрифту
    }

    // Кастомна функція для програмної установки
    func setCustomFont(name: String, size: CGFloat) {
        if let customFont = UIFont(name: name, size: size) {
            font = customFont
        } else {
            font = UIFont.systemFont(ofSize: size)
        }
        scaleFontKeepingFamily()  // Масштабуємо після встановлення
    }

    private func scaleFontKeepingFamily() {
        let screenHeight = UIScreen.main.bounds.height
        guard let oldFont = self.font else { return }
        let oldSize = oldFont.pointSize
        let scaleFactor = screenHeight / baseHeight
        let newFontSize = oldSize * scaleFactor
        self.font = UIFont(descriptor: oldFont.fontDescriptor, size: newFontSize)
    }
}
