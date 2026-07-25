//
//  SceneDelegate.swift
//  lengyan
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)
        self.window = window

        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.setupMainUI(window: window)

            // Handle widget deep link on cold launch via connectionOptions
            if let urlContext = connectionOptions.urlContexts.first {
                _ = appDelegate.handleOpenURL(urlContext.url)
            }
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let urlContext = URLContexts.first,
           let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            _ = appDelegate.handleOpenURL(urlContext.url)
        }
    }

    func sceneWillResignActive(_ scene: UIScene) {
        AudioPlayerObserver.shared.saveCurrentProgressImmediately()
        Prefers.shared.persist()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        AudioPlayerObserver.shared.saveCurrentProgressImmediately()
        Prefers.shared.persist()
    }
}
