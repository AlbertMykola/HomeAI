import UIKit

/// All demo images share the same canvas and crop. Only their reveal masks move.
final class OnboardingHeroView: UIView, UIGestureRecognizerDelegate {
    var panelTop: CGFloat = 552 { didSet { setNeedsLayout() } }
    var layoutScale: CGFloat = 1 { didSet { setNeedsLayout() } }
    /// iPhone Duo unfolded (Figma Duo/P/01 and L/01 · O3): the prompt spans the visual instead of an iPhone column.
    var fullWidthPrompt = false { didSet { if fullWidthPrompt != oldValue { setNeedsLayout() } } }

    private var page = OnboardingPageViewController.Page.room
    @IBOutlet private weak var canvas: UIView!
    @IBOutlet private weak var before: UIImageView!
    @IBOutlet private weak var after: UIImageView!
    private let revealMask = CALayer()
    private let scrim = CAGradientLayer()
    private let background = CAGradientLayer()
    @IBOutlet private weak var divider: UIView!
    @IBOutlet private weak var handle: UIView!
    @IBOutlet private weak var beforeLabel: UILabel!
    @IBOutlet private weak var afterLabel: UILabel!
    @IBOutlet private weak var prompt: UIView!
    @IBOutlet private weak var promptLabel: UILabel!
    @IBOutlet private weak var caret: UIView!
    @IBOutlet private weak var send: UIView!
    @IBOutlet private weak var scan: UIView!
    private let scanGlow = CAGradientLayer()
    @IBOutlet private var cards: [OnboardingToolCard]!
    @IBOutlet private var comparisonSymbols: [UIImageView]!
    @IBOutlet private var promptSymbols: [UIImageView]!
    @IBOutlet private var animatedLayoutConstraints: [NSLayoutConstraint]!
    private lazy var geometry = StoryboardGeometry(constraints: animatedLayoutConstraints)
    private var symbols: [UIImageView] {
        (page == .room ? comparisonSymbols : promptSymbols).sorted { $0.tag < $1.tag }
    }
    private var displayLink: CADisplayLink?
    private var elapsed: TimeInterval = 0
    private var previousTimestamp: TimeInterval?
    private var manualFraction: CGFloat?
    private var returnFraction: CGFloat?
    private var manualResume: TimeInterval = 0
    private var carouselOffset = 0
    private var carouselResume: TimeInterval = 0
    private(set) var isRunning = false
    private(set) var revealFraction: CGFloat = 1
    var interactiveGestures: [UIGestureRecognizer] {
        (gestureRecognizers ?? []) + (handle.gestureRecognizers ?? [])
    }

    private var still: Bool { OnboardingPreview.still || UIAccessibility.isReduceMotionEnabled }
    private var s: CGFloat { layoutScale }
    private var imageHeight: CGFloat { panelTop + 48 * s }

