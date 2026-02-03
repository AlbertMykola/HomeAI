//
//  StyleCellModel.swift
//  HomeAI
//
//  Created by Mykola Albert on 11.09.2025.
//

import Foundation

struct StyleCellModel {
    let name: String
    let imageName: String
    let isNew: Bool
    
    init(name: String, imageName: String, isNew: Bool = false) {
        self.name = name
        self.imageName = imageName
        self.isNew = isNew
    }
}
