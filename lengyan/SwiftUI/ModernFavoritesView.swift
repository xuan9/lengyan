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
class FavoritesCache {
    static let shared = FavoritesCache()

    private var cachedFavorites: [FavoriteItem] = []
    private var cachedCurated: [FavoriteItem] = []
    private var lastCachedPaths: Set<String> = []
    private var lastCachedCuratedPaths: Set<String> = []
    private var lastUpdateTime: Date?
    private var lastCuratedUpdateTime: Date?
    private let cacheValidityInterval: TimeInterval = 300

    private init() {}

    func getCachedFavorites() -> [FavoriteItem]? {
        guard let lastUpdate = lastUpdateTime,
              Date().timeIntervalSince(lastUpdate) < cacheValidityInterval else { return nil }
        let currentPaths = Set(Prefers.shared.userLikes)
        guard currentPaths == lastCachedPaths else { return nil }
        return cachedFavorites
    }

    func getCachedCurated() -> [FavoriteItem]? {
        guard let lastUpdate = lastCuratedUpdateTime,
              Date().timeIntervalSince(lastUpdate) < cacheValidityInterval else { return nil }
        // 系统精选不变，只检查时间
        return cachedCurated
    }

    func cacheFavorites(_ favorites: [FavoriteItem], paths: [String]) {
        cachedFavorites = favorites
        lastCachedPaths = Set(paths)
        lastUpdateTime = Date()
    }

    func cacheCurated(_ items: [FavoriteItem]) {
        cachedCurated = items
        lastCuratedUpdateTime = Date()
    }

    func invalidate() {
        cachedFavorites = []
        lastCachedPaths = []
        lastUpdateTime = nil
    }

    static func invalidateOnFavoriteChange() {
        shared.invalidate()
    }

    static func addFavorite(path: String) {
        Prefers.shared.like(path)
        Prefers.shared.persist()
        shared.invalidate()
        NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
    }

    static func removeFavorite(path: String) {
        Prefers.shared.unlike(path)
        Prefers.shared.persist()
        shared.invalidate()
        NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
    }
}

struct FavoriteItem: Identifiable {
    let id = UUID()
    let path: String
    let title: String
    let content: String
    let hasChildren: Bool
}

// MARK: - Tab 枚举
private enum FavoritesTab: String, CaseIterable {
    case personal = "收藏"
    case curated = "精选"
}

struct ModernFavoritesView: View {
    @AppStorage("favoritesSelectedTab") private var selectedTab: FavoritesTab = .personal
    @State private var favorites: [FavoriteItem] = []
    @State private var curatedItems: [FavoriteItem] = []
    @State private var isLoading = true
    @State private var themeVersion: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            ZenTabHeaderView(titleKey: "star_tab_title", symbolName: "bookmark")

            // 顶部 Tab 切换 — 轻盈透气
            HStack(spacing: 0) {
                ForEach(FavoritesTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab }) {
                        VStack(spacing: 4) {
                            Text(tab.rawValue)
                                .font(.system(size: 14, weight: selectedTab == tab ? .regular : .light))
                                .foregroundColor(selectedTab == tab
                                    ? SutraDesignSystem.color(.primary)
                                    : SutraDesignSystem.color(.textSecondary))
                            Rectangle()
                                .fill(selectedTab == tab
                                    ? SutraDesignSystem.color(.primary).opacity(0.5)
                                    : Color.clear)
                                .frame(width: 24, height: 0.8)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 6)

            // 内容
            ScrollView {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.top, 60)
                } else if currentItems.isEmpty {
                    emptyView
                } else {
                    VStack(spacing: 14) {
                        ForEach(currentItems) { item in
                            favoriteCard(item)
                        }
                    }
                    .padding(.horizontal, 10)
                    .readingContentWidth()
                }

