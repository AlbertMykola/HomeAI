import UIKit

public enum GeologicaFamily {
    case standard(GeologicaWeight)     // Geologica-*
    case auto(GeologicaWeight)         // Geologica_Auto-*
    case cursive(GeologicaWeight)      // Geologica_Cursive-*
}

public enum GeologicaWeight: String {
    case thin = "Thin"
    case extraLight = "ExtraLight"
    case light = "Light"
    case regular = "Regular"
    case medium = "Medium"
    case semiBold = "SemiBold"
    case bold = "Bold"
    case extraBold = "ExtraBold"
    case black = "Black"
}

// MARK: - App typography

/// Готові стилі тексту: Geologica + базовий pt з макету (висота 852), масштаб через `scaledByHeight`.
public enum AppTypography {
    /// Заголовок секції (напр. «Smart tools»).
    case sectionHeaderTitle
    /// Другорядне посилання в шапці секції (напр. «See all»).
    case sectionHeaderLink

    public var font: UIFont {
        switch self {
        case .sectionHeaderTitle:
            UIFont.geologica(.standard(.medium), size: CGFloat(18).scaledByHeight())
        case .sectionHeaderLink:
            UIFont.geologica(.standard(.medium), size: CGFloat(15).scaledByHeight())
        }
    }
}

public extension UIFont {

    static func geologica(_ family: GeologicaFamily, size: CGFloat, textStyle: UIFont.TextStyle? = nil, maximumPointSize: CGFloat? = nil) -> UIFont {
        let name = geologicaFontName(for: family)

        let base = UIFont(name: name, size: size) ?? .systemFont(ofSize: size)
        guard let style = textStyle else { return base }

        let metrics = UIFontMetrics(forTextStyle: style)
        if let maxSize = maximumPointSize {
            return metrics.scaledFont(for: base, maximumPointSize: maxSize)
        } else {
            return metrics.scaledFont(for: base)
        }
    }

    static func geologica(_ family: GeologicaFamily, size: CGFloat) -> UIFont {
        geologica(family, size: size, textStyle: nil)
    }

    private static func geologicaFontName(for family: GeologicaFamily) -> String {
        switch family {
        case .standard(let w): return "Geologica-\(w.rawValue)"
        case .auto(let w):     return "Geologica_Auto-\(w.rawValue)"
        case .cursive(let w):  return "Geologica_Cursive-\(w.rawValue)"
        }
    }
}
