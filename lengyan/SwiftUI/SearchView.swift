//
//  SearchView.swift
//  lengyan
//
//  全文搜索界面 — 合并结果 + 搜索历史 + 关键词建议
//

import SwiftUI

// MARK: - 搜索关键词分类

enum SearchSuggestionCategory: String, CaseIterable {
    case core = "核心主旨"
    case doctrine = "义理辩证"
    case practice = "修行观修"
    case terms = "菩提因果"

    var keywords: [String] {
        switch self {
        case .core:     return ["如来藏", "常住真心", "妙真如性", "本非因缘", "虚空"]
        case .doctrine: return ["客尘", "生灭", "知见立知", "演若达多", "第二月"]
        case .practice: return ["反闻闻自性", "歇即菩提", "圆通", "六结", "清净明诲"]
        case .terms:    return ["菩提", "涅槃", "妄想", "轮回", "干慧地"]
        }
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
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(SutraDesignSystem.color(.textSecondary))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        Color(SutraDesignTokens.shared.color(for: .decorativeGold))
                            .opacity(0.08)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        Color(SutraDesignTokens.shared.color(for: .decorativeGold))
                            .opacity(0.15),
                        lineWidth: 0.5
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .onTapGesture { onTap(text) }
    }

    private func computeRows() -> [[String]] {
        let font = UIFont.systemFont(ofSize: 14, weight: .regular)
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
    func dismissKeyboardOnScroll() -> some View {
        self.scrollDismissesKeyboard(.interactively)
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
            Button(action: { dismissModal() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(SutraDesignSystem.color(.textPrimary))
            }

            // 输入框
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(SutraDesignSystem.color(.textSecondary))

                TextField(Book.shared.isSimplifiedChinese ? "搜索经文..." : "搜尋經文...", text: $query)
                    .font(SutraTypographyBridge.uiBody(weight: .regular))
                    .foregroundColor(SutraDesignSystem.color(.textPrimary))
                    .focused($isSearchFieldFocused)
                    .submitLabel(.search)
                    .onSubmit {
                        isSearchFieldFocused = false
                    }

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
                    .stroke(Color(SutraDesignTokens.shared.color(for: .decorativeGold)).opacity(0.3), lineWidth: 0.5)
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
                VStack(spacing: 28) {
                    // 最近搜索
                    if !recentSearches.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(Book.shared.isSimplifiedChinese ? "最近搜索" : "最近搜索".traditional)
                                    .font(SutraTypographyBridge.uiCaption(weight: .regular))
                                    .foregroundColor(SutraDesignSystem.color(.textSecondary))
                                Spacer()
                                Button(action: {
                                    Prefers.shared.clearSearchHistory()
                                    recentSearches = []
                                }) {
                                    Text(Book.shared.isSimplifiedChinese ? "清除" : "清除".traditional)
                                        .font(.system(size: 13, weight: .light))
                                        .foregroundColor(SutraDesignSystem.color(.textTertiary))
                                }
                            }
                            FlowLayout(spacing: 8, items: recentSearches, availableWidth: geo.size.width) { term in
                                query = term
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // 楞严关键词建议
                    VStack(alignment: .leading, spacing: 28) {
                        ForEach(SearchSuggestionCategory.allCases, id: \.self) { category in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(Book.shared.isSimplifiedChinese ? category.rawValue : category.rawValue.traditional)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(SutraDesignSystem.color(.textSecondary))
                                FlowLayout(
                                    spacing: 10,
                                    items: category.keywords.map { Book.shared.isSimplifiedChinese ? $0.simplified : $0.traditional },
                                    availableWidth: geo.size.width
                                ) { keyword in
                                    query = keyword
                                }
                            }
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
        VStack(spacing: 16) {
            Spacer()
            Text(Book.shared.isSimplifiedChinese ? "未找到相关内容" : "未找到相關內容")
                .font(SutraTypographyBridge.uiBody(weight: .regular))
                .foregroundColor(SutraDesignSystem.color(.textSecondary))
            Spacer()
        }
    }

    // MARK: - 结果列表

    private var resultList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
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

        return HStack(spacing: 0) {
            Capsule()
                .fill(capsuleColor.opacity(0.7))
                .frame(width: 3)
                .padding(.vertical, 6)

            VStack(alignment: .leading, spacing: 4) {
                // 科判命中（合并卡片中的次要信息 / 纯科判卡片的主要内容）
                if let outlineText = result.outlineMatch {
                    highlightedText(outlineText, query: query, highlightColor: SutraDesignSystem.color(.primary))
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
                            highlightedText(sutraText, query: query, highlightColor: SutraDesignSystem.color(.primary))
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
        .contentShape(Rectangle())
        .onTapGesture {
            navigateToResult(result)
        }
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
        guard query.count >= 2 else {
            results = []
            return
        }
        results = SearchService.shared.mergedSearch(query: query)
        searchCompleted = true
        Prefers.shared.addSearchQuery(query)
        recentSearches = Prefers.shared.searchHistory
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
        isSearchFieldFocused = false
        if let onNavigate {
            onNavigate(result)
        } else {
            assertionFailure("SearchView.onNavigate not set — caller should provide it")
        }
    }
}
