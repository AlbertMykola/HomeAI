import UIKit

extension UIButton {

    // MARK: - Liquid Glass style (iOS 26+)
    // 0=glass, 1=clearGlass, 2=prominentGlass, 3=prominentClearGlass, 4=filled
    @IBInspectable
    var glassStyleRaw: Int {
        get {
            if #available(iOS 26.0, *) {
                switch configuration {
                case .glass():                 return 0
                case .clearGlass():            return 1
                case .prominentGlass():        return 2
                case .prominentClearGlass():   return 3
                case .filled():                return 4
                default:                       return 0
                }
            } else {
                return 0
            }
        }
        set {
            applyGlassStyle(newValue)
        }
    }

    private func applyGlassStyle(_ raw: Int) {
        if #available(iOS 26.0, *) {
            var newConfig: UIButton.Configuration
            switch raw {
            case 1: newConfig = .clearGlass()
            case 2: newConfig = .prominentGlass()
            case 3: newConfig = .prominentClearGlass()
            case 4: newConfig = .filled()
            default: newConfig = .glass()
            }

            // зберегти важливі параметри зі старої конфігурації
            if let old = self.configuration {
                newConfig.title = old.title
                newConfig.image = old.image
                newConfig.imagePlacement = old.imagePlacement
                newConfig.imagePadding = old.imagePadding
                newConfig.attributedTitle = old.attributedTitle
                newConfig.baseForegroundColor = old.baseForegroundColor
                newConfig.baseBackgroundColor = old.baseBackgroundColor
                newConfig.background = old.background
                if #available(iOS 26.0, *) {
                    newConfig.symbolContentTransition = old.symbolContentTransition
                }
                newConfig.contentInsets = old.contentInsets
                newConfig.subtitle = old.subtitle
            }

            self.configuration = newConfig
        } else {
            // Fallback для iOS < 26: опційно використовувати .filled або залишити існуючу конфігурацію
            if raw == 4 {
                var cfg = self.configuration ?? .filled()
                if let old = self.configuration {
                    cfg.title = old.title
                    cfg.image = old.image
                    cfg.imagePlacement = old.imagePlacement
                    cfg.imagePadding = old.imagePadding
                    cfg.attributedTitle = old.attributedTitle
                    cfg.baseForegroundColor = old.baseForegroundColor
                    cfg.baseBackgroundColor = old.baseBackgroundColor
                    cfg.background = old.background
                    cfg.contentInsets = old.contentInsets
                    cfg.subtitle = old.subtitle
                }
                self.configuration = cfg
            }
        }
    }

    // MARK: - Title (plain)
    @IBInspectable
    var buttonTitle: String? {
        get { return configuration?.title }
        set {
            var cfg = configuration ?? UIButton.Configuration.plain()
            cfg.title = newValue
            self.configuration = cfg
        }
    }

    // MARK: - System image
    @IBInspectable
    var systemImageName: String? {
        get { configuration?.image?.accessibilityIdentifier }
        set {
            guard let name = newValue else { return }
            var cfg = configuration ?? UIButton.Configuration.plain()
            cfg.image = UIImage(systemName: name)
            self.configuration = cfg
        }
    }

    // MARK: - Image placement: 0 leading, 1 trailing, 2 top, 3 bottom
    @IBInspectable
    var imagePlacementRaw: Int {
        get {
            switch configuration?.imagePlacement {
            case .trailing: return 1
            case .top:      return 2
            case .bottom:   return 3
            default:        return 0
            }
        }
        set {
            var cfg = configuration ?? UIButton.Configuration.plain()
            switch newValue {
            case 1: cfg.imagePlacement = .trailing
            case 2: cfg.imagePlacement = .top
            case 3: cfg.imagePlacement = .bottom
            default: cfg.imagePlacement = .leading
            }
            self.configuration = cfg
        }
    }

    @IBInspectable
    var imagePadding: CGFloat {
        get { configuration?.imagePadding ?? 0 }
        set {
            var cfg = configuration ?? UIButton.Configuration.plain()
            cfg.imagePadding = newValue
            self.configuration = cfg
        }
    }

    // MARK: - Symbol transition (iOS 26+)
    @IBInspectable
    var symbolTransitionReplace: Bool {
        get {
            if #available(iOS 26.0, *) {
                return configuration?.symbolContentTransition != nil
            } else {
                return false
            }
        }
        set {
            if #available(iOS 26.0, *) {
                var cfg = configuration ?? .glass()
                cfg.symbolContentTransition = newValue ? UISymbolContentTransition(.replace) : nil
                self.configuration = cfg
            }
        }
    }

    // MARK: - Colors
    @IBInspectable
    var buttonColor: UIColor? {
        get { return configuration?.baseForegroundColor }
        set {
            var cfg = configuration ?? UIButton.Configuration.plain()
            cfg.baseForegroundColor = newValue
            self.configuration = cfg
        }
    }

    @IBInspectable
    var buttonBackgroundColor: UIColor? {
        get { return configuration?.background.backgroundColor }
        set {
            var cfg = configuration ?? UIButton.Configuration.plain()
            var bg = cfg.background
            bg.backgroundColor = newValue
            cfg.background = bg
            self.configuration = cfg
        }
    }

    // MARK: - Font by PostScript name
    @IBInspectable
    var buttonFontName: String? {
        get { nil }
        set {
            var cfg = configuration ?? UIButton.Configuration.plain()
            let baseSize = UIFont.labelFontSize
            let uiFont = newValue.flatMap { UIFont(name: $0, size: baseSize) } ?? UIFont.systemFont(ofSize: baseSize)

            // Якщо заголовок вже атрибутований — оновити шрифт, інакше створити новий AttributedString
            if var attr = cfg.attributedTitle {
                attr.font = uiFont
                cfg.attributedTitle = attr
            } else {
                var attr = AttributedString(cfg.title ?? "")
                attr.font = uiFont
                cfg.attributedTitle = attr
            }
            self.configuration = cfg
        }
    }
}
