//
//  ModernSettingsView.swift
//  lengyan
//
//  Settings — words are the interface.
//

import SwiftUI
import StoreKit
import WidgetKit

struct ModernSettingsView: View {
    @State private var fontSizeLevel: Int = Prefers.shared.fontSizeLevel
    @State private var selectedTheme: SutraTheme = SutraDesignTokens.shared.currentTheme
    @State private var isReminderOn: Bool = Prefers.shared.isDailyReminderOn
    @State private var reminderHour: Int = Prefers.shared.reminderHour
    @State private var reminderMinute: Int = Prefers.shared.reminderMinute
    @State private var showPermissionDeniedAlert: Bool = false
    @State private var hasDesktopWidget: Bool = false
    @State private var hasLockScreenWidget: Bool = false
    @State private var isSyncingReminderState: Bool = false

    private var sizeLabels: [String] {
        [
            L10n.str("settings_font_size_xs"),
            L10n.str("settings_font_size_s"),
            L10n.str("settings_font_size_m"),
            L10n.str("settings_font_size_l"),
            L10n.str("settings_font_size_xl"),
        ]
    }
    private let sizeFonts: [CGFloat] = [13, 16, 20, 25, 30]
    private static let widgetKind = "DailyVerseWidget"

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZenTabHeaderView(titleKey: "settings_tab_title", symbolName: "gearshape")

                // ── 修行 ──
                zenSection(L10n.str("settings_section_practice")) {
                    if shouldShowWidgetGuideRow {
                        widgetGuideRow
                        zenDivider
                    }
                    reminderControl
                    if isReminderOn {
                        zenDivider
                        compactTimePicker
                    }
                }

                // ── 外观 ──
                zenSection(L10n.str("settings_section_appearance")) {
                    fontSizeControl
                    zenDivider
                    themeControl
                }

