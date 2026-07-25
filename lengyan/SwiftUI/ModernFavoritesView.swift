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

private extension Book {
    func displayName(of item: [String: Any]) -> String {
        item["name"] as? String ?? ""
    }
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
    var id: String { path }
    let path: String
    let title: String
    let content: String
    let hasChildren: Bool
}

class FavoritesViewModel: ObservableObject {
    @Published var favorites: [FavoriteItem] = []
    @Published var curatedItems: [FavoriteItem] = []
    @Published var isLoading = true

    init() {
        // If under UITesting / snapshot-mode, load synchronously during init to ensure immediate rendering
        if ProcessInfo.processInfo.arguments.contains("--uitesting") || ProcessInfo.processInfo.arguments.contains("--snapshot-mode") {
            // 快照模式：若无个人收藏，预置「破妄识无处」一条，让「我的收藏」区有内容
            var paths = Prefers.shared.userLikes
            if paths.isEmpty {
                let seedPath = "/A2/B1/C2/D1/E2/F1/G1/H1/I2/J1/K1"  // 破妄识无处（破妄識無處）
                Prefers.shared.like(seedPath)
                paths = [seedPath]
            }
            let cpItems = self.loadItems(from: paths)
            FavoritesCache.shared.cacheFavorites(cpItems, paths: paths)
            self.favorites = cpItems

            let ccItems = self.loadItems(from: DEFAULT_STARTS)
            FavoritesCache.shared.cacheCurated(ccItems)
            self.curatedItems = ccItems

            self.isLoading = false
        }
    }

    func loadAll() {
        let cachedPersonal = FavoritesCache.shared.getCachedFavorites()
        let cachedCurated = FavoritesCache.shared.getCachedCurated()

        if let cp = cachedPersonal, let cc = cachedCurated {
            self.favorites = cp
            self.curatedItems = cc
            self.isLoading = false
            return
        }

        // If under UITesting / snapshot-mode, load synchronously
        if ProcessInfo.processInfo.arguments.contains("--uitesting") || ProcessInfo.processInfo.arguments.contains("--snapshot-mode") {
            let paths = Prefers.shared.userLikes
            let cpItems = self.loadItems(from: paths)
            FavoritesCache.shared.cacheFavorites(cpItems, paths: paths)

            let ccItems = self.loadItems(from: DEFAULT_STARTS)
            FavoritesCache.shared.cacheCurated(ccItems)

            self.favorites = cpItems
            self.curatedItems = ccItems
            self.isLoading = false
            return
        }

        self.isLoading = true
        let group = DispatchGroup()

        if let cp = cachedPersonal {
            self.favorites = cp
        } else {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                let paths = Prefers.shared.userLikes
                let items = self.loadItems(from: paths)
                FavoritesCache.shared.cacheFavorites(items, paths: paths)
                DispatchQueue.main.async {
                    self.favorites = items
                    group.leave()
                }
            }
        }

        if let cc = cachedCurated {
            self.curatedItems = cc
        } else {
            group.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                let items = self.loadItems(from: DEFAULT_STARTS)
                FavoritesCache.shared.cacheCurated(items)
                DispatchQueue.main.async {
                    self.curatedItems = items
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            self.isLoading = false
        }
    }

    private func loadItems(from paths: [String]) -> [FavoriteItem] {
        var items: [FavoriteItem] = []
        for path in paths {
            let item = Book.shared.itemOfPath(path)
            let displayTitle = Book.shared.displayName(of: item)
            let title = displayTitle.isEmpty ? L10n.str("unknown_sutra") : displayTitle
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
        return result.isEmpty ? L10n.str("no_content_preview") : result
    }
}

struct ModernFavoritesView: View {
    @StateObject private var viewModel = FavoritesViewModel()
    @State private var themeVersion: Int = 0
    @State private var selectedItem: FavoriteItem?

    private var activeSelectedItem: FavoriteItem? {
        selectedItem ?? viewModel.favorites.first ?? viewModel.curatedItems.first
    }

    private var themeBackgroundColor: Color {
        _ = themeVersion
        return Color(uiColor: SutraDesignTokens.shared.color(for: .background))
    }

