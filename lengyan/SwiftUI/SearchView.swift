//
//  SearchView.swift
//  lengyan
//
//  全文搜索界面 — 合并结果 + 搜索历史 + 关键词建议
//

import SwiftUI

// MARK: - 搜索关键词建议

private let defaultSearchKeywords: [String] = [
    "如来藏", "真心", "妙明", "妙真如性", "因缘", "和合", "虚空",
    "客尘", "生灭", "菩提", "涅槃", "妄想", "圆通",
    "反闻闻自性", "歇即菩提"
]

// MARK: - 按压反馈（复刻 UIKit zen 手感：轻缩 + 微透 + 弹簧回弹）

private struct SutraPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - FlowLayout

struct FlowLayout: View {
    var spacing: CGFloat = 10
    var items: [String]
    var availableWidth: CGFloat
    var onTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(computeRows(), id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(row, id: \.self) { text in
                        tagView(text)
                    }
                }
            }
        }
    }

    private func tagView(_ text: String) -> some View {
        Button(action: {
            HapticManager.shared.lightTap()
            onTap(text)
        }) {
            Text(text)
                .font(SutraTypographyBridge.uiSmall(weight: .regular))
                .foregroundColor(SutraDesignSystem.color(.textSecondary))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(SutraDesignSystem.color(.decorativeGold).opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(SutraDesignSystem.color(.decorativeGold).opacity(0.15), lineWidth: 0.5)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8).inset(by: -4))
        }
        .buttonStyle(SutraPressableStyle())
        .accessibilityLabel(String(format: L10n.str("search_accessibility_search_format"), text))
        .accessibilityHint(L10n.str("search_accessibility_fill_hint"))
    }

    @MainActor
    private func computeRows() -> [[String]] {
        let font = SutraTypographyManager.shared.uiFont(for: .uiSmall, weight: .regular)
        let tagHPadding: CGFloat = 28
        let screenWidth = availableWidth - 32 // 减去左右 padding 16*2

        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentWidth: CGFloat = 0

        for text in items {
            let textWidth = (text as NSString).size(withAttributes: [.font: font]).width
            let itemWidth = textWidth + tagHPadding

            if currentWidth + itemWidth > screenWidth, !currentRow.isEmpty {
                rows.append(currentRow)
                currentRow = []
                currentWidth = 0
            }
            currentRow.append(text)
            currentWidth += itemWidth + spacing
        }
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        return rows
    }
}

// MARK: - SearchHostingController

class SearchHostingController: UIHostingController<SearchView> {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
}

// MARK: - 键盘收起

extension View {
    @ViewBuilder
    func dismissKeyboardOnScroll() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(.interactively)
        } else {
            self
        }
    }
}

// MARK: - SearchView

struct SearchView: View {
    @State private var query = ""
    @State private var results: [MergedSearchResult] = []
    @State private var recentSearches: [String] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var searchCompleted = false
    @FocusState private var isSearchFieldFocused: Bool

