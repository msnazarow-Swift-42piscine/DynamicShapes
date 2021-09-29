//
//  ShapeView.swift
//  DynamicShapes
//
//  Created by out-nazarov2-ms on 28.09.2021.
//

import UIKit

class ShapeView: UIView {
    enum Shape: Int, CaseIterable {
        case ellipse = 0
        case rectangle
    }

    let shape: Shape

    override var collisionBoundsType: UIDynamicItemCollisionBoundsType {
        switch shape {
        case .ellipse:
            return .ellipse
        case .rectangle:
            return .rectangle
        }
    }

    init(shape: Shape, frame: CGRect, color: UIColor) {
        self.shape = shape
        super.init(frame: frame)
        layer.masksToBounds = true
        clipsToBounds = true
        backgroundColor = color
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        switch shape {
        case .ellipse:
            layer.cornerRadius = 0.5 * layer.bounds.width
        default:
            break
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
