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

    var deviceID: String? { amplitude.getDeviceId() }

    func logEvent(_ event: AmpitudeEvent) {
        #if DEBUG
        AppQA.record(event.event, properties: event.properties ?? [:])
        #endif
        // Відправка івенту до Amplitude
        if let properties = event.properties {
            amplitude.track(eventType: event.event, eventProperties: properties)
        } else {
            amplitude.track(eventType: event.event)
        }
        // Відправка івенту до Firebase
        if !Self.isTestingBuild {
            if let props = event.properties {
                Analytics.logEvent(event.event, parameters: firebaseParameters(from: props))
            } else {
                Analytics.logEvent(event.event, parameters: nil)
            }
        }
    }

    /// Snake_case events of the redesign (push_preprompt_view, share_complete, …).
    func logRedesignEvent(_ name: String, properties: [String: Any] = [:]) {
        #if DEBUG
        AppQA.record(name, properties: properties)
        #endif
        amplitude.track(eventType: name, eventProperties: properties.isEmpty ? nil : properties)
        if !Self.isTestingBuild {
            Analytics.logEvent(name, parameters: properties.isEmpty ? nil : firebaseParameters(from: properties))
        }
    }

    /// Stable snake_case events for the purchase funnel. Keep the legacy events above
    /// until dashboards have migrated; those events do not distinguish trials.
    func logPaywallEvent(_ name: String, properties: [String: Any]) {
        var payload = properties
        payload["event_schema_version"] = 2
        payload["app_version"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        payload["build_number"] = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        #if DEBUG
        AppQA.record(name, properties: payload)
        #endif
        amplitude.track(eventType: name, eventProperties: payload)
        if !Self.isTestingBuild {
            Analytics.logEvent(name, parameters: firebaseParameters(from: payload))
        }
    }

    /// Apple Search Ads: `FROM_ASA_ACTION` лише для ASA-інсталу (один раз).
    func logAppleSearchAdsAttribution(_ result: AppleSearchAdsAttributionResult) {
        guard case .attributed(let data) = result else { return }
        guard !UserDefaults.standard.bool(forKey: Constants.Keys.didLogASAAttributionToAmplitude) else { return }

        var properties: [String: Any] = [:]
        for (key, value) in data where key != "attribution" {
            properties["asa_\(key)"] = value
        }

        logEvent(.fromASAAction(properties: properties))
        UserDefaults.standard.set(true, forKey: Constants.Keys.didLogASAAttributionToAmplitude)

        #if DEBUG
        print("[Amplitude] FROM_ASA_ACTION logged")
        #endif
    }

//    /// Request tracking permission and, if granted, get IDFA and log the event
//    func requestTrackingAndLogIDFA(completion: ((ATTrackingManager.AuthorizationStatus, String?) -> Void)? = nil) {
//        if #available(iOS 14, *) {
//            ATTrackingManager.requestTrackingAuthorization { [weak self] status in
//                let granted = (status == .authorized)
//                self?.logEvent(.trackingPermission(granted: granted))
//                var idfa: String? = nil
//                if granted {
//                    idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
//                    print("IDFA: \(idfa!)")
//                } else {
//                    print("IDFA not available or tracking not authorized")
//                }
//                completion?(status, idfa)
//            }
//        } else {
//            // iOS < 14
//            let granted = ASIdentifierManager.shared().isAdvertisingTrackingEnabled
//            self.logEvent(.trackingPermission(granted: granted))
//            let idfa = granted ? ASIdentifierManager.shared().advertisingIdentifier.uuidString : nil
//            if let idfa = idfa {
//                print("IDFA: \(idfa)")
//            } else {
//                print("IDFA not available or tracking not authorized")
//            }
//            completion?(.authorized, idfa)
//        }
//    }

    // MARK: – Helpers

    private func firebaseParameters(from properties: [String: Any]) -> [String: Any] {
        var sanitized: [String: Any] = [:]
        for (key, value) in properties {
            switch value {
            case let v as String: sanitized[key] = v
            case let v as Int: sanitized[key] = v
            case let v as Double: sanitized[key] = v
            case let v as Bool: sanitized[key] = v
            case let v as NSNumber: sanitized[key] = v
            default: sanitized[key] = "\(value)"
            }
        }
        return sanitized
    }

    private static var isTestingBuild: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        #if DEBUG
        return true
        #else
        return Bundle.main
            .appStoreReceiptURL?
            .lastPathComponent == "sandboxReceipt"
        #endif
        #endif
    }
}

enum AmpitudeEvent {

