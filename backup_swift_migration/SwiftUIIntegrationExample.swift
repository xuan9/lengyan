//
//  SwiftUIIntegrationExample.swift
//  lengyan
//
//  Created by SwiftUI Migration on 2025/10/29.
//  Copyright © 2025年 xuan. All rights reserved.
//

import UIKit
import SwiftUI

// MARK: - Example: Enhanced Tab Bar with SwiftUI
class EnhancedTabBarViewController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabBarWithSwiftUI()
    }

    private func setupTabBarWithSwiftUI() {
        // Create enhanced tab bar with SwiftUI beauty
        let enhancedTabBar = ModernTabBarView()

        // Wrap SwiftUI in UIViewController
        let hostingController = UIHostingController(rootView: enhancedTabBar)

        // Replace the current tab bar controller's view with SwiftUI
        self.addChild(hostingController)
        self.view.addSubview(hostingController.view)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: self.view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])

        hostingController.didMove(toParent: self)
    }
}

// MARK: - Example: Audio Tab with SwiftUI Enhancement
class EnhancedAudioViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupModernAudioPlayer()
    }

    private func setupModernAudioPlayer() {
        // Create beautiful SwiftUI audio player
        let modernAudioPlayer = ModernAudioPlayerView()

        // Create hosting controller
        let hostingController = UIHostingController(rootView: modernAudioPlayer)

        // Add as child view controller
        addChild(hostingController)
        view.addSubview(hostingController.view)

        // Setup constraints
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hostingController.didMove(toParent: self)
    }
}

// MARK: - Example: Reading Tab with SwiftUI Enhancement
class EnhancedReadingViewController: UIViewController {
    private var sutraContent: String = ""
    private var chapterTitle: String = "楞严经 卷一"
    private var chapterSubtitle: String = "The Śūraṅgama Sūtra, Volume 1"

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBeautifulReadingView()
    }

    private func setupBeautifulReadingView() {
        // Create beautiful SwiftUI reading view
        let beautifulReading = BeautifulSutraReadingView(
            sutraContent: sutraContent,
            chapterTitle: chapterTitle,
            chapterSubtitle: chapterSubtitle
        )

        // Create hosting controller
        let hostingController = UIHostingController(rootView: beautifulReading)

        // Add as child view controller
        addChild(hostingController)
        view.addSubview(hostingController.view)

        // Setup constraints
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint_equalToSystemSpacingAfter(view.leadingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hostingController.didMove(toParent: self)
    }

    // Method to update content when navigating
    func updateContent(_ content: String, chapter: String, subtitle: String?) {
        sutraContent = content
        chapterTitle = chapter
        chapterSubtitle = subtitle

        // Recreate SwiftUI view with new content
        if let hostingController = children.first as? UIHostingController<BeautifulSutraReadingView> {
            let newReadingView = BeautifulSutraReadingView(
                sutraContent: content,
                chapterTitle: chapter,
                chapterSubtitle: subtitle
            )
            hostingController.rootView = newReadingView
        }
    }
}

// MARK: - Example: Favorites Tab with SwiftUI Beauty
class EnhancedFavoritesViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupModernFavoritesView()
    }

    private func setupModernFavoritesView() {
        // Create beautiful SwiftUI favorites view
        let modernFavorites = ModernFavoritesView()

        // Create hosting controller
        let hostingController = UIHostingController(rootView: modernFavorites)

        // Add as child view controller
        addChild(hostingController)
        view.addSubview(hostingController.view)

        // Setup constraints
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint_equalToSystemSpacingAfter(view.leadingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hostingController.didMove(toParent: self)
    }
}

// MARK: - Example: Modal SwiftUI Presentation
class ModalPresentationExample: UIViewController {

    @IBAction func presentModernAudioPlayer(_ sender: UIButton) {
        let modernAudioPlayer = ModernAudioPlayerView()

        // Present SwiftUI modally with navigation
        let navigationController = UINavigationController(rootViewController: UIHostingController(rootView: modernAudioPlayer))
        navigationController.modalPresentationStyle = .pageSheet

        present(navigationController, animated: true)
    }

    @IBAction func presentBeautifulReadingView(_ sender: UIButton) {
        let beautifulReading = BeautifulSutraReadingView(
            sutraContent: "如是我聞。一時，佛在室羅筏城...",
            chapterTitle: "楞严经 卷一",
            chapterSubtitle: "The Śūraṅgama Sūtra, Volume 1"
        )

        // Present SwiftUI modally
        let navigationController = UINavigationController(rootViewController: UIHostingController(rootView: beautifulReading))
        navigationController.modalPresentationStyle = .pageSheet

        present(navigationController, animated: true)
    }

    @IBAction func presentModernSettings(_ sender: UIButton) {
        let modernSettings = ModernSettingsView()

        // Present SwiftUI settings modally
        let navigationController = UINavigationController(rootViewController: UIHostingController(rootView: modernSettings))
        navigationController.modalPresentationStyle = .formSheet

        present(navigationController, animated: true)
    }
}

