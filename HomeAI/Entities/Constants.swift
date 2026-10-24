import UIKit

struct Constants {
    
    struct Colors {
        static let yellowPremium = UIColor(red: 165 / 255, green: 238 / 255, blue: 47 / 255, alpha: 1)
    }
    
    struct Keys {
        // Adapty
        static let adapty = "public_live_IwMFkQu9.T9yq1wYc8VltAWFTXzdZ"
        static let adaptyAccessLevel = "premium"
        
        static let obPlacement = "ob-placement-com"
        static let appLaunchPlacement = "app_launch_placement"
        static let optionPlacememt = "option_ai_placement"
        static let reachedLimit = "limit_reached_ai_placement"
        static let saveImagePlacement = "save_image_placement"
        static let shareImagePlacement = "share_image_placement"
        static let detailsEditPlacement = "details_edit_placement"
        static let defaults = "default_placement"

        /// Кеш remote config з worker (`GET /app/config`).
        static let cachedWorkerAppConfig = "cached_worker_app_config_v1"
        /// Кеш remote config з Supabase (`App_Config`).
        static let cachedSupabaseAppConfig = "cached_supabase_app_config_v1"

        // OB
        static let didShowOnboarding = "did_show_onboarding_8"
        static let onboardingGoal = "onboarding_goal"
        static let didShowRateAlert = "did_show_rate_alert_2"
        static let didShowAddPhotoPhotoTips = "did_show_add_photo_photo_tips_1"
        static let didLogTrackingPermission = "did_log_tracking_permission_1"
        static let didLogASAAttributionToAmplitude = "did_log_asa_attribution_to_amplitude_1"

        /// Amplitude + Firebase: інстал через Apple Search Ads.
        static let amplitudeFromASAActionEvent = "FROM_ASA_ACTION"

        // DEBUG: Adapty subscription override
        static let debugHasActiveSubscriptionOverrideEnabled = "debug_has_active_subscription_override_enabled"
        static let debugHasActiveSubscription = "debug_has_active_subscription"
        
        // APP
        static let appleId = "6752722494"
        static let amplitude = "900d7a894490363f703c5c5f14b1e1ee"

        /// Amplitude: `selectOption` при тапі «Переглянути все» (smart tools).
        static let amplitudeSeeAllSmartToolsOption = "see_all_smart_tools"
        /// Amplitude: `selectOption` при тапі картки чату з Options.
        static let amplitudeChatAssistantOption = "chat_assistant"
        static let appsFlyer = "Ybs8rhkmbbzn6Y6fiPf2WT"
        /// OneLink host для Associated Domains (`applinks:` + це значення).
        static let appsFlyerOneLinkHost = "rehomelyai.onelink.me"
        static let sentryDSN = "https://79780af0545dcf2cadf3e1507293bd6c@o4511988932804608.ingest.de.sentry.io/4512047093514320"
    }
    
    struct API {
        /// Базовий URL Cloudflare worker (проксі Gemini / OpenAI + `/app/config`).
        static let workerProxyBase = "https://gemini-secure-proxy.dirty-truth-app.workers.dev"
        static var workerAppConfigURL: String { workerProxyBase + "/app/config" }

        static let chatGPT = "https://openai-proxy.dirty-truth-app.workers.dev"
        /// Чат з асистентами (`ChatViewController`). Іде в Gemini text-model через наш worker,
        /// бо `OPENAI_API_KEY` на воркері поки не заданий, а Gemini ключ уже є й безкоштовний.
        /// Якщо в майбутньому додати `OPENAI_API_KEY` — можна повернути:
        ///   `https://gemini-secure-proxy.dirty-truth-app.workers.dev/openai/v1/chat/completions`
        static let assistantChat = workerProxyBase + "/gemini/v1beta/models/gemini-2.5-flash:generateContent"
        /// Шлемо одразу в Nano Banana 2 (Gemini 3.1 Flash Image Preview) — краща за `gemini-2.5-flash-image`
        /// в instruction following і edits (наприклад, rearrange furniture).
        /// Якщо потрібно тимчасово відкотитися — `https://gemini-secure-proxy.dirty-truth-app.workers.dev/`
        /// віддає дефолтну модель воркера.
        static var gemini: String {
            workerProxyBase + "/gemini/v1beta/models/\(Generation.modelID):generateContent"
        }
        static let privacy = "https://sites.google.com/view/homeaiprivacy"
        static let terms = "https://sites.google.com/view/homeai-terms"
        
