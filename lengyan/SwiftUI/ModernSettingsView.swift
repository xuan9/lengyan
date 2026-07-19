//
//  ModernSettingsView.swift
//  lengyan
//
//  Settings — words are the interface.
//

import SwiftUI
import StoreKit
import UIKit
import WidgetKit

enum WidgetGuidePlacement: Equatable {
    case lockScreen
    case homeScreen
}

struct WidgetInstallationState: Equatable {
    let hasStandardSize: Bool
    let hasLockScreenAccessory: Bool

    static let empty = WidgetInstallationState(
        hasStandardSize: false,
        hasLockScreenAccessory: false
    )

    var isInstalled: Bool {
        hasStandardSize || hasLockScreenAccessory
    }
}

enum WidgetGuidePlatform {
    static var supportsLockScreenWidget: Bool {
        supportsLockScreenWidget(
            systemMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
            isPad: UIDevice.current.userInterfaceIdiom == .pad
        )
    }

    static func supportsLockScreenWidget(
        systemMajorVersion: Int,
        isPad: Bool
    ) -> Bool {
        systemMajorVersion >= (isPad ? 17 : 16)
    }

    static func preferredPlacement(
        installation: WidgetInstallationState?,
        supportsLockScreen: Bool
    ) -> WidgetGuidePlacement {
        guard supportsLockScreen else { return .homeScreen }
        if installation?.hasLockScreenAccessory == true,
           installation?.hasStandardSize == false {
            return .homeScreen
        }
        return .lockScreen
    }
}

private enum WidgetInstallationReader {
    static let widgetKind = "DailyVerseWidget"

    static func refresh(completion: @escaping (WidgetInstallationState) -> Void) {
        #if DEBUG
        if CommandLine.arguments.contains("--widget-guide-empty-state") {
            DispatchQueue.main.async {
                completion(.empty)
            }
            return
        }
        #endif

        let supportsLockScreen = WidgetGuidePlatform.supportsLockScreenWidget
        WidgetCenter.shared.getCurrentConfigurations { result in
            guard case let .success(configurations) = result else {
                // A transient WidgetKit failure must not erase a previously
                // known installation state or tell the user to add it again.
                return
            }

            let matchingWidgets = configurations.filter { $0.kind == widgetKind }
            let hasStandardSize = matchingWidgets.contains { info in
                switch info.family {
                case .systemSmall, .systemMedium, .systemLarge:
                    return true
                default:
                    return false
                }
            }
            let hasLockScreenAccessory: Bool
            if #available(iOS 16.0, *), supportsLockScreen {
                hasLockScreenAccessory = matchingWidgets.contains { info in
                    info.family == .accessoryRectangular
                }
            } else {
                hasLockScreenAccessory = false
            }

            let state = WidgetInstallationState(
                hasStandardSize: hasStandardSize,
                hasLockScreenAccessory: hasLockScreenAccessory
            )
            DispatchQueue.main.async {
                completion(state)
            }
        }
    }
}

struct ModernSettingsView: View {
    @State private var fontSizeLevel: Int = Prefers.shared.fontSizeLevel
    @State private var selectedTheme: SutraTheme = SutraDesignTokens.shared.currentTheme
    @State private var isReminderOn: Bool = Prefers.shared.isDailyReminderOn
    @State private var reminderHour: Int = Prefers.shared.reminderHour
    @State private var reminderMinute: Int = Prefers.shared.reminderMinute
    @State private var showPermissionDeniedAlert: Bool = false
    @State private var widgetInstallation: WidgetInstallationState?
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
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZenTabHeaderView(titleKey: "settings_tab_title", symbolName: "gearshape")

