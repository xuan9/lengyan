//
//  DailyVerseWidget.swift
//  LengyanWidget
//
//  每日一偈桌面小组件 — YouVersion 式留存引擎
//  支持三种尺寸：
//    小：经文金句（≤20字）+ 出处
//    中：经文 + 宣纸纹理背景 + 装饰
//    大：经文 + 白话引导 + "点击阅读" 提示
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
    let source: String
    let path: String
    let isPlaceholder: Bool

    static let placeholder = DailyVerseEntry(
        date: Date(),
        text: "一切众生从无始来\n生死相续皆由不知\n常住真心性净明体",
        source: "卷一 · 七处征心",
        path: "",
        isPlaceholder: true
    )

    static let fallback = DailyVerseEntry(
        date: Date(),
        text: "狂心若歇 歇即菩提",
        source: "楞严经",
        path: "/A2/B1/C2/D1/E2/F1/G1/H1/I1/J2",
        isPlaceholder: false
    )
}

// MARK: - Timeline Provider

struct DailyVerseProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyVerseEntry {
        return .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyVerseEntry) -> Void) {
        let entry = loadEntry() ?? .fallback
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyVerseEntry>) -> Void) {
        let entry = loadEntry() ?? .fallback

        // 下一次更新：明天凌晨 0:05
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date())!)
        let nextUpdate = calendar.date(byAdding: .minute, value: 5, to: tomorrow)!

        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    /// 从 App Group UserDefaults 加载今日经文
    private func loadEntry() -> DailyVerseEntry? {
        guard let data = SharedVerseData.load() else { return nil }
        return DailyVerseEntry(
            date: Date(),
            text: data.text,
            source: data.source,
            path: data.path,
            isPlaceholder: false
        )
    }
}

// MARK: - Small Widget View

struct SmallVerseView: View {
    let entry: DailyVerseEntry

    var body: some View {
        ZStack {
            // 背景
            WidgetTokens.background

            VStack(spacing: 6) {
                Spacer(minLength: 4)

                // 经文 — 紧凑金句
                Text(truncatedText(max: 20))
                    .font(WidgetTokens.sutraFont(size: 14))
                    .foregroundColor(WidgetTokens.sutraText)
                    .lineSpacing(5)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 12)

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

    private func truncatedText(max: Int) -> String {
        let clean = entry.text.replacingOccurrences(of: "\n", with: "")
        if clean.count <= max { return clean }
        return String(clean.prefix(max - 1)) + "…"
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
            // 宣纸纹理背景
            WidgetTokens.background

            HStack(spacing: 0) {
                // 左侧装饰线
                Rectangle()
                    .fill(WidgetTokens.decorativeGold.opacity(0.3))
                    .frame(width: 2)
                    .padding(.vertical, 16)
                    .padding(.leading, 16)

                VStack(alignment: .leading, spacing: 8) {
                    Spacer(minLength: 4)

                    // 顶部标签
                    HStack(spacing: 4) {
                        Text("✧")
                            .font(.system(size: 8))
                            .foregroundColor(WidgetTokens.decorativeGold.opacity(0.6))
                        Text("每日一偈")
                            .font(WidgetTokens.bodyFont(size: 10, weight: .medium))
                            .foregroundColor(WidgetTokens.textTertiary)
                            .tracking(2)
                    }

                    // 经文
                    Text(entry.text.replacingOccurrences(of: "\n", with: ""))
                        .font(WidgetTokens.sutraFont(size: 16))
                        .foregroundColor(WidgetTokens.sutraText)
                        .lineSpacing(6)
                        .lineLimit(3)
                        .minimumScaleFactor(0.75)

                    Spacer(minLength: 2)

                    // 底部来源
                    HStack {
                        decorativeLine
                        Text(entry.source)
                            .font(WidgetTokens.bodyFont(size: 10, weight: .regular))
                            .foregroundColor(WidgetTokens.textTertiary)
                            .tracking(1)
                        decorativeLine
                    }

                    Spacer(minLength: 4)
                }
                .padding(.leading, 12)
                .padding(.trailing, 16)
            }
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

// MARK: - Large Widget View

struct LargeVerseView: View {
    let entry: DailyVerseEntry

    var body: some View {
        ZStack {
            // 背景
            WidgetTokens.background

            // 微妙渐变
            LinearGradient(
                colors: [
                    WidgetTokens.surface.opacity(0.3),
                    .clear,
                    WidgetTokens.decorativeGold.opacity(0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                Spacer(minLength: 16)

                // 顶部装饰
                HStack(spacing: 6) {
                    topLine
                    Text("✧ 每日一偈 ✧")
                        .font(WidgetTokens.bodyFont(size: 11, weight: .medium))
                        .foregroundColor(WidgetTokens.textTertiary)
                        .tracking(3)
                    topLine
                }

                Spacer(minLength: 16)

                // 开引号
                HStack {
                    Text("「")
                        .font(.system(size: 24, weight: .ultraLight))
                        .foregroundColor(WidgetTokens.decorativeGold.opacity(0.5))
                        .padding(.leading, 24)
                    Spacer()
                }

                // 经文正文
                Text(entry.text.replacingOccurrences(of: "\n", with: ""))
                    .font(WidgetTokens.sutraFont(size: 20))
                    .foregroundColor(WidgetTokens.sutraText)
                    .lineSpacing(10)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 28)

                // 闭引号
                HStack {
                    Spacer()
                    Text("」")
                        .font(.system(size: 24, weight: .ultraLight))
                        .foregroundColor(WidgetTokens.decorativeGold.opacity(0.5))
                        .padding(.trailing, 24)
                }

                Spacer(minLength: 12)

                // 来源标注
                HStack(spacing: 6) {
                    bottomLine
                    Text("── \(entry.source) ──")
                        .font(WidgetTokens.bodyFont(size: 11, weight: .regular))
                        .foregroundColor(WidgetTokens.textTertiary)
                        .tracking(1.5)
                    bottomLine
                }

                Spacer(minLength: 16)

                // 底部引导
                HStack {
                    Spacer()
                    Text("点击阅读全文 →")
                        .font(WidgetTokens.bodyFont(size: 11, weight: .medium))
                        .foregroundColor(WidgetTokens.decorativeGold.opacity(0.7))
                    Spacer()
                }

                Spacer(minLength: 12)
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
        .configurationDisplayName("每日一偈")
        .description("每天一句楞严经文金句，如晨钟暮鼓。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// 根据 Widget 尺寸自动选择视图
struct WidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: DailyVerseEntry

    var body: some View {
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
