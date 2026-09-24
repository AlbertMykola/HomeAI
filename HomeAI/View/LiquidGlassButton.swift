import UIKit

enum LiquidGlassMode {
    case system
    case light
    case dark

    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum LiquidGlassState {
    case `default`
    case highlighted
    case selected
    case disabled

    var controlState: UIControl.State {
        switch self {
        case .default: return .normal
        case .highlighted: return .highlighted
        case .selected: return .selected
        case .disabled: return .disabled
        }
    }
}

enum LiquidGlassButtonStyle {
    case glass
    case clearGlass
    case prominentGlass
    case prominentClearGlass
    case plain
    case gray
    case tinted
    case filled

    @available(iOS 26.0, *)
    func systemConfiguration(tinted: Bool) -> UIButton.Configuration {
        switch self {
        case .glass:
            return tinted ? .prominentGlass() : .glass()
        case .clearGlass:
            return tinted ? .prominentClearGlass() : .clearGlass()
        case .prominentGlass:
            return .prominentGlass()
        case .prominentClearGlass:
            return .prominentClearGlass()
        case .plain:
            return .plain()
        case .gray:
            return .gray()
        case .tinted:
            return .tinted()
        case .filled:
            return .filled()
        }
    }

    func fallbackConfiguration() -> UIButton.Configuration {
        switch self {
        case .plain:
            return .plain()
        case .gray:
            return .gray()
        case .tinted:
            return .tinted()
        case .glass, .clearGlass, .prominentGlass, .prominentClearGlass, .filled:
            return .filled()
        }
    }
}

enum LiquidGlassButtonCornerStyle {
    case capsule
    case fixed(CGFloat)
    case system

    func radius(for bounds: CGRect) -> CGFloat? {
        switch self {
        case .capsule:
            return max(bounds.height / 2, 0)
        case .fixed(let radius):
            return max(radius, 0)
        case .system:
            return nil
        }
    }
}

struct LiquidGlassConfig {
    var style: LiquidGlassButtonStyle
    var tinted: Bool
    var mode: LiquidGlassMode
    var state: LiquidGlassState
    var title: String?
    var foregroundColor: UIColor
    var backgroundColor: UIColor
    var contentInsets: NSDirectionalEdgeInsets
    var font: UIFont?
    var image: UIImage?
    var imagePlacement: NSDirectionalRectEdge
    var imagePadding: CGFloat
    var cornerStyle: LiquidGlassButtonCornerStyle
    var isInteractive: Bool

    init(
        style: LiquidGlassButtonStyle = .glass,
        tinted: Bool = false,
        mode: LiquidGlassMode = .system,
        state: LiquidGlassState = .default,
        title: String? = nil,
        foregroundColor: UIColor = .white,
        backgroundColor: UIColor = .systemBlue,
        contentInsets: NSDirectionalEdgeInsets = .init(top: 14, leading: 24, bottom: 14, trailing: 24),
        font: UIFont? = nil,
        image: UIImage? = nil,
        imagePlacement: NSDirectionalRectEdge = .leading,
        imagePadding: CGFloat = 0,
        cornerStyle: LiquidGlassButtonCornerStyle = .capsule,
        cornerRadius: CGFloat? = nil,
        isInteractive: Bool = true
    ) {
        self.style = style
        self.tinted = tinted
        self.mode = mode
        self.state = state
        self.title = title
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.contentInsets = contentInsets
        self.font = font
        self.image = image
        self.imagePlacement = imagePlacement
        self.imagePadding = imagePadding
        self.cornerStyle = cornerRadius.map { .fixed($0) } ?? cornerStyle
        self.isInteractive = isInteractive
    }
}

final class LiquidGlassButton: UIButton {

    private var liquidGlassConfig: LiquidGlassConfig?
    private var loadingIndicator: UIActivityIndicatorView?
    private var isLoadingState = false
    private var titleAlphaBeforeLoading: CGFloat = 1

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        clipsToBounds = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        applyCornerStyleIfNeeded()
        updateConfigurationCornerRadiusIfNeeded()
    }

