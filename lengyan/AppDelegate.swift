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
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    internal var lastScheduledNotificationFireDay: Int?
    internal static let MAX_SCHEDULED_NOTIFICATIONS: Int = 7

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

        // Handle notification if app was launched from notification
        let notification = launchOptions?[UIApplicationLaunchOptionsKey.localNotification] as? UILocalNotification
        if notification != nil {
            DispatchQueue.global().async {
                for _ in (0..<100) {
                    if Book.shared.loaded {
                        break
                    }
                    Thread.sleep(forTimeInterval: 0.1)
                }
                DispatchQueue.main.async {
                    self.openNotificationItem(path: notification!.userInfo?["path"] as! String)
                }
            }
        }

        return true
    }

    private func setupMainUI() {
        // Create main window
        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window

        // Create and setup the main tab bar controller
        let tabBarController = UITabBarController()
        setupTabs(for: tabBarController)
        configureAppearance()

        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
    }

    private func setupTabs(for tabBarController: UITabBarController) {
        // Setup Reading Tab
        let sutraFrontVC = SutraFrontViewController()
        let readingNavController = UINavigationController(rootViewController: sutraFrontVC)
        readingNavController.tabBarItem = UITabBarItem(
            title: NSLocalizedString("reading_tab_title", comment: ""),
            image: UIImage(named: "book"),
            selectedImage: UIImage(named: "book")
        )

        // Setup Listening Tab with SwiftUI
        let modernAudioPlayer = ModernAudioPlayerView()
        let audioHostingController = UIHostingController(rootView: modernAudioPlayer)
        let listeningNavController = UINavigationController(rootViewController: audioHostingController)
        listeningNavController.tabBarItem = UITabBarItem(
            title: NSLocalizedString("media_tab_title", comment: ""),
            image: UIImage(systemName: "music.note.list")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)),
            selectedImage: UIImage(systemName: "music.note.list")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .medium))
        )
        // Hide navigation bar for cleaner SwiftUI interface
        listeningNavController.navigationBar.isHidden = true

        // Setup Favorites Tab with SwiftUI
        let modernFavorites = ModernFavoritesView()
        let favoritesHostingController = UIHostingController(rootView: modernFavorites)
        let favoritesNavController = UINavigationController(rootViewController: favoritesHostingController)
        favoritesNavController.tabBarItem = UITabBarItem(
            title: NSLocalizedString("star_tab_title", comment: ""),
            image: UIImage(systemName: "heart")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)),
            selectedImage: UIImage(systemName: "heart.fill")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .medium))
        )
        // Hide navigation bar for cleaner SwiftUI interface
        favoritesNavController.navigationBar.isHidden = true

        tabBarController.viewControllers = [readingNavController, listeningNavController, favoritesNavController]
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

        navigationBarAppearance.configureWithOpaqueBackground()
        navigationBarAppearance.backgroundColor = designSystem.color(for: .navigationBar)
        navigationBarAppearance.shadowColor = designSystem.color(for: .decorativeGold).withAlphaComponent(0.15)
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
        UINavigationBar.appearance().backgroundColor = designSystem.color(for: .navigationBar)
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

        // TabBar 翠竹绿选中 + 淡雅未选中
        appearance.selectionIndicatorTintColor = designSystem.color(for: .primary)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .font: SutraTypographySystem().uiFont(for: .uiCaption, weight: .regular),
            .foregroundColor: designSystem.color(for: .textTertiary)
        ]

        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .font: SutraTypographySystem().uiFont(for: .uiCaption, weight: .medium),
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

    @available(iOS 10.0, *)
    func scheduleItem(path:String) ->Bool{
        var isLeaf = false;
        let i = KEY_PATHS.index(where:{$0==path})
        if i == KEY_PATHS.count - 1 {
            isLeaf = true;
        } else {
            let next = KEY_PATHS[KEY_PATHS.index(after: i!)]
            isLeaf = !next.hasPrefix(path)
        }
        if isLeaf {
            let content = UNMutableNotificationContent()
            let item = Book.shared.itemOfPath(path)
//            content.title =  (item["name"] as? String ?? "楞严经")
            content.body = Book.shared.getSutra(item);
            content.userInfo = ["path":path];
            // Configure the trigger at 8pm
            var dateInfo = DateComponents()
            dateInfo.hour = 7
            dateInfo.minute = 0
            if lastScheduledNotificationFireDay == nil {
                let today = NSCalendar.current.component(.day, from: Date());
                lastScheduledNotificationFireDay =  today
            }
            if lastScheduledNotificationFireDay! >= AppDelegate.MAX_SCHEDULED_NOTIFICATIONS  {
                dateInfo.day = 1
            } else {
                dateInfo.day = lastScheduledNotificationFireDay! + 1
            }
            

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateInfo, repeats: false)
            let request = UNNotificationRequest(identifier: "SutraReminder\(dateInfo.day!)", content: content, trigger: trigger)
            
            print("schedule notification:\(path) at day \(dateInfo.day!), title: \(content.title)");
           
            UNUserNotificationCenter.current().add(request, withCompletionHandler: { (error:Error?) in
                print(error?.localizedDescription ?? "")
            })
            lastScheduledNotificationFireDay = dateInfo.day;
            return true
        } else {
            return false;
        }
    }
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        Prefers.shared.persist()
    }
    
    func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
        print("did received notification on app state: \(application.applicationState == .active)")
        if application.applicationState != .active && notification.fireDate!.timeIntervalSinceNow < -0.2 {
            openNotificationItem(path: notification.userInfo?["path"] as! String)
        }
    }
    func openNotificationItem(path:String){
        while !Book.shared.loaded {
            
        }
        let root = window?.rootViewController as! UITabBarController
        root.selectedIndex = 1
        (root.selectedViewController as!UINavigationController).popToRootViewController(animated: false)
        
        ((root.selectedViewController as! UINavigationController).topViewController as! SutraFrontViewController).openSutraOfPath(path: path)

    }

}
