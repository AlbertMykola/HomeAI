import Foundation

enum AppLocalization {
    static var language: String {
        #if DEBUG
        if AppQA.enabled, let language = AppQA.language { return language }
        #endif
        return Bundle.main.preferredLocalizations.first ?? "en"
    }
    static var locale: Locale { Locale(identifier: language) }
}

extension String {
    
    // MARK: - Localization
    var localized: String {
        #if DEBUG
        if let bundle = AppQA.localizationBundle { return bundle.localizedString(forKey: self, value: nil, table: nil) }
        #endif
        return NSLocalizedString(self, tableName: nil, bundle: .main, value: "", comment: "")
    }
}