    func configure(page: OnboardingPageViewController.Page) {
        self.page = page
        clipsToBounds = true
        background.colors = [DS.Color.limeSoft.cgColor, UIColor.white.cgColor]
        background.startPoint = CGPoint(x: 0.5, y: 0)
        background.endPoint = CGPoint(x: 0.5, y: 1)
        layer.insertSublayer(background, at: 0)
        canvas.clipsToBounds = true

        if page == .tools {
            cards.sort { $0.tag < $1.tag }
            let left = UISwipeGestureRecognizer(target: self, action: #selector(swipeTools(_:)))
            left.direction = .left
            let right = UISwipeGestureRecognizer(target: self, action: #selector(swipeTools(_:)))
            right.direction = .right
            addGestureRecognizer(left)
            addGestureRecognizer(right)
        } else {
            for image in [after!, before!] {
                image.contentMode = .scaleAspectFill
                image.clipsToBounds = true
            }
            if page == .room {
                before.image = UIImage(named: "ob_room_before")
                after.image = UIImage(named: "ob_room_after")
                before.layer.mask = revealMask
                setupComparison()
            } else {
                before.image = UIImage(named: "ob_words_before")
                after.image = UIImage(named: "ob_words_after")
                canvas.bringSubviewToFront(after)
                after.layer.mask = revealMask
                setupPrompt()
            }
            scrim.colors = [UIColor.black.withAlphaComponent(0.35).cgColor, UIColor.clear.cgColor]
            canvas.layer.addSublayer(scrim)
            revealMask.backgroundColor = UIColor.black.cgColor
        }
        before.isHidden = page == .tools
        after.isHidden = page == .tools
        cards.forEach { $0.isHidden = page != .tools }
        [divider!, handle!, beforeLabel!, afterLabel!].forEach { $0.isHidden = page != .room }
        prompt.isHidden = page != .words
        scan.isHidden = page != .words
        if page == .words { canvas.bringSubviewToFront(scan) }
        accessibilityIdentifier = "onboarding.hero.\(page)"
        prepare()
    }

    private func setupComparison() {
        divider.backgroundColor = .white
        divider.layer.shadowColor = UIColor.black.cgColor
        divider.layer.shadowRadius = 4
        divider.layer.shadowOpacity = 0.3
        handle.backgroundColor = UIColor.white.withAlphaComponent(0.85)
        handle.layer.shadowColor = UIColor.black.cgColor
        handle.layer.shadowRadius = 7
        handle.layer.shadowOpacity = 0.2
        handle.layer.shadowOffset = CGSize(width: 0, height: 4)
        for (label, text) in [(beforeLabel!, "onboarding_before"), (afterLabel!, "onboarding_after")] {
            label.text = text.localized
            label.textColor = .white
            label.textAlignment = .center
            label.backgroundColor = UIColor.black.withAlphaComponent(0.35)
            label.clipsToBounds = true
        }
        // Restrict the recognizer to the handle so ordinary horizontal swipes still page.
        handle.isUserInteractionEnabled = true
        handle.accessibilityIdentifier = "onboarding.comparison.handle"
        handle.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(dragComparison(_:))))
    }

    private func setupPrompt() {
        scan.backgroundColor = DS.Color.lime
        scan.layer.shadowColor = DS.Color.lime.cgColor
        scan.layer.shadowRadius = 12
        scan.layer.shadowOpacity = 0.9
        scanGlow.colors = [UIColor.clear.cgColor, UIColor.white.withAlphaComponent(0.45).cgColor]
        canvas.layer.insertSublayer(scanGlow, below: scan.layer)
        prompt.backgroundColor = UIColor.white.withAlphaComponent(0.88)
        prompt.layer.shadowColor = UIColor.black.cgColor
        prompt.layer.shadowOpacity = 0.18
        prompt.layer.shadowRadius = 12
        prompt.layer.shadowOffset = CGSize(width: 0, height: 8)
        promptLabel.numberOfLines = 2
        promptLabel.lineBreakMode = .byWordWrapping
        caret.backgroundColor = DS.Color.limeText
        prompt.isUserInteractionEnabled = false
    }

    func prepare() {
        pause()
        elapsed = 0
        manualFraction = nil
        returnFraction = nil
        carouselOffset = 0
        setNeedsLayout()
    }

