//
//  RoomListViewController.swift
//  HomeAI
//
//  Created by Mykola Albert on 10.09.2025.
//

import UIKit

private struct Defaults {
    struct Text {
        static let headline = "Choose Room".localized
    }
}

class RoomListViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, PageStepDelegate, PromptManagerHolder {

    @IBOutlet weak private var collectionView: UICollectionView!
    
    var promptManager: GemeniPromptManager?

    private var selectedIndexPath: IndexPath?
    private let amplitude = AmplitudeService.shared

    var completion: (() -> Void)?
    var canProceedToNextStep: Bool { selectedIndexPath != nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        amplitude.logEvent(.showRoomList)
        config()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.applyPageFlowBottomInset(in: view)
    }

    private func config() {
        navigationItem.title = nil
        
        configCollection()
    }
    
    private func configCollection() {
        collectionView.register(UINib(nibName: "RoomCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "RoomCollectionViewCell")

        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.allowsMultipleSelection = false
        
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.minimumInteritemSpacing = 8
            layout.minimumLineSpacing = 8
            layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        }
        
        collectionView.applyPageFlowBottomInset(in: view)
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        InteriorType.allCases.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "RoomCollectionViewCell", for: indexPath) as? RoomCollectionViewCell else {
            return UICollectionViewCell()
        }
        guard let room = InteriorType.allCases[safe: indexPath.item] else { return cell }
        let isSelected = (indexPath == selectedIndexPath)
        cell.configure(room: room, isSelected: isSelected)

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        hapticVibration()
        let previousSelected = selectedIndexPath
        selectedIndexPath = indexPath
        guard let room = InteriorType.allCases[safe: indexPath.item] else { return }
        promptManager?.updateRoom(room)
        amplitude.logEvent(.chooseRoom(room: room.name))
        var pathsToReload: [IndexPath] = [indexPath]
        if let previous = previousSelected, previous != indexPath {
            pathsToReload.append(previous)
        }
        collectionView.reloadItems(at: pathsToReload)

        completion?()
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        guard let layout = collectionViewLayout as? UICollectionViewFlowLayout else { return .zero }
        let itemsPerRow: CGFloat = 3
        let totalPadding = layout.sectionInset.left + layout.sectionInset.right + layout.minimumInteritemSpacing * (itemsPerRow - 1)
        let isPad = UIDevice.current.userInterfaceIdiom == .pad

        let availableWidth = isPad ? collectionView.bounds.width - totalPadding.scaledByWidth() : collectionView.bounds.width - totalPadding
        let width = floor(availableWidth / itemsPerRow)
        return CGSize(width: width, height: width)
    }
}
