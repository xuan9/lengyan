import SwiftUI
import AVFoundation

// MARK: - Main View
struct ModernAudioPlayerView: View {
    @ObservedObject var manager = AudioManager.shared
    @ObservedObject var audioObserver = AudioPlayerObserver.shared
    @State private var showModeMenu = false
    @State private var modeButtonFrame: CGRect = .zero
    @State private var showTrackList = true
    @State private var isListInteractive = true // 防止过渡动画期间误触

    var body: some View {
        GeometryReader { rootGeo in
            let tabBarOverlapHeight = tabBarOverlapHeight(in: rootGeo.frame(in: .global))

            ZStack(alignment: .bottom) {
                // 1. 全景沉浸式动态古画背景 + 启动画面风格的竖向书法标题
                ZStack(alignment: .topTrailing) {
                    GeometryReader { geo in
                        Image("sutra_splash")
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .scaleEffect(audioObserver.isPlaying ? 1.03 : 1.0)
                            .animation(.easeInOut(duration: 30).repeatForever(autoreverses: true), value: audioObserver.isPlaying)
                            .clipped()
                    }

                    // 竖向排版已移至 immersivePlayerControls，这里只保留背景图片
                }
                .ignoresSafeArea()
                .opacity(showTrackList ? 0.0 : 1.0) // 当列表出现时，佛画和文字一起彻底淡出消失
                .animation(.easeInOut(duration: 0.8), value: showTrackList)
                .onTapGesture {
                    // 点击佛画区域，立刻切回列表模式
                    if !showTrackList {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            showTrackList = true
                        }
                    }
                }

                // 2. 纯净背景色，列表模式下的绝对底色
                Color(SutraDesignTokens.shared.color(for: .background))
                    .opacity(showTrackList ? 1.0 : 0.0)
                    .animation(.easeInOut(duration: 0.8), value: showTrackList)
                    .ignoresSafeArea()

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
                            Text(L10n.str("audio_credit"))
                                .font(SutraTypographyBridge.uiCaption(weight: .light))
                                .foregroundColor(Color(SutraDesignTokens.shared.color(for: .textSecondary)))
                                .padding(.top, 36)
                                .padding(.bottom, 8)
                        }
                        .padding(.bottom, audioObserver.showPlayerBar ? 260 : 120)
                        .readingContentWidth()
                    }
                }
                .opacity(showTrackList ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.8), value: showTrackList)
                .allowsHitTesting(isListInteractive)

                if audioObserver.showPlayerBar {
                    Group {
                        if showTrackList {
                            listModePlayerBar(tabBarOverlapHeight: tabBarOverlapHeight)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            immersivePlayerControls
                                .contentShape(Rectangle())
                                .transition(.opacity)
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: audioObserver.showPlayerBar)
                }
            }
            .frame(width: rootGeo.size.width, height: rootGeo.size.height)
        }
        // 彻底无视底部安全区，防止 UIKit 隐藏 TabBar 时导致的 Layout 瞬间跳动
        .ignoresSafeArea(.all, edges: .bottom)
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
                            playModeRow(.repeatOne, title: L10n.str("play_mode_repeat_one"), icon: "ic_repeat_one")
                            goldDivider
                            playModeRow(.repeatAll, title: L10n.str("play_mode_repeat"), icon: "ic_repeat")
                            goldDivider
                            ForEach(1...3, id: \.self) { i in
                                playModeRow(
                                    playMode(for: i),
                                    title: String(format: L10n.str("play_mode_times_format"), L10n.str("play_mode_play_one"), i),
                                    icon: "ic_looks_\(i)"
                                )
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
        .onChange(of: showTrackList) { isVisible in
            NotificationCenter.default.post(name: NSNotification.Name("ToggleTabBar"), object: nil, userInfo: ["isHidden": !isVisible])
            
            if isVisible {
                // 等待 0.6 秒佛画消散后再允许点击，彻底防止误触
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    if showTrackList { isListInteractive = true }
                }
            } else {
                isListInteractive = false
            }
        }
        .onAppear {
            if !showTrackList {
                NotificationCenter.default.post(name: NSNotification.Name("ToggleTabBar"), object: nil, userInfo: ["isHidden": true])
            }
        }
        .onDisappear {
            NotificationCenter.default.post(name: NSNotification.Name("ToggleTabBar"), object: nil, userInfo: ["isHidden": false])
        }
    }

    private var isCurrentTrackDownloading: Bool {
        let s = manager.downloadState(forTrackName: audioObserver.currentTrack)
        debugLog("UI isDownloading track=\(audioObserver.currentTrack ?? "nil") isDL=\(s.isDownloading) prog=\(s.progress)")
        return s.isDownloading
    }

    private var currentTrackDownloadProgress: Double {
        manager.downloadState(forTrackName: audioObserver.currentTrack).progress
    }

    private var isWaitingWithoutPlayableTrack: Bool {
        audioObserver.queuePlayer?.currentItem == nil
            && manager.isPreparingRequestedTrack
    }

    private var playButtonShowsDownload: Bool {
        isCurrentTrackDownloading || isWaitingWithoutPlayableTrack
    }

    private var playButtonDownloadProgress: Double {
        isWaitingWithoutPlayableTrack
            ? manager.pendingTrackProgress
            : currentTrackDownloadProgress
    }

    private var pendingPreparationText: String? {
        guard let name = manager.pendingTrackName else { return nil }
        return String(
            format: L10n.str(
                manager.pendingUsesFallback
                    ? "audio_preparing_fallback_track_format"
                    : "audio_preparing_track_format"
            ),
            name,
            Int((manager.pendingTrackProgress * 100).rounded())
        )
    }

    // MARK: - Reusable Player Controls
    private var playButton: some View {
        Button(action: manager.togglePlayPause) {
            Group {
                if playButtonShowsDownload {
                    ZenProgressRing(
                        progress: playButtonDownloadProgress,
                        color: Color(SutraDesignTokens.shared.color(for: .background)),
                        size: 20,
                        lineWidth: 1.5
                    )
                } else {
                    Image(systemName: audioObserver.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundColor(Color(SutraDesignTokens.shared.color(for: .background)))
                }
            }
            .frame(width: 44, height: 44)
            .background(Color(SutraDesignTokens.shared.color(for: .primary)))
            .clipShape(Circle())
            .shadow(color: showTrackList ? Color(SutraDesignTokens.shared.color(for: .primary)).opacity(0.3) : .clear, radius: 8, x: 0, y: 4)
        }
        .disabled(playButtonShowsDownload)
    }

    private var modeButton: some View {
        Button(action: { showModeMenu.toggle() }) {
            Image(manager.selectedPlayMode.iconName)
                .renderingMode(.template)
        }
        .background(
            // 仅在菜单展开时测量自身 frame。常驻的 GeometryReader→PreferenceKey→@State 会在
            // 高频重绘（如下载进度 0.1s 刷新）时形成 AttributeGraph 布局环，从而阻断 downloadStatus
            // 等状态变更向 UI 的传递（表现为小播放器卡在「下载中」）。门控后下载期间不再测量、不成环。
            Group {
                if showModeMenu {
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ButtonFramePreferenceKey.self,
                            value: geo.frame(in: .global)
                        )
                    }
                }
            }
        )
        .onPreferenceChange(ButtonFramePreferenceKey.self) { frame in
            modeButtonFrame = frame
        }
    }

    private var listButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.6)) {
                showTrackList.toggle()
            }
        }) {
            Image(systemName: "list.bullet")
        }
    }

    private var timeDisplay: some View {
        Group {
            if audioObserver.totalTime > 0 {
                HStack(spacing: 4) {
                    Text(AudioManager.formatTime(audioObserver.currentTime))
                    Text("/")
                    Text(AudioManager.formatTime(audioObserver.totalTime))
                }
            } else {
                Text(" ")
            }
        }
        .font(.system(size: 11, weight: .medium, design: .monospaced))
    }

    // MARK: - Layout 1: List Mode Player Bar (Glassmorphism Pill)
    private func listModePlayerBar(tabBarOverlapHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            // 播放器药丸主体
            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                HStack(alignment: .center, spacing: 16) {
                    playButton

                    VStack(alignment: .leading, spacing: 4) {
                        if let track = audioObserver.currentTrack, !track.isEmpty {
                            Text(track)
                                .font(SutraTypographyBridge.uiBody(weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        } else if let pendingTrackName = manager.pendingTrackName {
                            Text(pendingTrackName)
                                .font(SutraTypographyBridge.uiBody(weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        } else {
                            Text(L10n.str("audio_empty_prompt"))
                                .font(SutraTypographyBridge.uiCaption(weight: .light))
                                .tracking(2)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }

                        if let pendingPreparationText {
                            Text(pendingPreparationText)
                                .font(SutraTypographyBridge.uiCaption(weight: .regular))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        } else if isCurrentTrackDownloading {
                            ZenBreathingText(text: L10n.str("downloading_text"))
                        } else {
                            timeDisplay
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    HStack(spacing: 20) {
                        modeButton
                    }
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 12)
            .padding(.horizontal, 16)

            // 透明防穿透遮罩（填满药丸和 TabBar 之间的物理空隙，拦截点击事件防止穿透到下方的列表）
            Color.black.opacity(0.001)
                .frame(height: 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    // 空操作，专用于拦截点击事件，防止穿透
                }

            if tabBarOverlapHeight > 0 {
                // 如果当前 SwiftUI 容器延伸到 TabBar 下方，只补真实重叠高度；非透明 TabBar 已占位时这里为 0。
                Color.clear
                    .frame(height: tabBarOverlapHeight)
            }
        }
    }

    private func tabBarOverlapHeight(in viewFrame: CGRect) -> CGFloat {
        guard
            let tabBar = activeTabBar(),
            !tabBar.isHidden,
            tabBar.alpha > 0.01
        else {
            return 0
        }

        let tabBarFrame = tabBar.convert(tabBar.bounds, to: nil)
        guard !tabBarFrame.isEmpty else { return 0 }

        let overlap = viewFrame.intersection(tabBarFrame)
        guard !overlap.isNull else { return 0 }

        return max(0, min(tabBarFrame.height, overlap.height))
    }

    private func activeTabBar() -> UITabBar? {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }

        return (window?.rootViewController as? UITabBarController)?.tabBar
    }

    // MARK: - Layout 2: Immersive Buddha Mode Controls (Zen Single Column)
    private var immersivePlayerControls: some View {
        VStack(alignment: .center, spacing: 0) {
            // 标题 + 卧香左右并排，负间距贴合
            HStack(alignment: .top, spacing: -12) {
                // 竖排标题
                Group {
                    if let track = audioObserver.currentTrack, !track.isEmpty {
                        Text(track.map { String($0) }.joined(separator: "\n"))
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(Color(red: 0.45, green: 0.12, blue: 0.10))
                            .lineSpacing(4)
                    } else {
                        Text(L10n.str("audio_immersive_title"))
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(Color(red: 0.45, green: 0.12, blue: 0.10))
                            .lineSpacing(4)
                    }
                }
                .fixedSize()

                // 竖向卧香紧贴标题右侧；直接用 maxHeight:.infinity 填满 HStack 高度（=标题高度），
                // 不再「量标题高度 → @State → 喂回 frame」——那是 AttributeGraph 布局环的源头
                verticalIncenseProgressBar
                    .frame(minWidth: 44, maxWidth: 44, maxHeight: .infinity)
                    .clipped()
            }

            if let pendingPreparationText {
                Text(pendingPreparationText)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(red: 0.45, green: 0.12, blue: 0.10).opacity(0.75))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 120)
                    .padding(.top, 10)
                    .offset(x: -14)
            }

            // 时间圈：静态细线圈，仅显示时间，进度由卧香表达
            ZStack {
                Circle()
                    .stroke(Color(red: 0.45, green: 0.12, blue: 0.10).opacity(0.25), lineWidth: 0.5)
                    .frame(width: 48, height: 48)

                VStack(spacing: 2) {
                    if audioObserver.totalTime > 0 {
                        Text(AudioManager.formatTime(audioObserver.currentTime))
                            .foregroundColor(Color(red: 0.45, green: 0.12, blue: 0.10))
                        Text(AudioManager.formatTime(audioObserver.totalTime))
                            .foregroundColor(Color(red: 0.45, green: 0.12, blue: 0.10))
                    } else {
                        Text(" ")
                    }
                }
                .font(.system(size: 9, weight: .medium, design: .monospaced))
            }
            .padding(.top, 12)
            .offset(x: -14)

            // 控制按钮竖排，对齐标题视觉中心
            VStack(spacing: 24) {
                playButton
                listButton
                    .font(.system(size: 20))
                    .foregroundColor(Color(red: 0.45, green: 0.12, blue: 0.10).opacity(0.8))
            }
            .padding(.top, 24)
            .offset(x: -14)
        }
        .fixedSize()
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 24)
        .padding(.top, 94)
        .frame(maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.height > 60 && abs(value.translation.height) > abs(value.translation.width) * 1.5 {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            showTrackList = true
                        }
                    }
                }
        )
    }

    // MARK: - Incense Progress Bar (Zen Vertical Floating Incense)
    private var verticalIncenseProgressBar: some View {
        GeometryReader { geometry in
            let progress = audioObserver.totalTime > 0 ? CGFloat(audioObserver.currentTime / audioObserver.totalTime) : 0
            let burntHeight = geometry.size.height * progress
            let unburntHeight = geometry.size.height - burntHeight
            
            ZStack(alignment: .top) {
                // 香灰痕迹
                Capsule()
                    .fill(Color(red: 0.45, green: 0.12, blue: 0.10).opacity(0.15))
                    .frame(width: 1, height: geometry.size.height)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                // 剩下的竖香（从上向下燃烧）
                VStack(spacing: 0) {
                    Spacer(minLength: burntHeight)
                    Capsule()
                        .fill(Color(red: 0.45, green: 0.12, blue: 0.10).opacity(0.35))
                        .frame(width: 1, height: unburntHeight)
                }
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard audioObserver.totalTime > 0 else { return }
                        let percent = min(max(value.location.y / geometry.size.height, 0), 1)
                        let seekTime = audioObserver.totalTime * Double(percent)
                        audioObserver.seek(to: seekTime)
                    }
            )
        }
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

    // MARK: - Progress Bar
    private var progressBar: some View {
        GeometryReader { geometry in
            let progress = audioObserver.totalTime > 0 ? CGFloat(audioObserver.currentTime / audioObserver.totalTime) : 0
            ZStack(alignment: .leading) {
                // 进度槽背景：在佛画模式下使用专属暗红色，避免深色模式下的白色因为太浅而看不清
                Capsule()
                    .fill(showTrackList ? Color.primary.opacity(0.12) : Color(red: 0.45, green: 0.12, blue: 0.10).opacity(0.15))
                    .frame(height: 3)

                Capsule()
                    .fill(Color(SutraDesignTokens.shared.color(for: .primary)).opacity(0.85))
                    .frame(width: max(0, min(geometry.size.width * progress, geometry.size.width)), height: 3)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard audioObserver.totalTime > 0 else { return }
                        let percent = min(max(value.location.x / geometry.size.width, 0), 1)
                        let seekTime = audioObserver.totalTime * Double(percent)
                        audioObserver.seek(to: seekTime)
                    }
            )
        }
        .frame(height: 4)
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
                    HStack(spacing: 7) {
                        Text(L10n.str("audio_preparing_short"))
                            .font(SutraTypographyBridge.uiCaption(weight: .regular))
                            .foregroundColor(Color(SutraDesignTokens.shared.color(for: .textSecondary)))
                        ZenProgressRing(
                            progress: progress,
                            color: primary,
                            size: 14,
                            lineWidth: 1.5
                        )
                    }
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

// MARK: - Zen Audio Player Visual Subcomponents
private struct ZenProgressRing: View {
    let progress: Double
    let color: Color
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(max(0.05, min(progress, 1.0))))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.15), value: progress)
        }
        .frame(width: size, height: size)
    }
}

private struct ZenBreathingText: View {
    let text: String
    @State private var isBreathing = false

    var body: some View {
        Text(text)
            .font(SutraTypographyBridge.uiCaption(weight: .light))
            .foregroundColor(Color(SutraDesignTokens.shared.color(for: .textSecondary)))
            .lineLimit(1)
            .opacity(isBreathing ? 0.35 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isBreathing = true
                }
            }
    }
}
