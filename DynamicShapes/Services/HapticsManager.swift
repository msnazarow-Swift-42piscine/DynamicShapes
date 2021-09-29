//
//  HapticsManager.swift
//  DynamicShapes
//
//  Created by out-nazarov2-ms on 28.09.2021.
//

import UIKit

final class HapticsManager {
    static let shared = HapticsManager()

    private init() {}

    func selectionVirbate() {
        let selectionFeedbackGenerator = UISelectionFeedbackGenerator()
        selectionFeedbackGenerator.prepare()
        selectionFeedbackGenerator.selectionChanged()
    }

    func vibrate(for type: UINotificationFeedbackGenerator.FeedbackType) {
        DispatchQueue.main.async {
            let notificationFeedbackGenerator = UINotificationFeedbackGenerator()
            notificationFeedbackGenerator.prepare()
            notificationFeedbackGenerator.notificationOccurred(type)
        }
    }
}
