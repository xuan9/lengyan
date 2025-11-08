import SwiftUI
import AVFoundation
import MediaPlayer
import Combine

// MARK: - Media Data Model
struct MediaGroup: Identifiable {
    let id = UUID()
    let name: String
    let files: [String]
    let names: [String]
    let fileExtension: String
}

struct MediaItem: Identifiable {
    let id = UUID()
    let name: String
    let file: String
    let fileExtension: String
    let groupName: String
    let status: MediaStatus
    let progress: Double

    enum MediaStatus {
        case notDownloaded
        case downloading
        case downloaded
        case error
    }
}

// MARK: - Play Mode Enum
enum PlayMode: Int, CaseIterable {
    case repeatAll = -1
    case repeatOne = 999
    case playOnce = 1
    case playTwice = 2
    case play3Times = 3
    case play4Times = 4
    case play5Times = 5
    case play6Times = 6

    var displayName: String {
        switch self {
        case .repeatAll: return NSLocalizedString("play_mode_repeat", comment: "順序循環")
        case .repeatOne: return NSLocalizedString("play_mode_repeat_one", comment: "單曲循環")
        case .playOnce: return NSLocalizedString("play_mode_play_one", comment: "單曲播放") + "1次"
        case .playTwice: return NSLocalizedString("play_mode_play_one", comment: "單曲播放") + "2次"
        case .play3Times: return NSLocalizedString("play_mode_play_one", comment: "單曲播放") + "3次"
        case .play4Times: return NSLocalizedString("play_mode_play_one", comment: "單曲播放") + "4次"
        case .play5Times: return NSLocalizedString("play_mode_play_one", comment: "單曲播放") + "5次"
        case .play6Times: return NSLocalizedString("play_mode_play_one", comment: "單曲播放") + "6次"
        }
    }

    var iconName: String {
        switch self {
        case .repeatAll: return "ic_repeat"
        case .repeatOne: return "ic_repeat_one"
        case .playOnce: return "ic_looks_1"
        case .playTwice: return "ic_looks_2"
        case .play3Times: return "ic_looks_3"
        case .play4Times: return "ic_looks_4"
        case .play5Times: return "ic_looks_5"
        case .play6Times: return "ic_looks_6"
        }
    }
}

// MARK: - Main View
struct ModernAudioPlayerView: View {
    @ObservedObject var audioObserver = AudioPlayerObserver.shared
    @State private var mediaGroups: [MediaGroup] = []
    @State private var mediaItems: [MediaItem] = []
    @State private var isLoading = true
    @State private var selectedPlayMode: PlayMode = .repeatAll

    // Download Management
    @State private var downloadProgress: [String: Double] = [:]
    @State private var downloadStatus: [String: MediaItem.MediaStatus] = [:]
    @State private var resourceRequests: [String: NSBundleResourceRequest] = [:] // Store requests

