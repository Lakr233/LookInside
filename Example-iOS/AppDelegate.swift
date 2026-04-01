//
//  AppDelegate.swift
//  Example-iOS
//
//  Created by JH on 2026/3/31.
//  Copyright © 2026 hughkli. All rights reserved.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let userActivity = options.userActivities.first {
            switch userActivity.activityType {
            case "detail":
                return UISceneConfiguration(name: "Detail", sessionRole: connectingSceneSession.role)
            case "settings":
                return UISceneConfiguration(name: "Settings", sessionRole: connectingSceneSession.role)
            default:
                break
            }
        }
        return UISceneConfiguration(name: "Main", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
    }
}