        // Supabase
        static let supabaseURL = "https://dmgdmiyovhknsgylocge.supabase.co"
        static let supabaseAnonKey = "sb_publishable_24RyxTfQ5hirSFXgwEp--A_iV9Qh8dA"
        static let supabaseStorageBucket = "Images"
        static let supabaseImagesBucket = "\(supabaseURL)/storage/v1/object/public/\(supabaseStorageBucket)"
        /// Приватний bucket для фото юзера після генерації; lifecycle — видалення через 3 дні.
        static let supabaseUserPhotosBucket = "UserPhotos"
        static var supabaseAppConfigURL: String {
            "\(supabaseURL)/rest/v1/App_Config?select=*&order=id.asc&limit=1"
        }
        static let firebaseStorageBucket = "homeai-41580.firebasestorage.app"
    }
    
    struct Text {
        static let brand = "ReHomely"
    }

    struct Images {
        static let preview = "preview_image"
        static var previewPlaceholder: UIImage? { UIImage(named: preview) }
    }

    /// Fallback-и, якщо worker config ще не завантажився або недоступний.
    struct GenerationLimits {
        static let freeGenerationsLifetime = 1
        static let premiumGenerationsPerDay = 15
    }

    struct Generation {
        static var modelID: String {
            #if DEBUG
            // Quality/cost check only (`-geminiModel gemini-nano-banana-2.1`); Release always uses the default.
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-geminiModel"), args.indices.contains(i + 1) { return args[i + 1] }
            #endif
            return "gemini-3.1-flash-image-preview"
        }
        static let promptVersion = "2026-09-24.1"
        static let gptImagePromptVersion = "2026-09-17.gpt-image-2.5-test"
        /// The model returns 1K images; a larger input adds bytes and latency, not quality.
        static let maxImageLongEdge: CGFloat = 1_536
        static let jpegCompressionQuality: CGFloat = 0.82
        static let maxRequestBodyBytes = 14_000_000
        static let requestTimeout: TimeInterval = 180
        static let resourceTimeout: TimeInterval = 240
        static let maximumRetryCount = 2
        static let maximumCustomPromptLength = 1_000

        struct OpenAI {
            static let productionWorkerURL = "https://fragrant-fog-a5e3.dirty-truth-app.workers.dev/v1/images/generate"
            /// Shared gate for the worker (`X-HomeAI-Mobile-Key`, worker secret MOBILE_GATE_KEY). Not strong auth:
            /// it only stops casual use of the public workers.dev URL.
            /// From the gitignored `HomeAI/Resources/Secrets.plist` (template: `Secrets.example.plist`).
            static var mobileGateKey: String? { AppSecrets.value(for: "MOBILE_GATE_KEY") }
            static let flareModel = "gpt-image-2.5-flare"
            static let sunburstModel = "gpt-image-2.5-sunburst"
            static let quality = "medium"
        }
    }

    struct PaywallRemote {
        static let showTopCloseButtonFallback = true
    }

    // MARK: - Debug
    /// Тимчасові перемикачі для розробки. Перед релізом вимкнути / перевірити.
    struct Debug {
        /// Якщо `true` — після TabBar показується paywall (лише без активної підписки). Для верстки paywall.
        static let alwaysShowPaywallOnLaunch = false
        /// DEBUG: `-skipLaunchPaywall` launch argument — no launch paywall (screen QA in the simulator).
        static let skipLaunchPaywall = {
            #if DEBUG
            ProcessInfo.processInfo.arguments.contains("-skipLaunchPaywall")
            #else
            false
            #endif
        }()
        /// DEBUG: explicitly opt into replaying onboarding; normal launches respect completion.
        static let alwaysShowOnboarding = {
            #if DEBUG
            ProcessInfo.processInfo.arguments.contains("-showOnboarding")
                && !ProcessInfo.processInfo.arguments.contains("-skipOnboarding")
            #else
            false
            #endif
        }()
    }
}
