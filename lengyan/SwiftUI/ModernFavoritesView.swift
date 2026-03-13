//
//  ModernFavoritesView.swift
//  lengyan
//
//  Created by SwiftUI Migration on 2025/10/29.
//  Copyright © 2025年 xuan. All rights reserved.
//

import SwiftUI
import Combine

// MARK: - Notifications
extension Notification.Name {
    static let favoritesDidChange = Notification.Name("favoritesDidChange")
}

// MARK: - Favorites Cache
/// A caching mechanism for favorite items that improves performance by avoiding
/// repeated data processing when switching to the favorites tab.
///
/// The cache:
/// - Stores processed FavoriteItem objects for 5 minutes
/// - Automatically invalidates when the favorites list changes
/// - Provides helper methods for adding/removing favorites with cache management
/// - Uses notifications to notify other parts of the app about favorites changes
class FavoritesCache {
    static let shared = FavoritesCache()

    private var cachedFavorites: [FavoriteItem] = []
    private var lastCachedPaths: Set<String> = []
    private var lastUpdateTime: Date?
    private let cacheValidityInterval: TimeInterval = 300 // 5 minutes

    private init() {}

    /// Retrieve cached favorites if available and valid
    /// - Returns: Cached favorites array or nil if cache is invalid/expired
    func getCachedFavorites() -> [FavoriteItem]? {
        // Check if cache is still valid
        guard let lastUpdate = lastUpdateTime,
              Date().timeIntervalSince(lastUpdate) < cacheValidityInterval else {
            return nil
        }

        // Check if favorites list hasn't changed
        let currentPaths = Set(Prefers.shared.likes)
        guard currentPaths == lastCachedPaths else {
            return nil
        }

        return cachedFavorites
    }

    /// Store favorites in cache
    /// - Parameters:
    ///   - favorites: Array of processed FavoriteItem objects
    ///   - paths: Array of favorite paths for validation
    func cacheFavorites(_ favorites: [FavoriteItem], paths: [String]) {
        cachedFavorites = favorites
        lastCachedPaths = Set(paths)
        lastUpdateTime = Date()
    }

    /// Invalidate the cache (use when favorites change)
    func invalidate() {
        cachedFavorites = []
        lastCachedPaths = []
        lastUpdateTime = nil
    }

    /// Check if cache needs to be refreshed
    /// - Returns: true if cache is invalid or expired
    func shouldRefresh() -> Bool {
        return getCachedFavorites() == nil
    }

    /// Public method to invalidate cache when favorites are modified externally
    /// Call this after Prefers.shared.like() or Prefers.shared.unlike()
    static func invalidateOnFavoriteChange() {
        shared.invalidate()
        print("🔄 Cache invalidated due to favorite change")
    }

    /// Helper method to add a favorite and notify cache
    /// Use this from other parts of the app when adding favorites
    /// - Parameter path: The path of the item to favorite
    static func addFavorite(path: String) {
        Prefers.shared.like(path)
        Prefers.shared.persist()
        shared.invalidate()

        // Post notification for other views
        NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
        print("⭐ Added favorite and invalidated cache: \(path)")
    }

    /// Helper method to remove a favorite and notify cache
    /// Use this from other parts of the app when removing favorites
    /// - Parameter path: The path of the item to unfavorite
    static func removeFavorite(path: String) {
        Prefers.shared.unlike(path)
        Prefers.shared.persist()
        shared.invalidate()

        // Post notification for other views
        NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
        print("🗑️ Removed favorite and invalidated cache: \(path)")
    }
}

struct FavoriteItem: Identifiable {
    let id = UUID()
    let path: String
    let title: String
    let content: String
    let hasChildren: Bool
}

