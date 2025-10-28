import Foundation

extension String {
    
    // MARK: - Localization
    var localized: String {
        return NSLocalizedString(self, tableName: nil, bundle: .main, value: "", comment: "")
    }
}