    private var isWideScreen: Bool {
        if UIDevice.current.userInterfaceIdiom != .pad { return false }
        let width = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.bounds.width ?? UIScreen.main.bounds.width
        return width >= 768
    }

    var body: some View {
        GeometryReader { rootGeo in
            let isSplitView = isWideScreen
            let tabBarOverlapHeight = tabBarOverlapHeight(in: rootGeo.frame(in: .global))

            Group {
                if isSplitView {
                    HStack(spacing: 0) {
                        // Left Panel: Sidebar
                        VStack(spacing: 0) {
                            ZenTabHeaderView(titleKey: "star_tab_title", symbolName: "bookmark")

                            // Sidebar Content List
                            ScrollView {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .padding(.top, 60)
                                } else {
                                    VStack(spacing: 0) {
                                        // Section 1: 我的收藏
                                        SectionHeader(title: L10n.str("favorites_tab_personal"))

                                        if viewModel.favorites.isEmpty {
                                            personalEmptyCard
                                                .padding(.horizontal, 10)
                                        } else {
                                            VStack(spacing: 14) {
                                                ForEach(viewModel.favorites) { item in
                                                    favoriteCard(item)
                                                }
                                            }
                                            .padding(.horizontal, 10)
                                        }

                                        // Section 2: 编者精选
                                        SectionHeader(title: L10n.str("favorites_tab_curated"))

                                        VStack(spacing: 14) {
                                            ForEach(viewModel.curatedItems) { item in
                                                favoriteCard(item)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                    }
                                }
                            }
                        }
                        .frame(width: 320)
                        .background(themeBackgroundColor)

                        // Divider Line
                        Rectangle()
                            .fill(Color(uiColor: SutraDesignTokens.shared.color(for: .divider)).opacity(0.3))
                            .frame(width: 0.5)
                            .ignoresSafeArea(.all, edges: .vertical)

                        // Right Panel: Detail view
                        VStack(spacing: 0) {
                            if viewModel.isLoading {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Spacer()
                            } else if let selected = activeSelectedItem {
                                SwiftUISutraReader(path: selected.path, hasChildren: selected.hasChildren)
                                    .id(selected.path)
                            } else {
                                // If selectedItem is nil (i.e. empty personal favorites)
                                ZenPlaceholderView(
                                    titleKey: "favorites_curated_empty",
                                    descKey: "favorites_curated_title"
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(themeBackgroundColor)
                    }
                    .onAppear {
                        viewModel.loadAll()
                        hideNavBar()
                        updateDefaultSelection()
                    }
                    .onChange(of: viewModel.isLoading) { isLoading in
                        if !isLoading {
                            updateDefaultSelection()
                        }
                    }
                    .onChange(of: viewModel.favorites.count) { _ in
                        if selectedItem == nil {
                            updateDefaultSelection()
                        }
                    }
                    .onChange(of: viewModel.curatedItems.count) { _ in
                        if selectedItem == nil {
                            updateDefaultSelection()
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .favoritesDidChange)) { _ in
                        FavoritesCache.invalidateOnFavoriteChange()
                        viewModel.loadAll()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .themeDidChange)) { _ in
                        themeVersion += 1
                    }
                } else {
                    // iPhone (Phone layout)
                    VStack(spacing: 0) {
                        ZenTabHeaderView(titleKey: "star_tab_title", symbolName: "bookmark")

                        // 内容
                        ScrollView {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .padding(.top, 60)
                            } else {
                                VStack(spacing: 0) {
                                    // Section 1: 我的收藏
                                    SectionHeader(title: L10n.str("favorites_tab_personal"))

                                    if viewModel.favorites.isEmpty {
                                        personalEmptyCard
                                            .padding(.horizontal, 10)
                                            .readingContentWidth()
                                    } else {
                                        VStack(spacing: 14) {
                                            ForEach(viewModel.favorites) { item in
                                                favoriteCard(item)
                                            }
                                        }
                                        .padding(.horizontal, 10)
                                        .readingContentWidth()
                                    }

                                    // Section 2: 编者精选
                                    SectionHeader(title: L10n.str("favorites_tab_curated"))

                                    VStack(spacing: 14) {
                                        ForEach(viewModel.curatedItems) { item in
                                            favoriteCard(item)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .readingContentWidth()
                                }
                                .padding(.bottom, tabBarOverlapHeight)
                            }
                        }
                    }
                    .background(themeBackgroundColor)
                    .onAppear {
                        viewModel.loadAll()
                        hideNavBar()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .favoritesDidChange)) { _ in
                        FavoritesCache.invalidateOnFavoriteChange()
                        viewModel.loadAll()
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .themeDidChange)) { _ in
                        themeVersion += 1
                    }
                }
            }
            .frame(width: rootGeo.size.width, height: rootGeo.size.height)
            .background(themeBackgroundColor)
        }
        .background(themeBackgroundColor.ignoresSafeArea(.all, edges: .top))
        .ignoresSafeArea(.all, edges: .top)
    }

    private func tabBarOverlapHeight(in viewFrame: CGRect) -> CGFloat {
        guard
            let tabBar = activeTabBar(),
            !tabBar.isHidden,
            tabBar.alpha > 0.01
        else {
            return 0
        }

        let tabBarFrame = tabBar.convert(tabBar.bounds, to: nil)
        guard !tabBarFrame.isEmpty else { return 0 }

        let overlap = viewFrame.intersection(tabBarFrame)
        guard !overlap.isNull else { return 0 }

        return max(0, min(tabBarFrame.height, overlap.height))
    }

    private func activeTabBar() -> UITabBar? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        return (window?.rootViewController as? UITabBarController)?.tabBar
    }

    private var emptyView: some View {
        VStack(spacing: SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingXL)) {
            Text(L10n.str("favorites_curated_empty"))
                .font(.system(size: 14, weight: .light))
                .foregroundColor(SutraDesignSystem.color(.textSecondary))

            Text(L10n.str("favorites_curated_title"))
                .font(.system(size: 13, weight: .light))
                .foregroundColor(SutraDesignSystem.secondaryTextColor().opacity(0.5))
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
        .padding(.top, 60)
    }

    private var personalEmptyCard: some View {
        HStack(spacing: 0) {
            Capsule()
                .fill(Color(SutraDesignTokens.shared.color(for: .primary)).opacity(0.2))
                .frame(width: 3)
                .padding(.vertical, 8)

            Text(L10n.str("favorites_personal_empty_desc"))
                .font(.system(size: 12, weight: .light))
                .foregroundColor(SutraDesignSystem.color(.textSecondary).opacity(0.6))
                .lineLimit(2)
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
                .padding(.leading, 14)
                .padding(.trailing, 16)
                .padding(.vertical, 16)
            
            Spacer()
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    Color(SutraDesignTokens.shared.color(for: .divider)).opacity(0.15),
                    style: StrokeStyle(lineWidth: 0.5, dash: [4, 4])
                )
        )
    }

