import UIKit

class ModeCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak private var containerView: LiquidGlassView!
    @IBOutlet weak private var modeLabel: UILabel!
    @IBOutlet weak private var subtitleLabel: UILabel?
    
    private var currentMode: DesignMode?
    private var gradientStops: [UIView.GradientStop] = []
    private let gradientView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isUserInteractionEnabled = false
        return v
    }()
    
    override var isSelected: Bool {
        didSet { updateSelectionState() }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setup()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        isSelected = false
        containerView.removeGradientLayer()
        gradientView.removeGradientLayer()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        containerView.updateGradientFrame()
        gradientView.updateGradientFrame()
        applyGradientIfPossible()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyGradientIfPossible()
    }
    
    private func setup() {
        contentView.backgroundColor = .clear
        containerView.layer.cornerRadius = 14
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.separator.cgColor
        containerView.layer.masksToBounds = true
        [modeLabel, subtitleLabel].forEach { $0?.scaleFontByHeight = true }

        containerView.addSubview(gradientView)
        NSLayoutConstraint.activate([
            gradientView.topAnchor.constraint(equalTo: containerView.topAnchor),
            gradientView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        gradientView.layer.cornerRadius = containerView.layer.cornerRadius
        gradientView.clipsToBounds = true
        // Текстові елементи тримаємо над градієнтом
        if let subtitleLabel { containerView.bringSubviewToFront(subtitleLabel) }
        containerView.bringSubviewToFront(modeLabel)
    }
    
    func configure(mode: DesignMode) {
        currentMode = mode
        modeLabel.text = mode.title
        subtitleLabel?.text = mode.subtitle
        updateSelectionState()
        updateGradient()
    }
    
    private func updateGradient() {
        guard let mode = currentMode else { return }
        let gradientColors = mode.gradient

        // Рівномірно розкладаємо стопи за кількістю кольорів
        let stops: [UIView.GradientStop] = gradientColors.enumerated().map { idx, color in
            let percent = gradientColors.count > 1
            ? CGFloat(idx) / CGFloat(gradientColors.count - 1) * 100
            : 50.0
            return UIView.GradientStop(percent: percent, color: color)
        }

        gradientStops = stops
        setNeedsLayout()
        applyGradientIfPossible()
    }

    private func applyGradientIfPossible() {
        guard !gradientStops.isEmpty,
              gradientView.bounds.width > 0,
              gradientView.bounds.height > 0 else { return }
        gradientView.layer.cornerRadius = containerView.layer.cornerRadius
        gradientView.clipsToBounds = true
        gradientView.setGradient(stops: gradientStops, direction: .horizontal)
        gradientView.updateGradientFrame()
    }
    
    private func updateSelectionState() {
        let selected = isSelected
        containerView.layer.borderColor = selected ? UIColor.label.cgColor : UIColor.separator.cgColor
        containerView.layer.borderWidth = selected ? 2 : 1
    }
}