                // ── 修行 ──
                zenSection(L10n.str("settings_section_practice")) {
                    widgetGuideRow
                    zenDivider
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

                privacyPolicyFooter

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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
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

    private var widgetGuideActionText: String {
        guard let widgetInstallation else {
            return L10n.str("settings_widget_action_open")
        }
        if WidgetGuidePlatform.supportsLockScreenWidget,
           !widgetInstallation.hasLockScreenAccessory {
            return L10n.str("settings_widget_action_recommended_lock_screen")
        }
        if widgetInstallation.isInstalled {
            return L10n.str("settings_widget_action_added")
        }
        return L10n.str("settings_widget_action_add_home_screen")
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
        .accessibilityIdentifier("settings_widget_guide_row")
    }

    private func openWidgetGuide() {
        NavigationHelper.pushSwiftUIView(
            WidgetGuideView(
                initialInstallation: widgetInstallation
            ),
            title: L10n.str("settings_widget_title")
        )
    }

    private func refreshWidgetInstallState() {
        WidgetInstallationReader.refresh { state in
            widgetInstallation = state
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

    private var privacyPolicyFooter: some View {
        Button(action: openPrivacyPolicy) {
            Text(L10n.str("settings_privacy_policy"))
                .font(SutraTypographyBridge.uiSmall(weight: .regular))
                .foregroundColor(SutraDesignSystem.color(.textSecondary))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: 44)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.top, 20)
    }

    // MARK: - Navigation (delegates to NavigationHelper)

    private func openAcknowledgments() {
        NavigationHelper.pushSwiftUIView(SutraAcknowledgmentsView(), title: L10n.str("settings_acknowledgments"))
    }

    private func openFeedback() {
        NavigationHelper.pushSwiftUIView(FeedbackView(), title: L10n.str("settings_feedback"))
    }

    private func openPrivacyPolicy() {
        NavigationHelper.pushSwiftUIView(
            PrivacyPolicyView(),
            title: L10n.str("settings_privacy_policy")
        )
    }

    private func openAppStoreRating() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        SKStoreReviewController.requestReview(in: scene)
    }
}

struct PrivacyPolicyView: View {
    private var dividerColor: Color {
        SutraDesignSystem.color(.primary).opacity(0.12)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                policySection(title: L10n.str("privacy_policy_local_title")) {
                    policyParagraph(L10n.str("privacy_policy_local_body"))
                }

                Rectangle()
                    .fill(dividerColor)
                    .frame(height: 0.5)
                    .padding(.vertical, 28)

                policySection(title: L10n.str("privacy_policy_feedback_title")) {
                    VStack(alignment: .leading, spacing: 16) {
                        policyParagraph(L10n.str("privacy_policy_feedback_body"))
                        policyParagraph(L10n.str("privacy_policy_retention_body"))
                    }
                }

                Text(L10n.str("privacy_policy_updated"))
                    .font(SutraTypographyBridge.uiSmall(weight: .light))
                    .foregroundColor(SutraDesignSystem.color(.textTertiary))
                    .padding(.top, 36)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 32)
            .padding(.bottom, 80)
            .readingContentWidth()
            .textSelection(.enabled)
        }
        .background(SutraDesignSystem.backgroundColor())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func policySection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(SutraTypographyBridge.uiCaption(weight: .semibold))
                .tracking(2.5)
                .foregroundColor(SutraDesignSystem.color(.primary))
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func policyParagraph(_ text: String) -> some View {
        Text(text)
            .font(SutraTypographyBridge.uiBody(weight: .regular))
            .foregroundColor(SutraDesignSystem.color(.textPrimary))
            .lineSpacing(7)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct WidgetGuideView: View {
    @Environment(\.sizeCategory) private var sizeCategory
    @State private var installation: WidgetInstallationState?
    @State private var selectedPlacement: WidgetGuidePlacement
    @State private var hasChosenPlacement = false

    private let supportsLockScreen: Bool

    init(initialInstallation: WidgetInstallationState?) {
        let supportsLockScreen = WidgetGuidePlatform.supportsLockScreenWidget
        self.supportsLockScreen = supportsLockScreen
        _installation = State(initialValue: initialInstallation)
        _selectedPlacement = State(initialValue: WidgetGuidePlatform.preferredPlacement(
            installation: initialInstallation,
            supportsLockScreen: supportsLockScreen
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerCard
                    .padding(.top, 24)

                if supportsLockScreen {
                    placementPicker
                        .padding(.top, 22)
                }

                guideSectionTitle(sectionTitle)
                    .padding(.top, 26)

                guideIllustration
                    .padding(.bottom, 26)

                VStack(alignment: .leading, spacing: 20) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        WidgetGuideStepRow(number: index + 1, text: step)
                    }
                }

                usageNote
                    .padding(.top, 30)
                    .padding(.bottom, 80)
            }
            .padding(.horizontal, 28)
            .readingContentWidth()
        }
        .background(SutraDesignSystem.backgroundColor())
        .onAppear(perform: refreshInstallation)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshInstallation()
        }
    }

    private var selectedPlacementIsInstalled: Bool {
        switch selectedPlacement {
        case .lockScreen:
            return installation?.hasLockScreenAccessory == true
        case .homeScreen:
            return installation?.hasStandardSize == true
        }
    }

    private var headerBadgeKey: String {
        if selectedPlacementIsInstalled {
            return "widget_guide_badge_added"
        }
        return selectedPlacement == .lockScreen
            ? "widget_guide_badge_lock_recommended"
            : "widget_guide_badge_home"
    }

    private var headerSymbol: String {
        if selectedPlacementIsInstalled {
            return "checkmark.circle.fill"
        }
        return selectedPlacement == .lockScreen ? "lock" : "rectangle.grid.2x2"
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: headerSymbol)
                    .foregroundColor(SutraDesignSystem.color(.primary))
                    .accessibilityHidden(true)
                Text(L10n.str(headerBadgeKey))
                    .foregroundColor(SutraDesignSystem.color(.textPrimary))
            }
            .font(.subheadline.weight(.semibold))

            Text(headerTitle)
                .font(.title2.weight(.semibold))
                .foregroundColor(SutraDesignSystem.color(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)

            Text(headerBody)
                .font(.body)
                .foregroundColor(SutraDesignSystem.color(.textSecondary))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(SutraDesignSystem.color(.card).opacity(0.62))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(SutraDesignSystem.color(.primary).opacity(0.12), lineWidth: 0.75)
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("widget_guide_header")
    }

    private var headerTitle: String {
        if selectedPlacementIsInstalled {
            return L10n.str("widget_guide_header_added_title")
        }
        return L10n.str(selectedPlacement == .lockScreen
            ? "widget_guide_header_lock_title"
            : "widget_guide_header_home_title")
    }

    private var headerBody: String {
        if selectedPlacementIsInstalled {
            return L10n.str("widget_guide_header_added_body")
        }
        return L10n.str(selectedPlacement == .lockScreen
            ? "widget_guide_header_lock_body"
            : "widget_guide_header_home_body")
    }

    @ViewBuilder
    private var placementPicker: some View {
        if sizeCategory.isAccessibilityCategory {
            VStack(spacing: 10) {
                lockScreenPlacementButton
                homeScreenPlacementButton
            }
            .accessibilityElement(children: .contain)
        } else {
            HStack(spacing: 10) {
                lockScreenPlacementButton
                homeScreenPlacementButton
            }
            .accessibilityElement(children: .contain)
        }
    }

    private var lockScreenPlacementButton: some View {
        placementButton(
            .lockScreen,
            title: L10n.str("widget_guide_lock_tab"),
            symbol: "lock"
        )
    }

    private var homeScreenPlacementButton: some View {
        placementButton(
            .homeScreen,
            title: L10n.str("widget_guide_home_tab"),
            symbol: "rectangle.grid.2x2"
        )
    }

    private func placementButton(
        _ placement: WidgetGuidePlacement,
        title: String,
        symbol: String
    ) -> some View {
        let isSelected = selectedPlacement == placement
        return Button {
            hasChosenPlacement = true
            selectedPlacement = placement
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(isSelected
                        ? SutraDesignSystem.color(.primary)
                        : SutraDesignSystem.color(.textSecondary))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected
                        ? SutraDesignSystem.color(.textPrimary)
                        : SutraDesignSystem.color(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(SutraDesignSystem.color(.card).opacity(isSelected ? 0.8 : 0.35))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        SutraDesignSystem.color(.primary).opacity(isSelected ? 0.42 : 0.1),
                        lineWidth: isSelected ? 1 : 0.5
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier(placement == .lockScreen
            ? "widget_guide_lock_tab"
            : "widget_guide_home_tab")
    }

    private var sectionTitle: String {
        L10n.str(selectedPlacement == .lockScreen
            ? "widget_guide_lock_section_title"
            : "widget_guide_home_section_title")
    }

    @ViewBuilder
    private var guideIllustration: some View {
        if selectedPlacement == .lockScreen {
            WidgetGuideLockScreenIllustration()
        } else {
            WidgetGuideHomeScreenIllustration()
        }
    }

    private var steps: [String] {
        let prefix = selectedPlacement == .lockScreen
            ? "widget_guide_lock_step_"
            : "widget_guide_home_step_"
        return (1...4).map { L10n.str("\(prefix)\($0)") }
    }

    private func guideSectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .tracking(2)
            .foregroundColor(SutraDesignSystem.color(.textPrimary))
            .padding(.bottom, 14)
            .accessibilityAddTraits(.isHeader)
    }

    private var usageNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(SutraDesignSystem.color(.primary))
                .frame(width: 22)
                .accessibilityHidden(true)
            Text(L10n.str("widget_guide_usage_note"))
                .font(.subheadline)
                .foregroundColor(SutraDesignSystem.color(.textSecondary))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SutraDesignSystem.color(.card).opacity(0.4))
        )
    }

    private func refreshInstallation() {
        WidgetInstallationReader.refresh { state in
            installation = state
            if !hasChosenPlacement {
                selectedPlacement = WidgetGuidePlatform.preferredPlacement(
                    installation: state,
                    supportsLockScreen: supportsLockScreen
                )
            }
        }
    }
}

