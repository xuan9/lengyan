//
//  ReminderManager.swift
//  lengyan
//
//  每日提醒通知管理 — 每日推送经文偈语
//  绝对防重复：identifier = daily_sutra_yyyyMMdd，每天唯一
//  调度60天，kill/打开/多天不用都不会重复
//

import UserNotifications

class ReminderManager {
    static let shared = ReminderManager()

    /// 调度天数
    private static let maxScheduleDays = 60

    /// identifier前缀
    private static let idPrefix = "daily_sutra_"

    private init() {}

    // MARK: - 权限请求 + 调度

    func requestPermissionAndSchedule() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    Prefers.shared.isDailyReminderOn = true
                    self.scheduleDaily()
                } else {
                    Prefers.shared.isDailyReminderOn = false
                }
            }
        }
    }

    // MARK: - 调度未来60天通知

    func scheduleDaily() {
        let center = UNUserNotificationCenter.current()

        // 先清除所有旧通知，彻底杜绝重复
        center.removeAllPendingNotificationRequests()

        guard Book.shared.loaded else { return }

        let verses = selectVersesForNextDays(count: ReminderManager.maxScheduleDays)
        let baseHour = Prefers.shared.reminderHour
        let baseMinute = Prefers.shared.reminderMinute
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for (index, verse) in verses.enumerated() {
            guard index < ReminderManager.maxScheduleDays else { break }
            guard let triggerDate = calendar.date(byAdding: .day, value: index, to: today) else { continue }

            // identifier包含日期，绝对唯一，同一天不会产生两条
            let dateStr = stringFromDate(triggerDate)
            let identifier = "\(ReminderManager.idPrefix)\(dateStr)"

            let item = Book.shared.itemOfPath(verse)
            let title = item["name"] as? String ?? "楞严经"
            let body = Book.shared.getSutra(item, maxLength: 80)
            let cleanBody = cleanNotificationBody(body)

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = cleanBody
            content.sound = nil
            content.userInfo = ["path": verse]

            var dc = DateComponents()
            dc.hour = baseHour
            dc.minute = baseMinute
            dc.day = calendar.component(.day, from: triggerDate)
            dc.month = calendar.component(.month, from: triggerDate)
            dc.year = calendar.component(.year, from: triggerDate)

            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request)
        }
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - 日期格式化

    private func stringFromDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f.string(from: date)
    }

    // MARK: - 经文选择：精选 + 收藏合并轮换

    private func selectVersesForNextDays(count: Int) -> [String] {
        var pool = DEFAULT_STARTS
        let userBookmarks = Prefers.shared.userLikes
        for bookmark in userBookmarks {
            if !pool.contains(bookmark) {
                pool.append(bookmark)
            }
        }

        // 排除最近读过的经文，避免推送刚读过的内容
        if let lastRead = Prefers.shared.lastReadPath {
            pool.removeAll { $0 == lastRead }
        }

        // 兜底：池子清空了就用默认第一条
        if pool.isEmpty {
            pool = [DEFAULT_STARTS.first ?? "/A1/B1/C1"]
        }

        let dayIndex = Calendar.current.component(.day, from: Date())
        let startIndex = dayIndex % pool.count

        var result: [String] = []
        for i in 0..<count {
            let idx = (startIndex + i) % pool.count
            result.append(pool[idx])
        }
        return result
    }

    // MARK: - 清理通知文本

    private func cleanNotificationBody(_ text: String) -> String {
        var result = text

        let prefixes = [
            "佛言：", "佛告阿难：", "阿难！", "阿难白佛言：",
            "佛言：富楼那！", "文殊！", "尔时",
        ]
        for prefix in prefixes {
            if result.hasPrefix(prefix) {
                result = String(result.dropFirst(prefix.count))
                break
            }
        }

        if result.count > 80 {
            result = String(result.prefix(77)) + "…"
        }

        return result.trimmingCharacters(in: .whitespaces)
    }
}
