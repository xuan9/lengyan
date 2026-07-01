//
//  DailyVerseWidget.swift
//  LengyanWidget
//
//  今日读经小组件 — 可读经文 + 主题感知
//  支持三种桌面尺寸 + 一种 Lock Screen/StandBy 经文卡片：
//    小：短段经文
//    中：经文段落
//    大：完整经文段落（~300字）+ 出处 + 「点击阅读」引导
//    accessoryRectangular — 锁屏经句卡片
//
//  数据源：主App通过 App Group UserDefaults 写入
//  更新策略：每日凌晨刷新
//

import WidgetKit
import SwiftUI

// MARK: - 动态字号计算

/// 按字数与可用空间，算出「能容下全部经文的最大字号」。
/// 填满优先：短经文放大到上限，长经文回落到底线；绝不跌破 minSize。
///
/// - Parameters:
///   - charCount: 经文字数（CJK 全角，每字宽 ≈ 1em = 字号）
///   - availableWidth: 经文区可用宽（逻辑点，已扣除 padding）
///   - availableHeight: 经文区可用高
///   - lineSpacing: 行距（pt），与 .lineSpacing 修饰符一致
///   - minSize: 可读底线字号
///   - maxSize: 美学上限字号
/// - Returns: 夹取在 [minSize, maxSize] 的最佳字号
///
/// 推导：CJK 楷体每字宽 ≈ 字号，行高 ≈ 字号 + lineSpacing。
///   每行字数 = floor(availableWidth / size)
///   最多行数 = floor(availableHeight / (size + lineSpacing))
///   容量 = 每行字数 × 最多行数 ≥ charCount
/// 从 maxSize 向下递减，首个满足容量的即为答案。
func dynamicFontSize(
    charCount: Int,
    availableWidth: CGFloat,
    availableHeight: CGFloat,
    lineSpacing: CGFloat,
    minSize: CGFloat,
    maxSize: CGFloat
) -> CGFloat {
    // 候选字号：从大到小，步长 1pt 精细搜索
    var best = minSize
    var size = maxSize
    while size >= minSize {
        let charsPerLine = max(1, Int(availableWidth / size))
        let lineHeight = size + lineSpacing
        let maxLines = max(1, Int(availableHeight / lineHeight))
        let capacity = charsPerLine * maxLines
        if capacity >= charCount {
            best = size
            break
        }
        size -= 1
    }
    return best
}

// MARK: - Timeline Entry

struct DailyVerseEntry: TimelineEntry {
    let date: Date
    let text: String
    let fullText: String
    let source: String
    let path: String
    let theme: String
    let isPlaceholder: Bool
    /// 主App尚未授记过今日经文 — 显示优雅空态而非伪数据
    let needsOnboarding: Bool

    /// 首次占位：极简留白金句（首次添加 Widget 第一印象）
    static let placeholder = DailyVerseEntry(
        date: Date(),
        text: "常住真心 · 性净明体",
        fullText: "一切众生从无始来，生死相续，皆由不知常住真心性净明体。",
        source: "卷一 · 七处征心",
        path: "",
        theme: "sepia",
        isPlaceholder: true,
        needsOnboarding: false
    )

    /// 内置兜底：主App 已运行过但当日数据缺失时使用
    static let fallback = DailyVerseEntry(
        date: Date(),
        text: "常住真心 · 性净明体",
        fullText: "一切众生从无始来，生死相续，皆由不知常住真心性净明体，用诸妄想，此想不真，故有轮转。",
        source: "卷一 · 七处征心",
        path: "/A2/B1/C2/D1/E2/F1/G1/H1/I1/J2",
        theme: "sepia",
        isPlaceholder: false,
        needsOnboarding: false
    )

    /// 优雅空态：用户尚未打开主App授记
    static let onboarding = DailyVerseEntry(
        date: Date(),
        text: "",
        fullText: "",
        source: "",
        path: "",
        theme: "sepia",
        isPlaceholder: false,
        needsOnboarding: true
    )
}

// MARK: - Timeline Provider

