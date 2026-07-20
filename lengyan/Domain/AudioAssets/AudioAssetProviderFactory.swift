//
//  AudioAssetProviderFactory.swift
//  lengyan
//
//  This is the only production version/router boundary. Callers never branch
//  on OS version or import BackgroundAssets.
//

import Foundation

struct AudioAssetProviderPolicy: Sendable {
    let managedEnabled: Bool
    let managedCatalogReady: Bool

    static var production: AudioAssetProviderPolicy {
        let enabled = Bundle.main.object(
            forInfoDictionaryKey: "LengyanManagedAudioEnabled"
        ) as? Bool == true
        return AudioAssetProviderPolicy(
            managedEnabled: enabled,
            managedCatalogReady: AudioAssetCatalog.managedPacksReady
        )
    }
}

enum AudioAssetProviderFactory {
    private static let legacyODRDemotionKey =
        "audioAssets.didDemoteLegacyODRTagsForManagedV1"

    static func backendDecision(
        systemMajorVersion: Int,
        policy: AudioAssetProviderPolicy
    ) -> AudioAssetBackendKind {
        if systemMajorVersion >= 26,
           policy.managedEnabled,
           policy.managedCatalogReady {
            return .managedBackgroundAssets
        }
        return .legacyODR
    }

    static func makeProvider(
        policy: AudioAssetProviderPolicy = .production
    ) -> any AudioAssetProvider {
        let systemMajorVersion = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        let backend = backendDecision(
            systemMajorVersion: systemMajorVersion,
            policy: policy
        )

        let applePrimary: any AudioAssetProvider
        if #available(iOS 26.0, *), backend == .managedBackgroundAssets {
            demoteLegacyODRTagsIfNeeded()
            applePrimary = ManagedBackgroundAssetsAudioAssetProvider()
        } else {
            applePrimary = LegacyODRAudioAssetProvider()
        }

        var primary = applePrimary
#if AUDIO_FALLBACK_UI_TESTS
        if let faultMode = AudioAssetUITestSupport.primaryFaultMode {
            primary = AudioAssetUITestFaultProvider(
                backendKind: applePrimary.backendKind,
                mode: faultMode
            )
        }
#endif

        guard let fallbackConfiguration = CDNAudioFallbackConfiguration.production else {
            return primary
        }
#if AUDIO_FALLBACK_UI_TESTS
        AudioAssetUITestSupport.resetFallbackCacheIfRequested(
            configuration: fallbackConfiguration
        )
        let stallTimeout = AudioAssetUITestSupport.stallTimeoutOverride
            ?? fallbackConfiguration.stallTimeout
        let fallbackPresentationDelay =
            AudioAssetUITestSupport.fallbackPresentationDelayOverride ?? 0
#else
        let stallTimeout = fallbackConfiguration.stallTimeout
        let fallbackPresentationDelay: TimeInterval = 0
#endif
        let fallback = CDNAudioAssetProvider(configuration: fallbackConfiguration)
        return FailoverAudioAssetProvider(
            primary: primary,
            fallback: fallback,
            stallTimeout: stallTimeout,
            fallbackPresentationDelay: fallbackPresentationDelay
        )
    }

    static func shouldDemoteLegacyODRTags(
        systemMajorVersion: Int,
        backend: AudioAssetBackendKind,
        alreadyCompleted: Bool
    ) -> Bool {
        systemMajorVersion >= 26
            && backend == .managedBackgroundAssets
            && !alreadyCompleted
    }

    private static func demoteLegacyODRTagsIfNeeded(
        bundle: Bundle = .main,
        defaults: UserDefaults = .standard
    ) {
        guard shouldDemoteLegacyODRTags(
            systemMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
            backend: .managedBackgroundAssets,
            alreadyCompleted: defaults.bool(forKey: legacyODRDemotionKey)
        ) else { return }

        // ODR has no force-delete API. Priority zero makes every legacy audio
        // tag an early purge candidate once no NSBundleResourceRequest retains
        // it. Managed packs remain independently owned by AssetPackManager.
        bundle.setPreservationPriority(
            0,
            forTags: Set(AudioAssetCatalog.descriptors.map(\.odrTag))
        )
        defaults.set(true, forKey: legacyODRDemotionKey)
    }
}

#if AUDIO_FALLBACK_UI_TESTS
private enum AudioAssetUITestFaultMode: String, Sendable {
    case immediate
    case stall
    case outOfSpace = "out-of-space"
}

