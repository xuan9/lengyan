//
//  SharedVerseData.swift
//  lengyan
//
//  主App ↔ Widget 共享的每日经文数据
//  通过 App Group UserDefaults 传递
//  key: "widget_daily_verse"
//

import Foundation

/// Widget 与 App 共享的经文数据
/// 编码为 JSON 存入 App Group UserDefaults
struct SharedVerseData: Codable {
    let text: String         // 经文片段（≤40字）
    let source: String       // 来源标注 "卷二 · 十番显见"
    let path: String         // 科判路径，用于深链
    let dateString: String   // "2026-05-08"，用于判断是否过期

    /// App Group identifier
    static let appGroupID = "group.org.fuxuan.lengyan"

    /// UserDefaults key
    static let defaultsKey = "widget_daily_verse"

    /// 从 App Group UserDefaults 读取
    static func load() -> SharedVerseData? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: defaultsKey) else {
            return nil
        }
        return try? JSONDecoder().decode(SharedVerseData.self, from: data)
    }

    /// 写入 App Group UserDefaults
    func save() {
        guard let defaults = UserDefaults(suiteName: SharedVerseData.appGroupID),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: SharedVerseData.defaultsKey)
    }

    /// 判断是否今日数据
    var isToday: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayStr = formatter.string(from: Date())
        return dateString == todayStr
    }
}
