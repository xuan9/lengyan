//
//  ModernSettingsView.swift
//  lengyan
//
//  Settings — words are the interface.
//

import SwiftUI
import StoreKit

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
                    if isReminderOn { compactTimePicker }
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
                    aboutItem("评价 App", icon: "star.bubble", action: openAppStoreRating)
                    zenDivider
                    versionRow
                }

                Text("✧ ❀ ✧")
                    .font(.system(size: 11))
                    .foregroundColor(SutraDesignSystem.color(.primary).opacity(0.25))
                    .padding(.top, 48)
                    .padding(.bottom, 120)
            }
            .readingContentWidth()
        }
        .background(SutraDesignSystem.backgroundColor())
        .edgesIgnoringSafeArea(.bottom)
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

    // MARK: - 字体大小

    private var fontSizeControl: some View {
        HStack(alignment: .lastTextBaseline, spacing: 0) {
            ForEach(0..<5, id: \.self) { i in
                let isSelected = fontSizeLevel == i

                Button(action: { changeFontSize(i) }) {
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

    private func changeFontSize(_ level: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            fontSizeLevel = level
            Prefers.shared.fontSizeLevel = level
            NotificationCenter.default.post(name: .fontSizeDidChange, object: nil)
        }
    }

    // MARK: - 主题

    private var themeControl: some View {
        HStack(spacing: 0) {
            Text("主题")
                .font(SutraTypographyBridge.uiBody(weight: .regular))
                .foregroundColor(SutraDesignSystem.color(.textPrimary))
            Spacer()
            ForEach(SutraTheme.allCases.filter { $0 != .dark }, id: \.self) { theme in
                let sel = selectedTheme == theme
                let bgUIColor = theme == .light
                    ? UIColor(hex: "#FAF8F3") ?? .white
                    : theme == .sepia
                    ? UIColor(hex: "#F2E8D5") ?? .white
                    : UIColor(hex: "#1C1814") ?? .black
                let textUIColor = theme == .dark
                    ? UIColor(hex: "#E8DFD0") ?? .white
                    : UIColor(hex: "#33231A") ?? .black
                let label = theme == .light ? "宣纸" : theme == .sepia ? "古籍" : "夜读"
                Button(action: { changeTheme(theme) }) {
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

    private func changeTheme(_ theme: SutraTheme) {
        withAnimation(.easeInOut(duration: 0.25)) {
            selectedTheme = theme
            SutraDesignTokens.shared.setTheme(theme)
        }
    }

    // MARK: - 每日提醒

    private var reminderControl: some View {
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
                    if on { ReminderManager.shared.requestPermissionAndSchedule() }
                    else { ReminderManager.shared.cancelAll() }
                }
        }
        .padding(.vertical, 16)
    }

    private var compactTimePicker: some View {
        HStack(spacing: 14) {
            Image(systemName: "clock")
                .font(.system(size: 15, weight: .light))
                .foregroundColor(SutraDesignSystem.color(.primary))
                .frame(width: 24)
            Text("提醒时间")
                .font(SutraTypographyBridge.uiBody(weight: .regular))
                .foregroundColor(SutraDesignSystem.color(.textPrimary))
            Spacer()
            DatePicker("", selection: Binding(
                get: {
                    let c = Calendar.current
                    var d = DateComponents()
                    d.hour = reminderHour
                    d.minute = reminderMinute
                    return c.date(from: d) ?? Date()
                },
                set: { date in
                    let c = Calendar.current
                    reminderHour = c.component(.hour, from: date)
                    reminderMinute = c.component(.minute, from: date)
                    saveReminderTime()
                }
            ), displayedComponents: .hourAndMinute)
            .datePickerStyle(.compact)
            .labelsHidden()
        }
        .padding(.vertical, 18)
    }

    private func saveReminderTime() {
        Prefers.shared.reminderHour = reminderHour
        Prefers.shared.reminderMinute = reminderMinute
        if isReminderOn { ReminderManager.shared.scheduleDaily() }
    }

    // MARK: - 关于

    private func aboutItem(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .light))
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
            Text(NavigationHelper.appVersion)
                .font(.system(size: 12, weight: .light))
                .foregroundColor(SutraDesignSystem.color(.textSecondary))
        }
        .padding(.vertical, 16)
    }

    // MARK: - Navigation (delegates to NavigationHelper)

    private func openAcknowledgments() {
        NavigationHelper.pushSwiftUIView(SutraAcknowledgmentsView(), title: "致谢")
    }

    private func openFeedback() {
        NavigationHelper.pushSwiftUIView(FeedbackView(), title: "提交反馈")
    }

    private func openAppStoreRating() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        SKStoreReviewController.requestReview(in: scene)
    }
}

extension Notification.Name {
    static let fontSizeDidChange = Notification.Name("fontSizeDidChange")
}
