//
//  SearchView.swift
//  lengyan
//
//  全文搜索界面 — 与科判行同风格
//

import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var results: [SearchResult] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            searchBar

            // 结果列表 / 空状态
            if query.isEmpty {
                emptyState
            } else if results.isEmpty {
                noResultsState
            } else {
                resultList
            }
        }
        .background(SutraDesignSystem.backgroundColor())
        .onChange(of: query) { newValue in
            performSearch(newValue)
        }
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack(spacing: 12) {
            // 返回按钮 — 与阅读页返回一致
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(SutraDesignSystem.color(.textPrimary))
            }

            // 输入框
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(SutraDesignSystem.color(.textSecondary))

                TextField("搜索经文...", text: $query)
                    .font(SutraTypographyBridge.uiBody(weight: .regular))
                    .foregroundColor(SutraDesignSystem.color(.textPrimary))

                if !query.isEmpty {
                    Button(action: { query = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(SutraDesignSystem.color(.textSecondary))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(SutraDesignTokens.shared.color(for: .card)))
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(SutraDesignSystem.color(.navigationBar))
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("❀")
                .font(.system(size: 36))
                .foregroundColor(SutraDesignSystem.color(.textSecondary).opacity(0.5))
            Text("输入关键词搜索科判与经文")
                .font(SutraTypographyBridge.uiCaption(weight: .regular))
                .foregroundColor(SutraDesignSystem.color(.textSecondary))
            Spacer()
        }
    }

    // MARK: - 无结果

    private var noResultsState: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("未找到相关内容")
                .font(SutraTypographyBridge.uiBody(weight: .regular))
                .foregroundColor(SutraDesignSystem.color(.textSecondary))
            Spacer()
        }
    }

    // MARK: - 结果列表

    private var resultList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(results) { result in
                    resultRow(result)
                }
            }
            .padding(.top, 8)
        }
    }

    private func resultRow(_ result: SearchResult) -> some View {
        let primary = SutraDesignSystem.color(.primary)

        return VStack(alignment: .leading, spacing: 4) {
            // 匹配文本（高亮关键词）
            HStack(spacing: 0) {
                Text("• ")
                    .foregroundColor(Color(SutraDesignTokens.shared.color(for: .decorativeGold)))

                highlightedText(result.matchedText, query: query, highlightColor: primary)
            }
            .font(SutraTypographyBridge.uiBody(weight: .regular))
            .foregroundColor(SutraDesignSystem.color(.textPrimary))

            // 出处
            HStack {
                Spacer()
                Text(result.chapterName)
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(SutraDesignSystem.color(.textSecondary))
            }
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            navigateToResult(result)
        }
    }

    // MARK: - 高亮关键词

    private func highlightedText(_ text: String, query: String, highlightColor: Color) -> Text {
        guard !query.isEmpty else { return Text(text) }

        var result = Text("")
        var remaining = text
        while let range = remaining.range(of: query) {
            // 前段
            let before = String(remaining[remaining.startIndex..<range.lowerBound])
            if !before.isEmpty {
                result = result + Text(before)
            }
            // 高亮段
            let match = String(remaining[range])
            result = result + Text(match).foregroundColor(highlightColor)
            // 继续搜
            remaining = String(remaining[range.upperBound...])
        }
        if !remaining.isEmpty {
            result = result + Text(remaining)
        }
        return result
    }

    // MARK: - 搜索

    private func performSearch(_ query: String) {
        guard query.count >= 2 else {
            results = []
            return
        }
        results = SearchService.shared.search(query: query)
    }

    // MARK: - 导航

    private func navigateToResult(_ result: SearchResult) {
        // dismiss 完成后再导航，避免时序问题
        guard let presentingVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?
            .rootViewController?
            .presentedViewController else { return }

        presentingVC.dismiss(animated: true) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let tabBarController = window.rootViewController as? UITabBarController,
                  let navigationController = tabBarController.selectedViewController as? UINavigationController else { return }

            // 切到阅读 tab
            tabBarController.selectedIndex = 0

            // 查找 path 对应的 page index
            if let pageIndex = Book.shared.index?.firstIndex(where: { item in
                item["path"] == result.path
            }) {
                let pageVC = SutraPageViewController(transitionStyle: .pageCurl, navigationOrientation: .horizontal, options: nil)
                pageVC.page = pageIndex
                navigationController.setNavigationBarHidden(false, animated: false)
                navigationController.pushViewController(pageVC, animated: true)
            } else {
                // 按科判路径打开
                let sutraVC = SutraPurePageViewController(transitionStyle: .pageCurl, navigationOrientation: .horizontal, options: nil)
                sutraVC.path = result.path
                sutraVC.onDismiss = {
                    navigationController.setNavigationBarHidden(false, animated: false)
                }
                navigationController.setNavigationBarHidden(false, animated: false)
                navigationController.pushViewController(sutraVC, animated: true)
            }
        }
    }
}
