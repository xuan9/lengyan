//
//  LengyanSwiftUIBridge.swift
//  lengyan
//
//  Created by SwiftUI Migration on 2025/10/29.
//  Copyright © 2025年 xuan. All rights reserved.
//

import UIKit
import SwiftUI

// MARK: - UIKit to SwiftUI Bridge
class LengyanSwiftUIBridge {

    // MARK: - Create SwiftUI Hosting Controller
    static func createHostingController<Content: View>(
        for view: Content,
        parent: UIViewController? = nil
    ) -> UIHostingController<Content> {
        let hostingController = UIHostingController(rootView: view)

        if let parent = parent {
            parent.addChild(hostingController)
            parent.view.addSubview(hostingController.view)

            // Configure constraints
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: parent.view.safeAreaLayoutGuide.topAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: parent.view.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: parent.view.trailingAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: parent.view.bottomAnchor)
            ])

            hostingController.didMove(toParent: parent)
        }

        return hostingController
    }

    // MARK: - Create SwiftUI View in Navigation Controller
    static func createNavigationController<Content: View>(
        for view: Content,
        title: String? = nil,
        prefersLargeTitles: Bool = false
    ) -> UINavigationController {
        let hostingController = UIHostingController(rootView: view)
        let navigationController = UINavigationController(rootViewController: hostingController)

        navigationController.title = title
        navigationController.navigationBar.prefersLargeTitles = prefersLargeTitles

        return navigationController
    }

    // MARK: - Present SwiftUI Modally
    static func presentSwiftUIView<Content: View>(
        _ view: Content,
        from presentingViewController: UIViewController,
        animated: Bool = true,
        completion: (() -> Void)? = nil
    ) {
        let hostingController = UIHostingController(rootView: view)
        let navigationController = UINavigationController(rootViewController: hostingController)

        presentingViewController.present(navigationController, animated: animated, completion: completion)
    }
}

// MARK: - UIViewControllerRepresentable Wrappers
struct UIKitViewControllerWrapper<ViewController: UIViewController>: UIViewControllerRepresentable {

    let viewController: ViewController
    let configure: (ViewController) -> Void

    init(
        _ viewController: ViewController,
        configure: @escaping (ViewController) -> Void = { _ in }
    ) {
        self.viewController = viewController
        self.configure = configure
    }

    func makeUIViewController(context: Context) -> ViewController {
        configure(viewController)
        return viewController
    }

    func updateUIViewController(_ uiViewController: ViewController, context: Context) {
        configure(uiViewController)
    }
}

// MARK: - Specific Bridge Components for Lengyan
struct SutraTreeNavigationWrapper: UIViewControllerRepresentable {
    let onDismiss: (() -> Void)?

    func makeUIViewController(context: Context) -> SutraIndexViewController {
        let treeViewController = SutraIndexViewController()
        treeViewController.onDismiss = onDismiss
        return treeViewController
    }

    func updateUIViewController(_ uiViewController: SutraIndexViewController, context: Context) {
        // Update if needed
    }
}

struct SutraPageCurlWrapper: UIViewControllerRepresentable {
    let path: String
    let onDismiss: (() -> Void)?

    func makeUIViewController(context: Context) -> SutraPurePageViewController {
        let pageViewController = SutraPurePageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal,
            options: nil
        )
        pageViewController.path = path
        pageViewController.onDismiss = onDismiss
        return pageViewController
    }

    func updateUIViewController(_ uiViewController: SutraPurePageViewController, context: Context) {
        uiViewController.path = path
    }
}

struct AudioPlayerWrapper: UIViewControllerRepresentable {
    let onDismiss: (() -> Void)?

    func makeUIViewController(context: Context) -> UIViewController {
        // Create your existing audio player view controller here
        // This would be your current audio implementation
        let audioVC = UIViewController()
        audioVC.title = "聽經"
        audioVC.onDismiss = onDismiss
        return audioVC
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Update if needed
    }
}

// MARK: - SwiftUI Navigation Integration
extension UINavigationController {
    func pushViewController<Content: View>(
        _ view: Content,
        animated: Bool = true
    ) {
        let hostingController = UIHostingController(rootView: view)
        pushViewController(hostingController, animated: animated)
    }
}

