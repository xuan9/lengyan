//
//  AudioPlayerObserver.swift
//  lengyan
//
//  音频播放状态管理
//

import AVFoundation
import Combine
import MediaPlayer

class AudioPlayerObserver: NSObject, ObservableObject {
    static let shared = AudioPlayerObserver()

    @Published var currentTrack: String?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var totalTime: Double = 0
    @Published var showPlayerBar = false

    var queuePlayer: AVQueuePlayer?
    var playerTimer: Timer?
    var lastPlayFile: (String, String, String)?
    var onFirstPlaybackStarted: (() -> Void)?
    var onPlayerItemRemoved: (() -> Void)?
    private var playerCancellables = Set<AnyCancellable>()
    private var timeObserver: Any?
    private var isObservationSetup = false
    private var lastNowPlayingUpdateTime: Double = 0
    private var trackSubscription: AnyCancellable?
    private var hasReportedPlaybackStartForCurrentItem = false

    private override init() {
        super.init()

        trackSubscription = $currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.lastNowPlayingUpdateTime = 0
                self?.updateNowPlayingInfo()
            }
    }

    func cleanup() {
        let hadPlayerItem = queuePlayer?.currentItem != nil
        if let observer = timeObserver, let player = queuePlayer {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }

        playerCancellables.removeAll()

        playerTimer?.invalidate()
        playerTimer = nil

        queuePlayer = nil
        hasReportedPlaybackStartForCurrentItem = false

        if hadPlayerItem {
            onPlayerItemRemoved?()
        }

        isObservationSetup = false

        trackSubscription?.cancel()
        trackSubscription = nil

        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)

        removeRemoteCommands()

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func initializePlayerIfNeeded() {
        if queuePlayer == nil {
            queuePlayer = AVQueuePlayer()
            setupPlayerObservation()
        }
        setupAudioSessionIfNeeded()
    }

    func reinitializePlayer() {
        cleanup()
        queuePlayer = AVQueuePlayer()
        setupPlayerObservation()
    }

    private func setupPlayerObservation() {
        guard !isObservationSetup else { return }

        queuePlayer?.publisher(for: \.currentItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newItem in
                self?.hasReportedPlaybackStartForCurrentItem = false
                if let item = newItem {
                    self?.showPlayerBar = true
                    self?.totalTime = CMTimeGetSeconds(item.duration)
                }
            }
            .store(in: &playerCancellables)

        queuePlayer?.publisher(for: \.rate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newRate in
                guard let self else { return }
                self.isPlaying = newRate > 0
                if newRate > 0,
                   self.queuePlayer?.currentItem != nil,
                   !self.hasReportedPlaybackStartForCurrentItem {
                    self.hasReportedPlaybackStartForCurrentItem = true
                    self.onFirstPlaybackStarted?()
                }
                self.updateNowPlayingInfo()
            }
            .store(in: &playerCancellables)

        guard let player = queuePlayer else { return }

        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main) { [weak self] time in
            guard let self = self, let currentItem = player.currentItem, !self.isSeeking else { return }

            let currentTimeSeconds = CMTimeGetSeconds(time)
            let durationSeconds = CMTimeGetSeconds(currentItem.duration)

            if currentTimeSeconds.isFinite && currentTimeSeconds >= 0 {
                self.currentTime = currentTimeSeconds
                if abs(currentTimeSeconds - Prefers.shared.lastPlayTime) >= 1.0 {
                    Prefers.shared.lastPlayTime = currentTimeSeconds
                }
            } else {
                self.currentTime = 0
            }

            if (self.totalTime.isNaN || self.totalTime == 0) && durationSeconds.isFinite && durationSeconds > 0 {
                self.totalTime = durationSeconds
                Prefers.shared.lastTotalTime = durationSeconds
            }

            // 每5秒更新一次锁屏进度
            if currentTimeSeconds - self.lastNowPlayingUpdateTime >= 5.0 {
                self.lastNowPlayingUpdateTime = currentTimeSeconds
                self.updateNowPlayingInfo()
            }
        }

        isObservationSetup = true

        setupRemoteCommands()

        // 监听播放完成，通知AudioManager处理PlayMode逻辑
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidPlayToEndTime),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )

        // 监听音频打断通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    private func setupAudioSessionIfNeeded() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let session = AVAudioSession.sharedInstance()
                if session.category != AVAudioSession.Category.playback {
                    try session.setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.default)
                    try session.setActive(true, options: .notifyOthersOnDeactivation)
                }
            } catch {
                print("⚠️ Audio session setup failed: \(error)")
            }
        }
    }

    // MARK: - Now Playing Info

    private func getAppIcon() -> UIImage? {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last,
           let image = UIImage(named: lastIcon) {
            return image
        }
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons~ipad"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last,
           let image = UIImage(named: lastIcon) {
            return image
        }
        for name in ["AppIcon60x60", "AppIcon76x76", "AppIcon83.5x83.5", "AppIcon40x40", "AppIcon"] {
            if let image = UIImage(named: name) {
                return image
            }
        }
        return nil
    }

    func updateNowPlayingInfo() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentTrack ?? "楞嚴經",
            MPMediaItemPropertyArtist: GeneratedAudioManifest.nowPlayingArtist,
            MPMediaItemPropertyPlaybackDuration: totalTime,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        if let icon = getAppIcon() ?? UIImage(named: "sutra") {
            let artwork = MPMediaItemArtwork(boundsSize: icon.size) { _ in icon }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }


    // MARK: - Remote Commands

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget(self, action: #selector(handlePlay))
        commandCenter.pauseCommand.addTarget(self, action: #selector(handlePause))
        commandCenter.togglePlayPauseCommand.addTarget(self, action: #selector(handleTogglePlayPause))
        commandCenter.changePlaybackPositionCommand.addTarget(self, action: #selector(handleSeek(_:)))
        
        commandCenter.nextTrackCommand.addTarget(self, action: #selector(handleNextTrack))
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget(self, action: #selector(handlePreviousTrack))
        commandCenter.previousTrackCommand.isEnabled = true
    }

    private func removeRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.removeTarget(self)
        commandCenter.pauseCommand.removeTarget(self)
        commandCenter.togglePlayPauseCommand.removeTarget(self)
        commandCenter.changePlaybackPositionCommand.removeTarget(self)
        commandCenter.nextTrackCommand.removeTarget(self)
        commandCenter.previousTrackCommand.removeTarget(self)
    }

    func saveCurrentProgressImmediately() {
        if currentTime.isFinite && currentTime > 0 {
            Prefers.shared.lastPlayTime = currentTime
        }
        if totalTime.isFinite && totalTime > 0 {
            Prefers.shared.lastTotalTime = totalTime
        }
    }

    private var isSeeking = false

    func seek(to seconds: Double) {
        guard let player = queuePlayer else { return }
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        isSeeking = true
        self.currentTime = seconds
        self.lastNowPlayingUpdateTime = seconds
        self.updateNowPlayingInfo()
        Prefers.shared.lastPlayTime = seconds

        player.seek(to: time, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero) { [weak self] _ in
            DispatchQueue.main.async {
                self?.isSeeking = false
            }
        }
    }

    func clearSeekProtection() {
        isSeeking = false
    }

    func replaceItem(with url: URL) throws {
        initializePlayerIfNeeded()
        let item = AVPlayerItem(url: url)
        guard item.asset.isReadable else {
            throw AudioAssetError.missingLocalFile(url.path)
        }
        isSeeking = true
        queuePlayer?.removeAllItems()
        queuePlayer?.insert(item, after: nil)
        hasReportedPlaybackStartForCurrentItem = false
        currentTime = 0
        totalTime = 0
        lastNowPlayingUpdateTime = 0
    }

    func stopAndRemoveItem() {
        let hadPlayerItem = queuePlayer?.currentItem != nil
        queuePlayer?.pause()
        queuePlayer?.removeAllItems()
        isPlaying = false
        currentTime = 0
        totalTime = 0
        hasReportedPlaybackStartForCurrentItem = false
        if hadPlayerItem {
            onPlayerItemRemoved?()
        }
    }

    @objc private func handlePlay() -> MPRemoteCommandHandlerStatus {
        DispatchQueue.main.async { [weak self] in
            self?.queuePlayer?.play()
            self?.isPlaying = true
            self?.updateNowPlayingInfo()
        }
        return .success
    }

    @objc private func handlePause() -> MPRemoteCommandHandlerStatus {
        DispatchQueue.main.async { [weak self] in
            self?.queuePlayer?.pause()
            self?.isPlaying = false
            self?.updateNowPlayingInfo()
        }
        return .success
    }

    @objc private func handleTogglePlayPause() -> MPRemoteCommandHandlerStatus {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.queuePlayer?.rate ?? 0 > 0 {
                self.queuePlayer?.pause()
                self.isPlaying = false
            } else {
                self.queuePlayer?.play()
                self.isPlaying = true
            }
            self.updateNowPlayingInfo()
        }
        return .success
    }

    @objc private func handleSeek(_ event: MPChangePlaybackPositionCommandEvent) -> MPRemoteCommandHandlerStatus {
        DispatchQueue.main.async { [weak self] in
            self?.seek(to: event.positionTime)
        }
        return .success
    }

    @objc private func handleNextTrack() -> MPRemoteCommandHandlerStatus {
        DispatchQueue.main.async {
            AudioManager.shared.playNextTrack()
        }
        return .success
    }

    @objc private func handlePreviousTrack() -> MPRemoteCommandHandlerStatus {
        DispatchQueue.main.async {
            AudioManager.shared.playPreviousTrack()
        }
        return .success
    }

    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            DispatchQueue.main.async { [weak self] in
                self?.isPlaying = false
                self?.updateNowPlayingInfo()
            }
        case .ended:
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    DispatchQueue.main.async { [weak self] in
                        self?.queuePlayer?.play()
                        self?.isPlaying = true
                        self?.updateNowPlayingInfo()
                    }
                }
            }
        @unknown default:
            break
        }
    }

    @objc private func playerItemDidPlayToEndTime(_ notification: Notification) {
        guard notification.object is AVPlayerItem else { return }

        // AVQueuePlayer 在 didPlayToEndTime 后会移除已完成的 item，
        // 导致 currentItem 变为 nil，不能依赖 === currentItem 判断。
        // App 内只有一个 AVQueuePlayer，所以该通知必然属于当前播放的曲目。
        DispatchQueue.main.async {
            self.isPlaying = false
            AudioManager.shared.handlePlaybackCompletion()
        }
    }
}
