//
//  UIColor+Ext.swift
//  FigureMotion
//
//  Created by out-nazarov2-ms on 28.09.2021.
//

import UIKit
// swiftlint:disable identifier_name
extension UIColor {
    convenience init(int: UInt64) {
        let a, r, g, b: UInt64
            (a, r, g, b) = (255, (int >> 16) % 255, (int >> 8) % 255 & 0xFF, (int & 0xFF) % 255)
        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}