private struct WidgetGuideStepRow: View {
    @ScaledMetric(relativeTo: .body) private var numberDiameter: CGFloat = 27

    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundColor(SutraDesignSystem.color(.textPrimary))
                .frame(width: numberDiameter, height: numberDiameter)
                .background(
                    Circle()
                        .fill(SutraDesignSystem.color(.primary).opacity(0.1))
                )
                .overlay(
                    Circle()
                        .stroke(SutraDesignSystem.color(.primary).opacity(0.28), lineWidth: 0.75)
                )

            Text(text)
                .font(.body)
                .foregroundColor(SutraDesignSystem.color(.textPrimary))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(number). \(text)")
    }
}

private struct WidgetGuideLockScreenIllustration: View {
    var body: some View {
        VStack(spacing: 14) {
            Text("09:18")
                .font(.system(size: 42, weight: .thin, design: .rounded))
                .foregroundColor(SutraDesignSystem.color(.textPrimary).opacity(0.82))

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 11, weight: .semibold))
                    Text(L10n.str("widget_guide_preview_title"))
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(L10n.str("widget_guide_preview_verse"))
                    .font(SutraTypographyBridge.sutraCaption(weight: .regular))
                    .lineSpacing(2)
                    .lineLimit(3)
            }
            .foregroundColor(SutraDesignSystem.color(.textPrimary))
            .frame(maxWidth: 230, alignment: .leading)
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(SutraDesignSystem.color(.card).opacity(0.65))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(SutraDesignSystem.color(.primary).opacity(0.55), lineWidth: 1.5)
            )

            Text(L10n.str("widget_guide_lock_callout"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(SutraDesignSystem.color(.textPrimary))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .overlay(
                    Capsule()
                        .stroke(SutraDesignSystem.color(.primary).opacity(0.45), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, minHeight: 190)
        .padding(.vertical, 14)
        .background(illustrationBackground)
        .accessibilityHidden(true)
    }

    private var illustrationBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(SutraDesignSystem.color(.card).opacity(0.42))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(SutraDesignSystem.color(.primary).opacity(0.1), lineWidth: 0.75)
            )
    }
}

