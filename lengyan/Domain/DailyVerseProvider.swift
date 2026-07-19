//
//  DailyVerseProvider.swift
//  lengyan
//
//  今日读经数据提供者 — 增长飞轮的内容引擎
//  从 ReminderManager 提取共享的选偈逻辑
//  确保同一天返回同一句，支持近7天回溯
//

import Foundation
import WidgetKit

/// 每日经文数据模型
struct DailyVerse {
    let path: String           // 科判路径，用于深读导航
    let text: String           // 经文片段 (≤40字)
    let fullText: String       // 经文段落 (~300字，供 Widget 长阅读)
    let source: String         // 来源标注，如"卷二 · 十番显见"
    let isBookmarked: Bool     // 当前收藏状态
    let date: Date             // 对应日期
}

/// 每日经文提供者
/// 基于日期的确定性轮换算法，同一天总是返回同一句经文
final class DailyVerseProvider {
    private struct VerseSelectionSnapshot {
        let userLikes: [String]
        let lastReadPath: String?

        func contains(_ path: String) -> Bool {
            userLikes.contains(path)
        }
    }

    private struct WidgetSyncSnapshot {
        let theme: String
        let selection: VerseSelectionSnapshot
    }

    static let shared = DailyVerseProvider()
    private static let widgetSyncQueue = DispatchQueue(
        label: "org.fuxuan.lengyan.widget-data-sync",
        qos: .utility
    )
    /// Keep the Lock Screen useful even when the reader does not open the App
    /// for a while. This matches the 60-day reminder horizon.
    static let widgetScheduleDays = SharedVerseData.scheduleDays
    private static let widgetKind = "DailyVerseWidget"
    private static let scheduleLock = NSLock()
    private let widgetTimelineReloader: () -> Void

