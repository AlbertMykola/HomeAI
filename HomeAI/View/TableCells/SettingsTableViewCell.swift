import UIKit

final class SettingsTableViewCell: UITableViewCell {
    
    @IBOutlet weak private var iconImageView: UIImageView!
    @IBOutlet weak private var nameLabel: UILabel!
    @IBOutlet weak private var chevronImageView: UIImageView!
    @IBOutlet weak private var onSwitch: UISwitch!

    var switchChanged: ((Bool) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .default
        onSwitch.addTarget(self, action: #selector(handleSwitch(_:)), for: .valueChanged)
        iconImageView.tintColor = .label
        chevronImageView.tintColor = .tertiaryLabel
    }

    func configure(icon: String, title: String, showsSwitch: Bool, isOn: Bool?) {
        nameLabel.text = title
        iconImageView.image = UIImage(systemName: icon)
        onSwitch.isHidden = !showsSwitch
        chevronImageView.isHidden = showsSwitch
        if let isOn { onSwitch.isOn = isOn }
        selectionStyle = showsSwitch ? .none : .default
    }

    @objc private func handleSwitch(_ sender: UISwitch) {
        switchChanged?(sender.isOn)
    }
}
