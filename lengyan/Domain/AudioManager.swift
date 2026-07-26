//
//  AudioManager.swift
//  lengyan
//
//  UI/playback orchestration for the dual delivery stack. OS and backend
//  decisions live in AudioAssetProviderFactory; this type only handles user
//  selection, AVPlayer state, and the current -> next policy.
//

import AVFoundation
import Network
import UIKit

enum AudioPlaybackStartDecision: Equatable {
    case beginning
    case resume(at: Double)
}

enum AudioPlaybackResumePolicy {
    static func startDecision(
        savedAssetID: String?,
        requestedAssetID: String,
        savedTime: Double
    ) -> AudioPlaybackStartDecision {
        guard savedAssetID == requestedAssetID,
              savedTime.isFinite,
              savedTime > 0 else {
            return .beginning
        }
        return .resume(at: savedTime)
    }
}

private final class AudioAutomaticDownloadNetworkMonitor: @unchecked Sendable {
    static let shared = AudioAutomaticDownloadNetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(
        label: "org.fuxuan.lengyan.audio-prefetch-network"
    )
    private let lock = NSLock()
    private var latestPath: NWPath?
    private var suitablePathHandler: (@Sendable () -> Void)?

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.lock.lock()
            self.latestPath = path
            let handler = path.status == .satisfied
                && !path.isExpensive
                && !path.isConstrained
                ? self.suitablePathHandler
                : nil
            self.lock.unlock()
            if let handler {
                DispatchQueue.main.async(execute: handler)
            }
        }
        monitor.start(queue: queue)
    }

    func setSuitablePathHandler(_ handler: @escaping @Sendable () -> Void) {
        lock.lock()
        suitablePathHandler = handler
        let shouldNotify = latestPath.map {
            $0.status == .satisfied && !$0.isExpensive && !$0.isConstrained
        } ?? false
        lock.unlock()
        if shouldNotify {
            DispatchQueue.main.async(execute: handler)
        }
    }

    var allowsPrefetch: Bool {
        lock.lock()
        let path = latestPath
        lock.unlock()
        guard let path else { return false }
        return path.status == .satisfied
            && !path.isExpensive
            && !path.isConstrained
    }
}

final class AudioManager: ObservableObject {
    static let shared = AudioManager()

    let audioObserver = AudioPlayerObserver.shared

    @Published var mediaGroups: [MediaGroup] = []
    @Published var isLoading = true
    @Published var selectedPlayMode: PlayMode = .repeatAll
    @Published var downloadProgress: [String: Double] = [:]
    @Published var downloadStatus: [String: MediaItem.MediaStatus] = [:]
    @Published var downloadErrorMessage: String?
    @Published private(set) var pendingTrackName: String?
    @Published private(set) var pendingUsesFallback = false

    private let assetCoordinator: AudioAssetCoordinator
    private var playCount = 0
    private var selectionGeneration = UUID()
    private var playbackGeneration: UUID?
    private var prefetchTriggeredGeneration: UUID?
    private var requestedAssetID: String?
    private(set) var pendingAssetID: String?
    private var playingAssetID: String?
    private var resumableAssetID: String?
    private var lifecycleObservers: [NSObjectProtocol] = []

    var pendingTrackProgress: Double {
        guard let pendingAssetID else { return 0 }
        return min(max(downloadProgress[pendingAssetID] ?? 0, 0), 1)
    }

    var isPreparingRequestedTrack: Bool {
        pendingTrackName != nil && pendingAssetID != nil
    }

    private init() {
        let provider = AudioAssetProviderFactory.makeProvider()
        assetCoordinator = AudioAssetCoordinator(provider: provider)

        if let raw = Prefers.shared.lastPlayMode,
           let mode = PlayMode(rawValue: raw) {
            selectedPlayMode = mode
        }

        audioObserver.onFirstPlaybackStarted = { [weak self] in
            self?.startNextPrefetchIfNeeded()
        }
        audioObserver.onPlayerItemRemoved = { [weak self] in
            self?.playerItemWasRemoved()
        }
        AudioAutomaticDownloadNetworkMonitor.shared.setSuitablePathHandler {
            [weak self] in
            self?.startNextPrefetchIfNeeded()
        }
        installLifecycleObservers()

        if let catalogError = AudioAssetCatalog.validationError {
            assertionFailure(catalogError)
        }
        if Book.shared.loaded {
            loadMediaData()
        }

    }

