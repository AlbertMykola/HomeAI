//
//  Constants.swift
//  HomeAI
//
//  Created by Mykola Albert on 08.09.2025.
//

import UIKit

struct Constants {
    
    struct Colors {
        static let yellowPremium = UIColor(red: 165 / 255, green: 238 / 255, blue: 47 / 255, alpha: 1)
    }
    
    struct Keys {
        // APPHUD
        static let apphud = "app_P8d6XG2mgVC8tZFPxuw7Ro8pe7kHeD"
        static let obPlacement = "ob-placement-com"
        static let optionPlacememt = "option_ai_placement"
        static let reachedLimit = "limit_reached_ai_placement"
        static let saveImagePlacement = "save_image_placement"
        static let shareImagePlacement = "share_image_placement"
        static let detailsEditPlacement = "details_edit_placement"

        // OB
        static let didShowOnboarding = "did_show_onboarding_7"
        static let didShowRateAlert = "did_show_rate_alert_2"
        static let didShowAddPhotoPhotoTips = "did_show_add_photo_photo_tips_1"
        static let didLogTrackingPermission = "did_log_tracking_permission_1"

        // DEBUG: Apphud subscription override
        // Used only in DEBUG builds to simulate subscription state.
        static let debugHasActiveSubscriptionOverrideEnabled = "debug_has_active_subscription_override_enabled"
        static let debugHasActiveSubscription = "debug_has_active_subscription"
        
        // APP
        static let appleId = "6752722494"
        static let amplitude = "900d7a894490363f703c5c5f14b1e1ee"
    }
    
    struct API {
        static let chatGPT = "https://openai-proxy.dirty-truth-app.workers.dev"
        static let gemini = "https://gemini-secure-proxy.dirty-truth-app.workers.dev"
        static let privacy = "https://sites.google.com/view/homeaiprivacy"
        static let terms = "https://sites.google.com/view/homeai-terms"
        
        // Supabase
        static let supabaseURL = "https://dmgdmiyovhknsgylocge.supabase.co"
        static let supabaseAnonKey = "sb_publishable_24RyxTfQ5hirSFXgwEp--A_iV9Qh8dA"
        static let supabaseImagesBucket = "\(supabaseURL)/storage/v1/object/public/Images"
        static let firebaseStorageBucket = "homeai-41580.firebasestorage.app"
    }
    
    struct Text {
        static let brand = "ReHomely"
    }
}
