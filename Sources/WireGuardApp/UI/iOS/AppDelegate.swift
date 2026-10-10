// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import UIKit
import os.log

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var mainVC: MainViewController?

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Logger.configureGlobal(tagged: "APP", withFilePath: FileManager.logFileURL?.path)

        return true
    }
}

/// Owns the window and main view controller. iOS 27 requires apps built with its SDK to adopt the
/// UIScene lifecycle; the app-delegate-owned window used to be enough.
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    private static let lastDisplayedTunnelKey = "lastDisplayedTunnelName"

    var window: UIWindow?

    private var appDelegate: AppDelegate? {
        return UIApplication.shared.delegate as? AppDelegate
    }

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let mainVC = MainViewController()
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = mainVC
        window.makeKeyAndVisible()
        self.window = window
        appDelegate?.mainVC = mainVC

        if !connectionOptions.urlContexts.isEmpty || connectionOptions.shortcutItem != nil {
            if let url = connectionOptions.urlContexts.first?.url {
                mainVC.importFromDisposableFile(url: url)
            }
            if let shortcutItem = connectionOptions.shortcutItem {
                handle(shortcutItem: shortcutItem)
            }
        } else if let tunnelName = UserDefaults.standard.string(forKey: Self.lastDisplayedTunnelKey) {
            mainVC.showTunnelDetailForTunnel(named: tunnelName, animated: false, shouldToggleStatus: false)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        appDelegate?.mainVC?.importFromDisposableFile(url: url)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        appDelegate?.mainVC?.refreshTunnelConnectionStatuses()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // iOS discards a scene's saved state when the user force-quits, so remember the open tunnel ourselves.
        if let tunnelName = appDelegate?.mainVC?.displayedTunnelName {
            UserDefaults.standard.set(tunnelName, forKey: Self.lastDisplayedTunnelKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.lastDisplayedTunnelKey)
        }
        guard let allTunnelNames = appDelegate?.mainVC?.allTunnelNames() else { return }
        UIApplication.shared.shortcutItems = QuickActionItem.createItems(allTunnelNames: allTunnelNames)
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(handle(shortcutItem: shortcutItem))
    }

    @discardableResult
    private func handle(shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard shortcutItem.type == QuickActionItem.type else { return false }
        appDelegate?.mainVC?.showTunnelDetailForTunnel(named: shortcutItem.localizedTitle, animated: false, shouldToggleStatus: true)
        return true
    }
}