    var body: some View {
        VStack(spacing: 0) {
            // Main Content
            ScrollView {
                VStack(spacing: SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingLG)) {
                    // Header with prominent title and subtitle
                    VStack(alignment: .leading, spacing: SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingXS)) {
                        Text("聽經")
                            .font(SutraTypographyBridge.uiLargeTitle())
                            .foregroundColor(SutraDesignSystem.sutraTextColor())
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("屏東能淨協会證道")
                            .font(SutraTypographyBridge.uiBody())
                            .foregroundColor(SutraDesignSystem.secondaryTextColor())
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingXS))
                    .padding(.bottom, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingMD))
                    .padding(.horizontal, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingXS))

                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding(.top, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingComponentXXL))
                    } else {
                        // Media Groups List
                        ForEach(mediaGroups) { group in
                            mediaGroupSection(group)
                        }
                    }
                }
                .padding(SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingLG))
                .padding(.bottom, audioObserver.showPlayerBar ? 100 : 20) // Space for player bar
            }

            // Media Player Bar (appears when playing)
            if audioObserver.showPlayerBar {
                mediaPlayerBar
            }
        }
        .background(SutraDesignSystem.backgroundColor())
        .edgesIgnoringSafeArea(.bottom)
        .onAppear {
            loadMediaData()
            setupAudioSession()
        }
    }

    // MARK: - Media Player Bar
    private var mediaPlayerBar: some View {
        VStack(spacing: 0) {
            // White padding
            Rectangle()
                .fill(SutraDesignSystem.backgroundColor())
                .frame(height: 16)

            // Main player bar
            Rectangle()
                .fill(SutraDesignSystem.color(.surface))
                .frame(height: 90)
                .overlay(
                    VStack(spacing: 8) {
                        // Progress bar
                        progressSlider

                        // Title and controls
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(audioObserver.currentTrack ?? "")
                                    .font(SutraTypographyBridge.uiBody())
                                    .lineLimit(2)
                                    .foregroundColor(SutraDesignSystem.sutraTextColor())

                                HStack(spacing: 5) {
                                    Text(formatTime(audioObserver.currentTime))
                                        .font(SutraTypographyBridge.uiSmall())
                                        .foregroundColor(SutraDesignSystem.secondaryTextColor())

                                    Spacer()

                                    Text(formatTime(audioObserver.totalTime))
                                        .font(SutraTypographyBridge.uiSmall())
                                        .foregroundColor(SutraDesignSystem.secondaryTextColor())
                                }
                            }

                            Spacer()

                            // Play mode button
                            Button(action: { showPlayModeMenu() }) {
                                Image(selectedPlayMode.iconName)
                                    .renderingMode(.template)
                                    .foregroundColor(SutraDesignSystem.accentColor())
                                    .frame(width: 24, height: 24)
                            }

                            // Play/Pause button
                            Button(action: togglePlayPause) {
                                Image(audioObserver.isPlaying ? "ic_pause_circle_outline_48pt" : "ic_play_circle_outline_48pt")
                                    .foregroundColor(SutraDesignSystem.accentColor())
                                    .frame(width: 40, height: 40)
                            }
                        }
                        .padding(.horizontal, 30)
                    }
                )
        }
        .transition(.move(edge: .bottom))
        .animation(.easeInOut(duration: 0.3), value: audioObserver.showPlayerBar)
    }

    // MARK: - Progress Slider
    private var progressSlider: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .frame(height: 4)

                // Progress
                Rectangle()
                    .fill(Color(red: 0.941, green: 0.918, blue: 0.839))
                    .frame(width: geometry.size.width * (audioObserver.totalTime > 0 ? audioObserver.currentTime / audioObserver.totalTime : 0), height: 4)

                // Scrubber circle
                Circle()
                    .fill(Color(red: 0.941, green: 0.918, blue: 0.839))
                    .frame(width: 12, height: 12)
                    .offset(x: geometry.size.width * (audioObserver.totalTime > 0 ? audioObserver.currentTime / audioObserver.totalTime : 0) - 6)
            }
        }
        .frame(height: 25)
    }

    // MARK: - Media Group Section
    private func mediaGroupSection(_ group: MediaGroup) -> some View {
        VStack(alignment: .leading, spacing: SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingMD)) {
            // Section Header - World-class spacing and typography
            Text(group.name)
                .font(SutraTypographyBridge.uiTitle(weight: .semibold))
                .foregroundColor(SutraDesignSystem.sutraTextColor())
                .padding(.horizontal, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingMD))
                .padding(.vertical, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingMD))

            // Media Items - Better spacing between items
            VStack(spacing: SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingXS)) {
                ForEach(group.files.indices, id: \.self) { index in
                    mediaItemRow(
                        name: group.names[index],
                        file: group.files[index],
                        extension: group.fileExtension,
                        groupName: group.name
                    )
                }
            }
        }
        .padding(SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingMD))
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SutraDesignSystem.backgroundColor().opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(SutraDesignSystem.color(.border).opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Media Item Row
    private func mediaItemRow(name: String, file: String, extension: String, groupName: String) -> some View {
        let status = downloadStatus[file] ?? .notDownloaded
        let progress = downloadProgress[file] ?? 0

        return VStack(alignment: .leading, spacing: SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingXS)) {
            // Title with download status
            HStack {
                Text(titleWithStatus(name: name, status: status))
                    .font(SutraTypographyBridge.uiBody(weight: status == .downloaded ? .regular : .regular))
                    .foregroundColor(status == .downloaded ? SutraDesignSystem.sutraTextColor() : SutraDesignSystem.secondaryTextColor())

                Spacer()
            }

            // Download progress bar
            if status == .downloading {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 3)

                        Rectangle()
                            .fill(SutraDesignSystem.color(.accent))
                            .frame(width: geometry.size.width * progress, height: 3)
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(.horizontal, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingMD))
        .padding(.vertical, SutraDesignTokens.shared.spacing(for: SutraDesignTokens.SpacingTokens.spacingMD))
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(SutraDesignSystem.backgroundColor().opacity(0.6))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            handleMediaItemTap(name: name, file: file, fileExtension: `extension`, groupName: groupName)
        }
    }

    // MARK: - Helper Methods
    private func titleWithStatus(name: String, status: MediaItem.MediaStatus) -> String {
        switch status {
        case .notDownloaded:
            return name
        case .downloading:
            let downloadingText = NSLocalizedString("downloading_text", comment: "正在下载...")
            return name + " - " + downloadingText
        case .downloaded:
            return name
        case .error:
            let downloadFailed = NSLocalizedString("download_failed", comment: "下載失敗")
            return name + " - " + downloadFailed
        }
    }

    // MARK: - Play Mode Menu
    private func showPlayModeMenu() {
        let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        // Repeat All
        let aRepeat = UIAlertAction(title: NSLocalizedString("play_mode_repeat", comment: "順序循環"), style: .default) { _ in
            self.selectMode(mode: .repeatAll)
        }
        aRepeat.setValue(UIImage(named: "ic_repeat"), forKey: "image")
        optionMenu.addAction(aRepeat)

        // Repeat One
        let aRepeat0 = UIAlertAction(title: NSLocalizedString("play_mode_repeat_one", comment: "單曲循環"), style: .default) { _ in
            self.selectMode(mode: .repeatOne)
        }
        aRepeat0.setValue(UIImage(named: "ic_repeat_one"), forKey: "image")
    optionMenu.addAction(aRepeat0)

        // Play N times (1-6)
        let singlePlay = NSLocalizedString("play_mode_play_one", comment: "單曲播放")
        for i in 1...6 {
            let a = UIAlertAction(title: "\(singlePlay)\(i)次", style: .default) { _ in
                switch i {
                case 1: self.selectMode(mode: .playOnce)
                case 2: self.selectMode(mode: .playTwice)
                case 3: self.selectMode(mode: .play3Times)
                case 4: self.selectMode(mode: .play4Times)
                case 5: self.selectMode(mode: .play5Times)
                case 6: self.selectMode(mode: .play6Times)
                default: break
                }
            }
            a.setValue(UIImage(named: "ic_looks_\(i)"), forKey: "image")
            optionMenu.addAction(a)
        }

        // Cancel
        optionMenu.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: "取消"), style: .cancel))

        // Present the alert
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

    private func selectMode(mode: PlayMode) {
        selectedPlayMode = mode
        Prefers.shared.lastPlayMode = mode.rawValue
    }

    // MARK: - Data Loading
    private func loadMediaData() {
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

        // Resume last playback if available
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
        // Create resource request
        let resourceRequest = NSBundleResourceRequest(tags: [file])
        resourceRequest.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent

        // Try to check if resource is available
        resourceRequest.conditionallyBeginAccessingResources { (available: Bool) in
            DispatchQueue.main.async {
                if available {
                    // Check if URL is available
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

    // MARK: - Media Item Handling
    private func handleMediaItemTap(name: String, file: String, fileExtension: String, groupName: String) {
        let status = downloadStatus[file] ?? .notDownloaded

        switch status {
        case .downloaded:
            playMedia(name: name, file: file, fileExtension: fileExtension)
        case .notDownloaded, .error:
            downloadMedia(name: name, file: file, fileExtension: fileExtension)
        case .downloading:
            // Already downloading, do nothing
            break
        }
    }

    // MARK: - Resume Last Playback
    private func resumeLastPlayback() {
        guard let lastFileName = Prefers.shared.lastPlayFile?.first,
              !lastFileName.isEmpty else {
            print("📝 No last playback file to resume")
            return
        }

        // Check if we already have the same file loaded and playing
        if let currentFile = audioObserver.lastPlayFile?.1,
           currentFile == lastFileName,
           audioObserver.queuePlayer?.currentItem != nil {
            print("📝 Same file already loaded: \(lastFileName), preserving state")
            return
        }

        // Find the media group and item for this file
        for group in mediaGroups {
            if let index = group.files.firstIndex(of: lastFileName) {
                // Validate index bounds
                guard index < group.names.count && index < group.files.count else {
                    print("❌ Index out of bounds for file: \(lastFileName)")
                    continue
                }

                let name = group.names[index]
                let file = group.files[index]
                let ext = group.fileExtension

                // Mark as downloaded and load without autoplaying
                downloadStatus[file] = .downloaded
                playMedia(name: name, file: file, fileExtension: ext, autoplay: false)
                print("📝 Resumed last playback: \(name)")
                break
            }
        }
    }

    private func downloadMedia(name: String, file: String, fileExtension: String) {
        downloadStatus[file] = .downloading
        downloadProgress[file] = 0

        print("⬇️ Starting download for: \(file).\(fileExtension)")

        // Create On-Demand Resource request for the specific tag
        let resourceRequest = NSBundleResourceRequest(tags: [file])
        resourceRequest.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent

        // Store the request
        self.resourceRequests[file] = resourceRequest

        // Start download progress simulation (ODR doesn't provide direct progress callbacks)
        let progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            let currentProgress = self.downloadProgress[file] ?? 0

            if self.downloadStatus[file] == .downloaded || self.downloadStatus[file] == .error {
                timer.invalidate()
            } else if currentProgress < 0.9 {
                // Increment progress
                self.downloadProgress[file] = min(0.9, currentProgress + 0.05)
            }
        }

        // Begin accessing resources (triggers ODR download)
        resourceRequest.beginAccessingResources { (error: Error?) in
            DispatchQueue.main.async {
                progressTimer.invalidate()

                if let error = error {
                    print("❌ Error downloading ODR: \(error)")
                    self.downloadStatus[file] = .error
                    self.resourceRequests[file]?.endAccessingResources()
                    self.resourceRequests[file] = nil
                    self.downloadProgress.removeValue(forKey: file)

                    // Show error message based on error code (like old code)
                    let errorMessage = self.getODRErrorMessage(error as NSError)
                    print("❌ ODR Error details: \(errorMessage)")
                } else {
                    print("✅ Successfully downloaded ODR: \(file)")
                    self.downloadStatus[file] = .downloaded
                    self.downloadProgress[file] = 1.0

                    // Auto-play after download completes
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.downloadProgress.removeValue(forKey: file)
                        self.playMedia(name: name, file: file, fileExtension: fileExtension)
                    }
                }
            }
        }
    }

    private func playMedia(name: String, file: String, fileExtension: String, autoplay: Bool = true) {
        // Validate inputs
        guard !name.isEmpty && !file.isEmpty && !fileExtension.isEmpty else {
            print("❌ Invalid parameters for playMedia: name=\(name), file=\(file), ext=\(fileExtension)")
            return
        }

        audioObserver.currentTrack = name
        audioObserver.showPlayerBar = true

        // Initialize the AVQueuePlayer
        audioObserver.initializePlayerIfNeeded()

        // Get the stored resource request
        guard let resourceRequest = resourceRequests[file] else {
            print("❌ No resource request found for \(file)")
            // Try to create a new one
            let newRequest = NSBundleResourceRequest(tags: [file])
            newRequest.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
            self.resourceRequests[file] = newRequest
            playMediaUsingRequest(request: newRequest, name: name, file: file, fileExtension: fileExtension, autoplay: autoplay)
            return
        }

        playMediaUsingRequest(request: resourceRequest, name: name, file: file, fileExtension: fileExtension, autoplay: autoplay)
    }

    private func playMediaUsingRequest(request: NSBundleResourceRequest, name: String, file: String, fileExtension: String, autoplay: Bool = true) {
        // Standard ODR approach for real devices
        if let url = request.bundle.url(forResource: file, withExtension: fileExtension) {
            playAudio(url: url, name: name, autoplay: autoplay)
        } else {
            request.conditionallyBeginAccessingResources { available in
                if available, let url = request.bundle.url(forResource: file, withExtension: fileExtension) {
                    self.playAudio(url: url, name: name, autoplay: autoplay)
                }
                else {
                    print("❌ Resource not available: \(file)")
                }
            }
        }
    }


    private func playAudio(url: URL, name: String, autoplay: Bool = true) {
        // Validate URL
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ Audio file does not exist at path: \(url.path)")
            return
        }

        // Check if this is the same file that's already playing
        if let currentItem = audioObserver.queuePlayer?.currentItem,
           let currentURL = (currentItem.asset as? AVURLAsset)?.url,
           currentURL == url {
            // Same file - just toggle play/pause without resetting position
            audioObserver.currentTrack = name
            audioObserver.showPlayerBar = true

            if autoplay && !audioObserver.isPlaying {
                audioObserver.queuePlayer?.play()
                audioObserver.isPlaying = true
                print("🎵 Resumed playback: \(name)")
            } else if !autoplay && audioObserver.isPlaying {
                audioObserver.queuePlayer?.pause()
                audioObserver.isPlaying = false
                print("⏸️ Paused playback: \(name)")
            }
            return
        }

        // Different file or first play
        let playerItem = AVPlayerItem(url: url)

        // Check if player item is valid
        guard playerItem.asset.isReadable else {
            print("❌ Audio asset is not readable: \(url)")
            return
        }

        // Preserve current playback state before changing tracks
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

        print("✅ Successfully loaded audio: \(name) - URL: \(url)")

        // Start playback if autoplay is true OR if the previous track was playing
        if autoplay || wasPlaying {
            // Start playback after a brief delay to allow the item to load
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.audioObserver.queuePlayer?.play()
                self.audioObserver.isPlaying = true
            }
        } else {
            // Just load, don't play
            audioObserver.isPlaying = false
        }
    }

    // MARK: - Playback Controls
    private func togglePlayPause() {
        guard let player = audioObserver.queuePlayer else {
            print("❌ No player available")
            return
        }

        if audioObserver.isPlaying {
            player.pause()
            audioObserver.isPlaying = false
        } else {
            if player.currentItem != nil {
                player.play()
                audioObserver.isPlaying = true
            } else if let lastFile = audioObserver.lastPlayFile {
                playMedia(name: lastFile.0, file: lastFile.1, fileExtension: lastFile.2)
            } else {
                print("❌ No current item or last file to play")
            }
        }
    }

    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Use AVAudioSession API compatible with this iOS version
            try session.setCategory(AVAudioSessionCategoryPlayback, mode: AVAudioSessionModeDefault)
            try session.setActive(true, with: .notifyOthersOnDeactivation)
            print("✅ Audio session configured successfully")
        } catch {
            print("❌ Failed to setup audio session: \(error)")
            // Gracefully handle audio session failure - disable audio features
            DispatchQueue.main.async {
                // Could show user alert here about audio being unavailable
                print("🔇 Audio features disabled due to session failure")
            }
        }
    }

    // MARK: - Formatting
    private func formatTime(_ seconds: Double) -> String {
        // Handle invalid time values that could cause crashes
        guard seconds.isFinite && seconds >= 0 else {
            print("⚠️ Invalid time value: \(seconds), returning 00:00")
            return "00:00"
        }

        // Cap at reasonable maximum to prevent display issues
        let clampedSeconds = min(seconds, 99 * 60 + 59) // Max 99:59

        let minutes = Int(clampedSeconds) / 60
        let seconds = Int(clampedSeconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - ODR Error Handling
    private func getODRErrorMessage(_ error: NSError) -> String {
        switch error.code {
        case NSBundleOnDemandResourceOutOfSpaceError:
            return "Not enough space to download audio file"
        case NSBundleOnDemandResourceExceededMaximumSizeError:
            return "Audio file is too large"
        case NSBundleOnDemandResourceInvalidTagError:
            return "Invalid audio file tag"
        default:
            return "Download failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Audio Player Observer
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
        // Private init to enforce singleton pattern
    }

    func cleanup() {
        // Remove time observer
        if let observer = timeObserver, let player = queuePlayer {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }

        // Cancel all Combine subscriptions
        cancellables.removeAll()

        // Invalidate timer
        playerTimer?.invalidate()
        playerTimer = nil

        // Clear player
        queuePlayer = nil

        // Reset observation flag
        isObservationSetup = false
    }

    func initializePlayerIfNeeded() {
        if queuePlayer == nil {
            queuePlayer = AVQueuePlayer()
            setupPlayerObservation()
        }
        // Ensure audio session is configured (idempotent)
        setupAudioSessionIfNeeded()
    }

    func reinitializePlayer() {
        cleanup()
        queuePlayer = AVQueuePlayer()
        setupPlayerObservation()
    }

    private func setupPlayerObservation() {
        // Prevent setting up observation multiple times
        guard !isObservationSetup else { return }

        // Observe when current item changes
        queuePlayer?.publisher(for: \.currentItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newItem in
                if let item = newItem {
                    self?.showPlayerBar = true
                    self?.totalTime = CMTimeGetSeconds(item.duration)
                } else {
                    self?.showPlayerBar = false
                    self?.currentTrack = nil
                }
            }
            .store(in: &cancellables)
        
        // Observe playback rate changes
        queuePlayer?.publisher(for: \.rate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newRate in
                self?.isPlaying = newRate > 0
            }
            .store(in: &cancellables)

        // Add periodic time observer for progress updates
        guard let player = queuePlayer else { return }

        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main) { [weak self] time in
            guard let self = self, let currentItem = player.currentItem else { return }

            let currentTimeSeconds = CMTimeGetSeconds(time)
            let durationSeconds = CMTimeGetSeconds(currentItem.duration)

            // Validate and set current time with proper bounds checking
            if currentTimeSeconds.isFinite && currentTimeSeconds >= 0 {
                self.currentTime = currentTimeSeconds
            } else {
                print("⚠️ Invalid currentTime: \(currentTimeSeconds), using 0")
                self.currentTime = 0
            }

            // Validate and set total time
            if (self.totalTime.isNaN || self.totalTime == 0) && durationSeconds.isFinite && durationSeconds > 0 {
                self.totalTime = durationSeconds
            }
        }

        // Mark observation as setup
        isObservationSetup = true
    }

    // MARK: - Audio Session Setup
    private func setupAudioSessionIfNeeded() {
        do {
            let session = AVAudioSession.sharedInstance()
            // Only set category if it's not already set to avoid interruptions
            if session.category != AVAudioSessionCategoryPlayback {
                try session.setCategory(AVAudioSessionCategoryPlayback, mode: AVAudioSessionModeDefault)
                try session.setActive(true, with: .notifyOthersOnDeactivation)
                print("✅ Audio session configured successfully")
            }
        } catch {
            print("⚠️ Audio session setup failed: \(error)")
        }
    }
}

// MARK: - Image Extension
extension Image {
    func withRenderingMode(_ mode: Image.TemplateRenderingMode) -> some View {
        self.renderingMode(mode)
    }
}