    private init() {
        widgetTimelineReloader = {
            if #available(iOS 14.0, *) {
                WidgetCenter.shared.reloadTimelines(ofKind: DailyVerseProvider.widgetKind)
            }
        }
    }

    /// Internal initializer for testing the Widget reload side effect.
    init(widgetTimelineReloader: @escaping () -> Void) {
        self.widgetTimelineReloader = widgetTimelineReloader
    }

    // MARK: - Public API

    /// 今日经文
    func todayVerse() -> DailyVerse? {
        verse(for: Date())
    }

    /// 近期经文（今日 + 过去7天 = 最多8张）
    func recentVerses() -> [DailyVerse] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var verses: [DailyVerse] = []

        for dayOffset in 0..<8 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today),
                  let verse = verse(for: date) else { continue }
            verses.append(verse)
        }
        return verses
    }

    /// 主动同步到 Widget（AppDelegate 启动时调用）。
    /// - Returns: 共享数据有变化并已请求 Widget 刷新时为 `true`。
    @discardableResult
    func syncWidgetData() -> Bool {
        let snapshot = captureWidgetSyncSnapshot()
        return Self.widgetSyncQueue.sync {
            performWidgetDataSync(snapshot: snapshot)
        }
    }

    /// Refresh Widget data without retaining or racing mutable preferences.
    func syncWidgetDataAsync() {
        let snapshot = captureWidgetSyncSnapshot()
        Self.widgetSyncQueue.async { [self] in
            _ = performWidgetDataSync(snapshot: snapshot)
        }
    }

    private func performWidgetDataSync(snapshot: WidgetSyncSnapshot) -> Bool {
        var verses: [SharedVerseData] = []
        let calendar = Calendar.current
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for offset in 0..<Self.widgetScheduleDays {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today),
                  let v = verse(for: date, selection: snapshot.selection) else { continue }
            
            let shared = SharedVerseData(
                text: v.text,
                fullText: v.fullText,
                source: v.source,
                path: v.path,
                dateString: formatter.string(from: date),
                theme: snapshot.theme
            )
            verses.append(shared)
        }

        // Never replace a valid offline schedule with partial data. The serial
        // queue makes comparison, write, and reload one atomic sync operation.
        guard verses.count == Self.widgetScheduleDays,
              SharedVerseData.saveIfChanged(verses: verses) else {
            return false
        }

        // Refresh only this Widget kind, and only after its payload changed.
        widgetTimelineReloader()
        return true
    }

    // MARK: - Persistent Schedule
    private let scheduleKey = "DailyVerseSchedule"
    private var scheduledVerses: [String: String] {
        get { UserDefaults.standard.dictionary(forKey: scheduleKey) as? [String: String] ?? [:] }
        set { UserDefaults.standard.set(newValue, forKey: scheduleKey) }
    }

    /// 获取特定日期的锁定路径，供内部和 ReminderManager 使用
    func getPath(for date: Date) -> String {
        getPath(for: date, selection: captureVerseSelectionSnapshot())
    }

    private func getPath(for date: Date, selection: VerseSelectionSnapshot) -> String {
        Self.scheduleLock.lock()
        defer { Self.scheduleLock.unlock() }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: date)
        
        var schedule = self.scheduledVerses
        if let savedPath = schedule[dateStr] {
            return savedPath
        }
        
        var pool = buildPool(userLikes: selection.userLikes)
        if let lastRead = selection.lastReadPath {
            pool.removeAll { $0 == lastRead }
        }
        if pool.isEmpty {
            pool = [DEFAULT_STARTS.first ?? "/A1/B1/C1"]
        }
        
        // 使用自 Unix 纪元以来的天数，无缝跨越月份
        let epochDays = Int(date.timeIntervalSince1970 / 86400)
        let idx = epochDays % pool.count
        let path = pool[idx]
        
        schedule[dateStr] = path
        
        // 清理过期的记录防止无限增长
        if schedule.count > 100 {
            let sortedKeys = schedule.keys.sorted()
            let oldKeys = sortedKeys.dropLast(80)
            for k in oldKeys { schedule.removeValue(forKey: k) }
        }
        self.scheduledVerses = schedule
        
        return path
    }

    // MARK: - Core Selection Logic

    /// 为指定日期选取经文
    private func verse(for date: Date) -> DailyVerse? {
        verse(for: date, selection: captureVerseSelectionSnapshot())
    }

    private func verse(for date: Date, selection: VerseSelectionSnapshot) -> DailyVerse? {
        guard Book.shared.loaded else { return nil }

        // 获取确定性的路径
        let path = getPath(for: date, selection: selection)

        let item = Book.shared.itemOfPath(path)
        let rawFullText = Book.shared.getSutra(item, maxLength: 300)
        let fullText = cleanVerse(rawFullText)
        
        // 智能语义截取：在 55 字以内截取最长完整语义句，确保不以 "..." 或逗号生硬结尾
        let text = semanticTruncate(rawFullText, maxLength: 55)
        
        let source = buildSource(for: item, path: path)
        let isBookmarked = selection.contains(path)

        return DailyVerse(
            path: path,
            text: text,
            fullText: fullText,
            source: source,
            isBookmarked: isBookmarked,
            date: date
        )
    }

    // MARK: - Pool Construction

    /// 构建经文池：精选 + 用户收藏（去重）
    private func buildPool(userLikes: [String]) -> [String] {
        var pool = DEFAULT_STARTS
        for bookmark in userLikes {
            if !pool.contains(bookmark) {
                pool.append(bookmark)
            }
        }
        return pool
    }

    private func captureWidgetSyncSnapshot() -> WidgetSyncSnapshot {
        let capture = {
            WidgetSyncSnapshot(
                theme: SutraDesignTokens.shared.currentTheme.rawValue,
                selection: self.makeVerseSelectionSnapshot()
            )
        }
        if Thread.isMainThread {
            return capture()
        }
        return DispatchQueue.main.sync(execute: capture)
    }

    private func captureVerseSelectionSnapshot() -> VerseSelectionSnapshot {
        let capture = { self.makeVerseSelectionSnapshot() }
        if Thread.isMainThread {
            return capture()
        }
        return DispatchQueue.main.sync(execute: capture)
    }

    private func makeVerseSelectionSnapshot() -> VerseSelectionSnapshot {
        let lastReadPath: String?
        switch Prefers.shared.outlineResumeTarget {
        case let .paged(path, _), let .tree(path):
            lastReadPath = path
        case .chapter, nil:
            lastReadPath = nil
        }
        return VerseSelectionSnapshot(
            userLikes: Prefers.shared.userLikes,
            lastReadPath: lastReadPath
        )
    }

    // MARK: - Date Hashing

    /// 计算自 Unix 纪元以来的天数，保证同一天返回相同索引
    private func dayIndex(for date: Date) -> Int {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let epoch = calendar.startOfDay(for: Date(timeIntervalSince1970: 0))
        let days = calendar.dateComponents([.day], from: epoch, to: startOfDay).day ?? 0
        return abs(days)
    }

    // MARK: - Text Processing

    /// 智能语义截取：在指定的长度限制内，寻找最后一个完整标点符号切分，避免出现半句话
    private func semanticTruncate(_ text: String, maxLength: Int) -> String {
        let clean = cleanVerse(text)
        if clean.count <= maxLength {
            return clean
        }
        
        // 寻找限制长度范围内的最后一个结句标点或逗号
        let substring = String(clean.prefix(maxLength))
        let punctuations: [Character] = ["。", "；", "！", "？", "，", "；", "、", ";", "!", "?", ","]
        
        if let lastIdx = substring.lastIndex(where: { punctuations.contains($0) }) {
            let truncated = String(substring[...lastIdx])
            
            // 如果原本就是句号、叹号、问号等完整的结句，则原样保留，说明该句本身已完结
            if truncated.hasSuffix("。") || truncated.hasSuffix("！") || truncated.hasSuffix("？") ||
               truncated.hasSuffix("!") || truncated.hasSuffix("?") {
                return truncated
            }
            
            // 如果是逗号、分号、顿号等未完结符号，去掉它并追加 "..."，表明经文未完，敬重原典完整性
            if truncated.hasSuffix("，") || truncated.hasSuffix("、") || truncated.hasSuffix("；") ||
               truncated.hasSuffix(",") || truncated.hasSuffix(";") {
                return String(truncated.dropLast()) + "..."
            }
            
            return truncated + "..."
        }
        
        // 如果确实没有任何标点符号，则退回到截断并补齐省略号
        return String(substring.prefix(maxLength - 3)) + "..."
    }

    /// 清理经文前缀（佛言、阿难等称谓），使卡片上直接呈现核心内容
    private func cleanVerse(_ text: String) -> String {
        var result = text

        let prefixes = [
            "佛言：", "佛告阿难：", "阿难！", "阿难白佛言：",
            "佛言：富楼那！", "文殊！", "尔时，",
            "即时阿难在大众中，", "于是阿难及诸大众，",
        ]
        for prefix in prefixes {
            if result.hasPrefix(prefix) {
                result = String(result.dropFirst(prefix.count))
                break
            }
        }

        // 去除换行，卡片上显示为连续文本
        result = result.replacingOccurrences(of: "\n", with: "")
        result = result.trimmingCharacters(in: .whitespaces)

        return result
    }

    // MARK: - Source Attribution

    /// 构建来源标注："卷二 · 十番显见"
    private func buildSource(for item: [String: Any], path: String) -> String {
        // 从路径推断卷号
        let chapterNumber = extractChapterNumber(from: path)
        let chapterLabel = chapterNumber.map { "卷\(chineseNumber($0))" } ?? ""

        // 获取科判名
        let name = item["name"] as? String ?? ""

        // 如果科判名太长，取父级名称
        var sectionName = name
        if sectionName.count > 8 {
            if let parent = Book.shared.parentOfItem(item),
               let parentName = parent["name"] as? String,
               parentName.count <= 8 {
                sectionName = parentName
            } else {
                sectionName = String(sectionName.prefix(8))
            }
        }

        if !chapterLabel.isEmpty && !sectionName.isEmpty {
            return "\(chapterLabel) · \(sectionName)"
        } else if !chapterLabel.isEmpty {
            return chapterLabel
        } else {
            return sectionName
        }
    }

    /// 从路径提取卷号（1-10）
    private func extractChapterNumber(from path: String) -> Int? {
        guard Book.shared.loaded, let chapterMap = Book.shared.chapterMap else { return nil }

        for (chapterStr, paths) in chapterMap {
            for chapterPath in paths {
                if path.hasPrefix(chapterPath) || chapterPath.hasPrefix(path) {
                    return Int(chapterStr)
                }
            }
        }
        return nil
    }

    /// 阿拉伯数字 → 中文数字
    private func chineseNumber(_ n: Int) -> String {
        let map = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
        if n >= 1 && n <= 10 { return map[n] }
        return "\(n)"
    }
}