private struct WidgetGuideHomeScreenIllustration: View {
    private let appSymbols = ["text.book.closed", "headphones", "star", "gearshape"]
    private let appColumns = Array(
        repeating: GridItem(.flexible(minimum: 36, maximum: 52), spacing: 10),
        count: 4
    )

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Text(L10n.str("widget_guide_home_edit"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SutraDesignSystem.color(.textPrimary))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(
                        Capsule()
                            .stroke(SutraDesignSystem.color(.primary).opacity(0.5), lineWidth: 1.25)
                    )
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(SutraDesignSystem.color(.textTertiary))
                Label(L10n.str("widget_guide_home_add"), systemImage: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(SutraDesignSystem.color(.textPrimary))
                Spacer()
            }

            LazyVGrid(columns: appColumns, spacing: 10) {
                ForEach(appSymbols, id: \.self) { symbol in
                    RoundedRectangle(cornerRadius: 11)
                        .fill(SutraDesignSystem.color(.primary).opacity(0.08))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            Image(systemName: symbol)
                                .font(.system(size: 17, weight: .light))
                                .foregroundColor(SutraDesignSystem.color(.primary).opacity(0.7))
                        )
                }
            }
            .frame(maxWidth: 238)

            HStack(alignment: .center, spacing: 14) {
                Text(L10n.str("widget_guide_preview_verse"))
                    .font(SutraTypographyBridge.sutraCaption(weight: .regular))
                    .foregroundColor(SutraDesignSystem.color(.textPrimary))
                    .lineSpacing(3)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 13)
                            .fill(SutraDesignSystem.color(.card).opacity(0.72))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 13)
                            .stroke(SutraDesignSystem.color(.primary).opacity(0.32), lineWidth: 1)
                    )

                VStack(spacing: 10) {
                    ForEach(0..<2, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 9)
                            .fill(SutraDesignSystem.color(.primary).opacity(0.07))
                            .frame(width: 44, height: 44)
                    }
                }
            }
            .frame(maxWidth: 420)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 190)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(SutraDesignSystem.color(.card).opacity(0.42))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(SutraDesignSystem.color(.primary).opacity(0.1), lineWidth: 0.75)
        )
        .accessibilityHidden(true)
    }
}

extension Notification.Name {
    static let fontSizeDidChange = Notification.Name("fontSizeDidChange")
}
