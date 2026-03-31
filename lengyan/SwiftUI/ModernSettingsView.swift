//
//  ModernSettingsView.swift
//  lengyan
//
//  Settings — words are the interface.
//

import SwiftUI
import UserNotifications

struct ModernSettingsView: View {
    @State private var fontSizeLevel: Int = Prefers.shared.fontSizeLevel
    @State private var selectedTheme: SutraTheme = SutraDesignTokens.shared.currentTheme
    @State private var isReminderOn: Bool = Prefers.shared.isDailyReminderOn
    @State private var reminderHour: Int = Prefers.shared.reminderHour
    @State private var reminderMinute: Int = Prefers.shared.reminderMinute

    private let sizeLabels = ["特小", "小", "中", "大", "特大"]
    private let sizeFonts: [CGFloat] = [13, 16, 20, 25, 30]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZenTabHeaderView(titleKey: "settings_tab_title", symbolName: "gearshape")

                // ── 修行 ──
                zenSection("修行") {
                    reminderControl
                }

                // ── 外观 ──
                zenSection("外观") {
                    fontSizeControl
                    zenDivider
                    themeControl
                }

                // ── 关于 ──
                zenSection("关于") {
                    aboutItem("致谢", icon: "heart.text.square", action: openAcknowledgments)
                    zenDivider
                    aboutItem("提交反馈", icon: "envelope", action: openFeedback)
                    zenDivider
                    aboutItem("评价 App", icon: "star", action: openAppStoreRating)
                    zenDivider
                    versionRow
                }

