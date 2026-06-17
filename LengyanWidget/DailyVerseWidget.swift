//
//  DailyVerseWidget.swift
//  LengyanWidget
//
//  今日读经桌面小组件 — 可读经文 + 主题感知
//  支持三种尺寸 + 三种 Lock Screen/StandBy 配件：
//    小：经文金句（≤20字）+ 出处
//    中：经文段落 + 法卷金线 + 出处
//    大：完整经文段落（~300字）+ 出处 + 「点击阅读」引导
//    accessoryInline    — 锁屏顶部一行经句
//    accessoryCircular  — 锁屏圆形「楞严」二字
//    accessoryRectangular — 锁屏竖排经句卡片
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

struct DailyVerseProvider: TimelineProvider {
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
                // 极简版式 — 经文居中，去金线点缀，留白即为装裱
                VStack(spacing: 0) {
                    Spacer(minLength: 22)

                    let sutra = entry.smallText
                    // 动态字号：限 3 行（130×84），层级下调为小组件小字
                    let size = dynamicFontSize(
                        charCount: sutra.count,
                        availableWidth: 130,
                        availableHeight: 84,
                        lineSpacing: 4,
                        minSize: 13,
                        maxSize: 19
                    )
                    Text(sutra)
                        .font(WidgetTokens.sutraFont(size: size))
                        .foregroundColor(WidgetTokens.sutraText)
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14)

