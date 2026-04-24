//
//  AudioManager.swift
//  lengyan
//
//  音频下载与播放管理
//

import AVFoundation

class AudioManager: ObservableObject {
    static let shared = AudioManager()

    let audioObserver = AudioPlayerObserver.shared

    // MARK: - Published State

    @Published var mediaGroups: [MediaGroup] = []
    @Published var isLoading = true
    @Published var selectedPlayMode: PlayMode = .repeatAll

    // Download state
    @Published var downloadProgress: [String: Double] = [:]
    @Published var downloadStatus: [String: MediaItem.MediaStatus] = [:]
    @Published var downloadErrorMessage: String?
    var resourceRequests: [String: NSBundleResourceRequest] = [:]

    private init() {}

    // MARK: - Data Loading

    func loadMediaData() {
        guard let mediaData = Book.shared.media else {
            isLoading = false
            return
        }

        var groups: [MediaGroup] = []
        for mediaDict in mediaData {
            if let name = mediaDict["name"] as? String,
               let files = mediaDict["files"] as? [String],
               let names = mediaDict["names"] as? [String],
               let ext = mediaDict["extension"] as? String {
                groups.append(MediaGroup(name: name, files: files, names: names, fileExtension: ext))
            }
        }

        mediaGroups = groups
        checkMediaStatus()
        isLoading = false
        resumeLastPlayback()
    }

    private func checkMediaStatus() {
        for group in mediaGroups {
            for file in group.files {
                if downloadStatus[file] != .downloaded {
                    checkFileStatus(file: file, fileExtension: group.fileExtension)
                }
            }
        }
    }

    private func checkFileStatus(file: String, fileExtension: String) {
        let resourceRequest = NSBundleResourceRequest(tags: [file])
        resourceRequest.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent

        resourceRequest.conditionallyBeginAccessingResources { (available: Bool) in
            DispatchQueue.main.async {
                if available {
                    if resourceRequest.bundle.url(forResource: file, withExtension: fileExtension) != nil {
                        print("📦 ODR already available: \(file).\(fileExtension)")
                        self.downloadStatus[file] = .downloaded
                        self.resourceRequests[file] = resourceRequest
                    } else {
                        print("⏳ ODR not available: \(file).\(fileExtension) - needs download")
                        self.downloadStatus[file] = .notDownloaded
                    }
                } else {
                    print("⏳ ODR not downloaded: \(file).\(fileExtension) - Tap to download")
                    self.downloadStatus[file] = .notDownloaded
                }
            }
        }
    }

    // MARK: - Resume

    func resumeLastPlayback() {
        guard let lastFileName = Prefers.shared.lastPlayFile?.first,
              !lastFileName.isEmpty else {
            return
        }

        for group in mediaGroups {
            if let index = group.files.firstIndex(of: lastFileName) {
                guard index < group.names.count && index < group.files.count else { continue }
                let name = group.names[index]
                audioObserver.currentTrack = name
                downloadStatus[lastFileName] = .downloaded
                print("📝 Resumed playback UI: \(name)")
                break
            }
        }
    }

    // MARK: - Tap Handling

    func handleMediaItemTap(name: String, file: String, fileExtension: String) {
        let status = downloadStatus[file] ?? .notDownloaded
        switch status {
        case .downloaded:
            playMedia(name: name, file: file, fileExtension: fileExtension)
        case .notDownloaded, .error:
            downloadMedia(name: name, file: file, fileExtension: fileExtension)
        case .downloading:
            break
        }
    }

    // MARK: - Download

    func downloadMedia(name: String, file: String, fileExtension: String) {
        downloadStatus[file] = .downloading
        downloadProgress[file] = 0

        let resourceRequest = NSBundleResourceRequest(tags: [file])
        resourceRequest.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
        resourceRequests[file] = resourceRequest

        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            let currentProgress = self.downloadProgress[file] ?? 0
            if self.downloadStatus[file] == .downloaded || self.downloadStatus[file] == .error {
                timer.invalidate()
            } else if currentProgress < 0.9 {
                self.downloadProgress[file] = min(0.9, currentProgress + 0.05)
            }
        }