struct DailyVerseTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyVerseEntry {
        return .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyVerseEntry) -> Void) {
        let entry = loadEntry(for: Date()) ?? .onboarding
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyVerseEntry>) -> Void) {
        var entries: [DailyVerseEntry] = []
        let calendar = Calendar.current
        let today = Date()

        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let entryDate = offset == 0 ? today : calendar.startOfDay(for: date)

            if let entry = loadEntry(for: date, entryDate: entryDate) {
                entries.append(entry)
            } else if offset == 0 {
                // 今日数据缺失：若 App Group 完全为空，显示空态引导；
                // 否则用 fallback 经文保持 Widget 气质
                let entry: DailyVerseEntry
                if SharedVerseData.isEmpty {
                    entry = DailyVerseEntry.onboarding.copyWith(date: entryDate)
                } else {
                    entry = DailyVerseEntry.fallback.copyWith(date: entryDate)
                }
                entries.append(entry)
            }
        }

        // 次日凌晨刷新 — 「晨钟」意象必须日日更新
        let nextUpdate: Date
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
           let dawn = calendar.date(bySettingHour: 0, minute: 5, second: 0, of: tomorrow) {
            nextUpdate = dawn
        } else {
            nextUpdate = calendar.date(byAdding: .hour, value: 6, to: today) ?? today
        }
        let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
        completion(timeline)
    }

    /// 从 App Group UserDefaults 加载特定日期的经文
    private func loadEntry(for lookupDate: Date, entryDate: Date? = nil) -> DailyVerseEntry? {
        guard let data = SharedVerseData.load(for: lookupDate) else { return nil }
        WidgetTokens.resolveTheme(from: data.theme)
        return DailyVerseEntry(
            date: entryDate ?? lookupDate,
            text: data.text,
            fullText: data.effectiveFullText,
            source: data.source,
            path: data.path,
            theme: data.effectiveTheme,
            isPlaceholder: false,
            needsOnboarding: false
        )
    }
}

private extension DailyVerseEntry {
    func copyWith(date: Date) -> DailyVerseEntry {
        DailyVerseEntry(
            date: date,
            text: text,
            fullText: fullText,
            source: source,
            path: path,
            theme: theme,
            isPlaceholder: isPlaceholder,
            needsOnboarding: needsOnboarding
        )
    }
}

// MARK: - Small Widget View

struct SmallVerseView: View {
    let entry: DailyVerseEntry

    var body: some View {
        ZStack {
            WidgetTokens.background

            if entry.needsOnboarding {
                EmptyStateView(compact: true)
            } else {
                // 小尺寸也按经文段落排版：左对齐、紧凑留白。
                GeometryReader { proxy in
                    let horizontalPadding: CGFloat = 10
                    let verticalPadding: CGFloat = 9
                    let sutra = entry.compactText
                    let size = dynamicFontSize(
                        charCount: sutra.count,
                        availableWidth: max(CGFloat(80), proxy.size.width - horizontalPadding * 2),
                        availableHeight: max(CGFloat(80), proxy.size.height - verticalPadding * 2),
                        lineSpacing: 3.5,
                        minSize: 12.5,
                        maxSize: 13.5
                    )
                    Text(sutra)
                        .font(WidgetTokens.sutraFont(size: size))
                        .foregroundColor(WidgetTokens.sutraText)
                        .lineSpacing(3.5)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.9)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, verticalPadding)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
        .widgetURL(entry.url)
    }
}

// MARK: - Medium Widget View

struct MediumVerseView: View {
    let entry: DailyVerseEntry

    var body: some View {
        ZStack {
            WidgetTokens.background

            if entry.needsOnboarding {
                EmptyStateView(compact: false)
            } else {
                GeometryReader { proxy in
                    let horizontalPadding: CGFloat = 18
                    let verticalPadding: CGFloat = 14
                    let sutra = entry.mediumText
                    let size = dynamicFontSize(
                        charCount: sutra.count,
                        availableWidth: max(CGFloat(240), proxy.size.width - horizontalPadding * 2),
                        availableHeight: max(CGFloat(110), proxy.size.height - verticalPadding * 2),
                        lineSpacing: 5,
                        minSize: 13.5,
                        maxSize: 14.5
                    )
                    Text(sutra)
                        .font(WidgetTokens.sutraFont(size: size))
                        .foregroundColor(WidgetTokens.sutraText)
                        .lineSpacing(5)
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.9)
                        .padding(.horizontal, horizontalPadding)
                        .padding(.vertical, verticalPadding)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            }
        }
        .widgetURL(entry.url)
    }
}

// MARK: - Large Widget View — 可读经文

struct LargeVerseView: View {
    let entry: DailyVerseEntry