    /// Shows a spinner on the button and blocks interaction while `loading` is true.
    func setLoading(_ loading: Bool) {
        guard isLoadingState != loading else { return }
        isLoadingState = loading

        if loading {
            titleAlphaBeforeLoading = titleLabel?.alpha ?? 1
            titleLabel?.alpha = 0
            imageView?.alpha = 0
            isUserInteractionEnabled = false

            let indicator = loadingIndicator ?? makeLoadingIndicator()
            loadingIndicator = indicator
            if indicator.superview == nil {
                addSubview(indicator)
                NSLayoutConstraint.activate([
                    indicator.centerXAnchor.constraint(equalTo: centerXAnchor),
                    indicator.centerYAnchor.constraint(equalTo: centerYAnchor)
                ])
            }
            indicator.startAnimating()
        } else {
            loadingIndicator?.stopAnimating()
            titleLabel?.alpha = titleAlphaBeforeLoading
            imageView?.alpha = 1
            isUserInteractionEnabled = liquidGlassConfig?.isInteractive ?? true
        }
    }

    private func makeLoadingIndicator() -> UIActivityIndicatorView {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        indicator.color = .white
        return indicator
    }

    private func applyCornerStyleIfNeeded() {
        guard let radius = liquidGlassConfig?.cornerStyle.radius(for: bounds), radius > 0 else {
            return
        }

        layer.cornerRadius = radius
        layer.cornerCurve = .continuous

        for sub in subviews where sub is UIVisualEffectView {
            sub.layer.cornerRadius = radius
            sub.layer.cornerCurve = .continuous
            sub.clipsToBounds = true
        }
    }

    private func updateConfigurationCornerRadiusIfNeeded() {
        guard
            var buttonConfig = configuration,
            let radius = liquidGlassConfig?.cornerStyle.radius(for: bounds),
            radius > 0,
            buttonConfig.background.cornerRadius != radius
        else { return }

        buttonConfig.background.cornerRadius = radius
        configuration = buttonConfig
    }

    func applyLiquidGlass(_ config: LiquidGlassConfig) {
        liquidGlassConfig = config
        overrideUserInterfaceStyle = config.mode.userInterfaceStyle
        if !isLoadingState {
            isUserInteractionEnabled = config.isInteractive
        }
        isEnabled = config.state != .disabled
        isSelected = config.state == .selected
        isHighlighted = config.state == .highlighted
        setTitleColor(config.foregroundColor, for: config.state.controlState)

        if #available(iOS 26.0, *) {
            applySystemLiquidGlass(config)
        } else {
            applyFallbackLiquidGlass(config)
        }

        setNeedsLayout()
    }

    @available(iOS 26.0, *)
    private func applySystemLiquidGlass(_ config: LiquidGlassConfig) {
        var buttonConfig = config.style.systemConfiguration(tinted: config.tinted)
        buttonConfig.title = config.title
        buttonConfig.baseForegroundColor = config.foregroundColor
        buttonConfig.baseBackgroundColor = config.backgroundColor
        buttonConfig.contentInsets = config.contentInsets
        if let radius = config.cornerStyle.radius(for: bounds) {
            buttonConfig.background.cornerRadius = radius
        }
        buttonConfig.image = config.image
        buttonConfig.imagePlacement = config.imagePlacement
        buttonConfig.imagePadding = config.imagePadding

        if let title = config.title, let font = config.font {
            var attributedTitle = AttributedString(title)
            attributedTitle.font = font
            attributedTitle.foregroundColor = config.foregroundColor
            buttonConfig.attributedTitle = attributedTitle
        }

        configuration = buttonConfig
    }

    private func applyFallbackLiquidGlass(_ config: LiquidGlassConfig) {
        var buttonConfig = config.style.fallbackConfiguration()
        buttonConfig.title = config.title
        buttonConfig.baseForegroundColor = config.foregroundColor
        buttonConfig.baseBackgroundColor = config.backgroundColor
        buttonConfig.background.backgroundColor = config.backgroundColor
        if let radius = config.cornerStyle.radius(for: bounds) {
            buttonConfig.background.cornerRadius = radius
        }
        buttonConfig.contentInsets = config.contentInsets
        buttonConfig.image = config.image
        buttonConfig.imagePlacement = config.imagePlacement
        buttonConfig.imagePadding = config.imagePadding

        if let title = config.title, let font = config.font {
            var attributedTitle = AttributedString(title)
            attributedTitle.font = font
            attributedTitle.foregroundColor = config.foregroundColor
            buttonConfig.attributedTitle = attributedTitle
        }

        configuration = buttonConfig
    }
}