                Text("✧ ❀ ✧")
                    .font(.system(size: 11))
                    .foregroundColor(SutraDesignSystem.color(.primary).opacity(0.25))
                    .padding(.top, 48)
                    .padding(.bottom, 120)
            }
        }
        .background(SutraDesignSystem.backgroundColor())
        .edgesIgnoringSafeArea(.bottom)
        .onAppear { hideNavBar() }
    }

    // MARK: - Section

    private func zenSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(SutraTypographyBridge.uiCaption(weight: .semibold))
                .tracking(2.5)
                .foregroundColor(SutraDesignSystem.color(.primary))
                .padding(.top, 36)
                .padding(.bottom, 16)
            content()
        }
        .padding(.horizontal, 36)
    }

    private var zenDivider: some View {
        Rectangle()
            .fill(SutraDesignSystem.color(.primary).opacity(0.08))
            .frame(height: 0.5)
            .padding(.vertical, 4)
    }

    // MARK: - 字体大小 — 文字即界面

    private var fontSizeControl: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            ForEach(0..<5, id: \.self) { i in
                let isSelected = fontSizeLevel == i

                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        fontSizeLevel = i
                        Prefers.shared.fontSizeLevel = i
                        NotificationCenter.default.post(name: .fontSizeDidChange, object: nil)
                    }
                }) {
                    Text(sizeLabels[i])
                        .font(.system(size: sizeFonts[i], weight: isSelected ? .medium : .light))
                        .foregroundColor(isSelected
                            ? SutraDesignSystem.color(.primary)
                            : SutraDesignSystem.color(.textSecondary))
                        .overlay(alignment: .bottom) {
                            if isSelected {
                                Rectangle()
                                    .fill(SutraDesignSystem.color(.primary).opacity(0.4))
                                    .frame(height: 1.5)
                                    .padding(.bottom, -3)
                            }
                        }
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 50)
        .padding(.vertical, 12)
    }

    // MARK: - 主题 — 三个色块圆点

    private var themeControl: some View {
        HStack(spacing: 0) {
            Text("主题")
                .font(SutraTypographyBridge.uiBody(weight: .regular))
                .foregroundColor(SutraDesignSystem.color(.textPrimary))
            Spacer()

            ForEach(SutraTheme.allCases, id: \.self) { theme in
                let sel = selectedTheme == theme
                let bgUIColor = theme == .light
                    ? UIColor(hex: "#FAF8F3") ?? .white
                    : theme == .sepia
                    ? UIColor(hex: "#F2E8D5") ?? .white
                    : UIColor(hex: "#1C1814") ?? .black
                let textUIColor = theme == .dark
                    ? UIColor(hex: "#E8DFD0") ?? .white
                    : UIColor(hex: "#33231A") ?? .black
                let label = theme == .light ? "宣纸" : theme == .sepia ? "旧经" : "夜读"

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedTheme = theme
                        SutraDesignTokens.shared.setTheme(theme)
                    }
                }) {
                    Text(label)
                        .font(.system(size: 12, weight: sel ? .medium : .light))
                        .foregroundColor(Color(textUIColor))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(minWidth: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(bgUIColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(SutraDesignSystem.color(.primary).opacity(sel ? 0.5 : 0.15), lineWidth: sel ? 1.5 : 0.5)
                                )
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 16)
    }

    // MARK: - 每日提醒

    private var reminderControl: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("每日提醒")
                    .font(SutraTypographyBridge.uiBody(weight: .regular))
                    .foregroundColor(SutraDesignSystem.color(.textPrimary))
                Spacer()
                Toggle("", isOn: $isReminderOn)
                    .labelsHidden()
                    .tint(Color(SutraDesignTokens.shared.color(for: .primary)))
                    .onChange(of: isReminderOn) { on in
                        Prefers.shared.isDailyReminderOn = on
                        if on { requestNotificationPermissionAndSchedule() }
                        else { UNUserNotificationCenter.current().removeAllPendingNotificationRequests() }
                    }
            }

            if isReminderOn {
                HStack {
                    Spacer()
                    DatePicker(
                        "",
                        selection: Binding(
                            get: {
                                var c = DateComponents()
                                c.hour = reminderHour; c.minute = reminderMinute
                                return Calendar.current.date(from: c) ?? Date()
                            },
                            set: { d in
                                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                                reminderHour = c.hour ?? 7
                                reminderMinute = c.minute ?? 0
                                Prefers.shared.reminderHour = reminderHour
                                Prefers.shared.reminderMinute = reminderMinute
                                scheduleDailyReminder()
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                }
                .padding(.top, 8)
            }
        }
        .padding(.vertical, 16)
    }

    // MARK: - 关于

    private func aboutItem(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(SutraDesignSystem.color(.primary))
                    .frame(width: 24)

                Text(title)
                    .font(SutraTypographyBridge.uiBody(weight: .regular))
                    .foregroundColor(SutraDesignSystem.color(.textPrimary))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(SutraDesignSystem.color(.textSecondary))
            }
            .padding(.vertical, 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var versionRow: some View {
        HStack {
            Text("版本")
                .font(SutraTypographyBridge.uiBody(weight: .regular))
                .foregroundColor(SutraDesignSystem.color(.textPrimary))
            Spacer()
            Text(appVersion)
                .font(.system(size: 12, weight: .light))
                .foregroundColor(SutraDesignSystem.color(.textSecondary))
        }
        .padding(.vertical, 16)
    }

    // MARK: - Navigation

    private func openAcknowledgments() {
        guard let nav = currentNavigationController else { return }
        nav.setNavigationBarHidden(false, animated: false)
        let vc = UIHostingController(rootView: SutraAcknowledgmentsView())
        vc.title = "致谢"
        nav.pushViewController(vc, animated: true)
    }

    private func openFeedback() {
        let email = "fuxuan.org@gmail.com"
        let subject = "楞严经App反馈建议"
        if let url = URL(string: "mailto:\(email)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            UIApplication.shared.open(url)
        }
    }

    private func openAppStoreRating() {
        if let url = URL(string: "https://apps.apple.com/app/id YOUR_APP_ID?action=write-review") {
            UIApplication.shared.open(url)
        }
    }

    private var currentNavigationController: UINavigationController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first,
              let tab = window.rootViewController as? UITabBarController else { return nil }
        return tab.selectedViewController as? UINavigationController
    }

    private func hideNavBar() {
        currentNavigationController?.setNavigationBarHidden(true, animated: false)
    }

    // MARK: - Notifications

    private func requestNotificationPermissionAndSchedule() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                if granted { self.scheduleDailyReminder() }
                else { self.isReminderOn = false; Prefers.shared.isDailyReminderOn = false }
            }
        }
    }

    private func scheduleDailyReminder() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        let content = UNMutableNotificationContent()
        content.title = "楞严经"
        content.body = "是时候静心诵读了"
        content.sound = .default()
        var dc = DateComponents()
        dc.hour = reminderHour; dc.minute = reminderMinute
        center.add(UNNotificationRequest(identifier: "daily_sutra_reminder", content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)))
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return "\(v) (\(b))"
    }
}

extension Notification.Name {
    static let fontSizeDidChange = Notification.Name("fontSizeDidChange")
}
