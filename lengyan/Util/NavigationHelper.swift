//
//  NavigationHelper.swift
//  lengyan
//
//  UIKit navigation utilities for SwiftUI views
//

import UIKit
import SwiftUI

struct NavigationHelper {

    // MARK: - Navigation Controller

    static var currentNavigationController: UINavigationController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first,
              let tab = window.rootViewController as? UITabBarController else { return nil }
        return tab.selectedViewController as? UINavigationController
    }

    static func hideNavBar() {
        currentNavigationController?.setNavigationBarHidden(true, animated: false)
    }

    static func showNavBar() {
        currentNavigationController?.setNavigationBarHidden(false, animated: false)
    }

    static func pushSwiftUIView<T: View>(_ view: T, title: String) {
        guard let nav = currentNavigationController else { return }
        nav.setNavigationBarHidden(false, animated: false)
        let vc = UIHostingController(rootView: view)
        vc.title = title
        nav.pushViewController(vc, animated: true)
    }

    // MARK: - External Links

    static func openEmail(to: String, subject: String) {
        if let url = URL(string: "mailto:\(to)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            UIApplication.shared.open(url)
        }
    }

    static func openAppStoreReview(appId: String) {
        if let url = URL(string: "https://apps.apple.com/app/id\(appId)?action=write-review") {
            UIApplication.shared.open(url)
            }
    }

    // MARK: - App Info

    static var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return "\(v) (\(b))"
    }
}