                // ── 关于 ──
                zenSection(L10n.str("settings_section_about")) {
                    aboutItem(L10n.str("settings_feedback"), icon: "envelope", action: openFeedback)
                    zenDivider
                    aboutItem(L10n.str("settings_rate"), icon: "star.bubble", action: openAppStoreRating)
                    zenDivider
                    aboutItem(L10n.str("settings_acknowledgments"), icon: "heart.text.square", action: openAcknowledgments)
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
        .alert(L10n.str("settings_notification_alert_title"), isPresented: $showPermissionDeniedAlert) {
            Button(L10n.str("settings_notification_alert_open_settings")) { openSystemNotificationSettings() }
            Button(L10n.str("settings_notification_alert_ok"), role: .cancel) {}
        } message: {
            Text(L10n.str("settings_notification_alert_message"))
        }
        .onAppear {
            syncReminderState()
            refreshWidgetInstallState()
        }
        .onReceive(NotificationCenter.default.publisher(for: ReminderManager.reminderStateDidChange)) { _ in
            syncReminderState()
        }
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
            Text(L10n.str("settings_theme"))
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
                let label = theme == .light ? L10n.str("settings_theme_paper") : theme == .sepia ? L10n.str("settings_theme_classic") : L10n.str("settings_theme_night")
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

    // MARK: - 小组件

    private var shouldShowWidgetGuideRow: Bool {
        !(hasDesktopWidget && hasLockScreenWidget)
    }

    private var widgetGuideActionText: String {
        switch (hasDesktopWidget, hasLockScreenWidget) {
        case (true, false):
            return L10n.str("settings_widget_action_add_lock_screen")
        case (false, true):
            return L10n.str("settings_widget_action_add_home_screen")
        default:
            return L10n.str("settings_widget_action_add_both")
        }
    }

    private var widgetGuideRow: some View {
        Button(action: openWidgetGuide) {
            HStack(spacing: 0) {
                Text(L10n.str("settings_widget_today_verse"))
                    .font(SutraTypographyBridge.uiBody(weight: .regular))
                    .foregroundColor(SutraDesignSystem.color(.textPrimary))
                Spacer()
                Text(widgetGuideActionText)
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(SutraDesignSystem.color(.textSecondary))
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(SutraDesignSystem.color(.textSecondary))
                    .padding(.leading, 10)
            }
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func openWidgetGuide() {
        Prefers.shared.hasSeenWidgetGuide = true
        NavigationHelper.pushSwiftUIView(
            WidgetGuideView(
                hasDesktopWidget: hasDesktopWidget,
                hasLockScreenWidget: hasLockScreenWidget
            ),
            title: L10n.str("settings_widget_title")
        )
    }

    private func refreshWidgetInstallState() {
        WidgetCenter.shared.getCurrentConfigurations { result in
            let configurations = (try? result.get()) ?? []
            let matchingWidgets = configurations.filter { $0.kind == Self.widgetKind }
            let desktopInstalled = matchingWidgets.contains { info in
                switch info.family {
                case .systemSmall, .systemMedium, .systemLarge, .systemExtraLarge:
                    return true
                default:
                    return false
                }
            }
            let lockScreenInstalled: Bool
            if #available(iOS 16.0, *) {
                lockScreenInstalled = matchingWidgets.contains { info in
                    switch info.family {
                    case .accessoryRectangular:
                        return true
                    default:
                        return false
                    }
                }
            } else {
                lockScreenInstalled = false
            }
            DispatchQueue.main.async {
                hasDesktopWidget = desktopInstalled
                hasLockScreenWidget = lockScreenInstalled
                if desktopInstalled && lockScreenInstalled {
                    Prefers.shared.hasSeenWidgetGuide = true
                }
            }
        }
    }

    // MARK: - 每日提醒

    private var reminderControl: some View {
        HStack(spacing: 0) {
            Text(L10n.str("settings_daily_reminder"))
                .font(SutraTypographyBridge.uiBody(weight: .regular))
                .foregroundColor(SutraDesignSystem.color(.textPrimary))
            Spacer()
            Toggle("", isOn: $isReminderOn)
                .labelsHidden()
                .tint(Color(SutraDesignTokens.shared.color(for: .primary)))
                .onChange(of: isReminderOn) { on in
                    guard !isSyncingReminderState else { return }
                    handleReminderToggle(on)
                }
        }
        .padding(.vertical, 16)
    }

    /// 开关切换处理：开启时请求权限，拒绝则回滚开关并引导去系统设置。
    private func handleReminderToggle(_ on: Bool) {
        if on {
            ReminderManager.shared.requestPermissionAndSchedule { granted in
                if !granted {
                    // 权限被拒：回滚开关，与实际状态保持一致，并提示去设置开启
                    isReminderOn = false
                    showPermissionDeniedAlert = true
                }
            }
        } else {
            Prefers.shared.isDailyReminderOn = false
            ReminderManager.shared.cancelAll()
        }
    }

    private func syncReminderState() {
        isSyncingReminderState = true
        isReminderOn = Prefers.shared.isDailyReminderOn
        reminderHour = Prefers.shared.reminderHour
        reminderMinute = Prefers.shared.reminderMinute
        DispatchQueue.main.async {
            isSyncingReminderState = false
        }
    }

    /// 跳转系统设置页（让用户重新开启通知权限）。
    private func openSystemNotificationSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private var compactTimePicker: some View {
        HStack(spacing: 14) {
            Image(systemName: "clock")
                .font(.system(size: 15, weight: .light))
                .foregroundColor(SutraDesignSystem.color(.primary))
                .frame(width: 24)
            Text(L10n.str("settings_reminder_time"))
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

    // MARK: - Rows

    private func settingsItem(_ title: String, subtitle: String? = nil, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .light))
                    .foregroundColor(SutraDesignSystem.color(.primary))
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(SutraTypographyBridge.uiBody(weight: .regular))
                        .foregroundColor(SutraDesignSystem.color(.textPrimary))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(SutraDesignSystem.color(.textSecondary))
                    }
                }
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

    // MARK: - 关于

    private func aboutItem(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        settingsItem(title, icon: icon, action: action)
    }

    private var versionRow: some View {
        HStack {
            Text(L10n.str("settings_version"))
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
        NavigationHelper.pushSwiftUIView(SutraAcknowledgmentsView(), title: L10n.str("settings_acknowledgments"))
    }

    private func openFeedback() {
        NavigationHelper.pushSwiftUIView(FeedbackView(), title: L10n.str("settings_feedback"))
    }

    private func openAppStoreRating() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        SKStoreReviewController.requestReview(in: scene)
    }
}

struct WidgetGuideView: View {
    let hasDesktopWidget: Bool
    let hasLockScreenWidget: Bool

