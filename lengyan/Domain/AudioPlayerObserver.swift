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
    private var playerCancellables = Set<AnyCancellable>()
    private var timeObserver: Any?
    private var isObservationSetup = false
    private var lastNowPlayingUpdateTime: Double = 0
    private var trackSubscription: AnyCancellable?

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
        if let observer = timeObserver, let player = queuePlayer {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }

        playerCancellables.removeAll()

        playerTimer?.invalidate()
        playerTimer = nil

        queuePlayer = nil

        isObservationSetup = false

        trackSubscription?.cancel()
        trackSubscription = nil

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
                if let item = newItem {
                    self?.showPlayerBar = true
                    self?.totalTime = CMTimeGetSeconds(item.duration)
                }
            }
            .store(in: &playerCancellables)

        queuePlayer?.publisher(for: \.rate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newRate in
                self?.isPlaying = newRate > 0
                self?.updateNowPlayingInfo()
            }
            .store(in: &playerCancellables)

        guard let player = queuePlayer else { return }

        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main) { [weak self] time in
            guard let self = self, let currentItem = player.currentItem else { return }

            let currentTimeSeconds = CMTimeGetSeconds(time)
            let durationSeconds = CMTimeGetSeconds(currentItem.duration)

            if currentTimeSeconds.isFinite && currentTimeSeconds >= 0 {
                self.currentTime = currentTimeSeconds
            } else {
                self.currentTime = 0
            }

            if (self.totalTime.isNaN || self.totalTime == 0) && durationSeconds.isFinite && durationSeconds > 0 {
                self.totalTime = durationSeconds
            }

            // 每5秒更新一次锁屏进度
            if currentTimeSeconds - self.lastNowPlayingUpdateTime >= 5.0 {
                self.lastNowPlayingUpdateTime = currentTimeSeconds
                self.updateNowPlayingInfo()
            }
        }

        isObservationSetup = true

        setupRemoteCommands()
    }

    private func setupAudioSessionIfNeeded() {
        do {
            let session = AVAudioSession.sharedInstance()
            if session.category != AVAudioSessionCategoryPlayback {
                try session.setCategory(AVAudioSessionCategoryPlayback, mode: AVAudioSessionModeDefault)
                try session.setActive(true, with: .notifyOthersOnDeactivation)
            }
        } catch {
            print("⚠️ Audio session setup failed: \(error)")
        }
    }

    // MARK: - Now Playing Info

    func updateNowPlayingInfo() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentTrack ?? "楞嚴經",
            MPMediaItemPropertyArtist: "屏東能淨協會讀誦",
            MPMediaItemPropertyPlaybackDuration: totalTime,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        if let icon = UIImage(named: "AppIcon60x60") ?? UIImage(named: "Icon-60@2x") {
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
    }

    private func removeRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.removeTarget(self)
        commandCenter.pauseCommand.removeTarget(self)
        commandCenter.togglePlayPauseCommand.removeTarget(self)
        commandCenter.changePlaybackPositionCommand.removeTarget(self)
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
            guard let self = self else { return }
            let time = CMTime(seconds: event.positionTime, preferredTimescale: 600)
            self.queuePlayer?.seek(to: time, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero)
            self.currentTime = event.positionTime
            self.lastNowPlayingUpdateTime = event.positionTime
            self.updateNowPlayingInfo()
        }
        return .success
    }
}
