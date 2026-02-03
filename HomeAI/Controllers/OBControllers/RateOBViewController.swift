//
//  RateOBViewController.swift
//  HomeAI
//
//  Created by Mykola Albert on 23.09.2025.
//

import UIKit
import StoreKit

private struct Defaults {
    struct Text {
        static let headline = "HELP US GROW!".localized
        static let description = "Support us with a quick review! Your feedback keeps us going and helps us bring even more smart design magic to life".localized
        static let getStarted = "Get Started".localized
        
        static let comments: [[String]] = [["Great app for quick home redesign ideas.", "Great app, just wish it had more furniture options.", "AI suggestions were spot on. Love it!", "Felt like having a designer in my pocket!", "Clean interface and smart recommendations."],["Helped me visualize my new kitchen in minutes!", "Best home design app I’ve tried so far!", "Smart and super easy to use!", "Perfect for quick home makeovers!", "Redesigned my space in seconds. Amazing!"],
            ["AI ideas were creative and actually useful.", "Impressive AI! Saved me so much time.", "Cool features, especially the AI room planner.", "So intuitive! Made decorating fun again.", "AI ideas were creative and actually useful."]]
    }
}

final class RateOBViewController: UIViewController, OBPageChild {
    
    // MARK: - @IBOutlets
    @IBOutlet weak private var bottomGradientContainerView: UIView!
    
    @IBOutlet weak private var heartContainerView: UIView!

    @IBOutlet weak private var descriptionLabel: UILabel!
    @IBOutlet weak private var headlineLabel: UILabel!
    
    @IBOutlet weak private var nextButton: UIButton!
    @IBOutlet private var sizeConstraints: [NSLayoutConstraint]!

    // MARK: - Properties
    private var engine: CarouselEngine<String, RateCollectionViewCell>?
    
    weak var obDelegate: OBPageChildDelegate?
    private var addedGradient = false

    // MARK: - Lifecycles
    override func viewDidLoad() {
        super.viewDidLoad()
        config()
        AmplitudeService.shared.logEvent(.showOBRate)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        engine?.start()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        rate()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        engine?.stop()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if !addedGradient {
            bottomGradientContainerView.setGradient(stops: [.init(percent: 0, color: .systemBackground.withAlphaComponent(0)), .init(percent: 50, color: .systemBackground), .init(percent: 100, color: .systemBackground)], direction: .vertical)

            heartContainerView.cornerRadius = heartContainerView.frame.height / 2
            addedGradient = true
        }
        nextButton.layer.cornerRadius = nextButton.frame.height / 2
    }
    
    private func config() {
        headlineLabel.text = Defaults.Text.headline
        descriptionLabel.text = Defaults.Text.description
        nextButton.setTitle(Defaults.Text.getStarted, for: .normal)
        sizeConstraints.forEach { $0.scaleConstantByWidth() }
    }

    
    func rate() {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    // MARK: - @IBActions
    @IBAction private func nextTapped(_ sender: UIButton) {
        obDelegate?.obChildRequestsNext(self)
    }
}
