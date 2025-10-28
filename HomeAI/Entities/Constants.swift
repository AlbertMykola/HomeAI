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

        
        // OB
        static let didShowOnboarding = "did_show_onboarding_7"
        
        // APP
        static let appleId = "6475882299"
        static let amplitude = "900d7a894490363f703c5c5f14b1e1ee"
    }
    
    struct API {
        static let chatGPT = "https://openai-proxy.dirty-truth-app.workers.dev"
        
        static let privacy = "https://sites.google.com/view/homeaiprivacy"
        static let terms = "https://sites.google.com/view/homeai-terms"
    }
    
    struct Text {
        static let brand = "My Home AI"
    }
}
