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

    // PlayMode计数器
    private var playCount = 0

    // Download state
    @Published var downloadProgress: [String: Double] = [:]
    @Published var downloadStatus: [String: MediaItem.MediaStatus] = [:]
    @Published var downloadErrorMessage: String?
    var resourceRequests: [String: NSBundleResourceRequest] = [:]

    private init() {
        if let raw = Prefers.shared.lastPlayMode,
           let mode = PlayMode(rawValue: raw) {
            selectedPlayMode = mode
        }
        // 主动加载：避免 TabBar 非首屏 tab 的 onAppear 不触发导致列表为空
        if Book.shared.loaded {
            loadMediaData()
        }
    }

    // MARK: - Data Loading

    func loadMediaData() {
        // 已加载过则跳过
        guard mediaGroups.isEmpty else { return }
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
        // 我们不再启动时检查所有文件状态 (checkMediaStatus)。
        // ODR (按需资源) 的最佳实践是「按需检查」。
        // 当用户点击播放某个曲目时，系统会瞬间判断资源是否存在。
        isLoading = false
        resumeLastPlayback()
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
                // 不覆盖 downloadStatus — 让 checkMediaStatus 的异步回调决定真实状态
                // 如果文件未下载，用户点击时会自动走下载流程
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
            // 播放器已加载该曲目
            if audioObserver.currentTrack == name && audioObserver.queuePlayer?.currentItem != nil {
                // 如果再次点击正在播放的项目，则从头重新播放
                audioObserver.seek(to: 0)
                if !audioObserver.isPlaying {
                    audioObserver.queuePlayer?.play()
                }
            } else {
                playMedia(name: name, file: file, fileExtension: fileExtension)
            }
        case .notDownloaded, .error:
            downloadMedia(name: name, file: file, fileExtension: fileExtension)
        case .downloading:
            break
        }
    }

    // MARK: - Download

    func downloadMedia(name: String, file: String, fileExtension: String) {
        // 停止当前播放，防止出现一边播放旧音频一边下载新音频的混乱体验
        audioObserver.queuePlayer?.pause()
        audioObserver.isPlaying = false

        downloadStatus[file] = .downloading
        downloadProgress[file] = 0

        // 立即展示小播放器栏并同步曲目名，进入下载状态
        audioObserver.currentTrack = name
        audioObserver.showPlayerBar = true

        // 复用已有的 prefetch 请求，避免重复下载
        if let existing = resourceRequests[file] {
            // prefetch 已调用 beginAccessingResources，不能重复调用
            // 挂上进度 UI，等 prefetch 完成后自动播放
            setupDownloadTimerAndFetch(resourceRequest: existing, file: file, isPrefetchInProgress: true, name: name, fileExtension: fileExtension)
        } else {
            DispatchQueue.global(qos: .userInitiated).async {
                let req = NSBundleResourceRequest(tags: [file])
                req.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
                
                DispatchQueue.main.async {
                    self.resourceRequests[file] = req
                    self.setupDownloadTimerAndFetch(resourceRequest: req, file: file, isPrefetchInProgress: false, name: name, fileExtension: fileExtension)
                }
            }
        }
    }
    
    private func setupDownloadTimerAndFetch(resourceRequest: NSBundleResourceRequest, file: String, isPrefetchInProgress: Bool, name: String, fileExtension: String) {

        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if self.downloadStatus[file] == .downloaded || self.downloadStatus[file] == .error {
                timer.invalidate()
            } else {
                let realProgress = resourceRequest.progress.fractionCompleted
                self.downloadProgress[file] = realProgress > 0 ? realProgress : 0.01
            }
        }

        // prefetch 已在下载中，只需挂上完成回调，不能重复调用 beginAccessingResources
        if isPrefetchInProgress {
            // 轮询等待 prefetch 完成，然后自动播放
            let _ = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { timer in
                if self.downloadStatus[file] == .downloaded || self.downloadStatus[file] == .error {
                    timer.invalidate()
                    progressTimer.invalidate()
                    if self.downloadStatus[file] == .downloaded {
                        self.downloadProgress[file] = 1.0
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            self.downloadProgress.removeValue(forKey: file)
                            self.playMedia(name: name, file: file, fileExtension: fileExtension)
                        }
                    }
                }
            }
            return
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

        // 新曲目，重置播放计数（必须在设置 currentTrack 之前判断）
        if audioObserver.currentTrack != name {
            playCount = 0
        }

        audioObserver.currentTrack = name
        audioObserver.showPlayerBar = true
        audioObserver.initializePlayerIfNeeded()

        guard let resourceRequest = resourceRequests[file] else {
            DispatchQueue.global(qos: .userInitiated).async {
                let newRequest = NSBundleResourceRequest(tags: [file])
                newRequest.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
                DispatchQueue.main.async {
                    self.resourceRequests[file] = newRequest
                    self.playMediaUsingRequest(request: newRequest, name: name, file: file, fileExtension: fileExtension, autoplay: autoplay)
                }
            }
            return
        }

        playMediaUsingRequest(request: resourceRequest, name: name, file: file, fileExtension: fileExtension, autoplay: autoplay)
    }

    private func playMediaUsingRequest(request: NSBundleResourceRequest, name: String, file: String, fileExtension: String, autoplay: Bool = true) {
        if let url = request.bundle.url(forResource: file, withExtension: fileExtension) {
            playAudio(url: url, name: name, autoplay: autoplay)
        } else {
            // 获取不到 URL 说明尚未持有访问权限，需正式申请资源访问
            request.conditionallyBeginAccessingResources { available in
                DispatchQueue.main.async {
                    if available, let url = request.bundle.url(forResource: file, withExtension: fileExtension) {
                        self.playAudio(url: url, name: name, autoplay: autoplay)
                    } else {
                        print("❌ Resource not immediately available, triggering download: \(file)")
                        // 如果状态有误，回退到标准下载流程
                        self.downloadMedia(name: name, file: file, fileExtension: fileExtension)
                    }
                }
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

        // 循环模式：静默预下载下一首，确保无缝衔接
        if selectedPlayMode == .repeatAll {
            prefetchNextTrack()
        }
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        // 播放器未初始化（如恢复上次曲目后首次点击）→ 找到当前曲目并播放
        guard let player = audioObserver.queuePlayer else {
            startCurrentTrack()
            return
        }

        if audioObserver.isPlaying {
            player.pause()
            audioObserver.isPlaying = false
        } else {
            if player.currentItem != nil {
                player.play()
                audioObserver.isPlaying = true
            } else {
                startCurrentTrack()
            }
        }
    }

    /// 根据 currentTrack 名称找到对应文件，走完整的点击流程（自动处理下载）
    private func startCurrentTrack() {
        guard let trackName = audioObserver.currentTrack else { return }
        for group in mediaGroups {
            if let index = group.names.firstIndex(of: trackName) {
                let file = group.files[index]
                handleMediaItemTap(name: trackName, file: file, fileExtension: group.fileExtension)
                return
            }
        }
    }

    // MARK: - Play Mode

    func selectMode(_ mode: PlayMode) {
        selectedPlayMode = mode
        playCount = 0
        Prefers.shared.lastPlayMode = mode.rawValue
    }

    // MARK: - Playback Completion

    func handlePlaybackCompletion() {
        playCount += 1
        let mode = selectedPlayMode

        switch mode {
        case .repeatAll:
            playNextTrack()
        case .repeatOne:
            replayCurrentTrack()
        default:
            // playOnce / playNTimes
            let targetCount = mode.rawValue
            if playCount < targetCount {
                replayCurrentTrack()
            }
            // 达到次数则停止，不做任何操作
        }
    }

    private func replayCurrentTrack() {
        guard let last = audioObserver.lastPlayFile else { return }
        playMedia(name: last.0, file: last.1, fileExtension: last.2)
    }

    func playNextTrack() {
        let currentFile: String
        if let last = audioObserver.lastPlayFile {
            currentFile = last.1
        } else if let currentTrackName = audioObserver.currentTrack {
            var foundFile: String?
            for group in mediaGroups {
                if let index = group.names.firstIndex(of: currentTrackName) {
                    foundFile = group.files[index]
                    break
                }
            }
            guard let file = foundFile else { return }
            currentFile = file
        } else {
            // Play first item of first group
            guard let group = mediaGroups.first, !group.files.isEmpty else { return }
            handleMediaItemTap(name: group.names[0], file: group.files[0], fileExtension: group.fileExtension)
            return
        }

        // 在当前组中查找下一首，未下载的自动下载播放
        for group in mediaGroups {
            if let index = group.files.firstIndex(of: currentFile) {
                let nextIndex = (index + 1) % group.files.count
                let nextFile = group.files[nextIndex]
                let nextName = group.names[nextIndex]
                handleMediaItemTap(name: nextName, file: nextFile, fileExtension: group.fileExtension)
                return
            }
        }
    }

    func playPreviousTrack() {
        let currentFile: String
        if let last = audioObserver.lastPlayFile {
            currentFile = last.1
        } else if let currentTrackName = audioObserver.currentTrack {
            var foundFile: String?
            for group in mediaGroups {
                if let index = group.names.firstIndex(of: currentTrackName) {
                    foundFile = group.files[index]
                    break
                }
            }
            guard let file = foundFile else { return }
            currentFile = file
        } else {
            // Play first item of first group
            guard let group = mediaGroups.first, !group.files.isEmpty else { return }
            handleMediaItemTap(name: group.names[0], file: group.files[0], fileExtension: group.fileExtension)
            return
        }

        for group in mediaGroups {
            if let index = group.files.firstIndex(of: currentFile) {
                let prevIndex = (index - 1 + group.files.count) % group.files.count
                let prevFile = group.files[prevIndex]
                let prevName = group.names[prevIndex]
                handleMediaItemTap(name: prevName, file: prevFile, fileExtension: group.fileExtension)
                return
            }
        }
    }

    /// 静默预下载下一首曲目，确保循环播放无缝衔接
    private func prefetchNextTrack() {
        guard let last = audioObserver.lastPlayFile else { return }
        let currentFile = last.1

        for group in mediaGroups {
            if let index = group.files.firstIndex(of: currentFile) {
                let nextIndex = (index + 1) % group.files.count
                let nextFile = group.files[nextIndex]

                // 已下载、正在下载、或已有请求（用户手动触发），无需预取
                guard downloadStatus[nextFile] != .downloaded
                      && downloadStatus[nextFile] != .downloading
                      && resourceRequests[nextFile] == nil else { return }

                DispatchQueue.global(qos: .utility).async {
                    let request = NSBundleResourceRequest(tags: [nextFile])
                    DispatchQueue.main.async {
                        self.resourceRequests[nextFile] = request

                        request.beginAccessingResources { error in
                            DispatchQueue.main.async {
                                if error == nil {
                                    self.downloadStatus[nextFile] = .downloaded
                                }
                                // 预取静默完成，不影响 UI
                            }
                        }
                    }
                }
                return
            }
        }
    }

    // MARK: - Audio Session

    func setupAudioSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(AVAudioSessionCategoryPlayback, mode: AVAudioSessionModeDefault)
                try session.setActive(true, with: .notifyOthersOnDeactivation)
            } catch {
                print("❌ Failed to setup audio session: \(error)")
            }
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