    deinit {
        for observer in lifecycleObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Data Loading

    func loadMediaData() {
        guard mediaGroups.isEmpty else { return }
        guard let mediaData = Book.shared.media else {
            isLoading = false
            return
        }

        mediaGroups = mediaData.compactMap { mediaDict in
            guard let name = mediaDict["name"] as? String,
                  let files = mediaDict["files"] as? [String],
                  let names = mediaDict["names"] as? [String],
                  let ext = mediaDict["extension"] as? String else {
                return nil
            }
            return MediaGroup(
                name: name,
                files: files,
                names: names,
                fileExtension: ext
            )
        }

        isLoading = false

        for group in mediaGroups {
            for file in group.files {
                if CDNAudioCache.isCached(assetID: file) {
                    downloadStatus[file] = .downloaded
                }
            }
        }

        resumeLastPlayback()
    }

    func resumeLastPlayback() {
        guard let file = Prefers.shared.lastPlayFile?.first,
              AudioAssetCatalog.descriptor(for: file) != nil,
              mediaGroups.contains(where: { $0.files.contains(file) }),
              let trackInfo = track(for: file) else {
            resumableAssetID = nil
            return
        }
        // Keep the resume candidate separate from playing state, while populating
        // last known track info and progress for immediate UI reflection.
        resumableAssetID = file
        audioObserver.currentTrack = trackInfo.name
        audioObserver.lastPlayFile = (trackInfo.name, file, trackInfo.fileExtension)
        if Prefers.shared.lastPlayTime > 0 {
            audioObserver.currentTime = Prefers.shared.lastPlayTime
        }
        if Prefers.shared.lastTotalTime > 0 {
            audioObserver.totalTime = Prefers.shared.lastTotalTime
        }
    }

    // MARK: - Selection and Delivery

    func handleMediaItemTap(name: String, file: String, fileExtension: String) {
        if pendingAssetID == file,
           downloadStatus[file] == .downloading {
            return
        }
        if playingAssetID == file,
           audioObserver.queuePlayer?.currentItem != nil {
            let supersededPendingID = pendingAssetID
            if let playbackGeneration {
                selectionGeneration = playbackGeneration
            }
            requestedAssetID = file
            pendingAssetID = nil
            pendingTrackName = nil
            pendingUsesFallback = false
            prefetchTriggeredGeneration = nil
            let cancelledPendingSelection = supersededPendingID != nil
                && supersededPendingID != file
            if let supersededPendingID, cancelledPendingSelection {
                downloadStatus[supersededPendingID] = .notDownloaded
                downloadProgress.removeValue(forKey: supersededPendingID)
                cancelPendingSelectionAndResumePrefetchIfNeeded()
            }
            audioObserver.seek(to: 0)
            if !audioObserver.isPlaying {
                audioObserver.queuePlayer?.play()
            }
            if !cancelledPendingSelection {
                startNextPrefetchIfNeeded()
            }
            return
        }
        requestPlayback(
            name: name,
            file: file,
            fileExtension: fileExtension,
            autoplay: true
        )
    }

    func downloadMedia(name: String, file: String, fileExtension: String) {
        requestPlayback(
            name: name,
            file: file,
            fileExtension: fileExtension,
            autoplay: true
        )
    }

    func playMedia(
        name: String,
        file: String,
        fileExtension: String,
        autoplay: Bool = true
    ) {
        requestPlayback(
            name: name,
            file: file,
            fileExtension: fileExtension,
            autoplay: autoplay
        )
    }

    private func requestPlayback(
        name: String,
        file: String,
        fileExtension: String,
        autoplay: Bool
    ) {
        guard let descriptor = AudioAssetCatalog.descriptor(for: file),
              descriptor.fileExtension == fileExtension else {
            downloadStatus[file] = .error
            downloadErrorMessage = L10n.str("audio_error_invalid")
            return
        }

        let generation = UUID()
        selectionGeneration = generation
        requestedAssetID = file
        pendingAssetID = file
        pendingTrackName = name
        pendingUsesFallback = false
        resumableAssetID = file
        downloadErrorMessage = nil

        if downloadStatus[file] != .downloaded {
            downloadStatus[file] = .downloading
            if downloadProgress[file] == nil {
                downloadProgress[file] = 0
            }
        }
        // Explicit user intent always receives immediate acknowledgement. The
        // current title remains unchanged while another volume is prepared.
        audioObserver.showPlayerBar = true

        let shouldContinuePlaying = audioObserver.isPlaying
        Task { [weak self] in
            guard let self else { return }
            let handle = await self.assetCoordinator.requestPlayback(
                descriptor,
                generation: generation
            )
            do {
                for try await event in handle.events {
                    await MainActor.run {
                        self.receive(
                            event,
                            generation: generation,
                            name: name,
                            descriptor: descriptor,
                            autoplay: autoplay || shouldContinuePlaying
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    self.receiveDeliveryFailure(
                        error,
                        generation: generation,
                        assetID: file
                    )
                }
            }
        }
    }

    private func receive(
        _ event: AudioAssetEvent,
        generation: UUID,
        name: String,
        descriptor: AudioAssetDescriptor,
        autoplay: Bool
    ) {
        switch event {
        case .queued:
            guard selectionGeneration == generation else { return }
            if downloadStatus[descriptor.id] != .downloaded {
                downloadStatus[descriptor.id] = .downloading
            }
        case .fallbackActivated:
            guard selectionGeneration == generation else { return }
            pendingUsesFallback = true
        case .progress(let fraction):
            guard selectionGeneration == generation else { return }
            if downloadStatus[descriptor.id] != .downloaded {
                downloadStatus[descriptor.id] = .downloading
            }
            downloadProgress[descriptor.id] = min(max(fraction, 0), 1)
        case .ready(let lease):
            guard selectionGeneration == generation,
                  requestedAssetID == descriptor.id else {
                Task { await assetCoordinator.discard(lease) }
                return
            }
            installPlayback(
                lease: lease,
                generation: generation,
                name: name,
                descriptor: descriptor,
                autoplay: autoplay
            )
        }
    }

    private func installPlayback(
        lease: AudioAssetLease,
        generation: UUID,
        name: String,
        descriptor: AudioAssetDescriptor,
        autoplay: Bool
    ) {
        guard FileManager.default.isReadableFile(atPath: lease.localURL.path) else {
            Task { await assetCoordinator.discard(lease) }
            receiveDeliveryFailure(
                AudioAssetError.missingLocalFile(lease.localURL.path),
                generation: generation,
                assetID: descriptor.id
            )
            return
        }

        let startDecision = AudioPlaybackResumePolicy.startDecision(
            savedAssetID: Prefers.shared.lastPlayFile?.first,
            requestedAssetID: descriptor.id,
            savedTime: Prefers.shared.lastPlayTime
        )
        if startDecision == .beginning {
            playCount = 0
            Prefers.shared.lastPlayTime = 0
            Prefers.shared.lastTotalTime = 0
        }

        do {
            try audioObserver.replaceItem(with: lease.localURL)
        } catch {
            Task { await assetCoordinator.discard(lease) }
            receiveDeliveryFailure(error, generation: generation, assetID: descriptor.id)
            return
        }

        // AVPlayer now owns the new URL. Only at this point may the coordinator
        // release the previous current lease.
        Task { await assetCoordinator.commitPlayback(lease) }

        playingAssetID = descriptor.id
        pendingAssetID = nil
        pendingTrackName = nil
        pendingUsesFallback = false
        playbackGeneration = generation
        prefetchTriggeredGeneration = nil
        audioObserver.currentTrack = name
        audioObserver.showPlayerBar = true
        audioObserver.lastPlayFile = (name, descriptor.id, descriptor.fileExtension)
        Prefers.shared.lastPlayFile = [descriptor.id]
        downloadStatus[descriptor.id] = .downloaded
        downloadProgress.removeValue(forKey: descriptor.id)

        switch startDecision {
        case .beginning:
            audioObserver.clearSeekProtection()
        case .resume(let savedTime):
            audioObserver.seek(to: savedTime)
        }

        if autoplay {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self,
                      self.selectionGeneration == generation,
                      self.playingAssetID == descriptor.id else { return }
                self.audioObserver.queuePlayer?.play()
            }
        }
    }

    private func receiveDeliveryFailure(
        _ error: Error,
        generation: UUID,
        assetID: String
    ) {
        guard selectionGeneration == generation else { return }
        pendingAssetID = nil
        pendingTrackName = nil
        pendingUsesFallback = false
        downloadStatus[assetID] = .error
        downloadProgress.removeValue(forKey: assetID)
        if !isCancellation(error) {
            downloadErrorMessage = deliveryErrorMessage(error)
        }
    }

    func downloadState(forTrackName name: String?) -> (
        isDownloading: Bool,
        progress: Double
    ) {
        guard let name, !name.isEmpty else { return (false, 0) }
        for group in mediaGroups {
            if let index = group.names.firstIndex(of: name), index < group.files.count {
                let file = group.files[index]
                return (
                    downloadStatus[file] == .downloading,
                    downloadProgress[file] ?? 0
                )
            }
        }
        return (false, 0)
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        guard let player = audioObserver.queuePlayer,
              player.currentItem != nil else {
            startCurrentTrack()
            return
        }
        if audioObserver.isPlaying {
            player.pause()
        } else {
            player.play()
        }
    }

    func startPlayback() {
        if let player = audioObserver.queuePlayer, player.currentItem != nil {
            if !audioObserver.isPlaying { player.play() }
        } else {
            startCurrentTrack()
        }
    }

    func playChapter(chapter: Int) {
        if mediaGroups.isEmpty { loadMediaData() }
        guard chapter >= 0 && chapter < 10,
              let group = mediaGroups.first,
              chapter < group.files.count,
              chapter < group.names.count else { return }
        handleMediaItemTap(
            name: group.names[chapter],
            file: group.files[chapter],
            fileExtension: group.fileExtension
        )
    }

    private func startCurrentTrack() {
        let candidate = playingAssetID
            ?? resumableAssetID
            ?? audioObserver.lastPlayFile?.1
            ?? mediaGroups.first?.files.first
        guard let candidate,
              let track = track(for: candidate) else { return }
        handleMediaItemTap(
            name: track.name,
            file: candidate,
            fileExtension: track.fileExtension
        )
    }

    // MARK: - Play Mode and Completion

    func selectMode(_ mode: PlayMode) {
        selectedPlayMode = mode
        playCount = 0
        Prefers.shared.lastPlayMode = mode.rawValue
        if mode == .repeatAll {
            if audioObserver.isPlaying { startNextPrefetchIfNeeded() }
        } else {
            prefetchTriggeredGeneration = nil
            Task { await assetCoordinator.cancelPrefetch() }
        }
    }

    func handlePlaybackCompletion() {
        playCount += 1
        Prefers.shared.lastPlayTime = 0
        switch selectedPlayMode {
        case .repeatAll:
            playNextTrack()
        case .repeatOne:
            replayCurrentTrack()
        default:
            if playCount < selectedPlayMode.rawValue {
                replayCurrentTrack()
            } else {
                finishPlaybackWithoutNextTrack()
            }
        }
    }

    private func finishPlaybackWithoutNextTrack() {
        let hadPlayerItem = audioObserver.queuePlayer?.currentItem != nil
        audioObserver.stopAndRemoveItem()
        // AVQueuePlayer normally removed the completed item before the
        // notification arrives, so stopAndRemoveItem may have nothing left to
        // report. Explicitly release in that case.
        if !hadPlayerItem {
            playerItemWasRemoved()
        }
    }

    private func replayCurrentTrack() {
        guard let file = playingAssetID ?? audioObserver.lastPlayFile?.1,
              let track = track(for: file) else { return }
        playMedia(
            name: track.name,
            file: file,
            fileExtension: track.fileExtension
        )
    }

    func playNextTrack() {
        let current = playingAssetID
            ?? audioObserver.lastPlayFile?.1
            ?? resumableAssetID
        guard let current,
              let next = AudioAssetCatalog.next(after: current),
              let track = track(for: next.id) else {
            playFirstTrackIfAvailable()
            return
        }
        handleMediaItemTap(
            name: track.name,
            file: next.id,
            fileExtension: track.fileExtension
        )
    }

    func playPreviousTrack() {
        let current = playingAssetID
            ?? audioObserver.lastPlayFile?.1
            ?? resumableAssetID
        guard let current,
              let index = AudioAssetCatalog.orderedIDs.firstIndex(of: current) else {
            playFirstTrackIfAvailable()
            return
        }
        let previousID = AudioAssetCatalog.orderedIDs[
            (index - 1 + AudioAssetCatalog.orderedIDs.count)
                % AudioAssetCatalog.orderedIDs.count
        ]
        guard let track = track(for: previousID) else { return }
        handleMediaItemTap(
            name: track.name,
            file: previousID,
            fileExtension: track.fileExtension
        )
    }

    private func playFirstTrackIfAvailable() {
        guard let first = AudioAssetCatalog.orderedIDs.first,
              let track = track(for: first) else { return }
        handleMediaItemTap(
            name: track.name,
            file: first,
            fileExtension: track.fileExtension
        )
    }

    // MARK: - Current -> Next Prefetch

    private func startNextPrefetchIfNeeded() {
        guard selectedPlayMode == .repeatAll,
              !ProcessInfo.processInfo.isLowPowerModeEnabled,
              AudioAutomaticDownloadNetworkMonitor.shared.allowsPrefetch,
              let generation = playbackGeneration,
              generation == selectionGeneration,
              prefetchTriggeredGeneration != generation,
              let current = playingAssetID,
              let next = AudioAssetCatalog.next(after: current),
              next.id != current else { return }

        prefetchTriggeredGeneration = generation
        Task { [weak self] in
            guard let self else { return }
            await self.assetCoordinator.startPrefetch(
                next,
                ownerID: generation.uuidString
            )
        }
    }

    private func playerItemWasRemoved() {
        selectionGeneration = UUID()
        playbackGeneration = nil
        prefetchTriggeredGeneration = nil
        requestedAssetID = nil
        pendingAssetID = nil
        pendingTrackName = nil
        pendingUsesFallback = false
        playingAssetID = nil
        audioObserver.currentTrack = nil
        audioObserver.showPlayerBar = false
        Task { await assetCoordinator.stopAndReleaseAll() }
    }

    private func cancelPendingSelectionAndResumePrefetchIfNeeded() {
        let generation = playbackGeneration
        Task { [weak self] in
            guard let self else { return }
            await self.assetCoordinator.cancelPending()
            await MainActor.run {
                guard let generation,
                      self.playbackGeneration == generation,
                      self.selectionGeneration == generation,
                      self.audioObserver.queuePlayer?.currentItem != nil else { return }
                self.prefetchTriggeredGeneration = nil
                self.startNextPrefetchIfNeeded()
            }
        }
    }

    func stopAndReleaseAudio() {
        let hadPlayerItem = audioObserver.queuePlayer?.currentItem != nil
        audioObserver.stopAndRemoveItem()
        if !hadPlayerItem {
            playerItemWasRemoved()
        }
    }

    func audioAssetSnapshot() async -> AudioAssetCoordinatorSnapshot {
        await assetCoordinator.snapshot()
    }

    // MARK: - Lifecycle

    private func installLifecycleObservers() {
        let memory = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.prefetchTriggeredGeneration = nil
            Task { await self?.assetCoordinator.cancelPrefetch() }
        }
        let terminate = NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.audioObserver.saveCurrentProgressImmediately()
            Task {
                await self?.assetCoordinator.cleanExpiredStorage()
                await self?.assetCoordinator.shutdown()
            }
        }
        let background = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.audioObserver.saveCurrentProgressImmediately()
            Task {
                await self?.assetCoordinator.cleanExpiredStorage()
            }
        }
        let lowDisk = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSBundleResourceRequestLowDiskSpace,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.prefetchTriggeredGeneration = nil
            Task {
                await self?.assetCoordinator.reclaimUnusedManagedPacks()
            }
        }
        let power = NotificationCenter.default.addObserver(
            forName: Notification.Name.NSProcessInfoPowerStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard !ProcessInfo.processInfo.isLowPowerModeEnabled else { return }
            self?.startNextPrefetchIfNeeded()
        }
        lifecycleObservers = [memory, terminate, background, lowDisk, power]
    }

    // MARK: - Helpers

    private func track(for file: String) -> (name: String, fileExtension: String)? {
        for group in mediaGroups {
            if let index = group.files.firstIndex(of: file), index < group.names.count {
                return (group.names[index], group.fileExtension)
            }
        }
        return nil
    }

    func setupAudioSession() {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                print("Audio session setup failed: \(error)")
            }
        }
    }

    static func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "00:00" }
        let clampedSeconds = min(seconds, 99 * 60 + 59)
        return String(
            format: "%02d:%02d",
            Int(clampedSeconds) / 60,
            Int(clampedSeconds) % 60
        )
    }

    private func deliveryErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        switch nsError.code {
        case NSBundleOnDemandResourceOutOfSpaceError:
            return L10n.str("audio_error_out_of_space")
        case NSBundleOnDemandResourceExceededMaximumSizeError:
            return L10n.str("audio_error_too_big")
        case NSBundleOnDemandResourceInvalidTagError:
            return L10n.str("audio_error_invalid")
        default:
            return L10n.str("audio_error_download_failed")
        }
    }

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let assetError = error as? AudioAssetError,
           case .cancelled = assetError {
            return true
        }
        return false
    }
}
