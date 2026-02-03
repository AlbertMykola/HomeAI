//
//  PremiumCollectionCell.swift
//  HomeAI
//
//  Created by Mykola Albert on 18.09.2025.
//

import UIKit

class PremiumCollectionCell: UICollectionViewCell {

    @IBOutlet weak private var imageView: UIImageView!
    
    func configure(image: UIImage) {
        DispatchQueue.main.async { [weak self] in
            self?.imageView.image = image
        }
    }
}
