//
//  BeautifulSutraReadingView.swift
//  lengyan
//
//  Created by SwiftUI Migration on 2025/10/29.
//  Copyright © 2025年 xuan. All rights reserved.
//

import SwiftUI

// MARK: - Beautiful Sutra Reading View
struct BeautifulSutraReadingView: View {
    let sutraContent: String
    let chapterTitle: String
    let chapterSubtitle: String?
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var readingSettings = ReadingSettingsManager()

    // Reading controls state
    @State private var showControls = false
    @State private var showBookmarks = false
    @State private var currentPage = 1
    @State private var totalPages = 25

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    themeManager.backgroundColor,
                    themeManager.backgroundColor.opacity(0.95),
                    themeManager.backgroundColor.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // Chapter Header
                        chapterHeaderView

                        // Main Content
                        mainContentView
                            .id("content-start")

                        // Reading Controls
                        readingControlsView

                        // Navigation Footer
                        navigationFooterView
                    }
                }
                .onAppear {
                    // Scroll to top when view appears
                    proxy.scrollTo("content-start", anchor: .top)
                }
            }

            // Floating Action Button
            VStack {
                Spacer()

                HStack {
                    Spacer()

                    VStack(spacing: 16) {
                        // Bookmarks Button
                        FloatingActionButton(
                            icon: "bookmark",
                            color: LengyanDesignSystem.Colors.accentGold,
                            action: { showBookmarks.toggle() }
                        )

                        // Settings Button
                        FloatingActionButton(
                            icon: "textformat.size",
                            color: LengyanDesignSystem.Colors.accentBlue,
                            action: { showControls.toggle() }
                        )
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showControls) {
            ReadingControlsSheetView(readingSettings: readingSettings)
        }
        .sheet(isPresented: $showBookmarks) {
            BookmarksSheetView()
        }
    }

    // MARK: - Chapter Header
    private var chapterHeaderView: some View {
        VStack(spacing: 24) {
            // Breadcrumb Navigation
            HStack {
                Button(action: { /* Navigate back */ }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(themeManager.secondaryTextColor)
                }

                Text("楞严经")
                    .font(LengyanDesignSystem.Typography.uiCaption)
                    .foregroundColor(themeManager.secondaryTextColor)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(themeManager.secondaryTextColor)

                Text(chapterTitle)
                    .font(LengyanDesignSystem.Typography.uiCaption)
                    .foregroundColor(themeManager.secondaryTextColor)

                Spacer()
            }

            // Chapter Title Card
            VStack(spacing: 16) {
                Text(chapterTitle)
                    .font(LengyanDesignSystem.Typography.sutraLarge)
                    .fontWeight(.bold)
                    .foregroundColor(themeManager.primaryTextColor)
                    .multilineTextAlignment(.center)

                if let subtitle = chapterSubtitle {
                    Text(subtitle)
                        .font(LengyanDesignSystem.Typography.sutraBody)
                        .foregroundColor(themeManager.secondaryTextColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Reading Progress
                HStack {
                    Text("阅读进度")
                        .font(LengyanDesignSystem.Typography.uiSmall)
                        .foregroundColor(themeManager.secondaryTextColor)

                    Spacer()

                    Text("\(currentPage) / \(totalPages) 页")
                        .font(LengyanDesignSystem.Typography.uiSmall)
                        .foregroundColor(themeManager.secondaryTextColor)
                }

                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(themeManager.secondaryTextColor.opacity(0.2))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(LengyanDesignSystem.Colors.accentGold)
                            .frame(width: geometry.size.width * (Double(currentPage) / Double(totalPages)), height: 4)
                            .animation(.easeInOut(duration: 0.3), value: currentPage)
                    }
                }
                .frame(height: 4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .lengyanMaterialCard()
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    // MARK: - Main Content
    private var mainContentView: some View {
        VStack(spacing: 24) {
            // Sutra Text with beautiful typography
            LengyanSutraText(
                sutraContent,
                size: readingSettings.fontSize,
                lineHeight: readingSettings.lineHeight
            )
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .background(
                // Paper texture background
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                themeManager.cardColor,
                                themeManager.cardColor.opacity(0.95)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: LengyanDesignSystem.Shadow.small.color, radius: LengyanDesignSystem.Shadow.small.radius, x: LengyanDesignSystem.Shadow.small.x, y: LengyanDesignSystem.Shadow.small.y)
            )
            .padding(.horizontal, 16)

            // Chapter End Marker
            HStack {
                Rectangle()
                    .fill(LengyanDesignSystem.Colors.accentGold)
                    .frame(width: 60, height: 2)

                Text("本章结束")
                    .font(LengyanDesignSystem.Typography.uiCaption)
                    .foregroundColor(themeManager.secondaryTextColor)

                Rectangle()
                    .fill(LengyanDesignSystem.Colors.accentGold)
                    .frame(width: 60, height: 2)
            }
            .padding(.vertical, 32)
        }
    }

    // MARK: - Reading Controls
    private var readingControlsView: some View {
        VStack(spacing: 16) {
            HStack {
                Text("阅读设置")
                    .font(LengyanDesignSystem.Typography.uiHeading)
                    .foregroundColor(themeManager.primaryTextColor)

                Spacer()

                Button(action: { showControls.toggle() }) {
                    Text("自定义")
                        .font(LengyanDesignSystem.Typography.uiCaption)
                        .foregroundColor(LengyanDesignSystem.Colors.accentGold)
                }
            }

            // Quick Settings
            HStack(spacing: 24) {
                // Font Size
                QuickSettingButton(
                    icon: "textformat.size",
                    label: "字号",
                    value: "\(Int(readingSettings.fontSize.size))",
                    color: LengyanDesignSystem.Colors.accentBlue
                )

                // Line Height
                QuickSettingButton(
                    icon: "line.horizontal.3",
                    label: "行距",
                    value: String(format: "%.1f", readingSettings.lineHeight),
                    color: LengyanDesignSystem.Colors.success
                )

                // Theme
                QuickSettingButton(
                    icon: "paintbrush",
                    label: "主题",
                    value: themeManager.currentThemeName,
                    color: LengyanDesignSystem.Colors.accentGold
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .lengyanMaterialCard()
    }

    // MARK: - Navigation Footer
    private var navigationFooterView: some View {
        VStack(spacing: 20) {
            // Navigation Buttons
            HStack(spacing: 32) {
                // Previous Button
                Button(action: { /* Previous page */ }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left")
                        Text("上一页")
                    }
                    .lengyanSecondaryButton()
                }
                .disabled(currentPage == 1)

                Spacer()

                // Progress Indicator
                VStack(spacing: 4) {
                    Text("\(currentPage) / \(totalPages)")
                        .font(LengyanDesignSystem.Typography.uiCaption)
                        .foregroundColor(themeManager.secondaryTextColor)

                    HStack(spacing: 8) {
                        ForEach(1...totalPages, id: \.self) { page in
                            Circle()
                                .fill(page <= currentPage ? LengyanDesignSystem.Colors.accentGold : themeManager.secondaryTextColor.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                }

                Spacer()

                // Next Button
                Button(action: { /* Next page */ }) {
                    HStack(spacing: 8) {
                        Text("下一页")
                        Image(systemName: "chevron.right")
                    }
                    .lengyanAccentButton()
                }
                .disabled(currentPage == totalPages)
            }

            // Chapter Navigation
            HStack {
                Button(action: { /* Previous chapter */ }) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.left.circle")
                        Text("上一章")
                    }
                    .font(LengyanDesignSystem.Typography.uiCaption)
                    .foregroundColor(themeManager.secondaryTextColor)
                }

                Spacer()

                Text("第 \(currentPage) 章")
                    .font(LengyanDesignSystem.Typography.uiBody)
                    .foregroundColor(themeManager.primaryTextColor)

                Spacer()

                Button(action: { /* Next chapter */ }) {
                    HStack(spacing: 8) {
                        Text("下一章")
                        Image(systemName: "chevron.right.circle")
                    }
                    .font(LengyanDesignSystem.Typography.uiCaption)
                    .foregroundColor(themeManager.secondaryTextColor)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 24)
        .background(
            // Gradient overlay for depth
            LinearGradient(
                colors: [Color.clear, themeManager.backgroundColor.opacity(0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Floating Action Button
struct FloatingActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 56, height: 56)
                    .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }
    }
}

// MARK: - Quick Setting Button
struct QuickSettingButton: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    @StateObject private var themeManager = ThemeManager()

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(label)
                .font(LengyanDesignSystem.Typography.uiSmall)
                .foregroundColor(themeManager.secondaryTextColor)

            Text(value)
                .font(LengyanDesignSystem.Typography.uiCaption)
                .foregroundColor(color)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .lengyanMaterialCard()
    }
}

// MARK: - Reading Controls Sheet
struct ReadingControlsSheetView: View {
    @ObservedObject var readingSettings: ReadingSettingsManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager()

    var body: some View {
        NavigationView {
            List {
                // Font Size Section
                Section("字体大小") {
                    VStack(spacing: 16) {
                        HStack {
                            Text("字号")
                                .font(LengyanDesignSystem.Typography.uiBody)
                                .foregroundColor(themeManager.primaryTextColor)

                            Spacer()

                            Text("\(Int(readingSettings.fontSize.size))pt")
                                .font(LengyanDesignSystem.Typography.uiBody)
                                .foregroundColor(themeManager.secondaryTextColor)
                        }

                        Slider(value: $readingSettings.fontSizeValue, in: 14...24, step: 1)
                            .accentColor(LengyanDesignSystem.Colors.accentGold)
                    }
                    .padding(.vertical, 8)
                }

                // Line Height Section
                Section("行距设置") {
                    VStack(spacing: 16) {
                        HStack {
                            Text("行距")
                                .font(LengyanDesignSystem.Typography.uiBody)
                                .foregroundColor(themeManager.primaryTextColor)

                            Spacer()

                            Text(String(format: "%.1f", readingSettings.lineHeight))
                                .font(LengyanDesignSystem.Typography.uiBody)
                                .foregroundColor(themeManager.secondaryTextColor)
                        }

                        Slider(value: $readingSettings.lineHeight, in: 1.2...2.0, step: 0.1)
                            .accentColor(LengyanDesignSystem.Colors.accentGold)
                    }
                    .padding(.vertical, 8)
                }

                // Theme Section
                Section("主题设置") {
                    VStack(spacing: 12) {
                        ForEach(ThemeManager.AppTheme.allCases, id: \.self) { theme in
                            Button(action: {
                                themeManager.currentTheme = theme
                            }) {
                                HStack {
                                    Text(theme.displayName)
                                        .font(LengyanDesignSystem.Typography.uiBody)
                                        .foregroundColor(themeManager.primaryTextColor)

                                    Spacer()

                                    if themeManager.currentTheme == theme {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(LengyanDesignSystem.Colors.accentGold)
                                    }
                                }
                            }
                        }
                    }
                }

                // Reading Mode Section
                Section("阅读模式") {
                    Toggle("夜间模式", isOn: $readingSettings.nightMode)
                        .font(LengyanDesignSystem.Typography.uiBody)
                        .tint(LengyanDesignSystem.Colors.accentGold)

                    Toggle("显示翻译", isOn: $readingSettings.showTranslation)
                        .font(LengyanDesignSystem.Typography.uiBody)
                        .tint(LengyanDesignSystem.Colors.accentGold)

                    Toggle("自动翻页", isOn: $readingSettings.autoPageTurn)
                        .font(LengyanDesignSystem.Typography.uiBody)
                        .tint(LengyanDesignSystem.Colors.accentGold)
                }
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Bookmarks Sheet
struct BookmarksSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var themeManager = ThemeManager()
    @State private var bookmarks: [Bookmark] = [
        Bookmark(id: 1, title: "楞严经 卷一", position: "第 15 页", date: "2024-01-15"),
        Bookmark(id: 2, title: "楞严经 卷二", position: "第 42 页", date: "2024-01-16"),
        Bookmark(id: 3, title: "楞严经 卷三", position: "第 78 页", date: "2024-01-17")
    ]

    var body: some View {
        NavigationView {
            List {
                ForEach(bookmarks) { bookmark in
                    BookmarkRow(bookmark: bookmark)
                }
            }
            .background(themeManager.backgroundColor)
            .navigationTitle("书签")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Bookmark Row
struct BookmarkRow: View {
    let bookmark: Bookmark
    @StateObject private var themeManager = ThemeManager()

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 16))
                .foregroundColor(LengyanDesignSystem.Colors.accentGold)

            VStack(alignment: .leading, spacing: 4) {
                Text(bookmark.title)
                    .font(LengyanDesignSystem.Typography.uiBody)
                    .foregroundColor(themeManager.primaryTextColor)
                    .lineLimit(1)

                Text(bookmark.position)
                    .font(LengyanDesignSystem.Typography.uiSmall)
                    .foregroundColor(themeManager.secondaryTextColor)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(bookmark.date)
                    .font(LengyanDesignSystem.Typography.uiSmall)
                    .foregroundColor(themeManager.secondaryTextColor)

                Button(action: { /* Remove bookmark */ }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(themeManager.secondaryTextColor)
                }
            }
        }
        .padding(.vertical, 8)
        .listRowBackground(themeManager.backgroundColor)
    }
}

// MARK: - Reading Settings Manager
class ReadingSettingsManager: ObservableObject {
    @Published var fontSize: Font = LengyanDesignSystem.Typography.sutraBody {
        didSet {
            fontSizeValue = fontSize.size
        }
    }
    @Published var fontSizeValue: Double = 18.0
    @Published var lineHeight: CGFloat = 1.6
    @Published var nightMode: Bool = false
    @Published var showTranslation: Bool = false
    @Published var autoPageTurn: Bool = false
}

// MARK: - Data Models
struct Bookmark: Identifiable {
    let id: Int
    let title: String
    let position: String
    let date: String
}


// MARK: - Preview
struct BeautifulSutraReadingView_Previews: PreviewProvider {
    static var previews: some View {
        BeautifulSutraReadingView(
            sutraContent: "如是我聞。一時，佛在室羅筏城，祇桓精舍。與大比丘僧千二百五十人俱。皆是漏盡阿羅漢。世尊入城乞食，於其城中次第乞已，還至本處。飯食畢，收衣缽，洗足已。敷座而坐。",
            chapterTitle: "楞严经 卷一",
            chapterSubtitle: "The Śūraṅgama Sūtra, Volume 1"
        )
        .previewDisplayName("Beautiful Reading View")
    }
}