//
//  AppDelegate.swift
//  lengyan
//
//  Created by Xuan on 16/6/14.
//  Copyright © 2016年 xuan. All rights reserved.
//

import UIKit
import UserNotifications
import AVFoundation
import SwiftUI

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Load book data synchronously
        Book.shared.loadDataSyncWithCompletionHandler { () in
            print("Book data loaded on start")
        }
        return true
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        // Load and apply theme using the enhanced design system
        SutraDesignTokens.shared.loadSavedTheme()
        SutraDesignTokens.shared.applyThemeToApp()

        // Setup main UI
        setupMainUI()

        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self

        // 将所有可能涉及 IO 或底层 IPC 通信的非 UI 任务放到后台，坚决不阻塞启动
        DispatchQueue.global(qos: .utility).async {
            // 启动时调度每日提醒（60天，绝对防重复）
            if Prefers.shared.isDailyReminderOn {
                ReminderManager.shared.scheduleDaily()
            }

            // 同步每日经文到 Widget 小组件
            DailyVerseProvider.shared.syncWidgetData()
        }

        return true
    }

    private func setupMainUI() {
        // Create main window
        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window

        // Create and setup the main tab bar controller
        let tabBarController = UITabBarController()
        
        // 强制禁用 iOS 18 iPadOS 顶部悬浮 TabBar
        // 通过重写 horizontalSizeClass 为 compact，系统会回退使用经典的底部 TabBar
        if #available(iOS 18.0, *) {
            tabBarController.traitOverrides.horizontalSizeClass = .compact
        }
        
        // Set global tint color to affect system controls like iOS 18 floating Tab Bar
        window.tintColor = SutraDesignTokens.shared.color(for: .primary)
        tabBarController.tabBar.tintColor = SutraDesignTokens.shared.color(for: .primary)
        
        setupTabs(for: tabBarController)
        configureAppearance()

        window.rootViewController = tabBarController
        window.makeKeyAndVisible()

        // 监听沉浸模式的 TabBar 隐藏请求
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ToggleTabBar"), object: nil, queue: .main) { notification in
            if let isHidden = notification.userInfo?["isHidden"] as? Bool {
                UIView.animate(withDuration: 0.6) {
                    if #available(iOS 18.0, *) {
                        tabBarController.setTabBarHidden(isHidden, animated: true)
                    } else {
                        tabBarController.tabBar.isHidden = isHidden
                        tabBarController.view.setNeedsLayout()
                    }
                }
            }
        }
    }

    private func setupTabs(for tabBarController: UITabBarController) {
        // Setup Reading Tab
        let sutraFrontVC = SutraFrontViewController()
        let readingNavController = UINavigationController(rootViewController: sutraFrontVC)
        readingNavController.view.backgroundColor = SutraDesignTokens.shared.color(for: .background) // 消除 push 转场白色闪现
        readingNavController.tabBarItem = UITabBarItem(
            title: NSLocalizedString("reading_tab_title", comment: ""),
            image: UIImage(systemName: "book")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)),
            selectedImage: UIImage(systemName: "book.fill")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .medium))
        )

        // Setup Listening Tab — 听经是最高优先级的学习方式
        let modernAudioPlayer = ModernAudioPlayerView()
        let audioHostingController = UIHostingController(rootView: modernAudioPlayer)
        let listeningNavController = UINavigationController(rootViewController: audioHostingController)
        listeningNavController.tabBarItem = UITabBarItem(
            title: NSLocalizedString("media_tab_title", comment: ""),
            image: UIImage(systemName: "headphones")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)),
            selectedImage: UIImage(systemName: "headphones.fill")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .medium))
        )
        listeningNavController.navigationBar.isHidden = true

        // Setup Favorites Tab
        let modernFavorites = ModernFavoritesView()
        let favoritesHostingController = FavoritesHostingController(rootView: modernFavorites)
        let favoritesNavController = UINavigationController(rootViewController: favoritesHostingController)
        favoritesNavController.tabBarItem = UITabBarItem(
            title: NSLocalizedString("star_tab_title", comment: ""),
            image: UIImage(systemName: "heart")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)),
            selectedImage: UIImage(systemName: "heart.fill")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .medium))
        )
        favoritesNavController.navigationBar.isHidden = true

        // Setup Settings Tab
        let settingsView = ModernSettingsView()
        let settingsHostingController = NavBarHostingController(rootView: settingsView, showsNavBar: false)
        let settingsNavController = UINavigationController(rootViewController: settingsHostingController)
        settingsNavController.tabBarItem = UITabBarItem(
            title: NSLocalizedString("settings_tab_title", comment: ""),
            image: UIImage(systemName: "gearshape")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)),
            selectedImage: UIImage(systemName: "gearshape.fill")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .medium))
        )
        settingsNavController.navigationBar.isHidden = true

        tabBarController.viewControllers = [readingNavController, listeningNavController, favoritesNavController, settingsNavController]
        tabBarController.selectedIndex = 0
    }

    private func configureAppearance() {
        // Apply Zen design system
        setupZenNavigationAppearance()
        setupZenTabBarAppearance()
    }

    private func setupZenNavigationAppearance() {
        // Enhanced Zen navigation appearance
        let navigationBarAppearance = UINavigationBarAppearance()

        // Create zen-inspired colors
        let designSystem = SutraDesignTokens.shared

        navigationBarAppearance.configureWithTransparentBackground()
        navigationBarAppearance.backgroundColor = designSystem.color(for: .background)
        navigationBarAppearance.shadowColor = .clear
        navigationBarAppearance.shadowImage = UIImage()

        // Set typography for zen aesthetics
        let largeTitleFont = SutraTypographySystem().uiFont(for: .uiLargeTitle, weight: .regular)
        let titleFont = SutraTypographySystem().uiFont(for: .uiHeading, weight: .regular)

        navigationBarAppearance.largeTitleTextAttributes = [
            .font: largeTitleFont,
            .foregroundColor: designSystem.color(for: .textPrimary)
        ]

        navigationBarAppearance.titleTextAttributes = [
            .font: titleFont,
            .foregroundColor: designSystem.color(for: .textPrimary)
        ]

        // Apply appearance globally
        UINavigationBar.appearance().standardAppearance = navigationBarAppearance
        UINavigationBar.appearance().compactAppearance = navigationBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationBarAppearance

        UINavigationBar.appearance().isTranslucent = false
        UINavigationBar.appearance().backgroundColor = designSystem.color(for: .background)
    }

    private func setupZenTabBarAppearance() {
        // Enhanced Zen TabBar styling with better visual hierarchy
        let appearance = UITabBarAppearance()

        // Create zen-inspired colors
        let designSystem = SutraDesignTokens.shared

        // Background with subtle zen transparency
        appearance.backgroundColor = designSystem.color(for: .background)
        appearance.backgroundEffect = UIBlurEffect(style: .light)

        // 微妙金色分隔线
        appearance.shadowColor = designSystem.color(for: .decorativeGold).withAlphaComponent(0.15)
        appearance.shadowImage = UIImage()

        // TabBar 文字 — 小巧协调，与图标同色
        let tabBarFont = UIFont.systemFont(ofSize: 10, weight: .thin)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .font: tabBarFont,
            .foregroundColor: designSystem.color(for: .textTertiary)
        ]

        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .font: tabBarFont,
            .foregroundColor: designSystem.color(for: .primary)
        ]

        // Increase vertical position offset to prevent text-icon overlap
        appearance.stackedLayoutAppearance.normal.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 3)
        appearance.stackedLayoutAppearance.selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 3)

        // Icon appearance with zen colors
        appearance.stackedLayoutAppearance.normal.iconColor = designSystem.color(for: .textTertiary)
        appearance.stackedLayoutAppearance.selected.iconColor = designSystem.color(for: .primary)

        // Compact appearance for smaller devices
        appearance.compactInlineLayoutAppearance.normal.titleTextAttributes = appearance.stackedLayoutAppearance.normal.titleTextAttributes
        appearance.compactInlineLayoutAppearance.selected.titleTextAttributes = appearance.stackedLayoutAppearance.selected.titleTextAttributes
        appearance.compactInlineLayoutAppearance.normal.iconColor = appearance.stackedLayoutAppearance.normal.iconColor
        appearance.compactInlineLayoutAppearance.selected.iconColor = appearance.stackedLayoutAppearance.selected.iconColor

        // Inline appearance for newer iOS versions
        if #available(iOS 15.0, *) {
            appearance.inlineLayoutAppearance.normal.titleTextAttributes = appearance.stackedLayoutAppearance.normal.titleTextAttributes
            appearance.inlineLayoutAppearance.selected.titleTextAttributes = appearance.stackedLayoutAppearance.selected.titleTextAttributes
            appearance.inlineLayoutAppearance.normal.iconColor = appearance.stackedLayoutAppearance.normal.iconColor
            appearance.inlineLayoutAppearance.selected.iconColor = appearance.stackedLayoutAppearance.selected.iconColor
        }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        // Ensure consistent translucency
        UITabBar.appearance().isTranslucent = true
    }

    func applicationWillTerminate(_ application: UIApplication) {
        Prefers.shared.persist()
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let path = response.notification.request.content.userInfo["path"] as? String
        if let path = path {
            openNotificationItem(path: path)
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 静默展示，不打断用户
        completionHandler([])
    }

    func openNotificationItem(path: String) {
        while !Book.shared.loaded {
        }
        let root = window?.rootViewController as! UITabBarController
        root.selectedIndex = 0  // 读经 Tab
        guard let nav = root.selectedViewController as? UINavigationController else { return }
        nav.popToRootViewController(animated: false)
        (nav.topViewController as? SutraFrontViewController)?.openSutraOfPath(path: path)
    }

    // MARK: - Widget Deep Link

    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        // 处理 Widget 深链：lengyan://verse?path=/A2/B1/...
        guard url.scheme == "lengyan", url.host == "verse" else { return false }

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let pathItem = components.queryItems?.first(where: { $0.name == "path" }),
           let path = pathItem.value, !path.isEmpty {
            openNotificationItem(path: path)
            return true
        }
        return false
    }

}
