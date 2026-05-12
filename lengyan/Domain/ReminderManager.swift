//
//  ReminderManager.swift
//  lengyan
//
//  每日提醒通知管理 — 每日推送经文金句
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

        let baseHour = Prefers.shared.reminderHour
        let baseMinute = Prefers.shared.reminderMinute
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for index in 0..<ReminderManager.maxScheduleDays {
            guard let triggerDate = calendar.date(byAdding: .day, value: index, to: today) else { continue }

            // identifier包含日期，绝对唯一，同一天不会产生两条
            let dateStr = stringFromDate(triggerDate)
            let identifier = "\(ReminderManager.idPrefix)\(dateStr)"

            let path = DailyVerseProvider.shared.getPath(for: triggerDate)
            let item = Book.shared.itemOfPath(path)
            let title = "今日读经"
            let body = Book.shared.getSutra(item, maxLength: 80)
            let cleanBody = cleanNotificationBody(body)

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = cleanBody
            content.sound = nil
            content.userInfo = ["path": path]

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
