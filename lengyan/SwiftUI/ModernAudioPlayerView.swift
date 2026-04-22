import SwiftUI
import AVFoundation

// MARK: - Main View
struct ModernAudioPlayerView: View {
    @ObservedObject var manager = AudioManager.shared
    @ObservedObject var audioObserver = AudioPlayerObserver.shared

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
                }
                .background(Color(SutraDesignTokens.shared.color(for: .background)))
            }
            .background(Color(SutraDesignTokens.shared.color(for: .background)))

            if audioObserver.showPlayerBar {
                mediaPlayerBar
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .onAppear {
            manager.setupAudioSession()
            manager.loadMediaData()  // loadMediaData 内部已调用 resumeLastPlayback
            audioObserver.showPlayerBar = true
        }
    }

    // MARK: - Media Player Bar
    private var mediaPlayerBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Button(action: manager.togglePlayPause) {
                    Image(audioObserver.isPlaying ? "ic_pause_circle_outline_48pt" : "ic_play_circle_outline_48pt")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 36, height: 36)
                        .foregroundColor(Color(SutraDesignTokens.shared.color(for: .primary)))
                }

                VStack(alignment: .leading, spacing: 6) {
                    if audioObserver.currentTrack?.isEmpty ?? true {
                        Text("请 轻 触 上 列 卷 名 听 经")
                            .font(SutraTypographyBridge.uiCaption(weight: .light))
                            .foregroundColor(Color(SutraDesignTokens.shared.color(for: .textSecondary)))
                            .lineLimit(1)
                    } else {
                        Text(audioObserver.currentTrack!)
                            .font(SutraTypographyBridge.uiBody(weight: .medium))
                            .foregroundColor(Color(SutraDesignTokens.shared.color(for: .textPrimary)))
                            .lineLimit(1)
                    }
                    progressSliderWithTime
                }

                Spacer()

                if audioObserver.currentTrack != nil && !(audioObserver.currentTrack?.isEmpty ?? true) {
                    Button(action: { showPlayModeMenu() }) {
                        Image(manager.selectedPlayMode.iconName)
                            .renderingMode(.template)
                            .foregroundColor(Color(SutraDesignTokens.shared.color(for: .textSecondary)))
                            .frame(width: 24, height: 24)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(SutraDesignTokens.shared.color(for: .background)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color(SutraDesignTokens.shared.color(for: .primary)).opacity(0.1), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: audioObserver.showPlayerBar)
    }

    // MARK: - Progress Slider
    private var progressSliderWithTime: some View {
        HStack(spacing: 8) {
            Text(AudioManager.formatTime(audioObserver.currentTime))
                .font(SutraTypographyBridge.uiCaption(weight: .semibold))
                .monospacedDigit()
                .foregroundColor(Color(SutraDesignTokens.shared.color(for: .textSecondary)))

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
            .frame(height: 24)

            Text(AudioManager.formatTime(audioObserver.totalTime))
                .font(SutraTypographyBridge.uiCaption(weight: .semibold))
                .monospacedDigit()
                .foregroundColor(Color(SutraDesignTokens.shared.color(for: .textSecondary)))
        }
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

    // MARK: - Play Mode Menu (UIKit interop)
    private func showPlayModeMenu() {
        let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        let aRepeat = UIAlertAction(title: NSLocalizedString("play_mode_repeat", comment: "順序循環"), style: .default) { _ in
            manager.selectMode(.repeatAll)
        }
        aRepeat.setValue(UIImage(named: "ic_repeat"), forKey: "image")
        optionMenu.addAction(aRepeat)

        let aRepeat0 = UIAlertAction(title: NSLocalizedString("play_mode_repeat_one", comment: "單曲循環"), style: .default) { _ in
            manager.selectMode(.repeatOne)
        }
        aRepeat0.setValue(UIImage(named: "ic_repeat_one"), forKey: "image")
        optionMenu.addAction(aRepeat0)

        let singlePlay = NSLocalizedString("play_mode_play_one", comment: "單曲播放")
        for i in 1...6 {
            let a = UIAlertAction(title: "\(singlePlay)\(i)次", style: .default) { _ in
                switch i {
                case 1: manager.selectMode(.playOnce)
                case 2: manager.selectMode(.playTwice)
                case 3: manager.selectMode(.play3Times)
                case 4: manager.selectMode(.play4Times)
                case 5: manager.selectMode(.play5Times)
                case 6: manager.selectMode(.play6Times)
                default: break
                }
            }
            a.setValue(UIImage(named: "ic_looks_\(i)"), forKey: "image")
            optionMenu.addAction(a)
        }

        optionMenu.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: "取消"), style: .cancel))

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            if let presenter = optionMenu.popoverPresentationController {
                presenter.sourceView = rootViewController.view
                presenter.sourceRect = CGRect(x: rootViewController.view.bounds.width - 50, y: rootViewController.view.bounds.height - 100, width: 1, height: 1)
            }
            rootViewController.present(optionMenu, animated: true)
        }
    }
}
