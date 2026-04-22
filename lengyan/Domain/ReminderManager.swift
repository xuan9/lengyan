//
//  ReminderManager.swift
//  lengyan
//
//  每日提醒通知管理
//

import UserNotifications

class ReminderManager {
    static let shared = ReminderManager()

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

    func scheduleDaily() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let content = UNMutableNotificationContent()
        content.title = "楞严经"
        content.body = "是时候静心诵读了"
        content.sound = nil  // 默认静音
        var dc = DateComponents()
        dc.hour = Prefers.shared.reminderHour
        dc.minute = Prefers.shared.reminderMinute
        center.add(UNNotificationRequest(identifier: "daily_sutra_reminder", content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)))
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