                    Spacer(minLength: 22)
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
                VStack(alignment: .center, spacing: 0) {
                    // 古意印章题眉 — 「楞嚴」二字，与 Large 同源
                    Text("楞嚴")
                        .font(WidgetTokens.sutraFont(size: 12))
                        .foregroundColor(WidgetTokens.textTertiary)
                        .tracking(8)
                        .padding(.top, 18)

                    Spacer(minLength: 14)

                    // 经文段落左对齐 — 动态字号，填满优先
                    let sutra = entry.mediumText
                    // 可用宽 324pt（364-20×2）、高 ~108pt（170-题眉44-上下spacer）
                    let size = dynamicFontSize(
                        charCount: sutra.count,
                        availableWidth: 324,
                        availableHeight: 108,
                        lineSpacing: 6,
                        minSize: 16,
                        maxSize: 22
                    )
                    Text(sutra)
                        .font(WidgetTokens.sutraFont(size: size))
                        .foregroundColor(WidgetTokens.sutraText)
                        .lineSpacing(6)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 18)
                }
                .padding(.horizontal, 20)
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
                // 主内容 — 顶部对齐：印章题眉固定顶部，正文紧随，剩余空白落底部
                // 短/长经文标题位置都一致，不漂浮
                VStack(alignment: .center, spacing: 0) {
                    // 题眉区（固定顶部留白 + 印章 + 固定间距）
                    Text("楞嚴")
                        .font(WidgetTokens.sutraFont(size: 13))
                        .foregroundColor(WidgetTokens.textTertiary)
                        .tracking(8)
                        .padding(.top, 20)
                        .padding(.bottom, 20)

                    // 经文正文 — 左对齐，紧随题眉
                    sutraBody
                        .padding(.horizontal, 4)

                    // 所有剩余空间统一落到底部，不分散
                    Spacer(minLength: 0)
                }
                .padding(.leading, 18)
                .padding(.trailing, 18)
            }
        }
        .widgetURL(entry.url)
    }

    /// 经文正文：统一字号线性连贯 — 不再把首句当「破题」标题，
    /// 否则会把「阿难，…」一句完整的话砍成标题+正文两截，割裂阅读。
    /// 动态字号：按字数填满可用空间，短经文放大、长经文回落，不跌破 15pt。
    @ViewBuilder
    private var sutraBody: some View {
        let raw = entry.fullText.isEmpty ? entry.text : entry.fullText.normalized
        // 可用宽 320pt、高 ~340pt（题眉极小，经文占满主体）；层级最高 15-26pt
        let size = dynamicFontSize(
            charCount: raw.count,
            availableWidth: 320,
            availableHeight: 340,
            lineSpacing: 6,
            minSize: 15,
            maxSize: 26
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

/// 锁屏圆形 — 「楞严」二字法印
struct CircularVerseView: View {
    let entry: DailyVerseEntry

    var body: some View {
        ZStack {
            if entry.needsOnboarding {
                VStack(spacing: 2) {
                    Text("楞").font(WidgetTokens.sutraFont(size: 22))
                    Text("严").font(WidgetTokens.sutraFont(size: 22))
                }
                .minimumScaleFactor(0.7)
            } else {
                VStack(spacing: 1) {
                    Text("楞")
                        .font(WidgetTokens.sutraFont(size: 22))
                        .foregroundColor(.white)
                    Text("严")
                        .font(WidgetTokens.sutraFont(size: 22))
                        .foregroundColor(.white)
                }
                .minimumScaleFactor(0.7)
                .widgetLabel(entry.sourceShort)
            }
        }
    }
}

/// 锁屏竖排卡片 — 一句经文 + 出处
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
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.inlineText)
                    .font(WidgetTokens.sutraFont(size: 13))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
                Text(entry.source)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
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

    /// Small 专用：完整首句金句，目标 ≤22 字
    /// 按「句号/问号/感叹号」切分取首个完整句（含「阿难，…」呼语），
    /// 不再按逗号切分——否则会把「阿难，」呼语当首句只剩二字。
    /// 超长则在末个逗号处优雅截断，末尾补 …。
    var smallText: String {
        let src = fullBodyText
        // 先取第一个完整句（以 。；！？ 结尾），呼语逗号自然保留在句内
        let firstSentence = src.components(separatedBy: CharacterSet(charactersIn: "。；！？;!?"))
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? src
        if firstSentence.count <= 22 { return firstSentence }
        // 首句过长：回退到 22 字内最后一个逗号处截断，保语义完整
        let head = String(firstSentence.prefix(22))
        if let lastComma = head.lastIndex(where: { $0 == "，" || $0 == "、" }) {
            return String(head[..<lastComma]) + "…"
        }
        // 无逗号可切：硬截断
        let end = firstSentence.index(firstSentence.startIndex, offsetBy: 20, limitedBy: firstSentence.endIndex) ?? firstSentence.endIndex
        return String(firstSentence[..<end]) + "…"
    }

    /// Medium 专用：~80 字完整段落
    /// 按句号切分，累计 ≤78 字；不够则硬截断
    var mediumText: String {
        let src = fullBodyText
        if src.count <= 80 { return src }
        // 按完整句子（。；！？）累计
        var result = ""
        let chars = Array(src)
        var buffer = ""
        for ch in chars {
            buffer.append(ch)
            if "。；！？".contains(ch) {
                if (result + buffer).count <= 80 {
                    result += buffer
                    buffer = ""
                } else {
                    break
                }
            }
        }
        if result.isEmpty {
            // 无合适句号切分点，硬截断
            let end = src.index(src.startIndex, offsetBy: 78, limitedBy: src.endIndex) ?? src.endIndex
            return String(src[..<end]) + "…"
        }
        return result
    }

    /// inline/rectangular 用短文本，避免锁屏截断
    var inlineText: String {
        let trimmed = normalizedText
        if trimmed.count <= 24 { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: 24, limitedBy: trimmed.endIndex) ?? trimmed.endIndex
        return String(trimmed[..<end]) + "…"
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
        StaticConfiguration(kind: kind, provider: DailyVerseProvider()) { entry in
            if #available(iOSApplicationExtension 17.0, *) {
                WidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        WidgetTokens.background
                    }
            } else {
                WidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("今日读经")
        .description("每天一句楞严经文金句，如晨钟暮鼓。")
        .supportedFamilies([
            .systemSmall, .systemMedium, .systemLarge,
            .accessoryInline, .accessoryCircular, .accessoryRectangular
        ])
        .disableContentMarginsIfNeeded()
    }
}

/// 根据 Widget 尺寸自动选择视图
struct WidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: DailyVerseEntry

    var body: some View {
        let _ = WidgetTokens.resolveTheme(from: entry.theme)
        return Group {
            switch family {
            case .systemSmall:
                SmallVerseView(entry: entry)
            case .systemMedium:
                MediumVerseView(entry: entry)
            case .systemLarge:
                LargeVerseView(entry: entry)
            case .accessoryInline:
                InlineVerseView(entry: entry)
            case .accessoryCircular:
                CircularVerseView(entry: entry)
            case .accessoryRectangular:
                RectangularVerseView(entry: entry)
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

            InlineVerseView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .accessoryInline))
                .previewDisplayName("锁屏·行内")

            CircularVerseView(entry: .placeholder)
                .previewContext(WidgetPreviewContext(family: .accessoryCircular))
                .previewDisplayName("锁屏·圆形")

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
