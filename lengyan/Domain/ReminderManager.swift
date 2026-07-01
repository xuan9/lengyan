//
//  ReminderManager.swift
//  lengyan
//
//  每日提醒通知管理 — 每日在通知中心显示一段经文
//  绝对防重复：identifier = daily_sutra_yyyyMMdd，每天唯一
//  调度60天，kill/打开/多天不用都不会重复
//

import UserNotifications

class ReminderManager {
    static let shared = ReminderManager()
    static let reminderStateDidChange = Notification.Name("ReminderManager.reminderStateDidChange")

    /// 调度天数
    private static let maxScheduleDays = 60

    /// identifier前缀
    private static let idPrefix = "daily_sutra_"

    private init() {}

    // MARK: - 权限请求 + 调度

    /// 请求通知权限并调度。`completion` 在主线程回调是否授权成功，
    /// 调用方可据此同步 UI 状态（拒绝时回滚开关、引导去设置）。
    func requestPermissionAndSchedule(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    Prefers.shared.isDailyReminderOn = true
                    self.scheduleDaily()
                } else {
                    Prefers.shared.isDailyReminderOn = false
                }
                NotificationCenter.default.post(name: ReminderManager.reminderStateDidChange, object: nil)
                completion?(granted)
            }
        }
    }

    /// 当前通知授权状态（异步，主线程回调）。
    func authorizationStatus(_ handler: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                handler(settings.authorizationStatus)
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
            
            let isSimplified = Book.shared.isSimplifiedChinese
            let title = isSimplified ? "今日读经" : "今日讀經"
            
            let body = Book.shared.getSutra(item, maxLength: 80)
            let cleanBody = cleanNotificationBody(body)

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = cleanBody
            content.sound = nil
            content.categoryIdentifier = "DAILY_SUTRA_CATEGORY"
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
        NotificationCenter.default.post(name: ReminderManager.reminderStateDidChange, object: nil)
    }

    // MARK: - 日期格式化

    private func stringFromDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f.string(from: date)
    }

    // MARK: - 清理通知文本

    private func cleanNotificationBody(_ text: String) -> String {
        // 保留经文原味（含「佛言：」「阿难！」等呼语，是经文的语境与口吻），仅去空白、超长截断
        var result = text.trimmingCharacters(in: .whitespaces)
        if result.count > 80 {
            result = String(result.prefix(77)) + "…"
        }
        return result
    }
}
