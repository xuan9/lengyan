import SwiftUI
import AVFoundation

// MARK: - Main View
struct ModernAudioPlayerView: View {
    @ObservedObject var manager = AudioManager.shared
    @ObservedObject var audioObserver = AudioPlayerObserver.shared
    @State private var showModeMenu = false
    @State private var modeButtonFrame: CGRect = .zero

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                ZenTabHeaderView(titleKey: "media_tab_title", symbolName: "headphones")

                ScrollView {
                    VStack(spacing: 0) {
                        if manager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .padding(.top, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingComponentXXL))
                        } else {
                            flatTrackList
                        }

                        // 归属署名 — 安静低调
                        Text("屏东能净协会读诵")
                            .font(SutraTypographyBridge.uiCaption(weight: .light))
                            .foregroundColor(Color(SutraDesignTokens.shared.color(for: .textSecondary)))
                            .padding(.top, 36)
                            .padding(.bottom, 8)
                    }
                    .padding(.bottom, audioObserver.showPlayerBar ? 220 : 120)
                    .readingContentWidth()
                }
                .background(Color(SutraDesignTokens.shared.color(for: .background)))
            }
            .background(Color(SutraDesignTokens.shared.color(for: .background)))

            if audioObserver.showPlayerBar {
                mediaPlayerBar
            }
        }
        .overlay(alignment: .top) {
            Group {
                if let msg = manager.downloadErrorMessage {
                    Text(msg)
                        .font(SutraTypographyBridge.uiCaption(weight: .regular))
                        .foregroundColor(Color(SutraDesignTokens.shared.color(for: .textPrimary)))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(SutraDesignTokens.shared.color(for: .surface)).opacity(0.95))
                        )
                        .padding(.top, 60)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                manager.downloadErrorMessage = nil
                            }
                        }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: manager.downloadErrorMessage)
        }
        .onAppear {
            manager.setupAudioSession()
            manager.loadMediaData()  // loadMediaData 内部已调用 resumeLastPlayback
            audioObserver.showPlayerBar = true
        }
        .overlay {
            GeometryReader { overlayGeo in
                if showModeMenu && !modeButtonFrame.isEmpty {
                    ZStack(alignment: .bottomTrailing) {
                        Color.black.opacity(0.15)
                            .ignoresSafeArea()
                            .onTapGesture { showModeMenu = false }

                        // 菜单面板：通过 bottomTrailing 对齐和 padding 动态定位，避免硬编码高度 (230)
                        let localOrigin = overlayGeo.frame(in: .global).origin
                        let menuRightX = modeButtonFrame.maxX - localOrigin.x
                        let menuBottomY = modeButtonFrame.minY - localOrigin.y - 8
                        
                        let padTrailing = overlayGeo.size.width - menuRightX
                        let padBottom = overlayGeo.size.height - menuBottomY

                        VStack(spacing: 0) {
                            playModeRow(.repeatOne, title: NSLocalizedString("play_mode_repeat_one", comment: ""), icon: "ic_repeat_one")
                            goldDivider
                            playModeRow(.repeatAll, title: NSLocalizedString("play_mode_repeat", comment: ""), icon: "ic_repeat")
                            goldDivider
                            ForEach(1...3, id: \.self) { i in
                                playModeRow(playMode(for: i), title: "\(NSLocalizedString("play_mode_play_one", comment: ""))\(i)次", icon: "ic_looks_\(i)")
                                if i < 3 { goldDivider }
                            }
                        }
                        .frame(width: 210)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(SutraDesignTokens.shared.color(for: .surface)))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(SutraDesignTokens.shared.color(for: .decorativeGold)).opacity(0.2), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
                        .padding(.trailing, max(0, padTrailing))
                        .padding(.bottom, max(0, padBottom))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .ignoresSafeArea()
        }
        .animation(.easeInOut(duration: 0.2), value: showModeMenu)
    }

    // MARK: - Media Player Bar
    private var mediaPlayerBar: some View {
        HStack(alignment: .center, spacing: 0) {
            // 左列：播放按钮
            Button(action: manager.togglePlayPause) {
                Image(audioObserver.isPlaying ? "ic_pause_circle_outline_48pt" : "ic_play_circle_outline_48pt")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .foregroundColor(Color(SutraDesignTokens.shared.color(for: .primary)))
            }
            .padding(.leading, 16)

            // 中列：标题 + 进度条 + 时间
            VStack(alignment: .leading, spacing: 8) {
                if audioObserver.currentTrack?.isEmpty ?? true {
                    Text("请轻触卷名听经")
                        .font(SutraTypographyBridge.uiCaption(weight: .light))
                        .tracking(2)
                        .foregroundColor(Color(SutraDesignTokens.shared.color(for: .textSecondary)))
                        .lineLimit(1)
                } else {
                    Text(audioObserver.currentTrack!)
                        .font(SutraTypographyBridge.uiBody(weight: .regular))
                        .foregroundColor(Color(SutraDesignTokens.shared.color(for: .textPrimary)))
                        .lineLimit(1)
                }

                progressBar

                HStack {
                    Text(AudioManager.formatTime(audioObserver.currentTime))
                    Spacer()
                    Text(AudioManager.formatTime(audioObserver.totalTime))
                }
                .font(SutraTypographyBridge.uiSmall(weight: .regular))
                .monospacedDigit()
                .foregroundColor(Color(SutraDesignTokens.shared.color(for: .textTertiary)))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)

            // 右列：播放模式按钮
            Button(action: { showModeMenu.toggle() }) {
                Image(manager.selectedPlayMode.iconName)
                    .renderingMode(.template)
                    .foregroundColor(Color(SutraDesignTokens.shared.color(for: .textSecondary)))
                    .frame(width: 24, height: 24)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: ButtonFramePreferenceKey.self,
                                value: geo.frame(in: .global)
                            )
                        }
                    )
            }
            .padding(.trailing, 16)
            .onPreferenceChange(ButtonFramePreferenceKey.self) { frame in
                modeButtonFrame = frame
            }
        }
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(SutraDesignTokens.shared.color(for: .background)))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color(SutraDesignTokens.shared.color(for: .primary)).opacity(0.1), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 0)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: audioObserver.showPlayerBar)
    }

    private func playModeRow(_ mode: PlayMode, title: String, icon: String) -> some View {
        Button(action: {
            manager.selectMode(mode)
            showModeMenu = false
        }) {
            HStack(spacing: 12) {
                Image(icon)
                    .renderingMode(.template)
                    .foregroundColor(
                        manager.selectedPlayMode == mode
                            ? Color(SutraDesignTokens.shared.color(for: .primary))
                            : Color(SutraDesignTokens.shared.color(for: .textSecondary))
                    )
                    .frame(width: 20, height: 20)

                Text(title)
                    .font(SutraTypographyBridge.uiCaption(weight: manager.selectedPlayMode == mode ? .medium : .regular))
                    .foregroundColor(
                        manager.selectedPlayMode == mode
                            ? Color(SutraDesignTokens.shared.color(for: .primary))
                            : Color(SutraDesignTokens.shared.color(for: .sutraText))
                    )

                Spacer()

                if manager.selectedPlayMode == mode {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(SutraDesignTokens.shared.color(for: .primary)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var goldDivider: some View {
        Rectangle()
            .fill(Color(SutraDesignTokens.shared.color(for: .decorativeGold)).opacity(0.15))
            .frame(height: 0.5)
            .padding(.horizontal, 12)
    }

    private func playMode(for count: Int) -> PlayMode {
        switch count {
        case 1: return .playOnce
        case 2: return .playTwice
        case 3: return .play3Times
        case 4: return .play4Times
        case 5: return .play5Times
        case 6: return .play6Times
        default: return .playOnce
        }
    }

    // MARK: - Progress Bar (without time labels)
    private var progressBar: some View {
        GeometryReader { geometry in
            let progress = audioObserver.totalTime > 0 ? CGFloat(audioObserver.currentTime / audioObserver.totalTime) : 0
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color(SutraDesignTokens.shared.color(for: .primary)).opacity(0.12))
                    .frame(height: 5)
                    .cornerRadius(2.5)

                Rectangle()
                    .fill(Color(SutraDesignTokens.shared.color(for: .primary)))
                    .frame(width: max(0, min(geometry.size.width * progress, geometry.size.width)), height: 5)
                    .cornerRadius(2.5)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard audioObserver.totalTime > 0 else { return }
                        let percent = min(max(value.location.x / geometry.size.width, 0), 1)
                        let seekTime = audioObserver.totalTime * Double(percent)
                        audioObserver.currentTime = seekTime
                        let cmTime = CMTime(seconds: seekTime, preferredTimescale: 600)
                        audioObserver.queuePlayer?.seek(to: cmTime, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
                    }
            )
        }
        .frame(height: 5)
        .contentShape(Rectangle())
    }

    // MARK: - Flat Track List (经卷目录)
    private var flatTrackList: some View {
        VStack(spacing: 0) {
            ForEach(manager.mediaGroups) { group in
                ForEach(group.files.indices, id: \.self) { index in
                    let isLast = index == group.files.indices.last
                    let isMantra = group.files[index].hasPrefix("lyz")

                    // 楞嚴咒前加分隔 — 区分经文与咒
                    if isMantra {
                        Rectangle()
                            .fill(Color(SutraDesignTokens.shared.color(for: .primary)).opacity(0.12))
                            .frame(height: 0.5)
                            .padding(.horizontal, 36)
                            .padding(.vertical, 20)
                    }

                    trackRow(
                        name: group.names[index],
                        file: group.files[index],
                        fileExtension: group.fileExtension
                    )

                    // 曲目间极细线
                    if !isLast && !isMantra {
                        Rectangle()
                            .fill(Color(SutraDesignTokens.shared.color(for: .primary)).opacity(0.06))
                            .frame(height: 0.5)
                            .padding(.horizontal, 36)
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Track Row
    private func trackRow(name: String, file: String, fileExtension ext: String) -> some View {
        let status = manager.downloadStatus[file] ?? .notDownloaded
        let progress = manager.downloadProgress[file] ?? 0
        let isCurrent = audioObserver.currentTrack == name
        let isPlaying = isCurrent && audioObserver.isPlaying
        let primary = Color(SutraDesignTokens.shared.color(for: .primary))

        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                // 正在播放 — 左侧竹绿竖线
                if isCurrent {
                    Capsule()
                        .fill(primary)
                        .frame(width: 3)
                        .padding(.vertical, 6)
                }

                Text(name)
                    .font(SutraTypographyBridge.uiBody(weight: isCurrent ? .medium : .regular))
                    .foregroundColor(isCurrent
                        ? primary
                        : Color(SutraDesignTokens.shared.color(for: .textPrimary)))
                    .padding(.leading, isCurrent ? 14 : 17)

                Spacer()

                // 右侧状态指示
                if status == .downloading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.7)
                } else if status == .error {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(SutraDesignTokens.shared.color(for: .textSecondary)))
                } else if isPlaying {
                    Circle().fill(primary).frame(width: 6, height: 6)
                } else if isCurrent {
                    Circle().fill(primary.opacity(0.4)).frame(width: 6, height: 6)
                }
            }
            .frame(minHeight: 52)

            // 下载进度条（静默，无文字）
            if status == .downloading {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(primary.opacity(0.08))
                            .frame(height: 1)
                        Rectangle()
                            .fill(primary.opacity(0.5))
                            .frame(width: max(0, min(geometry.size.width * progress, geometry.size.width)), height: 1)
                    }
                }
                .frame(height: 1)
                .padding(.leading, isCurrent ? 17 : 20)
                .padding(.trailing, 36)
            }
        }
        .padding(.horizontal, 36)
        .contentShape(Rectangle())
        .onTapGesture {
            manager.handleMediaItemTap(name: name, file: file, fileExtension: ext)
        }
    }

}

private struct ButtonFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}