    func start() {
        guard !isRunning, window != nil else { return }
        isRunning = true
        previousTimestamp = nil
        guard !still else { setNeedsLayout(); return }
        let proxy = OnboardingDisplayLinkProxy(owner: self)
        let link = CADisplayLink(target: proxy, selector: #selector(OnboardingDisplayLinkProxy.tick(_:)))
        link.preferredFramesPerSecond = 60
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func pause() {
        isRunning = false
        displayLink?.invalidate()
        displayLink = nil
        previousTimestamp = nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { pause() }
    }

    deinit { displayLink?.invalidate() }

    fileprivate func tick(_ link: CADisplayLink) {
        guard UIApplication.shared.applicationState == .active else { previousTimestamp = nil; return }
        if let previousTimestamp {
            let delta = min(link.timestamp - previousTimestamp, 0.1)
            if manualFraction == nil { elapsed += delta }
            // A manual comparison holds elapsed while still allowing the three-second timeout.
            if manualFraction != nil { manualResume -= delta }
        }
        previousTimestamp = link.timestamp
        setNeedsLayout()
        layoutIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        background.frame = CGRect(x: 0, y: 0, width: bounds.width, height: imageHeight + 20 * s)
        geometry.setFrame(canvas, CGRect(x: 0, y: 0, width: bounds.width, height: imageHeight))
        if page == .tools {
            layoutCarousel()
        } else {
            geometry.setFrame(before, canvas.bounds)
            geometry.setFrame(after, canvas.bounds)
            scrim.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 140 * s)
            if page == .room { layoutComparison() } else { layoutPrompt() }
        }
        CATransaction.commit()
    }

    private func ease(_ value: Double) -> CGFloat {
        CGFloat((1 - cos(min(1, max(0, value)) * .pi)) / 2)
    }

    private func layoutComparison() {
        let x: CGFloat
        var visible: CGFloat = 1
        if let manualFraction {
            x = manualFraction
            if manualResume <= 0 {
                self.manualFraction = nil
                returnFraction = manualFraction
                elapsed = 0
            }
        } else if let returnFraction {
            x = returnFraction + (0.28 - returnFraction) * ease(elapsed / 0.9)
            if elapsed >= 0.9 { self.returnFraction = nil; elapsed = 1.6 }
        } else if still {
            x = 0.28
        } else if elapsed < 0.6 {
            x = 1
            visible = 0
        } else if elapsed < 1.6 {
            let progress = ease(elapsed - 0.6)
            x = 1 - 0.72 * progress
            visible = min(1, progress * 4)
        } else {
            let t = (elapsed - 1.6).truncatingRemainder(dividingBy: 2.6)
            if t < 0.4 { x = 0.28 }
            else if t < 1.3 { x = 0.28 + 0.44 * ease((t - 0.4) / 0.9) }
            else if t < 1.7 { x = 0.72 }
            else { x = 0.72 - 0.44 * ease((t - 1.7) / 0.9) }
        }
        revealFraction = x
        revealMask.frame = CGRect(x: 0, y: 0, width: bounds.width * x, height: imageHeight)
        geometry.setFrame(divider, CGRect(x: bounds.width * x - 1.5 * s, y: 0, width: 3 * s, height: imageHeight))
        geometry.setFrame(handle, CGRect(x: bounds.width * x - 22 * s, y: imageHeight / 2 - 22 * s, width: 44 * s, height: 44 * s))
        handle.layer.cornerRadius = 22 * s
        for (index, icon) in symbols.enumerated() {
            geometry.setFrame(icon, CGRect(x: CGFloat(index == 0 ? 7 : 22) * s, y: 14.5 * s, width: 15 * s, height: 15 * s))
            icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 11 * s, weight: .semibold)
        }
        divider.alpha = visible
        handle.alpha = visible
        afterLabel.alpha = visible
        for label in [beforeLabel!, afterLabel!] {
            label.font = DS.Font.geologica(.medium, 13 * s)
            label.layer.cornerRadius = 14 * s
            let width = label.intrinsicContentSize.width + 24 * s
            geometry.setFrame(label, CGRect(x: label === beforeLabel ? 16 * s : bounds.width - 16 * s - width,
                                 y: panelTop - 56 * s, width: width, height: 28 * s))
        }
    }