    var onDismiss: (() -> Void)?
    var onNavigate: ((MergedSearchResult) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            if query.isEmpty || !searchCompleted {
                emptyState
            } else if results.isEmpty {
                noResultsState
            } else {
                resultList
            }
        }
        .background(SutraDesignSystem.backgroundColor())
        .onAppear {
            isSearchFieldFocused = true
            recentSearches = Prefers.shared.searchHistory
        }
        .onChange(of: query) { newValue in
            searchCompleted = false
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                performSearch(newValue)
            }
        }
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack(spacing: 12) {
            // 返回按钮 — dismiss 整个 modal
            Button(action: {
                HapticManager.shared.lightTap()
                dismissModal()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(SutraDesignSystem.color(.textPrimary))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SutraPressableStyle())
            .accessibilityLabel(L10n.str("search_accessibility_back"))

            // 输入框
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(SutraDesignSystem.color(.textSecondary))

                TextField(L10n.str("search_placeholder"), text: $query)
                    .font(SutraTypographyBridge.uiBody(weight: .regular))
                    .foregroundColor(SutraDesignSystem.color(.textPrimary))
                    .focused($isSearchFieldFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        recordSearch(query)
                        isSearchFieldFocused = false
                    }

                if !query.isEmpty {
                    Button(action: {
                        HapticManager.shared.lightTap()
                        query = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(SutraDesignSystem.color(.textSecondary))
                            .frame(width: 28, height: 28)
                            .contentShape(Circle())
                    }
                    .buttonStyle(SutraPressableStyle())
                    .accessibilityLabel(L10n.str("search_clear"))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(SutraDesignSystem.color(.card))
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(SutraDesignSystem.color(.navigationBar))
    }

    // MARK: - 空状态（搜索历史 + 关键词建议）

    private var emptyState: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // 最近搜索
                    if !recentSearches.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(L10n.str("search_recent"))
                                    .font(SutraTypographyBridge.uiCaption(weight: .regular))
                                    .foregroundColor(SutraDesignSystem.color(.textSecondary))
                                Spacer()
                                Button(action: {
                                    HapticManager.shared.lightTap()
                                    Prefers.shared.clearSearchHistory()
                                    recentSearches = []
                                }) {
                                    Text(L10n.str("search_clear"))
                                        .font(SutraTypographyBridge.uiSmall(weight: .light))
                                        .foregroundColor(SutraDesignSystem.color(.textTertiary))
                                }
                                .buttonStyle(SutraPressableStyle())
                                .accessibilityLabel(L10n.str("search_clear_history"))
                            }
                            FlowLayout(spacing: 8, items: recentSearches, availableWidth: geo.size.width) { term in
                                query = term
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // 楞严关键词建议
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.str("search_classic_keywords"))
                            .font(SutraTypographyBridge.uiCaption(weight: .regular))
                            .foregroundColor(SutraDesignSystem.color(.textSecondary))
                        FlowLayout(
                            spacing: 10,
                            items: localizedSearchKeywords,
                            availableWidth: geo.size.width
                        ) { keyword in
                            query = keyword
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 40)
                }
                .padding(.top, 24)
            }
            .dismissKeyboardOnScroll()
        }
    }

    // MARK: - 无结果

    private var noResultsState: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 60)

                    VStack(spacing: 8) {
                        Text(String(format: L10n.str("search_no_results_format"), query))
                            .font(SutraTypographyBridge.uiBody(weight: .regular))
                            .foregroundColor(SutraDesignSystem.color(.textSecondary))
                        Text(L10n.str("search_try_another_keyword"))
                            .font(SutraTypographyBridge.uiSmall(weight: .regular))
                            .foregroundColor(SutraDesignSystem.color(.textTertiary))
                    }

                    // 保留关键词建议，把挫败转化为引导
                    FlowLayout(
                        spacing: 10,
                        items: localizedSearchKeywords,
                        availableWidth: geo.size.width
                    ) { keyword in
                        query = keyword
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)

                    Spacer(minLength: 40)
                }
                .frame(maxWidth: .infinity)
            }
            .dismissKeyboardOnScroll()
        }
    }

    // MARK: - 结果列表

    private var resultList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if query.count == 1, !refinementSuggestions.isEmpty {
                    refinementGuideBar
                }
                ForEach(results) { result in
                    resultCard(result)
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 20)
            .readingContentWidth()
        }
        .dismissKeyboardOnScroll()
    }

    // MARK: - 结果卡片（收藏风格，左侧竖条 + 内容 + 出处）

    private func resultCard(_ result: MergedSearchResult) -> some View {
        // 竖条颜色：纯科判命中用金色，其余用绿色
        let isOutlineOnly = result.hasOutline && !result.sutraHit
        let capsuleColor = isOutlineOnly
            ? Color(SutraDesignTokens.shared.color(for: .decorativeGold))
            : Color(SutraDesignTokens.shared.color(for: .primary))

        return Button(action: {
            HapticManager.shared.lightTap()
            navigateToResult(result)
        }) {
            HStack(spacing: 0) {
                Capsule()
                    .fill(capsuleColor.opacity(0.7))
                    .frame(width: 3)
                    .padding(.vertical, 6)

                VStack(alignment: .leading, spacing: 4) {
                    // 科判命中（合并卡片中的次要信息 / 纯科判卡片的主要内容）
                    if let outlineText = result.outlineMatch {
                        highlightedText(outlineText, query: query, highlightColor: SutraDesignSystem.color(.decorativeGold))
                            .font(.system(size: isOutlineOnly ? 15 : 12, weight: isOutlineOnly ? .regular : .light))
                            .foregroundColor(isOutlineOnly
                                ? SutraDesignSystem.color(.textPrimary)
                                : SutraDesignSystem.color(.textSecondary))
                            .lineLimit(1)
                    }

                    // 经文片段（命中时高亮，补充上下文时不高亮）
                    if let sutraText = result.sutraMatch {
                        Group {
                            if result.sutraHit {
                                highlightedText(sutraText, query: query, highlightColor: SutraDesignSystem.color(.decorativeGold))
                            } else {
                                Text(sutraText)
                            }
                        }
                        .font(SutraTypographyBridge.uiBody(weight: .regular))
                        .foregroundColor(SutraDesignSystem.color(.textPrimary))
                        .lineLimit(2)
                        .lineSpacing(4)
                    }

                    // 出处
                    HStack {
                        Spacer()
                        Text(result.chapterName)
                            .font(.system(size: 11, weight: .light))
                            .foregroundColor(SutraDesignSystem.color(.textSecondary))
                            .lineLimit(1)
                    }
                }
                .padding(.leading, 14)
                .padding(.trailing, 16)
                .padding(.vertical, 12)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(SutraDesignTokens.shared.color(for: .card)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                LinearGradient(
                                    colors: [capsuleColor.opacity(0.15), capsuleColor.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    )
            )
        }
        .buttonStyle(SutraPressableStyle())
        .accessibilityElement(children: .combine)
    }

    // MARK: - 高亮关键词

    private func highlightedText(_ text: String, query: String, highlightColor: Color) -> Text {
        guard !query.isEmpty else { return Text(text) }

        let simplifiedText = text.simplified
        let simplifiedQuery = query.simplified

        var result = Text("")
        var remainingText = text
        var remainingSimplifiedText = simplifiedText

        while let range = remainingSimplifiedText.range(of: simplifiedQuery, options: .caseInsensitive) {
            let beforeStartIndex = remainingText.startIndex
            let beforeEndIndex = remainingText.index(beforeStartIndex, offsetBy: remainingSimplifiedText.distance(from: remainingSimplifiedText.startIndex, to: range.lowerBound))
            
            let before = String(remainingText[beforeStartIndex..<beforeEndIndex])
            if !before.isEmpty {
                result = result + Text(before)
            }
            
            let matchEndIndex = remainingText.index(beforeEndIndex, offsetBy: remainingSimplifiedText.distance(from: range.lowerBound, to: range.upperBound))
            let match = String(remainingText[beforeEndIndex..<matchEndIndex])
            result = result + Text(match).foregroundColor(highlightColor).fontWeight(.semibold)
            
            remainingText = String(remainingText[matchEndIndex...])
            remainingSimplifiedText = String(remainingSimplifiedText[range.upperBound...])
        }
        
        if !remainingText.isEmpty {
            result = result + Text(remainingText)
        }
        return result
    }

    // MARK: - 搜索

    private func performSearch(_ query: String) {
        guard !query.isEmpty else {
            results = []
            return
        }
        var all = SearchService.shared.mergedSearch(query: query)
        if all.count > 50 { all = Array(all.prefix(50)) }
        results = all
        searchCompleted = true
        // 不在此记录历史 — debounce 会捕获 IME 中间态（拼音 / 部分字）
    }

    /// 仅在用户明确确认搜索意图时记录（提交 / 点选结果），过滤输入法中间态
    private func recordSearch(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespaces)
        guard containsChinese(trimmed) else { return }  // 挡掉纯拼音 / 字母残留
        Prefers.shared.addSearchQuery(trimmed)
        recentSearches = Prefers.shared.searchHistory
    }

    private func containsChinese(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) }
    }

    /// 单字搜索时，从关键词表中找出含该字的精炼词，引导用户精准定位
    private var refinementSuggestions: [String] {
        guard query.count == 1 else { return [] }
        let singleChar = query.simplified
        return localizedSearchKeywords.filter { keyword in
            keyword.simplified.contains(singleChar) && keyword.simplified != singleChar
        }
    }

    private var localizedSearchKeywords: [String] {
        defaultSearchKeywords.map { Book.shared.isSimplifiedChinese ? $0.simplified : $0.traditional }
    }

    // MARK: - 单字精炼引导条

    private var refinementGuideBar: some View {
        HStack(spacing: 6) {
            Text(String(format: L10n.str("search_refinement_format"), query))
                .font(SutraTypographyBridge.uiSmall(weight: .regular))
                .foregroundColor(SutraDesignSystem.color(.textTertiary))

            ForEach(refinementSuggestions, id: \.self) { word in
                Button(action: {
                    HapticManager.shared.lightTap()
                    query = word
                }) {
                    Text(word)
                        .font(SutraTypographyBridge.uiSmall(weight: .medium))
                        .foregroundColor(SutraDesignSystem.color(.decorativeGold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(SutraDesignSystem.color(.decorativeGold).opacity(0.08))
                        )
                }
                .buttonStyle(SutraPressableStyle())
                .accessibilityLabel(String(format: L10n.str("search_accessibility_search_format"), word))
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    // MARK: - 导航

    private func dismissModal() {
        isSearchFieldFocused = false
        searchTask?.cancel()
        if let onDismiss {
            onDismiss()
        } else {
            assertionFailure("SearchView.onDismiss not set — caller should provide it")
            // 兜底：直接 dismiss presenting VC
            (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
                .windows.first?.rootViewController?.dismiss(animated: true)
        }
    }

    private func navigateToResult(_ result: MergedSearchResult) {
        recordSearch(query)
        isSearchFieldFocused = false
        if let onNavigate {
            onNavigate(result)
        } else {
            assertionFailure("SearchView.onNavigate not set — caller should provide it")
        }
    }
}
