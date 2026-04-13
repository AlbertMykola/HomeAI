//
//  SceneDelegate.swift
//  HomeAI
//
//  Created by Mykola Albert on 08.09.2025.
//

import UIKit
import AppTrackingTransparency
import AdSupport
import FBSDKCoreKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    private enum ShortcutType {
        static let exclusiveOffer = "com.homeai.exclusiveOffer"
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        NavigationManager.shared.setupWindow(with: windowScene)

        if let shortcutItem = connectionOptions.shortcutItem {
            handle(shortcutItem: shortcutItem)
        }
    }

    func windowScene(_ windowScene: UIWindowScene,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        let handled = handle(shortcutItem: shortcutItem)
        completionHandler(handled)
    }

    @discardableResult
    private func handle(shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard shortcutItem.type == ShortcutType.exclusiveOffer else { return false }

        let userId = ApphudService.shared.userID
        let subject = "Get an Exclusive Offer - HomeAI \(userId)"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        let systemVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model

        let body = """
        Hi HomeAI team,

        I'd love to get an exclusive offer for HomeAI.

        My details:
        - Apphud user ID: \(userId)
        - App version: \(appVersion) (\(build))
        - Device: \(deviceModel)
        - iOS: \(systemVersion)

        Please let me know what special offer is available for my account.

        Best regards,
        """

        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body
        let urlString = "mailto:m.albert.apps@gmail.com?subject=\(encodedSubject)&body=\(encodedBody)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return true
        }

        return false
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        AppEvents.shared.activateApp()
        Task { @MainActor in
            ApphudService.shared.setMetaAttributionForCAPIIfNeeded()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // Log ATT permission only once per install.
            if UserDefaults.standard.bool(forKey: Constants.Keys.didLogTrackingPermission) {
                return
            }
            print("[SceneDelegate] Виклик TrackingManager.requestPermission...")
            
            TrackingManager.requestPermission { status in
                
                let granted = (status == .authorized)
                
                AmplitudeService.shared.logEvent(.trackingPermission(granted: granted))
                UserDefaults.standard.set(true, forKey: Constants.Keys.didLogTrackingPermission)
                
                if granted {
                    if let idfa = TrackingManager.getIDFA() {
                        print("[SceneDelegate] Отримано IDFA: \(idfa)")
                    }
                } else {
                    print("[SceneDelegate] Дозвіл на відстеження НЕ надано.")
                }
            }
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
}