    var body: some View {
        ZStack(alignment: .leading) {
            WidgetTokens.background

            if entry.needsOnboarding {
                EmptyStateView(compact: false)
            } else {
                // 主内容 — 顶部题眉 + 正文 + 底部卷名页脚（细发丝线分隔）
                VStack(alignment: .center, spacing: 0) {
                    // 经卷题眉 — 全名「大佛顶首楞嚴經」，庄重不单薄
                    Text("大佛顶首楞嚴經")
                        .font(WidgetTokens.sutraFont(size: 13))
                        .foregroundColor(WidgetTokens.textTertiary)
                        .tracking(3)
                        .padding(.top, 18)
                        .padding(.bottom, 18)

                    // 经文正文 — 左对齐，紧随题眉
                    sutraBody
                        .padding(.horizontal, 4)

                    Spacer(minLength: 12)

                    // 卷名页脚 — 细发丝线 + 极淡小字，提供每日定位感
                    if !entry.source.isEmpty {
                        VStack(spacing: 8) {
                            hairlineDivider
                            Text(entry.source)
                                .font(WidgetTokens.bodyFont(size: 11, weight: .regular))
                                .foregroundColor(WidgetTokens.textTertiary)
                                .tracking(1)
                        }
                        .padding(.bottom, 16)
                    }
                }
                .padding(.leading, 18)
                .padding(.trailing, 18)
            }
        }
        .widgetURL(entry.url)
    }

    /// 卷名页脚上方的细发丝线 — 克制装饰，不抢经文
    private var hairlineDivider: some View {
        Rectangle()
            .fill(WidgetTokens.textTertiary.opacity(0.3))
            .frame(width: 28, height: 0.5)
    }

