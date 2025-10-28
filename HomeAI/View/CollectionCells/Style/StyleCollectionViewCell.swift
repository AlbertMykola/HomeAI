//
//  StyleCollectionViewCell.swift
//  HomeAI
//
//  Created by Mykola Albert on 11.09.2025.
//

import UIKit

final class StyleCollectionViewCell: UICollectionViewCell {

    @IBOutlet private weak var styleImageView: UIImageView!
    @IBOutlet private weak var bottomBarView: LiquidGlassView!
    @IBOutlet private weak var nameLabel: CustomFontLabel!
    @IBOutlet private weak var containerView: UIView!

    private let imageService = ImageStorageService()

    override var isSelected: Bool {
        didSet {
            if isSelected {
                containerView.borderWidth = 1.5
                containerView.borderColor = UIColor.systemGreen
            } else {
                containerView.borderWidth = 0
                containerView.borderColor = UIColor.clear
            }
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        containerView.borderColor = UIColor.clear
    }

    override func prepareForReuse() {
        super.prepareForReuse()
  
        styleImageView.image = nil
        layer.borderWidth = 0
        layer.borderColor = UIColor.clear.cgColor
    }

    func config(style: StyleCellModel) {
        nameLabel.text = style.name
        styleImageView.image = UIImage(named: style.imageName)
    }
}
