//
//  DailyVerseWidget.swift
//  LengyanWidget
//
//  今日读经桌面小组件 — 可读经文 + 主题感知
//  支持三种尺寸：
//    小：经文金句（≤20字）+ 出处
//    中：经文段落 + 装饰线 + 出处
//    大：完整经文段落（~300字）+ 出处 + "点击阅读" 提示
//
//  数据源：主App通过 App Group UserDefaults 写入
//  更新频率：每日凌晨刷新
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct DailyVerseEntry: TimelineEntry {
    let date: Date
    let text: String
    let fullText: String
    let source: String
    let path: String
    let theme: String
    let isPlaceholder: Bool

    static let placeholder = DailyVerseEntry(
        date: Date(),
        text: "一切众生从无始来生死相续皆由不知常住真心性净明体",
        fullText: "一切众生从无始来，生死相续，皆由不知常住真心性净明体，用诸妄想，此想不真，故有轮转。",
        source: "卷一 · 七处征心",
        path: "",
        theme: "sepia",
        isPlaceholder: true
    )

    static let fallback = DailyVerseEntry(
        date: Date(),
        text: "狂心若歇 歇即菩提",
        fullText: "狂心若歇，歇即菩提。一切众生从无始来，生死相续，皆由不知常住真心性净明体，用诸妄想，此想不真，故有轮转。",
        source: "楞严经",
        path: "/A2/B1/C2/D1/E2/F1/G1/H1/I1/J2",
        theme: "sepia",
        isPlaceholder: false
    )
}

// MARK: - Timeline Provider

struct DailyVerseProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyVerseEntry {
        return .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyVerseEntry) -> Void) {
        let entry = loadEntry(for: Date()) ?? .fallback
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
                var fallbackEntry = DailyVerseEntry.fallback
                fallbackEntry = DailyVerseEntry(
                    date: entryDate,
                    text: fallbackEntry.text,
                    fullText: fallbackEntry.fullText,
                    source: fallbackEntry.source,
                    path: fallbackEntry.path,
                    theme: fallbackEntry.theme,
                    isPlaceholder: false
                )
                entries.append(fallbackEntry)
            }
        }

        // 下一次大更新：7天后，但 iOS 会在 App 被打开调用 reloadAllTimelines 时刷新
        let nextUpdate = calendar.date(byAdding: .day, value: 7, to: today)!
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
            isPlaceholder: false
        )
    }
}

// MARK: - Small Widget View

struct SmallVerseView: View {
    let entry: DailyVerseEntry

    var body: some View {
        ZStack {
            WidgetTokens.background

            VStack(spacing: 4) {
                Spacer(minLength: 2)

                // 经文 — 尽量多放
                Text(entry.text.replacingOccurrences(of: "\n", with: ""))
                    .font(WidgetTokens.sutraFont(size: 14))
                    .foregroundColor(WidgetTokens.sutraText)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 10)

                Spacer(minLength: 2)

                // 来源
                Text(entry.source)
                    .font(WidgetTokens.bodyFont(size: 9, weight: .regular))
                    .foregroundColor(WidgetTokens.textTertiary)

                Spacer(minLength: 4)
            }
        }
        .widgetURL(url)
    }

    private var url: URL? {
        URL(string: "lengyan://verse?path=\(entry.path)")
    }
}

// MARK: - Medium Widget View

struct MediumVerseView: View {
    let entry: DailyVerseEntry

    var body: some View {
        ZStack {
            WidgetTokens.background

            VStack(alignment: .leading, spacing: 6) {
                // 顶部标签
                HStack(spacing: 4) {
                    Text("✧")
                        .font(.system(size: 8))
                        .foregroundColor(WidgetTokens.decorativeGold.opacity(0.6))
                    Text("今日读经")
                        .font(WidgetTokens.bodyFont(size: 10, weight: .medium))
                        .foregroundColor(WidgetTokens.textTertiary)
                        .tracking(2)
                    Spacer()
                }
                .padding(.top, 14)

                // 经文段落 — 充分利用空间
                Text(entry.text.replacingOccurrences(of: "\n", with: ""))
                    .font(WidgetTokens.sutraFont(size: 15))
                    .foregroundColor(WidgetTokens.sutraText)
                    .lineSpacing(6)
                    .lineLimit(5)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 2)

                // 底部来源
                HStack {
                    Spacer()
                    decorativeLine
                    Text(entry.source)
                        .font(WidgetTokens.bodyFont(size: 10, weight: .regular))
                        .foregroundColor(WidgetTokens.textTertiary)
                        .tracking(1)
                    decorativeLine
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 16)
        }
        .widgetURL(url)
    }

    private var decorativeLine: some View {
        Rectangle()
            .fill(WidgetTokens.decorativeGold.opacity(0.25))
            .frame(width: 16, height: 0.5)
    }

    private var url: URL? {
        URL(string: "lengyan://verse?path=\(entry.path)")
    }
}

// MARK: - Large Widget View — 可读经文

struct LargeVerseView: View {
    let entry: DailyVerseEntry

    var body: some View {
        ZStack {
            WidgetTokens.background

            VStack(spacing: 0) {
                Spacer(minLength: 12)

                // 顶部装饰
                HStack(spacing: 6) {
                    topLine
                    Text("✧ 今日读经 ✧")
                        .font(WidgetTokens.bodyFont(size: 11, weight: .medium))
                        .foregroundColor(WidgetTokens.textTertiary)
                        .tracking(3)
                    topLine
                }

                Spacer(minLength: 10)

                // 经文正文 — 最大化空间利用
                Text(entry.fullText.replacingOccurrences(of: "\n", with: ""))
                    .font(WidgetTokens.sutraFont(size: 15))
                    .foregroundColor(WidgetTokens.sutraText)
                    .lineSpacing(6)
                    .multilineTextAlignment(.leading)
                    .lineLimit(14)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 16)

                Spacer(minLength: 8)

                // 来源标注
                HStack(spacing: 6) {
                    bottomLine
                    Text("── \(entry.source) ──")
                        .font(WidgetTokens.bodyFont(size: 11, weight: .regular))
                        .foregroundColor(WidgetTokens.textTertiary)
                        .tracking(1.5)
                    bottomLine
                }

                Spacer(minLength: 8)

                // 底部引导
                HStack {
                    Spacer()
                    Text("点击阅读全文 →")
                        .font(WidgetTokens.bodyFont(size: 11, weight: .medium))
                        .foregroundColor(WidgetTokens.decorativeGold.opacity(0.7))
                    Spacer()
                }

                Spacer(minLength: 10)
            }
        }
        .widgetURL(url)
    }

    private var topLine: some View {
        Rectangle()
            .fill(WidgetTokens.decorativeGold.opacity(0.25))
            .frame(width: 30, height: 0.5)
    }

    private var bottomLine: some View {
        Rectangle()
            .fill(WidgetTokens.decorativeGold.opacity(0.2))
            .frame(width: 20, height: 0.5)
    }

    private var url: URL? {
        URL(string: "lengyan://verse?path=\(entry.path)")
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
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
