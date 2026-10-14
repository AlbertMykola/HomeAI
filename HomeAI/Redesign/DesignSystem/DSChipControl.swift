import UIKit

/// Chip/Default (grey) ↔ Chip/Selected (lime soft + 1.5 pt lime border, medium label).
final class DSChipControl: DSPressableControl {

    @IBInspectable var isChipSelected: Bool = false { didSet { applyState(animated: false) } }

    override func awakeFromNib() {
        super.awakeFromNib()
        pill = true
        hapticOnPress = false
        applyState(animated: false)
    }

    func setChipSelected(_ selected: Bool, animated: Bool) {
        isChipSelected = selected
        applyState(animated: animated)
    }

    private var label: UILabel? { firstLabel(in: self) }

    private func applyState(animated: Bool) {
        let changes = {
            self.backgroundColor = self.isChipSelected ? DS.Color.limeSoft : UIColor(named: "dsChip")
            self.layer.borderWidth = self.isChipSelected ? 1.5 : 0
            self.layer.borderColor = DS.Color.lime.cgColor
            self.label?.font = DS.Font.geologica(self.isChipSelected ? .medium : .regular, self.label?.font.pointSize ?? 14)
        }
        if animated {
            UIView.animate(withDuration: 0.2, animations: changes)
        } else {
            changes()
        }
        accessibilityTraits = isChipSelected ? [.button, .selected] : .button
    }

    private func firstLabel(in view: UIView) -> UILabel? {
        for sub in view.subviews {
            if let l = sub as? UILabel { return l }
            if let l = firstLabel(in: sub) { return l }
        }
        return nil
    }
}
