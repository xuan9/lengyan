//
//  DailyVerseCardView.swift
//  lengyan
//
//  每日一偈卡片 — 增长飞轮的入口
//  隐喻：早课诵经，每日一句金言
//  交互：左右滑动切换近7天经文
//

import SwiftUI

/// 每日一偈卡片视图
/// 设计：宣纸质感 + 金色引号 + 禅意留白
struct DailyVerseCardView: View {
    /// 点击「阅读」回调，传递 path
    var onRead: ((String) -> Void)?
    /// 点击「分享」回调，传递经文内容和来源
    var onShare: ((String, String) -> Void)?

    @State private var verses: [DailyVerse] = []
    @State private var currentIndex: Int = 0

    var body: some View {
        Group {
            if verses.isEmpty {
                EmptyView()
            } else {
                cardCarousel
            }
        }
        .onAppear {
            loadVerses()
        }
    }

    // MARK: - Carousel

    private var cardCarousel: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(verses.enumerated()), id: \.offset) { index, verse in
                singleCard(verse: verse)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: cardHeight)
        .padding(.horizontal, 16)
    }

    /// 动态卡片高度：基于文字长度
    private var cardHeight: CGFloat {
        guard !verses.isEmpty else { return 180 }
        let textLen = verses[safe: currentIndex]?.text.count ?? 20
        if textLen <= 15 { return 168 }
        if textLen <= 25 { return 192 }
        return 220
    }

    // MARK: - Single Card

    private func singleCard(verse: DailyVerse) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)

            // 经文内容 — 金色引号包裹
            verseText(verse)

            Spacer().frame(height: 12)

            // 来源标注
            sourceLabel(verse)

            Spacer().frame(height: 16)

            // 底部操作栏
            actionBar(verse)

            Spacer().frame(height: 16)
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(cardBorder)
        .shadow(color: SutraDesignSystem.color(.shadow).opacity(0.08), radius: 8, y: 4)
    }

    // MARK: - Verse Text

    private func verseText(_ verse: DailyVerse) -> some View {
        HStack {
            Spacer().frame(width: 24)
            VStack(spacing: 0) {
                // 开引号
                HStack {
                    Text("「")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(SutraDesignSystem.color(.decorativeGold).opacity(0.6))
                    Spacer()
                }
                
                // 经文正文
                Text(verse.text)
                    .font(sutraFont)
                    .foregroundColor(SutraDesignSystem.color(.sutraText))
                    .lineSpacing(10)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)

                // 闭引号
                HStack {
                    Spacer()
                    Text("」")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(SutraDesignSystem.color(.decorativeGold).opacity(0.6))
                }
            }
            Spacer().frame(width: 24)
        }
    }

    // MARK: - Source Label

    private func sourceLabel(_ verse: DailyVerse) -> some View {
        HStack(spacing: 6) {
            // 装饰线
            Rectangle()
                .fill(SutraDesignSystem.color(.decorativeGold).opacity(0.3))
                .frame(width: 20, height: 0.5)

            Text(verse.source)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(SutraDesignSystem.color(.textTertiary))
                .tracking(1.5)

            Rectangle()
                .fill(SutraDesignSystem.color(.decorativeGold).opacity(0.3))
                .frame(width: 20, height: 0.5)
        }
    }

    // MARK: - Action Bar

    private func actionBar(_ verse: DailyVerse) -> some View {
        HStack(spacing: 0) {
            Spacer()

            // 收藏
            actionButton(
                icon: verse.isBookmarked ? "bookmark.fill" : "bookmark",
                label: "收藏",
                color: verse.isBookmarked
                    ? SutraDesignSystem.color(.bookmark)
                    : SutraDesignSystem.color(.textTertiary)
            ) {
                toggleBookmark(verse)
            }

            Spacer()

            // 分享
            actionButton(
                icon: "square.and.arrow.up",
                label: "分享",
                color: SutraDesignSystem.color(.textTertiary)
            ) {
                onShare?(verse.text, verse.source)
            }

            Spacer()

            // 深读
            actionButton(
                icon: "book.pages",
                label: "阅读",
                color: SutraDesignSystem.color(.textTertiary)
            ) {
                onRead?(verse.path)
            }

            Spacer()
        }
    }

    private func actionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .light))
                Text(label)
                    .font(.system(size: 10, weight: .regular))
            }
            .foregroundColor(color)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Background & Border

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(SutraDesignSystem.color(.card))
            // 微妙纹理叠加（模拟宣纸）
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    SutraDesignSystem.color(.surface)
                        .opacity(0.15)
                )
        }
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(
                SutraDesignSystem.color(.decorativeGold).opacity(0.2),
                lineWidth: 0.5
            )
    }

    // MARK: - Font

    private var sutraFont: Font {
        // 尝试使用楷体，回退到系统字体
        if let _ = UIFont(name: "STKaiti", size: 18) {
            return .custom("STKaiti", size: 18)
        }
        return .system(size: 18, weight: .regular)
    }

    // MARK: - Actions

    private func toggleBookmark(_ verse: DailyVerse) {
        HapticManager.shared.bookmarkToggle()
        if verse.isBookmarked {
            Prefers.shared.unlike(verse.path)
        } else {
            Prefers.shared.like(verse.path)
        }
        // 刷新数据
        loadVerses()
    }

    private func loadVerses() {
        verses = DailyVerseProvider.shared.recentVerses()
        currentIndex = 0
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