    // MARK: - 卡片
    private func favoriteCard(_ favorite: FavoriteItem) -> some View {
        let tabGreen = Color(SutraDesignTokens.shared.color(for: .primary))
        let isSelected = isWideScreen && activeSelectedItem?.id == favorite.id

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                if isSelected {
                    Capsule()
                        .fill(tabGreen)
                        .frame(width: 4)
                        .padding(.vertical, 10)
                } else {
                    Spacer()
                        .frame(width: 4)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(favorite.content)
                        .font(SutraTypographyBridge.uiBody(weight: .light))
                        .foregroundColor(SutraDesignSystem.sutraTextColor())
                        .lineLimit(3)
                        .lineSpacing(5)
                        .multilineTextAlignment(.leading)

                    HStack {
                        Spacer()
                        Text(favorite.title)
                            .font(.system(size: 10, weight: .light, design: .serif))
                            .foregroundColor(SutraDesignSystem.color(.textSecondary).opacity(0.7))
                            .lineLimit(1)
                            .trackingIfAvailable(0.5)
                    }
                }
                .padding(.leading, 12)
                .padding(.trailing, 14)
                .padding(.vertical, 14)
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? tabGreen.opacity(0.06) : Color.clear)
            )
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                if isWideScreen {
                    selectedItem = favorite
                } else {
                    navigateToReading(favorite)
                }
            }

            if !isSelected {
                Divider()
                    .background(SutraDesignSystem.color(.divider).opacity(0.2))
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
            }
        }
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
        let displayTitle = Book.shared.displayName(of: item)
        let title = displayTitle.isEmpty ? L10n.str("sutra") : displayTitle

        navigationController.setNavigationBarHidden(false, animated: false)

        let sutraVC = SutraPurePageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: nil
        )
        sutraVC.path = path
        sutraVC.isShowIndexButton = true
        sutraVC.hidesBottomBarWhenPushed = true
        sutraVC.title = title

        sutraVC.onDismiss = {
            navigationController.setNavigationBarHidden(true, animated: false)
        }

        navigationController.setNavigationBarHidden(false, animated: false)
        navigationController.pushViewController(sutraVC, animated: true)
    }

    private func openSpecificPage(_ path: String, navigationController: UINavigationController) {
        if let pageIndex = Book.shared.index?.firstIndex(where: { item in
            item["path"] == path
        }) {
            let item = Book.shared.index?[pageIndex]
            let title = item?["name"] as? String ?? L10n.str("sutra")

            navigationController.setNavigationBarHidden(false, animated: false)

            let pageVC = SutraPageViewController(
                transitionStyle: .scroll,
                navigationOrientation: .horizontal,
                options: nil
            )
            pageVC.page = pageIndex
            pageVC.hidesBottomBarWhenPushed = true
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

    private func updateDefaultSelection() {
        if let current = selectedItem {
            let combined = viewModel.favorites + viewModel.curatedItems
            if !combined.contains(where: { $0.path == current.path }) {
                selectedItem = nil
            }
        }
    }

    private func isLiked(_ item: FavoriteItem) -> Bool {
        Prefers.shared.isLike(item.path)
    }

    private func toggleBookmark(for item: FavoriteItem) {
        HapticManager.shared.bookmarkToggle()
        if isLiked(item) {
            Prefers.shared.unlike(item.path)
        } else {
            Prefers.shared.like(item.path)
        }
        Prefers.shared.persist()
        NotificationCenter.default.post(name: .favoritesDidChange, object: nil)
    }

    private func shareFavorite(_ item: FavoriteItem) {
        let bookTitle = NSLocalizedString("lengyan_book_title", comment: "《楞嚴經》")
        let sutraText = Book.shared.getSutra(Book.shared.itemOfPath(item.path))

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            SutraCardRenderer.presentPreview(
                text: sutraText,
                source: bookTitle,
                from: rootVC,
                barButtonItem: nil
            )
        }
    }
}

