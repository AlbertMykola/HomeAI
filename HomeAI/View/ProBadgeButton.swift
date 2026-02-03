import UIKit

@IBDesignable
final class ProBadgeButton: UIButton {

    // MARK: - Inspectables (уникати імен, що вже є в UIButton extension)
    @IBInspectable var titleText: String = "PRO" { didSet { applyTitle() } }
    @IBInspectable var proSystemImageName: String = "star_icon" { didSet { applyImage() } } // уникаємо конфлікту
    @IBInspectable var usesProminent: Bool = true { didSet { applyStyle() } }
    @IBInspectable var pillCorner: CGFloat = 12 { didSet { layer.cornerRadius = pillCorner } }
    @IBInspectable var fgColor: UIColor = .black { didSet { applyColors() } }
    @IBInspectable var bgColor: UIColor = Constants.Colors.yellowPremium { didSet { applyColors() } }
    @IBInspectable var contentTopBottom: CGFloat = 6 { didSet { updateInsets() } }
    @IBInspectable var contentLeftRight: CGFloat = 12 { didSet { updateInsets() } }
    @IBInspectable var imagePaddingValue: CGFloat = 6 { didSet { applyImagePadding() } }
    @IBInspectable var enableSymbolReplace: Bool = true { didSet { applySymbolTransition() } }
    @IBInspectable var fontName: String = "" { didSet { applyFont() } }
    @IBInspectable var fontSize: CGFloat = 13 { didSet { applyFont() } }

    // MARK: - Init
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        commonInit()
    }

    // MARK: - Public factories
    static func makeDefault() -> ProBadgeButton {
        let b = ProBadgeButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }

    static func makeBarButtonItem(target: Any?, action: Selector) -> UIBarButtonItem {
        let btn = ProBadgeButton.makeDefault()
        btn.addTarget(target, action: action, for: .touchUpInside)

        let container = UIView()
        container.addSubview(btn)
        NSLayoutConstraint.activate([
            btn.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            btn.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            btn.topAnchor.constraint(equalTo: container.topAnchor),
            btn.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            btn.heightAnchor.constraint(greaterThanOrEqualToConstant: 28)
        ])
        return UIBarButtonItem(customView: container)
    }

    // MARK: - Setup
    private func commonInit() {
        layer.cornerRadius = pillCorner
        clipsToBounds = true

        applyBaseConfiguration()
        applyTitle()
        applyImage()
        applyImagePlacement()
        applyImagePadding()
        applyColors()
        applyFont()
        applySymbolTransition()
        updateInsets()
    }

    private func applyBaseConfiguration() {
        if #available(iOS 26.0, *) {
            configuration = usesProminent ? .prominentGlass() : .glass()
        } else {
            var cfg = configuration ?? .filled()
            cfg.background.backgroundColor = bgColor
            cfg.baseForegroundColor = fgColor
            cfg.cornerStyle = .capsule
            configuration = cfg
        }
    }

    private func applyStyle() {
        if #available(iOS 26.0, *) {
            let old = configuration
            configuration = usesProminent ? .prominentGlass() : .glass()
            configuration?.title = old?.title
            configuration?.image = old?.image
            configuration?.imagePlacement = old?.imagePlacement ?? .leading
            configuration?.imagePadding = old?.imagePadding ?? imagePaddingValue
            configuration?.attributedTitle = old?.attributedTitle
            configuration?.baseForegroundColor = old?.baseForegroundColor
            configuration?.baseBackgroundColor = old?.baseBackgroundColor
            configuration?.background = old?.background ?? configuration?.background ?? UIBackgroundConfiguration.clear()
            configuration?.contentInsets = old?.contentInsets ?? NSDirectionalEdgeInsets(top: contentTopBottom, leading: contentLeftRight, bottom: contentTopBottom, trailing: contentLeftRight)
            applyColors()
        } else {
            applyColors()
        }
    }

    private func applyTitle() {
        if var cfg = configuration {
            if var attr = cfg.attributedTitle {
                let currentFont = attr.font
                var new = AttributedString(titleText)
                new.font = currentFont
                cfg.attributedTitle = new
                cfg.title = titleText
            } else {
                cfg.title = titleText
            }
            configuration = cfg
        } else {
            setTitle(titleText, for: .normal)
        }
    }

    private func applyImage() {
        // Використовуємо властивість з UIButton extension, але щоб уникнути override-конфлікту,
        // тут лише перенаправляємо на неї значення (якщо вона присутня в проєкті).
        // Якщо extension немає — присвоїмо напряму в configuration.
        if responds(to: Selector(("setSystemImageName:"))) {
            // KVC виклик @IBInspectable з extension (необов'язково; простіше напряму конфігурацію)
            var cfg = configuration ?? UIButton.Configuration.plain()
            cfg.image = UIImage(named: proSystemImageName)
            configuration = cfg
        } else {
            var cfg = configuration ?? UIButton.Configuration.plain()
            cfg.image = UIImage(systemName: proSystemImageName)
            configuration = cfg
        }
    }

    private func applyImagePlacement() {
        var cfg = configuration ?? .plain()
        cfg.imagePlacement = .leading
        configuration = cfg
    }

    private func applyImagePadding() {
        var cfg = configuration ?? .plain()
        cfg.imagePadding = imagePaddingValue
        configuration = cfg
    }

    private func applyColors() {
        var cfg = configuration ?? .plain()
        cfg.baseForegroundColor = fgColor
        var bg = cfg.background
        bg.backgroundColor = bgColor
        cfg.background = bg
        configuration = cfg
    }

    private func applySymbolTransition() {
        if #available(iOS 26.0, *) {
            var cfg = configuration ?? .glass()
            cfg.symbolContentTransition = enableSymbolReplace ? UISymbolContentTransition(.replace) : nil
            configuration = cfg
        }
    }

    private func applyFont() {
        let uiFont: UIFont
        if fontName.isEmpty {
            uiFont = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        } else {
            uiFont = UIFont(name: fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        }
        var cfg = configuration ?? .plain()
        if var attr = cfg.attributedTitle {
            attr.font = uiFont
            cfg.attributedTitle = attr
        } else {
            var attr = AttributedString(cfg.title ?? titleText)
            attr.font = uiFont
            cfg.attributedTitle = attr
        }
        configuration = cfg
    }

    private func updateInsets() {
        var cfg = configuration ?? .plain()
        cfg.contentInsets = NSDirectionalEdgeInsets(top: contentTopBottom, leading: contentLeftRight, bottom: contentTopBottom, trailing: contentLeftRight)
        configuration = cfg
    }
}
