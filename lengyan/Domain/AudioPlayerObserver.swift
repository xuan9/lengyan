//
//  AudioPlayerObserver.swift
//  lengyan
//
//  音频播放状态管理
//

import AVFoundation
import Combine

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
    private var cancellables = Set<AnyCancellable>()
    private var timeObserver: Any?
    private var isObservationSetup = false

    private override init() {
        super.init()
    }

    func cleanup() {
        if let observer = timeObserver, let player = queuePlayer {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }

        cancellables.removeAll()

        playerTimer?.invalidate()
        playerTimer = nil

        queuePlayer = nil

        isObservationSetup = false
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
            .store(in: &cancellables)

        queuePlayer?.publisher(for: \.rate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newRate in
                self?.isPlaying = newRate > 0
            }
            .store(in: &cancellables)

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
        }

        isObservationSetup = true
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
}