private extension View {
    @ViewBuilder
    func trackingIfAvailable(_ amount: CGFloat) -> some View {
        if #available(iOS 16.0, *) {
            self.tracking(amount)
        } else {
            self
        }
    }
}

// MARK: - HostingController — viewWillAppear 时立即隐藏导航栏，避免返回时闪烁
class FavoritesHostingController: UIHostingController<ModernFavoritesView> {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        view.backgroundColor = .clear
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
}

// MARK: - SwiftUISutraReader representable wrapper for iPad Split View
struct SwiftUISutraReader: UIViewControllerRepresentable {
    let path: String
    let hasChildren: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        let childVC: UIViewController
        if hasChildren {
            let sutraVC = SutraPurePageViewController(
                transitionStyle: .scroll,
                navigationOrientation: .horizontal,
                options: nil
            )
            sutraVC.path = path
            sutraVC.isShowIndexButton = true
            let item = Book.shared.itemOfPath(path)
            let displayTitle = Book.shared.displayName(of: item)
            sutraVC.title = displayTitle.isEmpty ? L10n.str("sutra") : displayTitle
            sutraVC.isEmbedded = true
            childVC = sutraVC
        } else {
            let pageIndex = Book.shared.index?.firstIndex(where: { item in
                item["path"] == path
            }) ?? 0
            let pageVC = SutraPageViewController(
                transitionStyle: .scroll,
                navigationOrientation: .horizontal,
                options: nil
            )
            pageVC.page = pageIndex
            let item = Book.shared.index?[pageIndex]
            pageVC.title = item?["name"] as? String ?? L10n.str("sutra")
            pageVC.isEmbedded = true
            childVC = pageVC
        }

