//
//  CustomLoaderView.swift
//  HomeAI
//
//  Created by Mykola Albert on 20.09.2025.
//

import UIKit

private struct Defaults {
    
    struct Images {
        static let images: [UIImage] = [
            UIImage(named: "kitchen_room_icon"),
            UIImage(named: "bedroom_room_icon"),
            UIImage(named: "bathroom_room_icon"),
            UIImage(named: "living_room_icon"),
            UIImage(named: "dinning_room_icon"),
            UIImage(named: "office_room_icon"),
            UIImage(named: "study_room_icon"),
            UIImage(named: "kids_room_icon"),
            UIImage(named: "attic_room_icon"),
            UIImage(named: "balcony_room_icon"),
            UIImage(named: "hallway_room_icon")
        ].compactMap { $0 }
    }
}

final class CustomLoaderView: UIView {
    
    private enum Direction {
        case side, bottom
        
        var transitionOption: UIView.AnimationOptions {
            switch self {
            case .side:   return .transitionFlipFromLeft // використаємо системний варіант
            case .bottom: return .transitionFlipFromTop
            }
        }
    }
    
    @IBOutlet weak var loadImageView: UIImageView!
    
    // MARK: - Private UI
    private let frontImageView = UIImageView()
    private let backImageView = UIImageView()
    
    // MARK: - Model
    private var frames: [UIImage] = []
    private var currentIndex = 0
    private var usingFrontOnTop = true
        
    private var nextDirection: Direction = .side
    
    // MARK: - Timing
    private let frameInterval: TimeInterval = 1.4
    private let swapDuration: TimeInterval = 0.45
    
    private var timer: Timer?
    
    public func start() { startSequence() }
    public func stop()  { stopSequence() }

    deinit { stopSequence() } // страховка
    
    // MARK: - Factory
    static func loadFromNib() -> CustomLoaderView {
        let v = Bundle.main.loadNibNamed("CustomLoaderView", owner: nil, options: nil)!.first as! CustomLoaderView
        v.frames = Defaults.Images.images
        if v.frames.isEmpty, let img = v.loadImageView.image { v.frames = [img] }
        
        v.setupSwapImageViews()
        v.setInitialFrame()
        return v
    }
}

// MARK: - Setup
private extension CustomLoaderView {
    
    func setupSwapImageViews() {
        for iv in [frontImageView, backImageView] {
            iv.translatesAutoresizingMaskIntoConstraints = false
            iv.contentMode = loadImageView.contentMode
            iv.clipsToBounds = loadImageView.clipsToBounds
            loadImageView.addSubview(iv)
            NSLayoutConstraint.activate([
                iv.leadingAnchor.constraint(equalTo: loadImageView.leadingAnchor),
                iv.trailingAnchor.constraint(equalTo: loadImageView.trailingAnchor),
                iv.topAnchor.constraint(equalTo: loadImageView.topAnchor),
                iv.bottomAnchor.constraint(equalTo: loadImageView.bottomAnchor)
            ])
        }
        frontImageView.isHidden = false
        backImageView.isHidden = true
    }
    
    func setInitialFrame() {
        guard let first = frames.first else { return }
        frontImageView.image = first
        backImageView.image = first
    }
}

// MARK: - Sequence
private extension CustomLoaderView {
    func startSequence() {
        guard frames.count > 1 else { return }
        scheduleNext()
    }
    
    func stopSequence() {
        timer?.invalidate()
        timer = nil
    }
    
    func scheduleNext() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: false) { [weak self] _ in
            self?.advance()
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }
    
    func advance() {
        guard frames.count > 1 else { return }
        
        let nextIndex = (currentIndex + 1) % frames.count
        let nextImage = frames[nextIndex]
        
        let fromView = usingFrontOnTop ? frontImageView : backImageView
        let toView   = usingFrontOnTop ? backImageView  : frontImageView
        
        toView.image = nextImage
        toView.isHidden = false
        
        let options: UIView.AnimationOptions = [.showHideTransitionViews, nextDirection.transitionOption]
        
        UIView.transition(from: fromView,
                          to: toView,
                          duration: swapDuration,
                          options: options,
                          completion: { [weak self] _ in
            guard let self else { return }
            self.currentIndex = nextIndex
            self.usingFrontOnTop.toggle()
            self.nextDirection = (self.nextDirection == .side) ? .bottom : .side
            self.scheduleNext()
        })

    }
}
