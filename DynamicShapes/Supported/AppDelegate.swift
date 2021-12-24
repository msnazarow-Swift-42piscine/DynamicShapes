//
//  AppDelegate.swift
//  DynamicShapes
//
//  Created by out-nazarov2-ms on 28.09.2021.
//

import UIKit
import CoreHaptics

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    var supportsHaptics = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        let hapticCapability = CHHapticEngine.capabilitiesForHardware()
        supportsHaptics = hapticCapability.supportsHaptics
        if let window = window {
            window.rootViewController = ViewController()
            window.makeKeyAndVisible()
        }
        return true
    }
}
