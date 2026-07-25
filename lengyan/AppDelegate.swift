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

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 强制 -AppleLanguages / -AppleLocale launch arguments 生效
        // （iOS 8+ 后系统不再自动应用这些参数，必须主动写入 NSUserDefaults
        //  否则 NSLocalizedString / Bundle.main.preferredLocalizations 不切换语言，
        //  导致 fastlane snapshot / UITest 中 zh-Hant 等本地化测试失效）
        applyLanguageLaunchArgumentsIfNeeded()
        applySnapshotLaunchArgumentsIfNeeded()

        // Load the bundled reading corpus synchronously before constructing UI.
        Book.shared.loadDataSyncWithCompletionHandler { result in
            switch result {
            case .success:
                print("Book data loaded on start")
            case let .failure(error):
                // Resource-level diagnostics only; never log scripture or user data.
                print("⚠️ Book data unavailable on start: \(error.localizedDescription)")
            }
        }
        return true
    }

    /// 读取 -AppleLanguages / -AppleLocale launch arguments，写入 NSUserDefaults，
    /// 让 Bundle.main.preferredLocalizations / NSLocalizedString 在本次启动就生效。
    private func applyLanguageLaunchArgumentsIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-AppleLanguages"), i + 1 < args.count {
            let raw = args[i + 1].trimmingCharacters(in: CharacterSet(charactersIn: "()\"' "))
            // 支持形如 (zh-Hant, en) 的列表，但 fastlane 通常只传单个
            let langs = raw.split(separator: ",").map { $0.trimmingCharacters(in: CharacterSet(charactersIn: " \"'()")) }
            UserDefaults.standard.set(langs, forKey: "AppleLanguages")
        }
        if let i = args.firstIndex(of: "-AppleLocale"), i + 1 < args.count {
            let locale = args[i + 1].trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            UserDefaults.standard.set([locale], forKey: "AppleLocales")
        }
    }

    private func applySnapshotLaunchArgumentsIfNeeded() {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("--snapshot-mode") else { return }

        if args.contains("--snapshot-reminder-on") {
            UserDefaults.standard.set(true, forKey: "dailyReminderOn")
            UserDefaults.standard.set(true, forKey: "hasSeenDailyReminderPrompt")
        }
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Load and apply theme using the enhanced design system
        SutraDesignTokens.shared.loadSavedTheme()
        SutraDesignTokens.shared.applyThemeToApp()

        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self
        registerNotificationCategory()

        // 在用户可交互前从主线程捕获一次稳定快照，再由串行后台队列准备
        // 未来 60 天的小组件数据。内容没有变化时不会重复写入或刷新。
        DailyVerseProvider.shared.syncWidgetDataAsync()

        DispatchQueue.global(qos: .background).async {
            if Prefers.shared.isDailyReminderOn {
                // 启动时调度每日提醒（60天，绝对防重复）
                ReminderManager.shared.scheduleDaily()
            }
        }

        return true
    }

    // MARK: - UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {}

    func setupMainUI(window: UIWindow) {
        let backgroundColor = SutraDesignTokens.shared.color(for: .background)
        window.backgroundColor = backgroundColor
        window.overrideUserInterfaceStyle = SutraDesignTokens.shared.interfaceStyle(for: SutraDesignTokens.shared.currentTheme)
        self.window = window

        // Create and setup the main tab bar controller
        let tabBarController = UITabBarController()
        tabBarController.view.backgroundColor = backgroundColor
        
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
        let iconConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let selectedIconConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)

        // Setup Reading Tab
        let sutraFrontVC = SutraFrontViewController()
        let readingNavController = SutraNavigationController(rootViewController: sutraFrontVC)
        readingNavController.view.backgroundColor = SutraDesignTokens.shared.color(for: .background) // 消除 push 转场白色闪现
        readingNavController.tabBarItem = UITabBarItem(
            title: L10n.str("reading_tab_title"),
            image: UIImage(systemName: "book")?.withConfiguration(iconConfiguration),
            selectedImage: UIImage(systemName: "book.fill")?.withConfiguration(selectedIconConfiguration)
        )

        // Setup Listening Tab — 听经是最高优先级的学习方式
        let modernAudioPlayer = ModernAudioPlayerView()
        let audioHostingController = UIHostingController(rootView: modernAudioPlayer)
        let listeningNavController = SutraNavigationController(rootViewController: audioHostingController)
        listeningNavController.tabBarItem = UITabBarItem(
            title: L10n.str("media_tab_title"),
            image: UIImage(systemName: "headphones")?.withConfiguration(iconConfiguration),
            selectedImage: UIImage(systemName: "headphones.fill")?.withConfiguration(selectedIconConfiguration)
        )
        listeningNavController.navigationBar.isHidden = true

        // Setup Favorites Tab
        let modernFavorites = ModernFavoritesView()
        let favoritesHostingController = FavoritesHostingController(rootView: modernFavorites)
        let favoritesNavController = SutraNavigationController(rootViewController: favoritesHostingController)
        favoritesNavController.tabBarItem = UITabBarItem(
            title: L10n.str("star_tab_title"),
            image: UIImage(systemName: "heart")?.withConfiguration(iconConfiguration),
            selectedImage: UIImage(systemName: "heart.fill")?.withConfiguration(selectedIconConfiguration)
        )
        favoritesNavController.navigationBar.isHidden = true

        // Setup Settings Tab
        let settingsView = ModernSettingsView()
        let settingsHostingController = NavBarHostingController(rootView: settingsView, showsNavBar: false)
        let settingsNavController = SutraNavigationController(rootViewController: settingsHostingController)
        settingsNavController.tabBarItem = UITabBarItem(
            title: L10n.str("settings_tab_title"),
            image: UIImage(systemName: "gearshape")?.withConfiguration(iconConfiguration),
            selectedImage: UIImage(systemName: "gearshape.fill")?.withConfiguration(selectedIconConfiguration)
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
        let designSystem = SutraDesignTokens.shared
        let appearance = designSystem.makeTabBarAppearance()

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = designSystem.color(for: .primary)
        UITabBar.appearance().unselectedItemTintColor = designSystem.color(for: .textSecondary)
        UITabBar.appearance().barTintColor = designSystem.color(for: .tabBar)
        UITabBar.appearance().backgroundColor = designSystem.color(for: .tabBar)

        // Opaque material keeps footer labels readable over long scripture content.
        UITabBar.appearance().isTranslucent = false
    }

    func applicationWillTerminate(_ application: UIApplication) {
        Prefers.shared.persist()
    }

    private func registerNotificationCategory() {
        let playAction = UNNotificationAction(
            identifier: "PLAY_ACTION",
            title: Book.shared.isSimplifiedChinese ? "🔊 播放此卷听经" : "🔊 播放此卷聽經",
            options: [] // Run in background
        )
        let category = UNNotificationCategory(
            identifier: "DAILY_SUTRA_CATEGORY",
            actions: [playAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let path = response.notification.request.content.userInfo["path"] as? String
        
        if response.actionIdentifier == "PLAY_ACTION" {
            if let path = path, let chapter = Book.shared.getChapterOfPath(path) {
                AudioManager.shared.playChapter(chapter: chapter)
            }
            completionHandler()
            return
        }
        
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
        if Book.shared.loaded {
            guard Book.shared.isValidResumePath(path) else { return }
            navigateToSutra(path: path)
            return
        }

        // A failed initial load is a packaging problem, not a condition that
        // improves by polling for five seconds. Retry explicitly once and only
        // navigate when the corpus is usable.
        Book.shared.retryLoading { [weak self] result in
            guard case .success = result,
                  Book.shared.isValidResumePath(path) else { return }
            self?.navigateToSutra(path: path)
        }
    }

    /// 切到读经 Tab 并打开指定经文（必须在主线程）。
    private func navigateToSutra(path: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let root = self.window?.rootViewController as? UITabBarController else { return }
            root.selectedIndex = 0  // 读经 Tab
            guard let nav = root.selectedViewController as? UINavigationController else { return }
            nav.popToRootViewController(animated: false)
            (nav.topViewController as? SutraFrontViewController)?.openSutraOfPath(path: path)
        }
    }

    // MARK: - Widget Deep Link

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return handleOpenURL(url)
    }

    @discardableResult
    func handleOpenURL(_ url: URL) -> Bool {
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
