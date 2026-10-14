import UIKit

/// A2 user message: optional photo 190×136 + lime gradient bubble on the right, "Couldn't send · Retry" under it.
/// Layout: AssistantUserCell.xib.
final class AssistantUserCell: UITableViewCell {
    static let reuseID = "AssistantUserCell"

    @IBOutlet private weak var photoImageView: UIImageView!
    @IBOutlet private weak var bubbleView: UIView!
    @IBOutlet private weak var messageLabel: UILabel!
    @IBOutlet private weak var errorControl: DSPressableControl!
    @IBOutlet private weak var errorLabel: UILabel!

    var onRetry: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        backgroundColor = .clear
    }

    func configure(_ message: AssistantMessage, image: UIImage?) {
        photoImageView.image = image
        photoImageView.isHidden = image == nil
        messageLabel.text = message.text
        bubbleView.isHidden = message.text.isEmpty
        errorLabel.text = "Couldn't send · Retry".localized
        errorControl.isHidden = message.state != .failed
    }

    @IBAction private func didTapRetry(_ sender: Any) {
        onRetry?()
    }
}

/// A2 assistant message: clay avatar, typing dots → answer typed out with a lime caret, then idea cards.
/// Layout: AssistantReplyCell.xib.
final class AssistantReplyCell: UITableViewCell {
    static let reuseID = "AssistantReplyCell"

    @IBOutlet private weak var typingView: UIView!
    @IBOutlet private var typingDots: [UIView]!
    @IBOutlet private(set) weak var answerLabel: UILabel!
    @IBOutlet private weak var caretView: UIView!
    @IBOutlet private weak var ideasCollectionView: UICollectionView!
    @IBOutlet private weak var ideasHeightConstraint: NSLayoutConstraint!

    var onApply: ((AssistantIdea) -> Void)?
    /// Called while the text grows so the table can resize the row.
    var onGrow: (() -> Void)?

