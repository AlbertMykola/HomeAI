//
//  LaunchViewController.swift
//  HomeAI
//
//  Created by Mykola Albert on 02.11.2025.
//

import UIKit

class LaunchViewController: UIViewController {
    
    @IBOutlet weak private var myProgress: UIProgressView!
    
    private let launchDuration: TimeInterval = 5.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        myProgress.progress = 0.0
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startLaunchAnimation()
    }
    
    private func startLaunchAnimation() {
        UIView.animate(withDuration: launchDuration, delay: 0.0, options: [.curveLinear], animations: {
            self.myProgress.setProgress(1.0, animated: true)
        }, completion: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + launchDuration) {
            self.completeLaunch()
        }
    }
    
    private func completeLaunch() {
        NavigationManager.shared.proceedToApp()
    }
}