    private func layoutCarousel() {
        let cycle = 3.35
        let time = still ? 0 : max(0, elapsed - carouselResume)
        let index = (Int(time / cycle) + carouselOffset + 5000) % cards.count
        let phase = time.truncatingRemainder(dividingBy: cycle)
        let move = ease((phase - 2.9) / 0.45)
        let widths: [CGFloat] = [260, 220, 200, 200, 220]
        let xs: [CGFloat] = [66, 351, 601, -408, -178]
        let ys: [CGFloat] = [118, 150, 170, 170, 150]
        let alphas: [CGFloat] = [1, 0.55, 0, 0, 0.55]
        let origin = (bounds.width - 393 * s) / 2
        for (i, card) in cards.enumerated() {
            let slot = (i - index + 5) % 5
            let next = (slot + 4) % 5
            func mix(_ values: [CGFloat]) -> CGFloat { values[slot] + (values[next] - values[slot]) * move }
            let width = mix(widths) * s
            geometry.setFrame(card, CGRect(x: origin + mix(xs) * s, y: mix(ys) * s, width: width, height: width * 1.5))
            card.alpha = mix(alphas)
            card.scale = s
            card.progress = slot == 0 ? min(1, max(0, CGFloat((phase - 0.65) / 1.15))) : (slot >= 3 ? 1 : 0)
            card.setNeedsLayout()
        }
        canvas.bringSubviewToFront(cards[index])
    }

    private func layoutPrompt() {
        let text = "onboarding_demo_prompt".localized
        let t = still ? 5.5 : elapsed.truncatingRemainder(dividingBy: Double(text.count) * 0.035 + 4.3)
        let typingDuration = Double(text.count) * 0.035
        let count = still ? text.count : min(text.count, max(0, Int((t - 0.6) / 0.035)))
        let sent = still || t > 0.6 + typingDuration + 0.3
        let progress = sent ? ease((t - 0.6 - typingDuration - 0.3) / 1.1) : 0
        revealFraction = still ? 1 : progress
        revealMask.frame = CGRect(x: 0, y: 0, width: bounds.width, height: imageHeight * revealFraction)
        let lineY = imageHeight * revealFraction
        geometry.setFrame(scan, CGRect(x: 0, y: lineY - 2 * s, width: bounds.width, height: 2 * s))
        scanGlow.frame = CGRect(x: 0, y: lineY - 120 * s, width: bounds.width, height: 120 * s)
        scan.alpha = progress > 0 && progress < 1 ? 1 : 0
        scanGlow.opacity = Float(scan.alpha)
        let inset = fullWidthPrompt ? 20 * s : max(20 * s, (bounds.width - 353 * s) / 2)
        let promptWidth = bounds.width - inset * 2
        geometry.setFrame(prompt, CGRect(x: inset, y: panelTop - 82 * s, width: promptWidth, height: 56 * s))
        prompt.layer.cornerRadius = 28 * s
        promptLabel.font = DS.Font.geologica(.regular, 15 * s)
        promptLabel.text = count == 0 ? "onboarding_demo_placeholder".localized : String(text.prefix(count))
        promptLabel.textColor = count == 0 ? DS.Color.textTertiary : .black
        geometry.setFrame(promptLabel, CGRect(x: 48 * s, y: 0, width: promptWidth - 108 * s, height: 56 * s))
        geometry.setFrame(caret, CGRect(x: promptWidth - 60 * s, y: 18 * s, width: 2 * s, height: 20 * s))
        caret.alpha = sent ? 0 : (Int(t / 0.5) % 2 == 0 ? 1 : 0)
        geometry.setFrame(send, CGRect(x: promptWidth - 48 * s, y: 8 * s, width: 40 * s, height: 40 * s))
        send.layer.cornerRadius = 20 * s
        send.backgroundColor = sent ? DS.Color.lime : (count == text.count ? .black : UIColor(white: 0.9, alpha: 1))
        geometry.setFrame(symbols[0], CGRect(x: 18 * s, y: 18 * s, width: 20 * s, height: 20 * s))
        geometry.setFrame(symbols[1], CGRect(x: 11 * s, y: 11 * s, width: 18 * s, height: 18 * s))
        symbols[1].tintColor = sent ? .black : (count == text.count ? .white : DS.Color.textTertiary)
    }