struct ModernFavoritesView: View {
    @State private var favorites: [FavoriteItem] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(spacing: SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingLG)) {
                // World-class Header with prominent title and helpful subtitle
                VStack(alignment: .leading, spacing: SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingSM)) {
                    Text(NSLocalizedString("star_tab_title", comment: ""))
                        .font(SutraTypographyBridge.uiLargeTitle())
                        .foregroundColor(SutraDesignSystem.sutraTextColor())
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(NSLocalizedString("favorites_subtitle", comment: ""))
                        .font(SutraTypographyBridge.uiBody())
                        .foregroundColor(SutraDesignSystem.secondaryTextColor())
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingLG))
                .padding(.horizontal, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingXS))

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.top, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingComponentXXL))
                } else if favorites.isEmpty {
                    // 🌺 禅意空状态 - 莲花图标 + 脉动动画
                    VStack(spacing: SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingXL)) {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 72, weight: .ultraLight))
                            .foregroundColor(SutraDesignSystem.color(.decorativeGold).opacity(0.5))

                        Text(NSLocalizedString("no_favorites", comment: ""))
                            .font(SutraTypographyBridge.uiTitle(weight: .medium))
                            .foregroundColor(SutraDesignSystem.color(.textTertiary))

                        Text(NSLocalizedString("no_favorites_description", comment: ""))
                            .font(SutraTypographyBridge.uiBody())
                            .foregroundColor(SutraDesignSystem.secondaryTextColor().opacity(0.6))
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .padding(.horizontal, 40)
                    }
                    .padding(.top, 80)
                } else {
                    // Favorites List
                    VStack(spacing: SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingMD)) {
                        ForEach(favorites) { favorite in
                            favoriteCard(favorite)
                        }
                    }
                }

                Spacer(minLength: SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingXL))
            }
            .padding(SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingLG))
        }
        .background(SutraDesignSystem.backgroundColor())
        .edgesIgnoringSafeArea(.bottom)
        .onAppear {
            loadFavorites()
        }
        .onReceive(NotificationCenter.default.publisher(for: .favoritesDidChange)) { _ in
            // Refresh cache when favorites change from other views
            FavoritesCache.invalidateOnFavoriteChange()
            loadFavorites()
        }
    }

    private func favoriteCard(_ favorite: FavoriteItem) -> some View {
        HStack(spacing: 0) {
            // 左侧装饰竖线 - accent 翠竹绿
            RoundedRectangle(cornerRadius: 2)
                .fill(SutraDesignSystem.accentColor())
                .frame(width: 3)
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingMD)) {
                // 标题和心形按钮
                HStack(alignment: .top, spacing: SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingMD)) {
                    Text(favorite.title)
                        .font(SutraTypographyBridge.uiTitle(weight: .semibold))
                        .foregroundColor(SutraDesignSystem.color(.chapterTitle))  // 鎏金色标题
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()

                    // 朱砂红心形按钮
                    Button(action: { removeFavorite(favorite) }) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(SutraDesignSystem.color(.favorite))  // 朱砂红
                            .font(.system(size: 22))
                            .frame(width: 44, height: 44)
                    }
                }

                // 经文预览
                Text(favorite.content)
                    .font(SutraTypographyBridge.uiBody())
                    .foregroundColor(SutraDesignSystem.secondaryTextColor())
                    .lineLimit(3)
                    .lineSpacing(5)
                    .multilineTextAlignment(.leading)

                // 日期
                Text(formatDate(from: favorite.path))
                    .font(SutraTypographyBridge.uiCaption())
                    .foregroundColor(SutraDesignSystem.secondaryTextColor().opacity(0.5))
            }
            .padding(.leading, 16)
            .padding(.vertical, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingLG))
            .padding(.trailing, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingLG))
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(SutraDesignSystem.color(.surface))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(SutraDesignSystem.color(.decorativeGold).opacity(0.2), lineWidth: 0.5)
                )
                .shadow(color: Color(SutraDesignTokens.shared.color(for: .shadow)), radius: 6, x: 0, y: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            navigateToReading(favorite)
        }
    }

    private func loadFavorites() {
        isLoading = true

        // Check cache first
        if let cached = FavoritesCache.shared.getCachedFavorites() {
            print("📦 Using cached favorites (count: \(cached.count))")
            self.favorites = cached
            self.isLoading = false
            return
        }

        print("🔄 Cache miss or invalid, loading favorites...")
        // Move heavy processing to background queue
        DispatchQueue.global(qos: .userInitiated).async {
            // Load favorites from Prefers.shared.likes
            let likedPaths = Prefers.shared.likes
            var loadedFavorites: [FavoriteItem] = []

            for path in likedPaths {
                let item = Book.shared.itemOfPath(path)
                let title = item["name"] as? String ?? NSLocalizedString("unknown_sutra", comment: "")
                let hasChildren = item["children"] != nil

                // Extract content more efficiently
                let content = self.extractContentEfficiently(from: item)

                let favorite = FavoriteItem(
                    path: path,
                    title: title,
                    content: content,
                    hasChildren: hasChildren
                )
                loadedFavorites.append(favorite)
            }

            // Sort favorites by title for better organization
            loadedFavorites.sort { $0.title < $1.title }

            // Cache the results
            FavoritesCache.shared.cacheFavorites(loadedFavorites, paths: likedPaths)
            print("💾 Cached \(loadedFavorites.count) favorites")

            DispatchQueue.main.async {
                self.favorites = loadedFavorites
                self.isLoading = false
            }
        }
    }

    private func extractContentEfficiently(from item: [String: Any]) -> String {
        // Use a more efficient method to get content with length limit
        if item["children"] != nil {
            return NSLocalizedString("contains_sub_chapters", comment: "")
        }

        // Directly get sutra with length limit
        let content = Book.shared.getSutra(item)
        if content.count > 150 {
            let index = content.index(content.startIndex, offsetBy: 150)
            return String(content[..<index]) + "..."
        }
        return content
    }


    private func formatDate(from path: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        return formatter.string(from: Date())
    }

    private func removeFavorite(_ favorite: FavoriteItem) {
        Prefers.shared.unlike(favorite.path)
        Prefers.shared.persist()

        // Remove from local array and update UI
        favorites.removeAll { $0.path == favorite.path }

        // Invalidate cache since favorites list changed
        FavoritesCache.shared.invalidate()

        // Post notification so other views can update
        NotificationCenter.default.post(name: .favoritesDidChange, object: nil)

        print("🗑️ Removed favorite, invalidated cache, and notified other views")
    }

    private func navigateToReading(_ favorite: FavoriteItem) {
        print("Navigate to reading: \(favorite.path)")

        // Find the navigation controller from the UIKit hierarchy
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let tabBarController = window.rootViewController as? UITabBarController,
           let navigationController = tabBarController.selectedViewController as? UINavigationController {

            if favorite.hasChildren {
                print("Open sutra with chapters: \(favorite.title)")
                openSutra(favorite.path, navigationController: navigationController)
            } else {
                print("Open specific page: \(favorite.title)")
                openSpecificPage(favorite.path, navigationController: navigationController)
            }
        } else {
            print("Error: Could not find navigation controller")
        }
    }

    private func openSutra(_ path: String, navigationController: UINavigationController) {
        // Get the title for this sutra item
        let item = Book.shared.itemOfPath(path)
        let title = item["name"] as? String ?? NSLocalizedString("sutra", comment: "")

        // Force navigation bar to be visible
        navigationController.setNavigationBarHidden(false, animated: false)

        let sutraVC = SutraPurePageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal,
            options: nil
        )
        sutraVC.path = path
        sutraVC.isShowIndexButton = true
        sutraVC.title = title

        sutraVC.onDismiss = {
            navigationController.setNavigationBarHidden(true, animated: false)
        }

        navigationController.pushViewController(sutraVC, animated: true)

        // Force navigation bar visibility after push
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            navigationController.setNavigationBarHidden(false, animated: false)
            sutraVC.navigationController?.setNavigationBarHidden(false, animated: false)
        }
    }

    private func openSpecificPage(_ path: String, navigationController: UINavigationController) {
        // Find the page index for this path
        if let pageIndex = Book.shared.index?.firstIndex(where: { item in
            item["path"] as? String == path
        }) {
            // Get the title for this page
            let item = Book.shared.index?[pageIndex]
            let title = item?["name"] as? String ?? NSLocalizedString("sutra", comment: "")

            // Force navigation bar to be visible
            navigationController.setNavigationBarHidden(false, animated: false)

            let pageVC = SutraPageViewController(
                transitionStyle: .pageCurl,
                navigationOrientation: .horizontal,
                options: nil
            )
            pageVC.page = pageIndex
            pageVC.title = title

            navigationController.pushViewController(pageVC, animated: true)

            // Force navigation bar visibility after push
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                navigationController.setNavigationBarHidden(false, animated: false)
                pageVC.navigationController?.setNavigationBarHidden(false, animated: false)
            }
        } else {
            print("Error: Could not find page index for path: \(path)")
        }
    }
}
