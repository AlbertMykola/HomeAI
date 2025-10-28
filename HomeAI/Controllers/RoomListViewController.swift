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

import UIKit

class RoomListViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, PageStepDelegate, PromptManagerHolder {

    @IBOutlet weak private var collectionView: UICollectionView!
    
    var selectedRoom: DesignOption?
    var promptManager: PromptManager?

    private var selectedIndexPath: IndexPath?
    private let amplitude = AmplitudeService.shared

    var completion: (() -> Void)?
    var canProceedToNextStep: Bool { selectedRoom != nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        amplitude.logEvent(.showRoomList)
        config()
    }

    private func config() {
        title = Defaults.Text.headline
        
        configCollection()
    }
    
    private func configCollection() {
        collectionView.register(UINib(nibName: "RoomCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "RoomCollectionViewCell")

        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.allowsMultipleSelection = false
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 150, right: 0)
        
        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.minimumInteritemSpacing = 8
            layout.minimumLineSpacing = 8
            layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        InteriorType.allCases.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "RoomCollectionViewCell", for: indexPath) as! RoomCollectionViewCell
        let room = InteriorType.allCases[indexPath.item]
        let isSelected = (indexPath == selectedIndexPath)
        promptManager?.updateRoom(room)
        cell.configure(room: room, isSelected: isSelected)

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let previousSelected = selectedIndexPath
        selectedIndexPath = indexPath
        amplitude.logEvent(.chooseRoom(room: InteriorType.allCases[indexPath.item].name))
        var pathsToReload: [IndexPath] = [indexPath]
        if let previous = previousSelected, previous != indexPath {
            pathsToReload.append(previous)
        }
        collectionView.reloadItems(at: pathsToReload)

        completion?()
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let layout = collectionViewLayout as! UICollectionViewFlowLayout
        let itemsPerRow: CGFloat = 3
        let totalPadding = layout.sectionInset.left + layout.sectionInset.right + layout.minimumInteritemSpacing * (itemsPerRow - 1)
        let isPad = UIDevice.current.userInterfaceIdiom == .pad

        let availableWidth = isPad ? collectionView.bounds.width - totalPadding.scaledByWidth() : collectionView.bounds.width - totalPadding
        let width = floor(availableWidth / itemsPerRow)
        return CGSize(width: width, height: width)
    }
}
