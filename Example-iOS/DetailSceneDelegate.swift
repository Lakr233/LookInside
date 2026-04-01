//
//  DetailSceneDelegate.swift
//  Example-iOS
//
//  Created by JH on 2026/4/1.
//  Copyright © 2026 hughkli. All rights reserved.
//

import UIKit

class DetailSceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        windowScene.title = "Detail Scene"

        if let sizeRestrictions = windowScene.sizeRestrictions {
            sizeRestrictions.minimumSize = CGSize(width: 320, height: 480)
            sizeRestrictions.maximumSize = CGSize(width: 600, height: 900)
        }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UINavigationController(rootViewController: DetailViewController())
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