// MARK: - Tab Bar Integration
struct ModernTabBarView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Reading Tab - Keep UIKit for performance
            UIKitViewControllerWrapper(SutraIndexViewController())
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("閱讀")
                }
                .tag(0)

            // Audio Tab - Keep UIKit for stability
            AudioPlayerWrapper()
                .tabItem {
                    Image(systemName: "headphones")
                    Text("聽經")
                }
                .tag(1)

            // Favorites Tab - SwiftUI for beauty
            ModernFavoritesView()
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("收藏")
                }
                .tag(2)
        }
        .accentColor(LengyanDesignSystem.Colors.accentGold)
    }
}

// MARK: - Modern Favorites View (SwiftUI)
struct ModernFavoritesView: View {
    @StateObject private var themeManager = ThemeManager()
    @State private var favorites: [FavoriteItem] = []
    @State private var searchText = ""
    @State private var selectedCategory = "全部"

    private let categories = ["全部", "經文", "註解", "音頻"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Header
                favoritesHeader

                // Favorites Content
                if filteredFavorites.isEmpty {
                    emptyStateView
                } else {
                    favoritesGrid
                }
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("收藏")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var favoritesHeader: some View {
        VStack(spacing: 16) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(themeManager.secondaryTextColor)

                TextField("搜索收藏内容...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .lengyanMaterialCard()

            // Category Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(categories, id: \.self) { category in
                        Button(action: { selectedCategory = category }) {
                            Text(category)
                                .font(LengyanDesignSystem.Typography.uiCaption)
                                .foregroundColor(selectedCategory == category ? .white : themeManager.primaryTextColor)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(selectedCategory == category ? LengyanDesignSystem.Colors.accentGold : LengyanDesignSystem.Colors.accentGold.opacity(0.1))
                                )
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var favoritesGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 16) {
                ForEach(filteredFavorites) { favorite in
                    FavoriteCardView(favorite: favorite)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "heart")
                .font(.system(size: 48))
                .foregroundColor(themeManager.secondaryTextColor)

            Text("暂无收藏内容")
                .font(LengyanDesignSystem.Typography.uiHeading)
                .foregroundColor(themeManager.primaryTextColor)

            Text("开始阅读并收藏您喜欢的经文内容")
                .font(LengyanDesignSystem.Typography.uiBody)
                .foregroundColor(themeManager.secondaryTextColor)
                .multilineTextAlignment(.center)
        }
        .padding(48)
    }

    private var filteredFavorites: [FavoriteItem] {
        favorites.filter { favorite in
            (selectedCategory == "全部" || favorite.category == selectedCategory) &&
            (searchText.isEmpty || favorite.title.localizedCaseInsensitiveContains(searchText))
        }
    }
}

// MARK: - Favorite Card Component
struct FavoriteCardView: View {
    let favorite: FavoriteItem
    @StateObject private var themeManager = ThemeManager()
    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category Badge
            Text(favorite.category)
                .font(LengyanDesignSystem.Typography.uiSmall)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(categoryColor)
                )

            // Title
            Text(favorite.title)
                .font(LengyanDesignSystem.Typography.uiBody)
                .foregroundColor(themeManager.primaryTextColor)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Spacer()

            // Date and Heart
            HStack {
                Text(favorite.date)
                    .font(LengyanDesignSystem.Typography.uiSmall)
                    .foregroundColor(themeManager.secondaryTextColor)

                Spacer()

                Button(action: { /* Toggle favorite */ }) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                }
            }
        }
        .padding(16)
        .frame(height: 140)
        .lengyanMaterialCard()
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }
    }

    private var categoryColor: Color {
        switch favorite.category {
        case "經文": return LengyanDesignSystem.Colors.accentBlue
        case "註解": return LengyanDesignSystem.Colors.success
        case "音頻": return LengyanDesignSystem.Colors.warning
        default: return LengyanDesignSystem.Colors.secondaryText
        }
    }
}

// MARK: - Data Models
struct FavoriteItem: Identifiable {
    let id = UUID()
    let title: String
    let category: String
    let date: String
}

// MARK: - Preview
struct LengyanSwiftUIBridge_Previews: PreviewProvider {
    static var previews: some View {
        ModernTabBarView()
            .previewDisplayName("Modern Tab Bar")

        ModernFavoritesView()
            .previewDisplayName("Modern Favorites")
    }
}