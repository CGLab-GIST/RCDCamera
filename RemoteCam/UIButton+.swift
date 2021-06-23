//
//  UIButton+.swift
//  RemoteCam
//
//  Created by 남수김 on 2021/06/23.
//

import UIKit

extension UIButton {
    func setRGBModeButtonUI(textColor: UIColor = .white,
                            bgColor: UIColor = .black,
                            borderColor: UIColor = .white) {
        self.layer.borderWidth = 1
        self.layer.borderColor = borderColor.cgColor
        self.layer.cornerRadius = 8
        self.backgroundColor = bgColor
        self.setTitleColor(textColor, for: .normal)
    }
}