    case openApp,
         // OB
    showOBWelcome, showOBExterior, showOBGarden, showOBRate,
         // Paywall
    showPaywall(id: String), getProducts, gotProducts, presBuyProduct(index: Int), boughtProduct, restore,
    paywallPrivacy(placement: String), paywallTerms(placement: String),
        // Adapty
    adaptyProfileId(id: String),
    fromASAAction(properties: [String: Any]),
        // Options
    showOptions, pressPro, selectOption(name: String),
    assistantChatMessage(assistant: String, message: String, status: String),
         
         //Page View
         pressAddPhoto, takeAPhoto, selectGallery, showAddPhoto, showColorList, chooseColor(color: String), showRoomList, chooseRoom(room: String), chooseType(type: String), showSurfaceMaterialPicker(type:SurfaceMaterialOption.Placement),
         
    // Generation
    showProcessing, startGeneration, finishGeneration, filedBuildPrompt, prompt(p: String), showRatingAlert, rateNowAction, dontRateAction, reachedLimit, dailyGenerationLimitReached,
    generationStarted(attemptID: String, option: String, promptVersion: String, provider: String, model: String),
    generationSucceeded(attemptID: String, option: String, promptVersion: String, provider: String, model: String, latencyMS: Int),
    generationFailed(attemptID: String, option: String, promptVersion: String, provider: String, model: String, category: String, statusCode: Int?, latencyMS: Int),
    generationCancelled(attemptID: String, option: String, promptVersion: String, latencyMS: Int),
    generationBlocked(attemptID: String, option: String, promptVersion: String, reason: String),
    generationPromptMetadata(option: String, promptVersion: String, promptLength: Int),
    generationStage(attemptID: String, stage: String, elapsedMS: Int),
    generationRetry(previousAttemptID: String, reason: String, retryNumber: Int),
    showGenerationsLeftAlert(remaining: Int), generationsLeftGetProAction(remaining: Int), generationsLeftMaybeLaterAction(remaining: Int),
    // Settings
    showSettings, chooseSetting(type: String), trackingPermission(granted: Bool),
    // Other
         error(message: String), showLoader, stopLoader, pressSwitch, closeButtonAction, continueAction, nextButton, alert(message: String), tryAgainAction,
    //Detail
    showDetail, selectingEdit(type: EditorActionType),
    detailLikeTap, detailLikeShowAlert, detailLikeOpenAppStore,
    detailDislikeTap, detailDislikeConfirmShare, detailDislikeCancelShare,
    detailReviewRequest, detailDislikeMailResult(result: String),
    //Inspiration
    showInspirations
    
    var event: String {
        switch self {
            
        case .openApp: "open_app"

            // OB
        case .showOBWelcome: "show OB Welcome"
        case .showOBExterior: "show OB Exterior"
        case .showOBGarden: "show OB Garden"
        case .showOBRate: "show OB Rate"
            // Paywall
        case .showPaywall: "show Paywall"
        case .getProducts: "get Products"
        case .gotProducts: "got Products"
        case .presBuyProduct(index: _): "press Buy Product"
        case .boughtProduct: "bought Product"
        case .restore: "restore Action"
        case .paywallPrivacy: "paywall privacy"
        case .paywallTerms: "paywall terms"
        case .adaptyProfileId: "adapty_profile_id"
        case .fromASAAction: Constants.Keys.amplitudeFromASAActionEvent
        case .error(message: _): "error"
        case .showLoader: "start loader"
        case .stopLoader: "stop loader"
        case .pressSwitch: "press switch"
        case .closeButtonAction: "close button action"
        case .continueAction: "continue action"
        case .showOptions: "show Options"
        case .pressPro: "press PRO"
        case .selectOption(name: _): "select option"
        case .assistantChatMessage: "assistant_chat_message"
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
        case .prompt(p: _): "prompt"
        case .generationStarted: "generation_started"
        case .generationSucceeded: "generation_succeeded"
        case .generationFailed: "generation_failed"
        case .generationCancelled: "generation_cancelled"
        case .generationBlocked: "generation_blocked"
        case .generationPromptMetadata: "generation_prompt_metadata"
        case .generationStage: "generation_stage"
        case .generationRetry: "generation_retry"
        case .chooseSetting(type: _): "choose Setting"
        case .showSettings: "show settings"
        case .trackingPermission: "tracking_permission"
        case .showSurfaceMaterialPicker(type: _): "show_surface_material_picker"
        case .showDetail: "show_detail"
        case .selectingEdit(type: _): "select_edit"
        case .detailLikeTap: "detail_like_tap"
        case .detailLikeShowAlert: "detail_like_show_alert"
        case .detailLikeOpenAppStore: "detail_like_open_app_store"
        case .detailDislikeTap: "detail_dislike_tap"
        case .detailDislikeConfirmShare: "detail_dislike_confirm_share"
        case .detailDislikeCancelShare: "detail_dislike_cancel_share"
        case .detailReviewRequest: "detail_review_request"
        case .detailDislikeMailResult(result: _): "detail_dislike_mail_result"
        case .showInspirations: "show_inspirations"
        case .showRatingAlert: "show RATING alert"
        case .rateNowAction: "rate now action"
        case .dontRateAction: "dont rate action"
        case .reachedLimit: "reached limit"
        case .dailyGenerationLimitReached: "daily_generation_limit_reached"
        case .showGenerationsLeftAlert: "show_generations_left_alert"
        case .generationsLeftGetProAction: "generations_left_get_pro"
        case .generationsLeftMaybeLaterAction: "generations_left_maybe_later"
        case .alert(message:  _): "alert_message"
        case .tryAgainAction: "try Again Action"
        }
    }
    
