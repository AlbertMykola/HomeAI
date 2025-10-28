import AmplitudeSwift
import AdSupport
import AppTrackingTransparency
import FirebaseAnalytics
import Foundation

final class AmplitudeService {
    static let shared = AmplitudeService()
    private let amplitude: Amplitude

    private init() {
        amplitude = Amplitude(configuration: Configuration(apiKey: Constants.Keys.amplitude, optOut: AmplitudeService.isTestingBuild))
    }

    func logEvent(_ event: AmpitudeEvent) {
        // Відправка івенту до Amplitude
        if let properties = event.properties {
            amplitude.track(eventType: event.event, eventProperties: properties)
        } else {
            amplitude.track(eventType: event.event)
        }
        // Відправка івенту до Firebase
        if let props = event.properties {
            Analytics.logEvent(event.event, parameters: props)
        } else {
            Analytics.logEvent(event.event, parameters: nil)
        }
    }

    /// Request tracking permission and, if granted, get IDFA and log the event
    func requestTrackingAndLogIDFA(completion: ((ATTrackingManager.AuthorizationStatus, String?) -> Void)? = nil) {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { [weak self] status in
                let granted = (status == .authorized)
                self?.logEvent(.trackingPermission(granted: granted))
                var idfa: String? = nil
                if granted {
                    idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
                    print("IDFA: \(idfa!)")
                } else {
                    print("IDFA not available or tracking not authorized")
                }
                completion?(status, idfa)
            }
        } else {
            // iOS < 14
            let granted = ASIdentifierManager.shared().isAdvertisingTrackingEnabled
            self.logEvent(.trackingPermission(granted: granted))
            let idfa = granted ? ASIdentifierManager.shared().advertisingIdentifier.uuidString : nil
            if let idfa = idfa {
                print("IDFA: \(idfa)")
            } else {
                print("IDFA not available or tracking not authorized")
            }
            completion?(.authorized, idfa)
        }
    }

    // MARK: – Helpers
    private static var isTestingBuild: Bool {
        #if DEBUG
        return true
        #else
        return Bundle.main
            .appStoreReceiptURL?
            .lastPathComponent == "sandboxReceipt"
        #endif
    }
}

enum AmpitudeEvent {

    case openApp,
         // OB
    showOBWelcome, showOBDesigns, showOBRate,
         // Paywall
    showPaywall(id: String), getProducts, gotProducts, presBuyProduct(index: Int), boughtProduct, restore,
        // Options
    showOptions, pressPro, selectOption(name: String),
         
         //Page View
    pressAddPhoto, takeAPhoto, selectGallery, showAddPhoto, showColorList, chooseColor(color: String), showRoomList, chooseRoom(room: String), chooseType(type: String),
         
        // Generation
         showProcessing, startGeneration, finishGeneration, filedBuildPrompt, prompt(p: String),
         // Settings
         showSettings, chooseSetting(type: String), trackingPermission(granted: Bool),
         
         
        // Other
    error(message: String), showLoader, stopLoader, pressSwitch, closeButtonAction, continueAction, nextButton
    
    var event: String {
        switch self {
            
        case .openApp: "open_app"

            // OB
        case .showOBWelcome: "show OB Welcome"
        case .showOBDesigns: "show OB Designs"
        case .showOBRate: "show OB Rate"
            // Paywall
        case .showPaywall: "show Paywall"
        case .getProducts: "get Products"
        case .gotProducts: "got Products"
        case .presBuyProduct(index: _): "press Buy Product"
        case .boughtProduct: "bought Product"
        case .restore: "restore Action"
        case .error(message: _): "error"
        case .showLoader: "start loader"
        case .stopLoader: "stop loader"
        case .pressSwitch: "press switch"
        case .closeButtonAction: "close button action"
        case .continueAction: "continue action"
        case .showOptions: "show Options"
        case .pressPro: "press PRO"
        case .selectOption(name: _): "select option"
        case .pressAddPhoto: "press Add Photo"
        case .takeAPhoto: "press Take a Photo"
        case .selectGallery: "select Gallery"
        case .nextButton: "press next"
        case .showAddPhoto: "show Add Photo"
        case .showColorList: "show Color List"
        case .chooseColor(color: _): "choose color"
        case .chooseRoom(room: _): "choose room"
        case .chooseType(type: _): "choose type"
        case .showRoomList: "show Room List"
        case .showProcessing: "show processing"
        case .startGeneration: "start generation"
        case .finishGeneration: "finish generation"
        case .filedBuildPrompt: "filed build prompt"
        case .prompt(p: _): "promt"
        case .chooseSetting(type: _): "choose Setting"
        case .showSettings: "show settings"
        case .trackingPermission: "tracking_permission"
        }
    }
    
    var properties: [String: Any]? {
        switch self {
        case .showPaywall(id: let id): return ["placement": id]
        case .presBuyProduct(index: let index): return ["index": index]
        case .error(message: let message): return ["message": message]
        case .selectOption(name: let option): return ["option": option]
        case .chooseColor(color: let color): return ["color": color]
        case .chooseRoom(room: let room): return ["room": room]
        case .chooseType(type: let type): return ["type": type]
        case .prompt(p: let prompt): return ["prompt": prompt]
        case .chooseSetting(type: let type): return ["type": type]
        case .trackingPermission(let granted): return ["granted": granted]
        default: return nil
        }
    }
}