    private var ideas: [AssistantIdea] = []
    private var revealLink: CADisplayLink?
    private var fullText = NSAttributedString()
    private var revealed = 0
    private var revealStep = 2
    private var onRevealDone: (() -> Void)?
    private(set) var messageID: String?

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        backgroundColor = .clear
        ideasCollectionView.register(UINib(nibName: "AssistantIdeaCell", bundle: nil),
                                     forCellWithReuseIdentifier: AssistantIdeaCell.reuseID)
        ideasCollectionView.dataSource = self
        ideasCollectionView.clipsToBounds = false
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stopReveal()
        onApply = nil
        onGrow = nil
    }

    func configure(_ message: AssistantMessage, reveal: Bool, onRevealDone: (() -> Void)? = nil) {
        messageID = message.id
        let typing = message.state == .typing
        typingView.isHidden = !typing
        typing ? startTypingDots() : stopTypingDots()
        ideas = message.ideas
        ideasCollectionView.reloadData()
        guard !typing else {
            answerLabel.isHidden = true
            caretView.isHidden = true
            setIdeasVisible(false)
            return
        }
        answerLabel.isHidden = false
        fullText = AssistantStore.attributed(message.text)
        if reveal, !DS.Motion.reduceMotion {
            self.onRevealDone = onRevealDone
            startReveal()
        } else {
            answerLabel.attributedText = fullText
            caretView.isHidden = true
            setIdeasVisible(!ideas.isEmpty)
        }
    }

    // MARK: Typing dots (−3 pt + opacity 0.35 → 1, 150 ms apart, 0.9 s loop)

    private func startTypingDots() {
        for dot in typingDots.sorted(by: { $0.tag < $1.tag }) {
            dot.layer.removeAllAnimations()
            let group = CAAnimationGroup()
            let opacity = CABasicAnimation(keyPath: "opacity")
            opacity.fromValue = 0.35
            opacity.toValue = 1
            let lift = CABasicAnimation(keyPath: "transform.translation.y")
            lift.fromValue = 0
            lift.toValue = -3
            group.animations = [opacity, lift]
            group.duration = 0.45
            group.autoreverses = true
            group.repeatCount = .infinity
            group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            group.beginTime = CACurrentMediaTime() + Double(dot.tag) * 0.15
            group.fillMode = .backwards
            dot.layer.opacity = 0.35
            dot.layer.add(group, forKey: "typing")
        }
    }

    private func stopTypingDots() {
        typingDots.forEach { $0.layer.removeAllAnimations() }
    }

    // MARK: Streaming-style reveal with a blinking lime caret (0.45 s)

    private func startReveal() {
        stopReveal()
        revealed = 0
        revealStep = max(2, fullText.length / 120)
        answerLabel.attributedText = fullText
        answerLabel.alpha = 1
        caretView.isHidden = false
        let blink = CAKeyframeAnimation(keyPath: "opacity")
        blink.values = [1, 0]
        blink.keyTimes = [0, 0.5]
        blink.calculationMode = .discrete
        blink.duration = 0.9
        blink.repeatCount = .infinity
        caretView.layer.add(blink, forKey: "blink")
        setIdeasVisible(false)
        applyReveal()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFramesPerSecond = 60
        link.add(to: .main, forMode: .common)
        revealLink = link
    }

    @objc private func tick() {
        revealed = min(fullText.length, revealed + revealStep)
        applyReveal()
        if revealed % (revealStep * 6) < revealStep { onGrow?() }
        guard revealed >= fullText.length else { return }
        stopReveal()
        caretView.layer.removeAllAnimations()
        UIView.animate(withDuration: 0.2) { self.caretView.alpha = 0 } completion: { _ in
            self.caretView.isHidden = true
            self.caretView.alpha = 1
        }
        if !ideas.isEmpty {
            setIdeasVisible(true)
            animateIdeas()
        }
        onGrow?()
        onRevealDone?()
        onRevealDone = nil
    }

    /// Hidden characters stay in place (clear colour) so the bubble doesn't jump while it types.
    private func applyReveal() {
        let text = NSMutableAttributedString(attributedString: fullText)
        if revealed < text.length {
            text.addAttribute(.foregroundColor, value: UIColor.clear,
                              range: NSRange(location: revealed, length: text.length - revealed))
        }
        answerLabel.attributedText = text
    }

    private func stopReveal() {
        revealLink?.invalidate()
        revealLink = nil
    }

    func finishRevealImmediately() {
        guard revealLink != nil else { return }
        revealed = fullText.length
        tick()
    }

    private func setIdeasVisible(_ visible: Bool) {
        ideasCollectionView.isHidden = !visible
        ideasHeightConstraint.constant = visible ? 218 : 0
    }

    /// Cards slide in from the right (+30 pt), 80 ms apart.
    private func animateIdeas() {
        ideasCollectionView.layoutIfNeeded()
        let cells = ideasCollectionView.visibleCells.sorted { $0.frame.minX < $1.frame.minX }
        cells.enumerated().forEach { i, cell in DS.Motion.enter(cell, delay: 0.08 * Double(i), dx: 30) }
    }
}

extension AssistantReplyCell: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { ideas.count }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AssistantIdeaCell.reuseID, for: indexPath)
        let idea = ideas[indexPath.item]
        (cell as? AssistantIdeaCell)?.configure(idea) { [weak self] in self?.onApply?(idea) }
        return cell
    }
}

/// Idea card: style preview, title, why, "Apply to my photo". Layout: AssistantIdeaCell.xib.
final class AssistantIdeaCell: UICollectionViewCell {
    static let reuseID = "AssistantIdeaCell"

    @IBOutlet private weak var previewImageView: UIImageView!
    @IBOutlet private weak var titleLabel: UILabel!
    @IBOutlet private weak var subtitleLabel: UILabel!
    @IBOutlet private weak var applyTitleLabel: UILabel!

    private var onApply: (() -> Void)?
    private var path: String?

    func configure(_ idea: AssistantIdea, onApply: @escaping () -> Void) {
        self.onApply = onApply
        titleLabel.text = idea.title
        subtitleLabel.text = idea.subtitle
        applyTitleLabel.text = "Apply to my photo".localized
        previewImageView.image = nil
        path = idea.previewPath
        if let p = idea.previewPath {
            CatalogImage.load(p) { [weak self] image in
                guard self?.path == p else { return }
                self?.previewImageView.image = image
            }
        }
    }

    @IBAction private func didTapApply(_ sender: Any) {
        onApply?()
    }
}