    @objc private func dragComparison(_ pan: UIPanGestureRecognizer) {
        returnFraction = nil
        manualFraction = min(1, max(0, pan.location(in: self).x / max(bounds.width, 1)))
        manualResume = pan.state == .ended || pan.state == .cancelled ? 3 : .greatestFiniteMagnitude
        setNeedsLayout()
    }

    @objc private func swipeTools(_ swipe: UISwipeGestureRecognizer) {
        let current = Int(max(0, elapsed - carouselResume) / 3.35)
        carouselOffset += current + (swipe.direction == .left ? 1 : -1)
        elapsed = 0
        carouselResume = 3
        DS.Haptic.selection()
        setNeedsLayout()
    }
}

private final class OnboardingDisplayLinkProxy: NSObject {
    weak var owner: OnboardingHeroView?
    init(owner: OnboardingHeroView) { self.owner = owner }
    @objc func tick(_ link: CADisplayLink) { owner?.tick(link) }
}

final class OnboardingToolCard: UIView {
    var scale: CGFloat = 1
    var progress: CGFloat = 0
    @IBOutlet private weak var clip: UIView!
    @IBOutlet private weak var before: UIImageView!
    @IBOutlet private weak var after: UIImageView!
    private let maskLayer = CALayer()
    @IBOutlet private weak var line: UIView!
    private let glow = CAGradientLayer()
    @IBOutlet private weak var chip: UIView!
    @IBOutlet private weak var icon: UIImageView!
    @IBOutlet private var animatedLayoutConstraints: [NSLayoutConstraint]!
    private lazy var geometry = StoryboardGeometry(constraints: animatedLayoutConstraints)
    @IBOutlet private weak var label: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        let tool = ["walls", "floor", "remove", "replace", "style"][tag]
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 20
        layer.shadowOffset = CGSize(width: 0, height: 14)
        after.layer.mask = maskLayer
        maskLayer.backgroundColor = UIColor.black.cgColor
        glow.colors = [UIColor.clear.cgColor, UIColor.white.withAlphaComponent(0.5).cgColor]
        clip.layer.insertSublayer(glow, below: line.layer)
        line.layer.shadowColor = DS.Color.lime.cgColor
        line.layer.shadowRadius = 12
        line.layer.shadowOpacity = 0.95
        label.text = "onboarding_tool_\(tool)".localized
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        geometry.setFrame(clip, bounds)
        clip.layer.cornerRadius = 34 * scale
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 34 * scale).cgPath
        geometry.setFrame(before, bounds)
        geometry.setFrame(after, bounds)
        maskLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height * progress)
        geometry.setFrame(line, CGRect(x: 0, y: bounds.height * progress - 2 * scale, width: bounds.width, height: 2 * scale))
        glow.frame = CGRect(x: 0, y: bounds.height * progress - 2 * scale - bounds.height * 0.28, width: bounds.width, height: bounds.height * 0.28)
        line.alpha = progress > 0 && progress < 1 ? 1 : 0
        glow.opacity = Float(line.alpha)
        label.font = DS.Font.geologica(.semiBold, 14 * scale)
        let maxWidth = bounds.width - 24 * scale
        let width = min(maxWidth, label.intrinsicContentSize.width + 62 * scale)
        geometry.setFrame(chip, CGRect(x: 12 * scale, y: bounds.height - 56 * scale, width: width, height: 44 * scale))
        chip.layer.cornerRadius = 22 * scale
        geometry.setFrame(icon, CGRect(x: 6 * scale, y: 5 * scale, width: 34 * scale, height: 34 * scale))
        geometry.setFrame(label, CGRect(x: 48 * scale, y: 0, width: max(0, width - 62 * scale), height: 44 * scale))
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        CATransaction.commit()
    }
}