    private let previewColumns = [
        GridItem(.adaptive(minimum: 92), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                statusRow
                    .padding(.top, 28)
                    .padding(.bottom, 28)

                guideSectionTitle(L10n.str("widget_guide_styles"))
                LazyVGrid(columns: previewColumns, alignment: .leading, spacing: 12) {
                    WidgetPreviewTile(title: L10n.str("widget_guide_home_title"), subtitle: L10n.str("widget_guide_home_subtitle"), symbol: "rectangle.grid.2x2")
                    WidgetPreviewTile(title: L10n.str("widget_guide_lock_title"), subtitle: L10n.str("widget_guide_lock_subtitle"), symbol: "lock")
                }
                .padding(.bottom, 32)

                guideSectionTitle(L10n.str("widget_guide_how_to_add"))
                instructionText(L10n.str("widget_guide_home_instruction"))
                instructionText(L10n.str("widget_guide_lock_instruction"))
                    .padding(.top, 10)

                guideSectionTitle(L10n.str("widget_guide_usage"))
                    .padding(.top, 32)
                instructionText(L10n.str("widget_guide_usage_instruction"))
                    .padding(.bottom, 80)
            }
            .padding(.horizontal, 36)
            .readingContentWidth()
        }
        .background(SutraDesignSystem.backgroundColor())
    }

    private var statusRow: some View {
        HStack(spacing: 14) {
            Image(systemName: hasDesktopWidget && hasLockScreenWidget ? "checkmark.circle" : "rectangle.grid.2x2")
                .font(.system(size: 18, weight: .light))
                .foregroundColor(SutraDesignSystem.color(.primary))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 5) {
                Text(widgetStatusTitle)
                    .font(SutraTypographyBridge.uiBody(weight: .regular))
                    .foregroundColor(SutraDesignSystem.color(.textPrimary))
                Text(widgetStatusSubtitle)
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(SutraDesignSystem.color(.textSecondary))
            }
        }
    }

    private var widgetStatusTitle: String {
        switch (hasDesktopWidget, hasLockScreenWidget) {
        case (true, true):
            return L10n.str("widget_status_both_added")
        case (true, false):
            return L10n.str("widget_status_home_added")
        case (false, true):
            return L10n.str("widget_status_lock_added")
        default:
            return L10n.str("widget_status_not_added")
        }
    }

    private var widgetStatusSubtitle: String {
        switch (hasDesktopWidget, hasLockScreenWidget) {
        case (true, true):
            return L10n.str("widget_status_both_added_subtitle")
        case (true, false):
            return L10n.str("widget_status_home_added_subtitle")
        case (false, true):
            return L10n.str("widget_status_lock_added_subtitle")
        default:
            return L10n.str("widget_status_not_added_subtitle")
        }
    }

    private func guideSectionTitle(_ text: String) -> some View {
        Text(text)
            .font(SutraTypographyBridge.uiCaption(weight: .semibold))
            .tracking(2)
            .foregroundColor(SutraDesignSystem.color(.primary))
            .padding(.bottom, 14)
    }

    private func instructionText(_ text: String) -> some View {
        Text(text)
            .font(SutraTypographyBridge.uiBody(weight: .regular))
            .foregroundColor(SutraDesignSystem.color(.textPrimary))
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct WidgetPreviewTile: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .light))
                .foregroundColor(SutraDesignSystem.color(.primary))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(SutraTypographyBridge.uiBody(weight: .regular))
                    .foregroundColor(SutraDesignSystem.color(.textPrimary))
                Text(subtitle)
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(SutraDesignSystem.color(.textSecondary))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(SutraDesignSystem.color(.card).opacity(0.55))
        )
    }
}

extension Notification.Name {
    static let fontSizeDidChange = Notification.Name("fontSizeDidChange")
}