// MARK: - Example: Navigation Enhancement
extension UINavigationController {
    func pushViewControllerWithSwiftUI<Content: View>(
        _ view: Content,
        animated: Bool = true
    ) {
        let hostingController = UIHostingController(rootView: view)
        pushViewController(hostingController, animated: animated)
    }

    func pushViewControllerWithSwiftUI<Content: View>(
        _ view: Content,
        title: String,
        animated: Bool = true
    ) {
        let hostingController = UIHostingController(rootView: view)
        hostingController.title = title
        pushViewController(hostingController, animated: animated)
    }
}

// MARK: - Example: Settings Screen with SwiftUI
struct ModernSettingsView: View {
    @StateObject private var themeManager = ThemeManager()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                // Reading Settings Section
                Section("阅读设置") {
                    SettingsRow(
                        title: "字体大小",
                        subtitle: "调整经文字体大小",
                        icon: "textformat.size",
                        action: { /* Show font size picker */ }
                    )

                    SettingsRow(
                        title: "主题设置",
                        subtitle: "选择阅读主题",
                        icon: "paintbrush",
                        action: { /* Show theme picker */ }
                    )

                    SettingsRow(
                        title: "阅读模式",
                        subtitle: "夜间模式等",
                        icon: "moon",
                        action: { /* Show mode picker */ }
                    )
                }

                // App Settings Section
                Section("应用设置") {
                    SettingsRow(
                        title: "关于应用",
                        subtitle: "版本信息与更新",
                        icon: "info.circle",
                        action: { /* Show about */ }
                    )

                    SettingsRow(
                        title: "反馈建议",
                        subtitle: "帮助我们改进应用",
                        icon: "envelope",
                        action: { /* Show feedback */ }
                    )
                }
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Settings Row Component
struct SettingsRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    @StateObject private var themeManager = ThemeManager()

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(LengyanDesignSystem.Colors.accentGold)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(LengyanDesignSystem.Typography.uiBody)
                        .foregroundColor(themeManager.primaryTextColor)

                    Text(subtitle)
                        .font(LengyanDesignSystem.Typography.uiCaption)
                        .foregroundColor(themeManager.secondaryTextColor)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(themeManager.secondaryTextColor)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .buttonStyle(PlainButtonStyle())
        .background(themeManager.backgroundColor)
        .listRowBackground(themeManager.backgroundColor)
    }
}

// MARK: - Example: Migration Integration
class MigrationIntegrationGuide {

    // MARK: - How to Use SwiftUI in Existing Code

    static func integrateAudioPlayer() {
        // OLD: Your existing audio player code
        // let audioPlayer = AudioPlayerViewController()
        // navigationController?.pushViewController(audioPlayer, animated: true)

        // NEW: Enhanced SwiftUI audio player
        let audioPlayer = ModernAudioPlayerView()
        navigationController?.pushViewControllerWithSwiftUI(audioPlayer, title: "聽經")
    }

    static func integrateReadingView() {
        // OLD: Your existing reading view controller
        // let readingVC = SutraPageContentViewController()
        // navigationController?.pushViewController(readingVC, animated: true)

        // NEW: Enhanced SwiftUI reading view
        let readingView = BeautifulSutraReadingView(
            sutraContent: getLatestSutraContent(),
            chapterTitle: getCurrentChapterTitle(),
            chapterSubtitle: getCurrentChapterSubtitle()
        )
        navigationController?.pushViewControllerWithSwiftUI(readingView, title: "閱讀")
    }

    static func integrateFavoritesView() {
        // OLD: Your existing favorites controller
        // let favoritesVC = FavoritesViewController()
        // navigationController?.pushViewController(favoritesVC, animated: true)

        // NEW: Enhanced SwiftUI favorites view
        let favoritesView = ModernFavoritesView()
        navigationController?.pushViewControllerWithSwiftUI(favoritesView, title: "收藏")
    }

    // MARK: - Helper Methods
    private static func getLatestSutraContent() -> String {
        // Fetch latest sutra content from your Book.shared
        return "如是我聞。一時，佛在室羅筏城..."
    }

    private static func getCurrentChapterTitle() -> String {
        // Get current chapter title
        return "楞严经 卷一"
    }

    private static func getCurrentChapterSubtitle() -> String? {
        // Get current chapter subtitle
        return "The Śūraṅgama Sūtra, Volume 1"
    }
}

// MARK: - Preview Helper
#if DEBUG
struct SwiftUIIntegrationExample_Previews: PreviewProvider {
    static var previews: some View {
        // Preview of integration examples
        Group {
            EnhancedTabBarViewController()
                .previewDisplayName("Enhanced Tab Bar")

            EnhancedAudioViewController()
                .previewDisplayName("Enhanced Audio")

            EnhancedReadingViewController()
                .previewDisplayName("Enhanced Reading")

            ModernSettingsView()
                .previewDisplayName("Modern Settings")
        }
    }
}
#endif