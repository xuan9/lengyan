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

    internal var lastScheduledNotificationFireDay: Int?;
    internal static let MAX_SCHEDULED_NOTIFICATIONS:Int = 7;
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        Book.shared.loadDataSyncWithCompletionHandler { () in
            print("Book data loaded on start")
        }
        return true
    }
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        // Initialize Zen Temple Serenity Design System
        SutraThemeManager.shared.loadSavedTheme()

        // Create programmatic UI with enhanced design system
        setupProgrammaticUI()

        let notification = launchOptions?[UIApplicationLaunchOptionsKey.localNotification] as? UILocalNotification

        if notification != nil {
            DispatchQueue.global().async {
                for _ in (0..<100) {
                    if Book.shared.loaded {
                        break;
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

    private func setupProgrammaticUI() {
        // Apply comprehensive Zen Temple Serenity design system
        SutraThemeManager.shared.loadSavedTheme()
        setupZenNavigationAppearance()
        setupZenTabBarAppearance()

        let window = UIWindow(frame: UIScreen.main.bounds)
        self.window = window

        // Create Tab Bar Controller
        let tabBarController = UITabBarController()

        // Setup Reading Tab
        let sutraFrontVC = SutraFrontViewController()
        let readingNavController = UINavigationController(rootViewController: sutraFrontVC)
        readingNavController.tabBarItem = UITabBarItem(
            title: "閱讀",
            image: UIImage(named: "book"),
            selectedImage: UIImage(named: "book")
        )

        // Setup Listening Tab with SwiftUI
        let modernAudioPlayer = ModernAudioPlayerView()
        let audioHostingController = UIHostingController(rootView: modernAudioPlayer)
        let listeningNavController = UINavigationController(rootViewController: audioHostingController)
        listeningNavController.tabBarItem = UITabBarItem(
            title: "聽經",
            image: UIImage(named: "ic_library_music"),
            selectedImage: UIImage(named: "ic_library_music")
        )

        // Setup Favorites Tab with SwiftUI
        let modernFavorites = ModernFavoritesView()
        let favoritesHostingController = UIHostingController(rootView: modernFavorites)
        let favoritesNavController = UINavigationController(rootViewController: favoritesHostingController)
        favoritesNavController.tabBarItem = UITabBarItem(
            title: "收藏",
            image: UIImage(named: "baseline_star_black_24pt"),
            selectedImage: UIImage(named: "baseline_star_black_24pt")
        )

        // Configure Tab Bar Appearance
        tabBarController.tabBar.isTranslucent = false

        // Set View Controllers
        tabBarController.viewControllers = [
            readingNavController,
            listeningNavController,
            favoritesNavController
        ]

        // Setup enhanced design will be called in viewDidLoad

        // Set Root View Controller
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
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

    // MARK: - Zen Temple Serenity Design System
    private func setupZenNavigationAppearance() {
        // Apply design system to navigation bars
        UINavigationBar.appearance().applySutraDesignSystem()
    }

    private func setupZenTabBarAppearance() {
        let theme = SutraThemeManager.shared.currentTheme

        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = SutraColors.Semantic.surface(theme: theme)
            appearance.shadowColor = SutraColors.Semantic.divider(theme: theme)
            appearance.shadowImage = UIImage()

            // Zen tab item styling with design system typography
            let normalFont = UIFont.sutraFont(style: SutraTypography.TextStyle.caption)
            let selectedFont = UIFont.sutraFont(style: SutraTypography.TextStyle.caption)

            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .font: normalFont,
                .foregroundColor: SutraColors.Light.textSecondary
            ]

            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .font: selectedFont,
                .foregroundColor: SutraColors.Semantic.accent(theme: theme)
            ]

            // Apply to all tab bars
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        } else {
            // Fallback for iOS 13-14 using design system colors
            UITabBar.appearance().barTintColor = SutraColors.Semantic.surface(theme: theme)
            UITabBar.appearance().shadowImage = UIImage()
            UITabBar.appearance().backgroundImage = UIImage()

            // Set tab bar item colors with design system
            UITabBar.appearance().tintColor = SutraColors.Semantic.accent(theme: theme)
            UITabBar.appearance().unselectedItemTintColor = SutraColors.Light.textSecondary
        }

        UITabBar.appearance().isTranslucent = true
    }
}