        resourceRequest.beginAccessingResources { (error: Error?) in
            DispatchQueue.main.async {
                progressTimer.invalidate()

                if let error = error {
                    print("❌ Error downloading ODR: \(error)")
                    self.downloadStatus[file] = .error
                    self.resourceRequests[file]?.endAccessingResources()
                    self.resourceRequests[file] = nil
                    self.downloadProgress.removeValue(forKey: file)
                    let msg = self.getODRErrorMessage(error as NSError)
                    print("❌ ODR Error details: \(msg)")
                    self.downloadErrorMessage = msg
                } else {
                    print("✅ Successfully downloaded ODR: \(file)")
                    self.downloadStatus[file] = .downloaded
                    self.downloadProgress[file] = 1.0

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.downloadProgress.removeValue(forKey: file)
                        self.playMedia(name: name, file: file, fileExtension: fileExtension)
                    }
                }
            }
        }
    }

    // MARK: - Playback

    func playMedia(name: String, file: String, fileExtension: String, autoplay: Bool = true) {
        guard !name.isEmpty && !file.isEmpty && !fileExtension.isEmpty else {
            print("❌ Invalid parameters for playMedia")
            return
        }

        audioObserver.currentTrack = name
        audioObserver.showPlayerBar = true
        audioObserver.initializePlayerIfNeeded()

        guard let resourceRequest = resourceRequests[file] else {
            let newRequest = NSBundleResourceRequest(tags: [file])
            newRequest.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
            resourceRequests[file] = newRequest
            playMediaUsingRequest(request: newRequest, name: name, file: file, fileExtension: fileExtension, autoplay: autoplay)
            return
        }

        playMediaUsingRequest(request: resourceRequest, name: name, file: file, fileExtension: fileExtension, autoplay: autoplay)
    }

    private func playMediaUsingRequest(request: NSBundleResourceRequest, name: String, file: String, fileExtension: String, autoplay: Bool = true) {
        if let url = request.bundle.url(forResource: file, withExtension: fileExtension) {
            playAudio(url: url, name: name, autoplay: autoplay)
        } else {
            guard !resourceRequests.keys.contains(file) else { return }
            resourceRequests[file] = request

            request.conditionallyBeginAccessingResources { available in
                if available, let url = request.bundle.url(forResource: file, withExtension: fileExtension) {
                    self.playAudio(url: url, name: name, autoplay: autoplay)
                } else {
                    print("❌ Resource not available: \(file)")
                }
                self.resourceRequests.removeValue(forKey: file)
            }
        }
    }

    private func playAudio(url: URL, name: String, autoplay: Bool = true) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ Audio file does not exist at path: \(url.path)")
            return
        }

        if let currentItem = audioObserver.queuePlayer?.currentItem,
           let currentURL = (currentItem.asset as? AVURLAsset)?.url,
           currentURL == url {
            audioObserver.currentTrack = name
            audioObserver.showPlayerBar = true

            if autoplay && !audioObserver.isPlaying {
                audioObserver.queuePlayer?.play()
                audioObserver.isPlaying = true
            } else if !autoplay && audioObserver.isPlaying {
                audioObserver.queuePlayer?.pause()
                audioObserver.isPlaying = false
            }
            return
        }

        let playerItem = AVPlayerItem(url: url)
        guard playerItem.asset.isReadable else {
            print("❌ Audio asset is not readable: \(url)")
            return
        }

        let wasPlaying = audioObserver.isPlaying

        audioObserver.currentTrack = name
        audioObserver.showPlayerBar = true

        audioObserver.queuePlayer?.removeAllItems()
        audioObserver.queuePlayer?.insert(playerItem, after: nil)

        let fileName = url.lastPathComponent.split(separator: ".").first?.description ?? ""
        audioObserver.lastPlayFile = (name, fileName, url.pathExtension)

        if let file = audioObserver.lastPlayFile?.1 {
            Prefers.shared.lastPlayFile = [file]
        }

        if autoplay || wasPlaying {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.audioObserver.queuePlayer?.play()
                self.audioObserver.isPlaying = true
            }
        } else {
            audioObserver.isPlaying = false
        }
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        guard let player = audioObserver.queuePlayer else { return }

        if audioObserver.isPlaying {
            player.pause()
            audioObserver.isPlaying = false
        } else {
            if player.currentItem != nil {
                player.play()
                audioObserver.isPlaying = true
            } else if let lastFile = audioObserver.lastPlayFile {
                playMedia(name: lastFile.0, file: lastFile.1, fileExtension: lastFile.2)
            }
        }
    }

    // MARK: - Play Mode

    func selectMode(_ mode: PlayMode) {
        selectedPlayMode = mode
        Prefers.shared.lastPlayMode = mode.rawValue
    }

    // MARK: - Audio Session

    func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(AVAudioSessionCategoryPlayback, mode: AVAudioSessionModeDefault)
            try session.setActive(true, with: .notifyOthersOnDeactivation)
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }

    // MARK: - Formatting

    static func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00" }
        let clampedSeconds = min(seconds, 99 * 60 + 59)
        let minutes = Int(clampedSeconds) / 60
        let seconds = Int(clampedSeconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - ODR Error Handling

    private func getODRErrorMessage(_ error: NSError) -> String {
        switch error.code {
        case NSBundleOnDemandResourceOutOfSpaceError:
            return "存储空间不足，无法下载音频"
        case NSBundleOnDemandResourceExceededMaximumSizeError:
            return "音频文件过大"
        case NSBundleOnDemandResourceInvalidTagError:
            return "音频资源无效"
        default:
            return "下载失败，请检查网络后重试"
        }
    }
}
