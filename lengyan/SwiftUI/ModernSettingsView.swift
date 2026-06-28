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
    @State private var hasSeenWidgetGuide: Bool = Prefers.shared.hasSeenWidgetGuide
    @State private var hasInstalledWidget: Bool = false

    private let sizeLabels = ["特小", "小", "中", "大", "特大"]
    private let sizeFonts: [CGFloat] = [13, 16, 20, 25, 30]
    private static let widgetKind = "DailyVerseWidget"

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZenTabHeaderView(titleKey: "settings_tab_title", symbolName: "gearshape")

                // ── 修行 ──
                zenSection("修行") {
                    if shouldShowWidgetHint {
                        widgetDiscoveryHint
                        zenDivider
                    }
                    if !hasInstalledWidget {
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
                zenSection("外观") {
                    fontSizeControl
                    zenDivider
                    themeControl
                }

                // ── 关于 ──
                zenSection("关于") {
                    aboutItem("反馈", icon: "envelope", action: openFeedback)
                    zenDivider
                    aboutItem("评价", icon: "star.bubble", action: openAppStoreRating)
                    zenDivider
                    aboutItem("致谢", icon: "heart.text.square", action: openAcknowledgments)
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
        .alert("通知未开启", isPresented: $showPermissionDeniedAlert) {
            Button("去设置") { openSystemNotificationSettings() }
            Button("知道了", role: .cancel) {}
        } message: {
            Text("每日读经提醒需要通知权限，才能把经文显示在通知中心。请前往「设置」开启本应用的通知。")
        }
        .onAppear {
            refreshWidgetInstallState()
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

    // MARK: - 小组件

    private var shouldShowWidgetHint: Bool {
        !hasSeenWidgetGuide && !hasInstalledWidget
    }

    private var widgetDiscoveryHint: some View {
        HStack(spacing: 14) {
            Image(systemName: "rectangle.grid.2x2")
                .font(.system(size: 15, weight: .light))
                .foregroundColor(SutraDesignSystem.color(.primary))
                .frame(width: 24)

            Button(action: { openWidgetGuide(markSeen: true) }) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("可将今日经文放到桌面与锁屏")
                        .font(SutraTypographyBridge.uiBody(weight: .regular))
                        .foregroundColor(SutraDesignSystem.color(.textPrimary))
                    Text("桌面小组件与锁屏配件")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(SutraDesignSystem.color(.textSecondary))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: dismissWidgetHint) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(SutraDesignSystem.color(.textSecondary))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("关闭")
        }
        .padding(.vertical, 16)
    }

    private var widgetGuideRow: some View {
        settingsItem(
            "桌面与锁屏小组件",
            subtitle: "今日经文可常驻一眼可见处",
            icon: "rectangle.grid.2x2",
            action: { openWidgetGuide(markSeen: true) }
        )
    }

    private func dismissWidgetHint() {
        withAnimation(.easeInOut(duration: 0.2)) {
            hasSeenWidgetGuide = true
            Prefers.shared.hasSeenWidgetGuide = true
        }
    }

    private func openWidgetGuide(markSeen: Bool) {
        if markSeen {
            hasSeenWidgetGuide = true
            Prefers.shared.hasSeenWidgetGuide = true
        }
        NavigationHelper.pushSwiftUIView(
            WidgetGuideView(hasInstalledWidget: hasInstalledWidget),
            title: "小组件"
        )
    }

    private func refreshWidgetInstallState() {
        WidgetCenter.shared.getCurrentConfigurations { result in
            let installed = (try? result.get())?.contains { $0.kind == Self.widgetKind } ?? false
            DispatchQueue.main.async {
                hasInstalledWidget = installed
                if installed {
                    hasSeenWidgetGuide = true
                    Prefers.shared.hasSeenWidgetGuide = true
                }
            }
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
        NavigationHelper.pushSwiftUIView(FeedbackView(), title: "反馈")
    }

    private func openAppStoreRating() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        SKStoreReviewController.requestReview(in: scene)
    }
}

struct WidgetGuideView: View {
    let hasInstalledWidget: Bool

    private let previewColumns = [
        GridItem(.adaptive(minimum: 92), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                statusRow
                    .padding(.top, 28)
                    .padding(.bottom, 28)

                guideSectionTitle("组件样式")
                LazyVGrid(columns: previewColumns, alignment: .leading, spacing: 12) {
                    WidgetPreviewTile(title: "桌面", subtitle: "小中大尺寸", symbol: "rectangle.grid.2x2")
                    WidgetPreviewTile(title: "锁屏", subtitle: "行内、圆形、矩形", symbol: "lock")
                    WidgetPreviewTile(title: "经文卡片", subtitle: "大号可读段落", symbol: "text.alignleft")
                }
                .padding(.bottom, 32)

                guideSectionTitle("添加方式")
                instructionText("长按桌面空白处 → 点「+」→ 搜索「楞严」→ 添加「今日读经」。")
                instructionText("锁屏长按 → 自定 → 锁屏 → 添加小组件 → 选择「楞严」。")
                    .padding(.top, 10)

                guideSectionTitle("使用")
                    .padding(.top, 32)
                instructionText("小组件每日自动更新经文。点按经文，可回到 App 深读。")
                    .padding(.bottom, 80)
            }
            .padding(.horizontal, 36)
            .readingContentWidth()
        }
        .background(SutraDesignSystem.backgroundColor())
    }

    private var statusRow: some View {
        HStack(spacing: 14) {
            Image(systemName: hasInstalledWidget ? "checkmark.circle" : "rectangle.grid.2x2")
                .font(.system(size: 18, weight: .light))
                .foregroundColor(SutraDesignSystem.color(.primary))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 5) {
                Text(hasInstalledWidget ? "已添加小组件" : "今日经文可放到桌面或锁屏")
                    .font(SutraTypographyBridge.uiBody(weight: .regular))
                    .foregroundColor(SutraDesignSystem.color(.textPrimary))
                Text(hasInstalledWidget ? "桌面或锁屏上的经文会随每日内容更新" : "打开 App 前，先在桌面或锁屏看一段")
                    .font(.system(size: 13, weight: .light))
                    .foregroundColor(SutraDesignSystem.color(.textSecondary))
            }
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