private enum AudioAssetUITestSupport {
    private static var arguments: [String] {
        ProcessInfo.processInfo.arguments
    }

    private static var isEnabled: Bool {
        arguments.contains("--uitesting")
    }

    static var primaryFaultMode: AudioAssetUITestFaultMode? {
        guard isEnabled,
              let rawValue = value(after: "--audio-primary-fault") else {
            return nil
        }
        return AudioAssetUITestFaultMode(rawValue: rawValue)
    }

    static var stallTimeoutOverride: TimeInterval? {
        guard isEnabled,
              let rawValue = value(after: "--audio-fallback-stall-timeout"),
              let value = TimeInterval(rawValue),
              value.isFinite else { return nil }
        return min(max(value, 0.5), 60)
    }

    static var fallbackPresentationDelayOverride: TimeInterval? {
        guard isEnabled,
              let rawValue = value(after: "--audio-fallback-presentation-delay"),
              let value = TimeInterval(rawValue),
              value.isFinite else { return nil }
        return min(max(value, 0), 5)
    }

    static func resetFallbackCacheIfRequested(
        configuration: CDNAudioFallbackConfiguration,
        fileManager: FileManager = .default
    ) {
        guard isEnabled,
              arguments.contains("--reset-audio-fallback-cache"),
              fileManager.fileExists(atPath: configuration.cacheDirectory.path) else {
            return
        }
        do {
            try fileManager.removeItem(at: configuration.cacheDirectory)
        } catch {
            assertionFailure("Unable to reset audio fallback UI-test cache: \(error)")
        }
    }

    private static func value(after flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }
}

private actor AudioAssetUITestFaultProvider: AudioAssetProvider {
    private struct Entry {
        let continuation: AsyncThrowingStream<AudioAssetEvent, Error>.Continuation
    }

    nonisolated let backendKind: AudioAssetBackendKind

    private let mode: AudioAssetUITestFaultMode
    private var entries: [UUID: Entry] = [:]
    private var isShutdown = false

    init(backendKind: AudioAssetBackendKind, mode: AudioAssetUITestFaultMode) {
        self.backendKind = backendKind
        self.mode = mode
    }

    func request(
        _ asset: AudioAssetDescriptor,
        intent: AudioAssetIntent
    ) async -> AudioAssetRequestHandle {
        let requestID = UUID()
        let output = AsyncThrowingStream<AudioAssetEvent, Error>.audioAssetStream()
        output.continuation.onTermination = { [weak self] _ in
            Task { await self?.cancel(requestID: requestID) }
        }

        guard !isShutdown else {
            output.continuation.finish(throwing: AudioAssetError.cancelled)
            return AudioAssetRequestHandle(
                requestID: requestID,
                assetID: asset.id,
                events: output.stream
            )
        }

        entries[requestID] = Entry(continuation: output.continuation)
        output.continuation.yield(.queued)
        if mode != .stall {
            Task { [weak self] in
                await self?.finishInjectedFailure(requestID: requestID)
            }
        }
        return AudioAssetRequestHandle(
            requestID: requestID,
            assetID: asset.id,
            events: output.stream
        )
    }

    func promote(requestID: UUID) async {}

    func cancel(requestID: UUID) async {
        guard let entry = entries.removeValue(forKey: requestID) else { return }
        entry.continuation.finish(throwing: AudioAssetError.cancelled)
    }

    func release(_ lease: AudioAssetLease) async {}

    func evict(assetID: String) async throws -> AudioAssetEvictionResult {
        .releasedToSystem
    }

    func shutdown() async {
        guard !isShutdown else { return }
        isShutdown = true
        let activeEntries = Array(entries.values)
        entries.removeAll()
        for entry in activeEntries {
            entry.continuation.finish(throwing: AudioAssetError.cancelled)
        }
    }

    private func finishInjectedFailure(requestID: UUID) {
        guard let entry = entries.removeValue(forKey: requestID) else { return }
        let error: Error
        switch mode {
        case .immediate:
            error = NSError(
                domain: NSURLErrorDomain,
                code: NSURLErrorCannotConnectToHost
            )
        case .outOfSpace:
            error = NSError(
                domain: NSCocoaErrorDomain,
                code: NSBundleOnDemandResourceOutOfSpaceError
            )
        case .stall:
            return
        }
        entry.continuation.finish(throwing: error)
    }
}
#endif