        let navController = SutraNavigationController(rootViewController: childVC)
        navController.navigationBar.isHidden = false
        return navController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let nav = uiViewController as? UINavigationController {
            let bgColor = SutraDesignTokens.shared.color(for: .background)
            nav.navigationBar.backgroundColor = bgColor
            nav.view.backgroundColor = bgColor
            if let topVC = nav.topViewController {
                topVC.view.backgroundColor = bgColor
            }
        }
    }
}

// MARK: - ZenPlaceholderView for empty split view state
struct ZenPlaceholderView: View {
    let titleKey: String
    let descKey: String

    var body: some View {
        ZStack {
            Color(uiColor: SutraDesignTokens.shared.color(for: .background)).ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "bookmark")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(Color(uiColor: SutraDesignTokens.shared.color(for: .textSecondary)).opacity(0.4))
                
                Text(L10n.str(titleKey))
                    .font(.system(size: 16, weight: .regular, design: .serif))
                    .foregroundColor(Color(uiColor: SutraDesignTokens.shared.color(for: .textPrimary)))
                    .tracking(2)
                
                Text(L10n.str(descKey))
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(Color(uiColor: SutraDesignTokens.shared.color(for: .textSecondary)).opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 40)
            }
        }
    }
}

// MARK: - SectionHeader for grouped collections
struct SectionHeader: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .light, design: .serif))
                .foregroundColor(SutraDesignSystem.color(.textSecondary).opacity(0.6))
                .tracking(2)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 20)
        .padding(.bottom, 6)
    }
}

// MARK: - ZenScriptureCardView for focused scripture contemplation in iPad Split View
struct ZenScriptureCardView: View {
    let favorite: FavoriteItem
    let onEnterReader: () -> Void
    
    private var fullText: String {
        let item = Book.shared.itemOfPath(favorite.path)
        let rawContent = Book.shared.getSutra(item, maxLength: 800)
        var result = ""
        var lastCharWasNewline = false
        for char in rawContent {
            if char == "\n" {
                if !lastCharWasNewline {
                    result.append("\n")
                    lastCharWasNewline = true
                }
            } else if char == " " || char == "\t" {
                continue
            } else {
                result.append(char)
                lastCharWasNewline = false
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 36) {
            Spacer()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 30) {
                    Text(fullText)
                        .font(.system(size: 40, weight: .regular, design: .serif))
                        .foregroundColor(SutraDesignSystem.color(.textPrimary))
                        .lineSpacing(26)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: 720)
                        .padding(.horizontal, 36)
                }
                .padding(.vertical, 24)
            }
            .frame(maxHeight: 620)
            
            HStack {
                Rectangle().fill(SutraDesignSystem.color(.divider).opacity(0.4)).frame(width: 100, height: 0.5)
                Image(systemName: "leaf")
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(SutraDesignSystem.color(.primary).opacity(0.4))
                Rectangle().fill(SutraDesignSystem.color(.divider).opacity(0.4)).frame(width: 100, height: 0.5)
            }
            
            VStack(spacing: 8) {
                Text(favorite.title)
                    .font(.system(size: 20, weight: .light, design: .serif))
                    .foregroundColor(SutraDesignSystem.color(.textSecondary))
                    .tracking(4)
                
                Text(NSLocalizedString("lengyan_book_title", comment: "《楞嚴經》"))
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(SutraDesignSystem.color(.textSecondary).opacity(0.6))
                    .tracking(3)
            }
            
            Button(action: onEnterReader) {
                HStack(spacing: 8) {
                    Text(L10n.str("enter_reading_mode"))
                        .font(.system(size: 15, weight: .light, design: .serif))
                        .tracking(1.5)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .light))
                }
                .foregroundColor(SutraDesignSystem.color(.primary))
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .stroke(SutraDesignSystem.color(.primary).opacity(0.25), lineWidth: 0.5)
                )
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(uiColor: SutraDesignTokens.shared.color(for: .card)).opacity(0.5))
                .shadow(color: SutraDesignSystem.color(.shadow).opacity(0.02), radius: 10, x: 0, y: 4)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
        )
    }
}
