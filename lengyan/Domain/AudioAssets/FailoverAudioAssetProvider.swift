//
//  FailoverAudioAssetProvider.swift
//  lengyan
//
//  Keeps Apple delivery as the primary source. A foreground playback request
//  moves to the CDN only after a real primary error or a no-progress watchdog;
//  silent prefetch never consumes fallback traffic.
//

import Foundation

actor FailoverAudioAssetProvider: AudioAssetProvider {
    private enum Source {
        case primary
        case fallback
    }

    private struct Entry {
        let asset: AudioAssetDescriptor
        let generation: UUID
        var intent: AudioAssetIntent
        let continuation: AsyncThrowingStream<AudioAssetEvent, Error>.Continuation
        var source: Source
        var underlyingRequestID: UUID?
        var task: Task<Void, Never>?
        var watchdog: Task<Void, Never>?
        var lastPrimaryProgress: Double
        var fallbackRequested: Bool
    }

    nonisolated let backendKind: AudioAssetBackendKind

    private let primary: any AudioAssetProvider
    private let fallback: CDNAudioAssetProvider
    private let stallTimeout: TimeInterval
    private var entries: [UUID: Entry] = [:]
    private var leaseOwners: [UUID: Source] = [:]
    private var isShutdown = false

    init(
        primary: any AudioAssetProvider,
        fallback: CDNAudioAssetProvider,
        stallTimeout: TimeInterval
    ) {
        self.primary = primary
        self.fallback = fallback
        self.stallTimeout = stallTimeout
        backendKind = primary.backendKind
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

        var entry = Entry(
            asset: asset,
            generation: UUID(),
            intent: intent,
            continuation: output.continuation,
            source: .primary,
            underlyingRequestID: nil,
            task: nil,
            watchdog: nil,
            lastPrimaryProgress: 0,
            fallbackRequested: false
        )
        output.continuation.yield(.queued)
        entry.task = Task { [weak self] in
            await self?.run(requestID: requestID)
        }
        entries[requestID] = entry

        return AudioAssetRequestHandle(
            requestID: requestID,
            assetID: asset.id,
            events: output.stream
        )
    }

    func promote(requestID: UUID) async {
        guard var entry = entries[requestID] else { return }
        entry.intent = .playback
        let source = entry.source
        let underlyingRequestID = entry.underlyingRequestID
        entries[requestID] = entry

        if let underlyingRequestID {
            switch source {
            case .primary:
                await primary.promote(requestID: underlyingRequestID)
                scheduleWatchdog(requestID: requestID)
            case .fallback:
                await fallback.promote(requestID: underlyingRequestID)
            }
        }
    }

    func cancel(requestID: UUID) async {
        guard let entry = entries.removeValue(forKey: requestID) else { return }
        entry.watchdog?.cancel()
        entry.task?.cancel()
        entry.continuation.finish(throwing: AudioAssetError.cancelled)
        guard let underlyingRequestID = entry.underlyingRequestID else { return }
        switch entry.source {
        case .primary:
            await primary.cancel(requestID: underlyingRequestID)
        case .fallback:
            await fallback.cancel(requestID: underlyingRequestID)
        }
    }

    func release(_ lease: AudioAssetLease) async {
        guard let owner = leaseOwners.removeValue(forKey: lease.id) else { return }
        switch owner {
        case .primary:
            await primary.release(lease)
        case .fallback:
            await fallback.release(lease)
        }
    }

    func evict(assetID: String) async throws -> AudioAssetEvictionResult {
        var primaryResult: AudioAssetEvictionResult?
        var fallbackResult: AudioAssetEvictionResult?
        var firstError: Error?

        do {
            primaryResult = try await primary.evict(assetID: assetID)
        } catch {
            firstError = error
        }
        do {
            fallbackResult = try await fallback.evict(assetID: assetID)
        } catch {
            if firstError == nil { firstError = error }
        }
        if let firstError { throw firstError }
        if case .removed? = fallbackResult { return .removed }
        return primaryResult ?? .releasedToSystem
    }

    func shutdown() async {
        guard !isShutdown else { return }
        isShutdown = true
        for requestID in Array(entries.keys) {
            await cancel(requestID: requestID)
        }
        leaseOwners.removeAll()
        await primary.shutdown()
        await fallback.shutdown()
    }

    private func run(requestID: UUID) async {
        guard let initialEntry = entries[requestID] else { return }
        if let cachedLease = await fallback.cachedLeaseIfAvailable(initialEntry.asset) {
            guard entries[requestID] != nil else {
                await fallback.release(cachedLease)
                return
            }
            deliverReady(requestID: requestID, lease: cachedLease, source: .fallback)
            return
        }

        do {
            try await consume(requestID: requestID, source: .primary)
            return
        } catch {
            guard shouldActivateFallback(error: error, requestID: requestID) else {
                finishFailure(requestID: requestID, error: error)
                return
            }
        }

        guard activateFallback(requestID: requestID) else { return }
        do {
            try await consume(requestID: requestID, source: .fallback)
        } catch {
            finishFailure(requestID: requestID, error: error)
        }
    }

    private func consume(requestID: UUID, source: Source) async throws {
        guard let entry = entries[requestID] else { throw AudioAssetError.cancelled }
        let handle: AudioAssetRequestHandle
        switch source {
        case .primary:
            handle = await primary.request(entry.asset, intent: entry.intent)
        case .fallback:
            handle = await fallback.request(entry.asset, intent: entry.intent)
        }

        guard var refreshed = entries[requestID], refreshed.source == source else {
            switch source {
            case .primary:
                await primary.cancel(requestID: handle.requestID)
            case .fallback:
                await fallback.cancel(requestID: handle.requestID)
            }
            throw AudioAssetError.cancelled
        }
        refreshed.underlyingRequestID = handle.requestID
        entries[requestID] = refreshed
        if source == .primary, isPlayback(refreshed.intent) {
            scheduleWatchdog(requestID: requestID)
        }

        for try await event in handle.events {
            guard !Task.isCancelled else { throw AudioAssetError.cancelled }
            if receive(event, requestID: requestID, source: source) {
                return
            }
        }
        if entries[requestID] != nil {
            throw AudioAssetError.missingLocalFile(refreshed.asset.fileName)
        }
    }

    private func receive(
        _ event: AudioAssetEvent,
        requestID: UUID,
        source: Source
    ) -> Bool {
        guard var entry = entries[requestID], entry.source == source else { return true }
        switch event {
        case .queued:
            return false
        case .fallbackActivated:
            entry.continuation.yield(.fallbackActivated)
            return false
        case .progress(let fraction):
            let clamped = min(max(fraction, 0), 1)
            if source == .primary,
               clamped > entry.lastPrimaryProgress + 0.001 {
                entry.lastPrimaryProgress = clamped
                entries[requestID] = entry
                if isPlayback(entry.intent) {
                    scheduleWatchdog(requestID: requestID)
                }
            }
            entry.continuation.yield(.progress(clamped))
            return false
        case .ready(let lease):
            deliverReady(requestID: requestID, lease: lease, source: source)
            return true
        }
    }

    private func deliverReady(
        requestID: UUID,
        lease: AudioAssetLease,
        source: Source
    ) {
        guard let entry = entries.removeValue(forKey: requestID) else {
            Task {
                switch source {
                case .primary:
                    await primary.release(lease)
                case .fallback:
                    await fallback.release(lease)
                }
            }
            return
        }
        entry.watchdog?.cancel()
        leaseOwners[lease.id] = source
        entry.continuation.yield(.progress(1))
        entry.continuation.yield(.ready(lease))
        entry.continuation.finish()
    }

    private func activateFallback(requestID: UUID) -> Bool {
        guard var entry = entries[requestID], isPlayback(entry.intent) else { return false }
        entry.watchdog?.cancel()
        entry.watchdog = nil
        entry.source = .fallback
        entry.underlyingRequestID = nil
        entry.lastPrimaryProgress = 0
        entry.fallbackRequested = false
        entries[requestID] = entry
        entry.continuation.yield(.fallbackActivated)
        entry.continuation.yield(.progress(0))
        return true
    }

    private func finishFailure(requestID: UUID, error: Error) {
        guard let entry = entries.removeValue(forKey: requestID) else { return }
        entry.watchdog?.cancel()
        entry.continuation.finish(throwing: error)
    }

    private func shouldActivateFallback(error: Error, requestID: UUID) -> Bool {
        guard let entry = entries[requestID], isPlayback(entry.intent) else { return false }
        if entry.fallbackRequested { return true }
        if error is CancellationError { return false }
        if case AudioAssetError.cancelled = error { return false }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain,
           nsError.code == NSURLErrorCancelled {
            return false
        }
        if isLocalOutOfSpace(error) { return false }
        return true
    }

    private func isLocalOutOfSpace(_ error: Error, depth: Int = 0) -> Bool {
        guard depth < 4 else { return false }
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain,
           (nsError.code == NSFileWriteOutOfSpaceError
            || nsError.code == NSBundleOnDemandResourceOutOfSpaceError) {
            return true
        }
        if nsError.domain == NSPOSIXErrorDomain,
           nsError.code == Int(POSIXErrorCode.ENOSPC.rawValue) {
            return true
        }
        guard let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error else {
            return false
        }
        return isLocalOutOfSpace(underlying, depth: depth + 1)
    }

    private func scheduleWatchdog(requestID: UUID) {
        guard var entry = entries[requestID],
              entry.source == .primary,
              isPlayback(entry.intent) else { return }
        entry.watchdog?.cancel()
        let generation = entry.generation
        let timeout = stallTimeout
        entry.watchdog = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
            } catch {
                return
            }
            await self?.primaryDidStall(requestID: requestID, generation: generation)
        }
        entries[requestID] = entry
    }

    private func primaryDidStall(requestID: UUID, generation: UUID) async {
        guard var entry = entries[requestID],
              entry.generation == generation,
              entry.source == .primary,
              isPlayback(entry.intent),
              let underlyingRequestID = entry.underlyingRequestID else { return }
        entry.fallbackRequested = true
        entry.watchdog = nil
        entries[requestID] = entry
        await primary.cancel(requestID: underlyingRequestID)
    }

    private func isPlayback(_ intent: AudioAssetIntent) -> Bool {
        if case .playback = intent { return true }
        return false
    }
}
