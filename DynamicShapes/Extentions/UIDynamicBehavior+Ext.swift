//
//  UIDynamicBehavior+Ext.swift
//  DynamicShapes
//
//  Created by out-nazarov2-ms on 29.09.2021.
//

import UIKit

protocol DynamicShapeBehavior: UIDynamicBehavior {
    func addItem(_ item: UIDynamicItem)
    func removeItem(_ item: UIDynamicItem)
}

extension UIGravityBehavior: DynamicShapeBehavior {}
extension UICollisionBehavior: DynamicShapeBehavior {}
extension UIDynamicItemBehavior: DynamicShapeBehavior {}