    var properties: [String: Any]? {
        switch self {
        case .showPaywall(id: let id): return ["placement": id]
        case .paywallPrivacy(placement: let placement), .paywallTerms(placement: let placement):
            return ["placement": placement]
        case .presBuyProduct(index: let index): return ["index": index]
        case .adaptyProfileId(id: let id): return ["adapty_profile_id": id]
        case .fromASAAction(properties: let properties): return properties
        case .error(message: let message): return ["message": message]
        case .selectOption(name: let option): return ["option": option]
        case .assistantChatMessage(assistant: let assistant, message: let message, status: let status):
            return [
                "assistant": assistant,
                "message_length": message.count,
                "status": status
            ]
        case .chooseColor(color: let color): return ["color": color]
        case .chooseRoom(room: let room): return ["room": room]
        case .chooseType(type: let type): return ["type": type]
        case .prompt(p: let prompt): return ["prompt_length": prompt.count]
        case let .generationStarted(attemptID, option, promptVersion, provider, model):
            return [
                "attempt_id": attemptID,
                "design_option": option,
                "prompt_version": promptVersion,
                "provider": provider,
                "model": model
            ]
        case let .generationSucceeded(attemptID, option, promptVersion, provider, model, latencyMS):
            return [
                "attempt_id": attemptID,
                "design_option": option,
                "prompt_version": promptVersion,
                "provider": provider,
                "model": model,
                "latency_ms": latencyMS
            ]
        case let .generationFailed(attemptID, option, promptVersion, provider, model, category, statusCode, latencyMS):
            var properties: [String: Any] = [
                "attempt_id": attemptID,
                "design_option": option,
                "prompt_version": promptVersion,
                "provider": provider,
                "model": model,
                "error_category": category,
                "latency_ms": latencyMS
            ]
            if let statusCode {
                properties["http_status"] = statusCode
            }
            return properties
        case let .generationCancelled(attemptID, option, promptVersion, latencyMS):
            return [
                "attempt_id": attemptID,
                "design_option": option,
                "prompt_version": promptVersion,
                "latency_ms": latencyMS
            ]
        case let .generationBlocked(attemptID, option, promptVersion, reason):
            return [
                "attempt_id": attemptID,
                "design_option": option,
                "prompt_version": promptVersion,
                "reason": reason
            ]
        case let .generationPromptMetadata(option, promptVersion, promptLength):
            return [
                "design_option": option,
                "prompt_version": promptVersion,
                "prompt_length": promptLength
            ]
        case let .generationStage(attemptID, stage, elapsedMS):
            return ["attempt_id": attemptID, "stage": stage, "elapsed_ms": elapsedMS]
        case let .generationRetry(previousAttemptID, reason, retryNumber):
            return ["previous_attempt_id": previousAttemptID, "reason": reason, "retry_number": retryNumber]
        case .chooseSetting(type: let type): return ["type": type]
        case .trackingPermission(let granted): return ["granted": granted]
        case .showSurfaceMaterialPicker(type: let type): return ["type": type == .floor ? "floor" : "wall"]
        case .selectingEdit(type: let type): return ["edit": type]
        case .detailDislikeMailResult(result: let result): return ["result": result]
        case .alert(message: let message): return ["message": message]
        case .showGenerationsLeftAlert(remaining: let remaining),
             .generationsLeftGetProAction(remaining: let remaining),
             .generationsLeftMaybeLaterAction(remaining: let remaining):
            return ["remaining": remaining]
        default: return nil
        }
    }
}
