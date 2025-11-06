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
                // Header
                Text("收藏")
                    .font(SutraTypographyBridge.uiHeading())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingMD))

                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.top, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingComponentXXL))
                } else if favorites.isEmpty {
                    // Empty State
                    VStack(spacing: SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingLG)) {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 60))
                            .foregroundColor(SutraDesignSystem.color(.accent).opacity(0.6))

                        Text("暂无收藏")
                            .font(SutraTypographyBridge.uiHeading())
                            .foregroundColor(SutraDesignSystem.sutraTextColor())

                        Text("在阅读时点击收藏按钮，将喜欢的经文添加到这里")
                            .font(SutraTypographyBridge.uiBody())
                            .foregroundColor(SutraDesignSystem.secondaryTextColor())
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingXL))
                    }
                    .padding(.top, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingComponentXXL))
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
        VStack(alignment: .leading, spacing: SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingSM)) {
            HStack {
                Text(favorite.title)
                    .font(SutraTypographyBridge.uiHeading())
                    .foregroundColor(SutraDesignSystem.sutraTextColor())
                    .lineLimit(2)

                Spacer()

                Button(action: { removeFavorite(favorite) }) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(SutraDesignSystem.color(.accent))
                        .font(.system(size: 16))
                }
            }

            Text(favorite.content)
                .font(SutraTypographyBridge.sutraCaption())
                .foregroundColor(SutraDesignSystem.secondaryTextColor())
                .lineLimit(4)
                .multilineTextAlignment(.leading)

            Text(formatDate(from: favorite.path))
                .font(SutraTypographyBridge.uiSmall())
                .foregroundColor(SutraDesignSystem.secondaryTextColor().opacity(0.7))
        }
        .padding(SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingMD))
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SutraDesignSystem.backgroundColor().opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(SutraDesignSystem.color(.border).opacity(0.2), lineWidth: 1)
                )
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
                let title = item["name"] as? String ?? "未知经文"
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
        if let children = item["children"] {
            return "包含子章节"
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
        let sutraVC = SutraPurePageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal,
            options: nil
        )
        sutraVC.path = path
        sutraVC.isShowIndexButton = true
        sutraVC.onDismiss = {
            navigationController.setNavigationBarHidden(false, animated: false)
        }
        navigationController.isNavigationBarHidden = false
        navigationController.pushViewController(sutraVC, animated: true)
    }

    private func openSpecificPage(_ path: String, navigationController: UINavigationController) {
        let pageVC = SutraPageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal,
            options: nil
        )

        // Find the page index for this path
        if let pageIndex = Book.shared.index?.firstIndex(where: { item in
            item["path"] as? String == path
        }) {
            pageVC.page = pageIndex
            navigationController.pushViewController(pageVC, animated: true)
        } else {
            print("Error: Could not find page index for path: \(path)")
        }
    }
}
