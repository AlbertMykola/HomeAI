import UIKit
import MessageUI

final class SettingsViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    enum Section: Int, CaseIterable {
        case general, legal
        var title: String {
            switch self {
            case .general: return "General"
            case .legal:   return "Legal & Support"
            }
        }
    }

    enum Row: String, Hashable {
        case notification
        case vibration
        case share
        case rateUs
        case privacy
        case terms
        case contact

        var title: String {
            switch self {
            case .notification: return "Notification".localized
            case .vibration:    return "Vibration".localized
            case .share:        return "Share".localized
            case .rateUs:       return "Rate us".localized
            case .privacy:      return "Privacy Policy".localized
            case .terms:        return "Terms & Conditions".localized
            case .contact:      return "Contact Us".localized
            }
        }

        var symbol: String {
            switch self {
            case .notification: return "bell"
            case .vibration:    return "iphone.radiowaves.left.and.right"
            case .share:        return "square.and.arrow.up"
            case .privacy:      return "lock.shield"
            case .terms:        return "doc.text"
            case .contact:      return "envelope"
            case .rateUs:       return "hand.thumbsup"
            }
        }

        var isToggle: Bool {
            switch self {
            case .notification, .vibration: return true
            default: return false
            }
        }
    }

    // MARK: - Diffable Data Source

    private final class SettingsDataSource: UITableViewDiffableDataSource<Section, Row> {
        override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            // Повертаємо текст заголовка секції
            Section(rawValue: section)?.title
        }
    }

    private typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Row>
    private var dataSource: SettingsDataSource!

    // MARK: - State

    private var notificationsOn = true
    private var vibrationOn = true
    private var amplitude = AmplitudeService.shared

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings".localized
        amplitude.logEvent(.showSettings)
        configureTable()
        configureDataSource()
        applySnapshot()
    }

    // MARK: - Setup

    private func configureTable() {
        tableView.register(UINib(nibName: "SettingsTableViewCell", bundle: nil), forCellReuseIdentifier: "SettingsTableViewCell")
        tableView.delegate = self
        tableView.rowHeight = 64
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 8
        }
    }

    private func configureDataSource() {
        dataSource = SettingsDataSource(tableView: tableView) { [weak self] tableView, indexPath, row in
            guard let self, let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsTableViewCell", for: indexPath) as? SettingsTableViewCell
            else { return UITableViewCell() }

            let isOn: Bool? = {
                switch row {
                case .notification: return self.notificationsOn
                case .vibration:    return self.vibrationOn
                default:            return nil
                }
            }()

            cell.configure(icon: row.symbol, title: row.title, showsSwitch: row.isToggle, isOn: isOn)

            cell.switchChanged = { [weak self] newValue in
                guard let self else { return }
                switch row {
                case .notification:
                    self.notificationsOn = newValue
                    self.reconfigure(.notification)
                case .vibration:
                    self.vibrationOn = newValue
                    self.reconfigure(.vibration)
                default:
                    break
                }
            }

            return cell
        }
    }

    private func applySnapshot() {
        var snap = Snapshot()
        snap.appendSections([.general, .legal])
        snap.appendItems([.notification, .vibration, .share, .rateUs], toSection: .general)
        snap.appendItems([.privacy, .terms, .contact], toSection: .legal)
        dataSource.apply(snap, animatingDifferences: false)
    }

    private func reconfigure(_ row: Row) {
        var snap = dataSource.snapshot()
        snap.reconfigureItems([row])
        dataSource.apply(snap, animatingDifferences: false)
    }

    // MARK: - Helpers
    private func openExternal(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    private func sendSupportEmail(to address: String) {
        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()
            mail.mailComposeDelegate = self
            mail.setToRecipients([address])
            mail.setSubject("Support Request")
            present(mail, animated: true)
        } else if let url = URL(string: "mailto:\(address)") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}

// MARK: - UITableViewDelegate
extension SettingsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let row = dataSource.itemIdentifier(for: indexPath) else { return }
        tableView.deselectRow(at: indexPath, animated: true)
        amplitude.logEvent(.chooseSetting(type: row.rawValue))
        switch row {
        case .share:
            let vc = UIActivityViewController(activityItems: ["Check out HomeAI!"], applicationActivities: nil)
            present(vc, animated: true)
        case .rateUs:
            let urlString = "itms-apps://itunes.apple.com/app/id\(Constants.Keys.appleId)?action=write-review"
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        case .privacy:
            openExternal(Constants.API.privacy)
        case .terms:
            openExternal(Constants.API.terms)
        case .contact:
            sendSupportEmail(to: "m.albert.apps@gmail.com")
        default:
            break
        }
    }
}

// MARK: - MFMailComposeViewControllerDelegate

extension SettingsViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult,
                               error: Error?) {
        controller.dismiss(animated: true)
    }
}
