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
        UINavigationBar.appearance().tintColor = UIColor.darkText
        
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