    /// 经文正文：统一字号线性连贯 — 不再把首句当「破题」标题，
    /// 否则会把「阿难，…」一句完整的话砍成标题+正文两截，割裂阅读。
    /// 动态字号：大组件可以比小/中组件稍大，但仍优先容纳完整段落。
    @ViewBuilder
    private var sutraBody: some View {
        let raw = entry.fullText.isEmpty ? entry.text : entry.fullText.normalized
        // 底线 14pt：300 字极限经文仍可容下；上限 17pt 避免短段落过度放大。
        let size = dynamicFontSize(
            charCount: raw.count,
            availableWidth: 320,
            availableHeight: 290,
            lineSpacing: 6,
            minSize: 14,
            maxSize: 17
        )
        Text(raw)
            .font(WidgetTokens.sutraFont(size: size))
            .foregroundColor(WidgetTokens.sutraText)
            .lineSpacing(6)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Lock Screen / StandBy Accessories

/// 锁屏顶部一行经句 — StandBy 横屏床头如案头经卷
struct InlineVerseView: View {
    let entry: DailyVerseEntry

    var body: some View {
        if entry.needsOnboarding {
            Text("楞严 · 待启卷")
        } else {
            Text(entry.inlineText)
        }
    }
}

/// 锁屏卡片 — 只放经文，不放出处 footer。
struct RectangularVerseView: View {
    let entry: DailyVerseEntry

    var body: some View {
        if entry.needsOnboarding {
            VStack(alignment: .leading, spacing: 4) {
                Text("楞严经")
                    .font(.system(size: 13, weight: .semibold))
                Text("请先打开主App启卷")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            GeometryReader { proxy in
                let text = entry.lockScreenText
                let size = dynamicFontSize(
                    charCount: text.count,
                    availableWidth: max(CGFloat(120), proxy.size.width),
                    availableHeight: max(CGFloat(48), proxy.size.height),
                    lineSpacing: 1.5,
                    minSize: 10.5,
                    maxSize: 12.5
                )
                Text(text)
                    .font(WidgetTokens.sutraFont(size: size))
                    .foregroundColor(.primary)
                    .lineSpacing(1.5)
                    .lineLimit(4)
                    .minimumScaleFactor(0.9)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Empty State (优雅空态)

private struct EmptyStateView: View {
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 6 : 10) {
            Spacer()
            Text("楞")
                .font(WidgetTokens.sutraFont(size: compact ? 28 : 36))
                .foregroundColor(WidgetTokens.decorativeGold.opacity(0.6))
            Text("请先打开楞严一次")
                .font(WidgetTokens.bodyFont(size: 11, weight: .regular))
                .foregroundColor(WidgetTokens.textTertiary)
                .tracking(1)
            Spacer()
        }
    }
}

// MARK: - Entry Helpers

private extension DailyVerseEntry {
    /// 去除换行，便于行内显示
    var normalizedText: String {
        text.replacingOccurrences(of: "\n", with: "")
    }

    /// 完整段落（去换行后），优先 fullText
    var fullBodyText: String {
        (fullText.isEmpty ? text : fullText).normalized
    }

    /// Small 专用：短段经文。小组件空间有限，但不要做成大字标语。
    var compactText: String {
        clippedFullText(limit: 58)
    }

    /// Medium 专用：约 120 字完整段落，减少中号组件无意义空白。
    /// 按句号切分，累计到上限；不够则硬截断。
    var mediumText: String {
        let limit = 120
        let src = fullBodyText
        if src.count <= limit { return src }
        // 按完整句子（。；！？）累计
        var result = ""
        let chars = Array(src)
        var buffer = ""
        for ch in chars {
            buffer.append(ch)
            if "。；！？".contains(ch) {
                if (result + buffer).count <= limit {
                    result += buffer
                    buffer = ""
                } else {
                    break
                }
            }
        }
        if result.isEmpty {
            // 无合适句号切分点，硬截断
            let end = src.index(src.startIndex, offsetBy: limit - 2, limitedBy: src.endIndex) ?? src.endIndex
            return String(src[..<end]) + "…"
        }
        return result
    }

    /// inline 用一行短文本，避免锁屏顶部截断。
    var inlineText: String {
        clippedFullText(limit: 24)
    }

    /// rectangular 锁屏卡片只放经文，不放 footer，给三行留足内容。
    var lockScreenText: String {
        clippedFullText(limit: 52)
    }

    private func clippedFullText(limit: Int) -> String {
        let src = fullBodyText
        if src.count <= limit { return src }
        let head = String(src.prefix(limit))
        if let sentenceEnd = head.lastIndex(where: { "。；！？".contains($0) }) {
            return String(head[...sentenceEnd])
        }
        if let comma = head.lastIndex(where: { "，、".contains($0) }) {
            return String(head[..<comma]) + "…"
        }
        let end = src.index(src.startIndex, offsetBy: max(1, limit - 1), limitedBy: src.endIndex) ?? src.endIndex
        return String(src[..<end]) + "…"
    }

    var sourceShort: String {
        // "卷一 · 七处征心" → "卷一"
        if let idx = source.range(of: " · ") {
            return String(source[..<idx.lowerBound])
        }
        return source
    }

    var url: URL? {
        guard !path.isEmpty else { return nil }
        return URL(string: "lengyan://verse?path=\(path)")
    }
}

private extension String {
    /// 规范化：去换行、合并空白
    var normalized: String {
        replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Widget Configuration

struct DailyVerseWidget: Widget {
    let kind: String = "DailyVerseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyVerseTimelineProvider()) { entry in
            if #available(iOS 17.0, iOSApplicationExtension 17.0, *) {
                WidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        WidgetTokens.background
                    }
            } else {
                WidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("今日读经")
        .description("每天一段楞严经文，可放在桌面或锁屏。")
        .supportedFamilies(supportedFamilies)
        .disableContentMarginsIfNeeded()
    }

    private var supportedFamilies: [WidgetFamily] {
        var families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
        if #available(iOS 16.0, iOSApplicationExtension 16.0, *) {
            families.append(.accessoryRectangular)
        }
        return families
    }
}

/// 根据 Widget 尺寸自动选择视图
struct WidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: DailyVerseEntry

    var body: some View {
        let _ = WidgetTokens.resolveTheme(from: entry.theme)
        return Group {
            widgetContent
        }
    }

    @ViewBuilder
    private var widgetContent: some View {
        if #available(iOS 16.0, iOSApplicationExtension 16.0, *) {
            switch family {
            case .systemSmall:
                SmallVerseView(entry: entry)
            case .systemMedium:
                MediumVerseView(entry: entry)
            case .systemLarge:
                LargeVerseView(entry: entry)
            case .accessoryRectangular:
                RectangularVerseView(entry: entry)
            default:
                MediumVerseView(entry: entry)
            }
        } else {
            switch family {
            case .systemSmall:
                SmallVerseView(entry: entry)
            case .systemMedium:
                MediumVerseView(entry: entry)
            case .systemLarge:
                LargeVerseView(entry: entry)
            default:
                MediumVerseView(entry: entry)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct DailyVerseWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SmallVerseView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("小尺寸")

            MediumVerseView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("中尺寸")

            LargeVerseView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .systemLarge))
                .previewDisplayName("大尺寸")

            RectangularVerseView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
                .previewDisplayName("锁屏·卡片")

            // 空态预览
            SmallVerseView(entry: .onboarding)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("空态·小")
        }
    }
}
#endif

// MARK: - WidgetConfiguration Helper

extension WidgetConfiguration {
    func disableContentMarginsIfNeeded() -> some WidgetConfiguration {
        #if compiler(>=5.9)
        if #available(iOS 17.0, *) {
            return self.contentMarginsDisabled()
        }
        #endif
        return self
    }
}
