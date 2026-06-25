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

        // Load book data synchronously
        Book.shared.loadDataSyncWithCompletionHandler { () in
            print("Book data loaded on start")
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

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // Load and apply theme using the enhanced design system
        SutraDesignTokens.shared.loadSavedTheme()
        SutraDesignTokens.shared.applyThemeToApp()

        // Setup main UI
        setupMainUI()

        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self
        registerNotificationCategory()

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
            title: L10n.str("reading_tab_title"),
            image: UIImage(systemName: "book")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)),
            selectedImage: UIImage(systemName: "book.fill")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .medium))
        )

        // Setup Listening Tab — 听经是最高优先级的学习方式
        let modernAudioPlayer = ModernAudioPlayerView()
        let audioHostingController = UIHostingController(rootView: modernAudioPlayer)
        let listeningNavController = UINavigationController(rootViewController: audioHostingController)
        listeningNavController.tabBarItem = UITabBarItem(
            title: L10n.str("media_tab_title"),
            image: UIImage(systemName: "headphones")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)),
            selectedImage: UIImage(systemName: "headphones.fill")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .medium))
        )
        listeningNavController.navigationBar.isHidden = true

        // Setup Favorites Tab
        let modernFavorites = ModernFavoritesView()
        let favoritesHostingController = FavoritesHostingController(rootView: modernFavorites)
        let favoritesNavController = UINavigationController(rootViewController: favoritesHostingController)
        favoritesNavController.tabBarItem = UITabBarItem(
            title: L10n.str("star_tab_title"),
            image: UIImage(systemName: "heart")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)),
            selectedImage: UIImage(systemName: "heart.fill")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .medium))
        )
        favoritesNavController.navigationBar.isHidden = true

        // Setup Settings Tab
        let settingsView = ModernSettingsView()
        let settingsHostingController = NavBarHostingController(rootView: settingsView, showsNavBar: false)
        let settingsNavController = UINavigationController(rootViewController: settingsHostingController)
        settingsNavController.tabBarItem = UITabBarItem(
            title: L10n.str("settings_tab_title"),
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
        // 书库在 didFinishLaunching 里已同步加载完毕（loadDataSyncWithCompletionHandler
        // 阻塞至读完 5 个 JSON 并置 loaded=true），故此处 loaded 几乎恒为 true。
        // 仍做防御性等待：若未来加载改为异步，这里不会退化为忙等死锁。
        openItemWhenBookReady(path: path)
    }

    /// 等待 Book.shared.loaded 后切主线程跳转；含超时保护避免任何死锁可能。
    private func openItemWhenBookReady(path: String, attempt: Int = 0) {
        if Book.shared.loaded {
            navigateToSutra(path: path)
            return
        }
        // 超时保护：每 0.1s 轮询一次，最多 50 次 ≈ 5 秒。
        // 超时后直接跳转——push VC 本身不读数据，实际取数在后续页面，
        // 且书库设计为必须加载（loadDataSync 已在启动同步完成），此分支理论上不可达。
        if attempt >= 50 {
            navigateToSutra(path: path)
            return
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.openItemWhenBookReady(path: path, attempt: attempt + 1)
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