                Spacer(minLength: SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingXL))
            }
        }
        .background(SutraDesignSystem.backgroundColor())
        .edgesIgnoringSafeArea(.bottom)
        .onAppear {
            loadAll()
            hideNavBar()
        }
        .onReceive(NotificationCenter.default.publisher(for: .favoritesDidChange)) { _ in
            FavoritesCache.invalidateOnFavoriteChange()
            loadAll()
        }
        .onReceive(NotificationCenter.default.publisher(for: .themeDidChange)) { _ in
            themeVersion += 1
        }
    }

    private var currentItems: [FavoriteItem] {
        selectedTab == .personal ? favorites : curatedItems
    }

    private var emptyView: some View {
        VStack(spacing: SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingXL)) {
            Text(selectedTab == .personal
                ? NSLocalizedString("no_favorites", comment: "")
                : "暂无精选内容")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(SutraDesignSystem.color(.textSecondary))

            Text(selectedTab == .personal
                ? "阅读时轻触收藏按钮即可收藏"
                : "经典段落由编者精选")
                .font(.system(size: 13, weight: .light))
                .foregroundColor(SutraDesignSystem.secondaryTextColor().opacity(0.5))

            if selectedTab == .personal {
                Button(action: { selectedTab = .curated }) {
                    Text("先看看精选 →")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(SutraDesignSystem.color(.primary).opacity(0.7))
                }
                .padding(.top, 4)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
        .padding(.top, 60)
    }

    // MARK: - 卡片
    private func favoriteCard(_ favorite: FavoriteItem) -> some View {
        let tabGreen = Color(SutraDesignTokens.shared.color(for: .primary))

        return HStack(spacing: 0) {
            Capsule()
                .fill(tabGreen.opacity(0.7))
                .frame(width: 3)
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 6) {
                Text(favorite.content)
                    .font(SutraTypographyBridge.uiBody(weight: .regular))
                    .foregroundColor(SutraDesignSystem.sutraTextColor())
                    .lineLimit(4)
                    .lineSpacing(6)
                    .multilineTextAlignment(.leading)

                HStack {
                    Spacer()
                    Text(favorite.title)
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(SutraDesignSystem.color(.textSecondary))
                        .lineLimit(1)
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 16)
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(SutraDesignTokens.shared.color(for: .card)))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [tabGreen.opacity(0.15), tabGreen.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            navigateToReading(favorite)
        }
    }

    // MARK: - 数据加载
    private func loadAll() {
        // 缓存全部命中时直接显示，不闪 loading
        let cachedPersonal = FavoritesCache.shared.getCachedFavorites()
        let cachedCurated = FavoritesCache.shared.getCachedCurated()

        if cachedPersonal != nil && cachedCurated != nil {
            favorites = cachedPersonal!
            curatedItems = cachedCurated!
            isLoading = false
            return
        }

        isLoading = true

        if let cached = cachedPersonal {
            favorites = cached
        } else {
            DispatchQueue.global(qos: .userInitiated).async {
                let paths = Prefers.shared.userLikes
                let items = self.loadItems(from: paths)
                FavoritesCache.shared.cacheFavorites(items, paths: paths)
                DispatchQueue.main.async {
                    self.favorites = items
                }
            }
        }

        if let cached = cachedCurated {
            curatedItems = cached
        } else {
            DispatchQueue.global(qos: .userInitiated).async {
                let items = self.loadItems(from: DEFAULT_STARTS)
                FavoritesCache.shared.cacheCurated(items)
                DispatchQueue.main.async {
                    self.curatedItems = items
                    self.isLoading = false
                }
            }
        }
    }

    private func loadItems(from paths: [String]) -> [FavoriteItem] {
        var items: [FavoriteItem] = []
        for path in paths {
            let item = Book.shared.itemOfPath(path)
            let title = item["name"] as? String ?? NSLocalizedString("unknown_sutra", comment: "")
            let hasChildren = item["children"] != nil
            let content = extractContentEfficiently(from: item)
            items.append(FavoriteItem(path: path, title: title, content: content, hasChildren: hasChildren))
        }
        items.sort { $0.title < $1.title }
        return items
    }

    private func extractContentEfficiently(from item: [String: Any]) -> String {
        let rawContent = Book.shared.getSutra(item, maxLength: 80)
        let maxCount = 50
        var result = ""
        result.reserveCapacity(maxCount + 3)
        var charCount = 0

        for char in rawContent {
            if char == "\n" || char == " " || char == "\t" { continue }
            result.append(char)
            charCount += 1
            if charCount >= maxCount { break }
        }
        if charCount >= maxCount && rawContent.count > maxCount {
            result.append("...")
        }
        return result.isEmpty ? NSLocalizedString("no_content_preview", comment: "") : result
    }

    // MARK: - 导航
    private func navigateToReading(_ favorite: FavoriteItem) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let tabBarController = window.rootViewController as? UITabBarController,
           let navigationController = tabBarController.selectedViewController as? UINavigationController {

            if favorite.hasChildren {
                openSutra(favorite.path, navigationController: navigationController)
            } else {
                openSpecificPage(favorite.path, navigationController: navigationController)
            }
        }
    }

    private func openSutra(_ path: String, navigationController: UINavigationController) {
        let item = Book.shared.itemOfPath(path)
        let title = item["name"] as? String ?? NSLocalizedString("sutra", comment: "")

        navigationController.setNavigationBarHidden(false, animated: false)

        let sutraVC = SutraPurePageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: nil
        )
        sutraVC.path = path
        sutraVC.isShowIndexButton = true
        sutraVC.title = title

        sutraVC.onDismiss = {
            navigationController.setNavigationBarHidden(true, animated: false)
        }

        navigationController.setNavigationBarHidden(false, animated: false)
        navigationController.pushViewController(sutraVC, animated: true)
    }

    private func openSpecificPage(_ path: String, navigationController: UINavigationController) {
        if let pageIndex = Book.shared.index?.firstIndex(where: { item in
            item["path"] as? String == path
        }) {
            let item = Book.shared.index?[pageIndex]
            let title = item?["name"] as? String ?? NSLocalizedString("sutra", comment: "")

            navigationController.setNavigationBarHidden(false, animated: false)

            let pageVC = SutraPageViewController(
                transitionStyle: .scroll,
                navigationOrientation: .horizontal,
                options: nil
            )
            pageVC.page = pageIndex
            pageVC.title = title

            navigationController.pushViewController(pageVC, animated: true)
        }
    }

    private func hideNavBar() {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let tabBarController = window.rootViewController as? UITabBarController,
           let navigationController = tabBarController.selectedViewController as? UINavigationController {
            navigationController.setNavigationBarHidden(true, animated: false)
        }
    }
}

// MARK: - HostingController — viewWillAppear 时立即隐藏导航栏，避免返回时闪烁
class FavoritesHostingController: UIHostingController<ModernFavoritesView> {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
}
