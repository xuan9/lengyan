//
//  NavigationHelper.swift
//  lengyan
//
//  UIKit navigation utilities for SwiftUI views
//

import UIKit
import SwiftUI

protocol NavigationPopAware: AnyObject {
    func navigationControllerDidPop()
}

/// Keeps the system edge-swipe pop gesture available even when a screen uses
/// custom navigation items. Several reader screens intentionally use an
/// icon-only back button, which otherwise leaves the gesture disabled and lets
/// the underlying page/tree gesture handle the swipe instead.
final class SutraNavigationController: UINavigationController, UIGestureRecognizerDelegate, UINavigationControllerDelegate {
    private var lastShownStack: [UIViewController] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        lastShownStack = viewControllers
        delegate = self
        interactivePopGestureRecognizer?.delegate = self
        interactivePopGestureRecognizer?.isEnabled = true
    }

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        interactivePopGestureRecognizer?.delegate = self
        interactivePopGestureRecognizer?.isEnabled = viewControllers.count > 1

        let previousStack = lastShownStack
        let currentStack = viewControllers
        let returnedToExistingController = previousStack.contains(where: { $0 === viewController })
        let poppedControllers = previousStack.filter { previous in
            !currentStack.contains(where: { $0 === previous })
        }
        lastShownStack = currentStack
        if returnedToExistingController {
            poppedControllers.forEach {
                ($0 as? NavigationPopAware)?.navigationControllerDidPop()
            }
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === interactivePopGestureRecognizer else { return true }
        return viewControllers.count > 1 && transitionCoordinator == nil
    }
}

// MARK: - 自动管理导航栏显隐的 HostingController

class NavBarHostingController<T: View>: UIHostingController<T> {
    let showsNavBar: Bool

    init(rootView: T, showsNavBar: Bool = true) {
        self.showsNavBar = showsNavBar
        super.init(rootView: rootView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.backgroundColor = .clear
        if showsNavBar {
            navigationController?.navigationBar.isHidden = false
            navigationController?.setNavigationBarHidden(false, animated: animated)
        } else {
            navigationController?.setNavigationBarHidden(true, animated: animated)
            navigationController?.navigationBar.isHidden = true
        }
    }
}

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
        // 临时取消 isHidden，让子页面导航栏正常工作
        nav.navigationBar.isHidden = false
        nav.setNavigationBarHidden(false, animated: false)
        let vc = NavBarHostingController(rootView: view, showsNavBar: true)
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
