//
//  SharedVerseData.swift
//  LengyanWidget
//
//  主App ↔ Widget 共享的每日经文数据
//  通过 App Group UserDefaults 传递
//  key: "lengyan_widget_daily_verse"
//

import Foundation

/// Widget 与 App 共享的经文数据
/// 编码为 JSON 存入 App Group UserDefaults
struct SharedVerseData: Codable {
    let text: String         // 短文本 ~40字（小/中 Widget）
    let fullText: String?    // 长文本 ~300字（大 Widget 可读段落）
    let source: String       // 来源标注 "卷二 · 十番显见"
    let path: String         // 科判路径，用于深链
    let dateString: String   // "2026-05-08"，用于判断是否过期
    let theme: String?       // "light" | "sepia" | "dark"

    /// App Group identifier
    static let appGroupID = "group.org.fuxuan.books"

    /// UserDefaults key
    static let defaultsKey = "lengyan_widget_daily_verse"

    /// 从 App Group 读取特定日期的经文
    static func load(for date: Date = Date()) -> SharedVerseData? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: defaultsKey),
              let array = try? JSONDecoder().decode([SharedVerseData].self, from: data) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let targetStr = formatter.string(from: date)

        return array.first { $0.dateString == targetStr }
    }

    /// App Group 是否完全为空 — 区分「未授记」与「当日数据缺失」
    /// 为空表示用户尚未打开过主App，Widget 应显示优雅空态而非伪数据
    static var isEmpty: Bool {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: defaultsKey),
              let array = try? JSONDecoder().decode([SharedVerseData].self, from: data) else {
            return true
        }
        return array.isEmpty
    }

    /// 批量写入未来多天的经文到 App Group
    static func save(verses: [SharedVerseData]) {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = try? JSONEncoder().encode(verses) else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    /// 判断是否今日数据
    var isToday: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())
        return dateString == todayStr
    }

    /// 可读长文本，fallback 到短文本
    var effectiveFullText: String {
        if let full = fullText, !full.isEmpty {
            return full
        }
        return text
    }

    /// 有效主题，fallback 到 sepia（App 默认）
    var effectiveTheme: String {
        theme ?? "sepia"
    }
}
