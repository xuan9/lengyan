//
//  LegacyODRAudioAssetProvider.swift
//  lengyan
//
//  iOS 15-25 provider. Every successful conditional access and every completed
//  beginAccessingResources call is paired with exactly one end call.
//

import Foundation

actor LegacyODRAudioAssetProvider: AudioAssetProvider {
    nonisolated let backendKind: AudioAssetBackendKind = .legacyODR

    private enum Phase {
        case checking
        case acquiring
        case ready(URL)
    }

    private struct Consumer {
        var intent: AudioAssetIntent
        let continuation: AsyncThrowingStream<AudioAssetEvent, Error>.Continuation
    }

    private struct Entry {
        let asset: AudioAssetDescriptor
        let generation: UUID
        let request: NSBundleResourceRequest
        var phase: Phase
        var consumers: [UUID: Consumer]
        var leaseIDs: Set<UUID>
        var progressObservation: NSKeyValueObservation?
        var beginStarted = false
        var accessCallbackReceived = false
        var accessNeedsEnd = false
        var endCalled = false
        var cancelWhenPossible = false
    }

    private var entries: [String: Entry] = [:]
    private var requestToAsset: [UUID: String] = [:]
    private var leaseToAsset: [UUID: String] = [:]
    private var lowDiskObserver: NSObjectProtocol?
    private var isShutdown = false

    init() {}

    private func ensureLowDiskObserver() {
        guard lowDiskObserver == nil else { return }
        lowDiskObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSBundleResourceRequestLowDiskSpace,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { await self?.releasePrefetchesForLowDisk() }
        }
    }

    deinit {
        if let lowDiskObserver {
            NotificationCenter.default.removeObserver(lowDiskObserver)
        }
    }

    func request(
        _ asset: AudioAssetDescriptor,
        intent: AudioAssetIntent
    ) async -> AudioAssetRequestHandle {
        ensureLowDiskObserver()
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

        requestToAsset[requestID] = asset.id
        let consumer = Consumer(intent: intent, continuation: output.continuation)

        if var entry = entries[asset.id] {
            entry.consumers[requestID] = consumer
            if case .playback = intent {
                entry.request.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
            }
            entries[asset.id] = entry
            output.continuation.yield(.queued)
            if case .ready(let url) = entry.phase {
                deliverReady(assetID: asset.id, generation: entry.generation, url: url)
            }
        } else {
            let resourceRequest = NSBundleResourceRequest(tags: [asset.odrTag])
            if case .playback = intent {
                resourceRequest.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
            }
            let generation = UUID()
            let observation = makeProgressObservation(
                request: resourceRequest,
                assetID: asset.id,
                generation: generation
            )
            entries[asset.id] = Entry(
                asset: asset,
                generation: generation,
                request: resourceRequest,
                phase: .checking,
                consumers: [requestID: consumer],
                leaseIDs: [],
                progressObservation: observation
            )
            output.continuation.yield(.queued)
            startConditionalCheck(
                request: resourceRequest,
                assetID: asset.id,
                generation: generation
            )
        }

        return AudioAssetRequestHandle(
            requestID: requestID,
            assetID: asset.id,
            events: output.stream
        )
    }

    func promote(requestID: UUID) async {
        guard let assetID = requestToAsset[requestID],
              var entry = entries[assetID],
              var consumer = entry.consumers[requestID] else { return }
        consumer.intent = .playback
        entry.consumers[requestID] = consumer
        entry.request.loadingPriority = NSBundleResourceRequestLoadingPriorityUrgent
        entries[assetID] = entry
    }

    func cancel(requestID: UUID) async {
        guard let assetID = requestToAsset.removeValue(forKey: requestID),
              var entry = entries[assetID],
              let consumer = entry.consumers.removeValue(forKey: requestID) else {
            return
        }

        consumer.continuation.finish(throwing: AudioAssetError.cancelled)
        if entry.consumers.isEmpty && entry.leaseIDs.isEmpty {
            switch entry.phase {
            case .checking:
                entry.cancelWhenPossible = true
                entries[assetID] = entry
            case .acquiring:
                entry.cancelWhenPossible = true
                entry.request.progress.cancel()
                entries[assetID] = entry
            case .ready:
                entries[assetID] = entry
                cleanupIfUnused(assetID: assetID, generation: entry.generation)
            }
        } else {
            entries[assetID] = entry
        }
    }

    func release(_ lease: AudioAssetLease) async {
        guard let assetID = leaseToAsset.removeValue(forKey: lease.id),
              var entry = entries[assetID] else { return }
        entry.leaseIDs.remove(lease.id)
        entries[assetID] = entry
        cleanupIfUnused(assetID: assetID, generation: entry.generation)
    }

    func evict(assetID: String) async throws -> AudioAssetEvictionResult {
        if let entry = entries[assetID], !entry.leaseIDs.isEmpty {
            throw AudioAssetError.packIsInUse(assetID)
        }
        await cancelConsumers(assetID: assetID)
        if let descriptor = AudioAssetCatalog.descriptor(for: assetID) {
            Bundle.main.setPreservationPriority(0, forTags: [descriptor.odrTag])
        }
        return .releasedToSystem
    }

    func shutdown() async {
        guard !isShutdown else { return }
        isShutdown = true
        if let lowDiskObserver {
            NotificationCenter.default.removeObserver(lowDiskObserver)
            self.lowDiskObserver = nil
        }
        for assetID in Array(entries.keys) {
            await cancelConsumers(assetID: assetID)
        }
    }

    private func startConditionalCheck(
        request: NSBundleResourceRequest,
        assetID: String,
        generation: UUID
    ) {
        request.conditionallyBeginAccessingResources { [weak self] available in
            Task {
                await self?.conditionalCheckFinished(
                    assetID: assetID,
                    generation: generation,
                    available: available
                )
            }
        }
    }

    private func conditionalCheckFinished(
        assetID: String,
        generation: UUID,
        available: Bool
    ) {
        guard var entry = entries[assetID], entry.generation == generation else { return }
        entry.accessCallbackReceived = true

        if available {
            entry.accessNeedsEnd = true
            entries[assetID] = entry
            if entry.cancelWhenPossible || entry.consumers.isEmpty {
                cleanupIfUnused(assetID: assetID, generation: generation)
            } else {
                resolveAndDeliver(assetID: assetID, generation: generation)
            }
            return
        }

        if entry.cancelWhenPossible || entry.consumers.isEmpty {
            entries[assetID] = entry
            cleanupIfUnused(assetID: assetID, generation: generation)
            return
        }

        entry.phase = .acquiring
        entry.beginStarted = true
        entry.accessCallbackReceived = false
        entries[assetID] = entry
        entry.request.beginAccessingResources { [weak self] error in
            Task {
                await self?.beginFinished(
                    assetID: assetID,
                    generation: generation,
                    error: error
                )
            }
        }
    }

    private func beginFinished(
        assetID: String,
        generation: UUID,
        error: Error?
    ) {
        guard var entry = entries[assetID], entry.generation == generation else { return }
        entry.accessCallbackReceived = true
        entry.accessNeedsEnd = true
        entries[assetID] = entry

        if let error {
            finishConsumers(assetID: assetID, generation: generation, error: error)
            cleanupIfUnused(assetID: assetID, generation: generation)
        } else if entry.cancelWhenPossible || entry.consumers.isEmpty {
            cleanupIfUnused(assetID: assetID, generation: generation)
        } else {
            resolveAndDeliver(assetID: assetID, generation: generation)
        }
    }

    private func resolveAndDeliver(assetID: String, generation: UUID) {
        guard let entry = entries[assetID], entry.generation == generation else { return }
        guard let url = entry.request.bundle.url(
            forResource: entry.asset.fileName,
            withExtension: entry.asset.fileExtension
        ), FileManager.default.isReadableFile(atPath: url.path) else {
            finishConsumers(
                assetID: assetID,
                generation: generation,
                error: AudioAssetError.missingLocalFile(entry.asset.fileName)
            )
            cleanupIfUnused(assetID: assetID, generation: generation)
            return
        }
        deliverReady(assetID: assetID, generation: generation, url: url)
    }

    private func deliverReady(assetID: String, generation: UUID, url: URL) {
        guard var entry = entries[assetID], entry.generation == generation else { return }
        entry.phase = .ready(url)
        let consumers = entry.consumers
        entry.consumers.removeAll()

        for (requestID, consumer) in consumers {
            requestToAsset.removeValue(forKey: requestID)
            let lease = AudioAssetLease(assetID: assetID, localURL: url)
            entry.leaseIDs.insert(lease.id)
            leaseToAsset[lease.id] = assetID
            consumer.continuation.yield(.progress(1))
            consumer.continuation.yield(.ready(lease))
            consumer.continuation.finish()
        }
        entries[assetID] = entry
        cleanupIfUnused(assetID: assetID, generation: generation)
    }

    private func finishConsumers(assetID: String, generation: UUID, error: Error) {
        guard var entry = entries[assetID], entry.generation == generation else { return }
        let consumers = entry.consumers
        entry.consumers.removeAll()
        entries[assetID] = entry
        for (requestID, consumer) in consumers {
            requestToAsset.removeValue(forKey: requestID)
            consumer.continuation.finish(throwing: error)
        }
    }

    private func cleanupIfUnused(assetID: String, generation: UUID) {
        guard var entry = entries[assetID],
              entry.generation == generation,
              entry.consumers.isEmpty,
              entry.leaseIDs.isEmpty else { return }

        if entry.beginStarted && !entry.accessCallbackReceived {
            entry.cancelWhenPossible = true
            entry.request.progress.cancel()
            entries[assetID] = entry
            return
        }

        entry.progressObservation?.invalidate()
        if entry.accessNeedsEnd && !entry.endCalled {
            entry.endCalled = true
            entry.request.endAccessingResources()
        }
        entries.removeValue(forKey: assetID)
    }

    private func makeProgressObservation(
        request: NSBundleResourceRequest,
        assetID: String,
        generation: UUID
    ) -> NSKeyValueObservation {
        request.progress.observe(\.fractionCompleted, options: [.initial, .new]) { [weak self] progress, _ in
            Task {
                await self?.publishProgress(
                    assetID: assetID,
                    generation: generation,
                    fraction: progress.fractionCompleted
                )
            }
        }
    }

    private func publishProgress(assetID: String, generation: UUID, fraction: Double) {
        guard let entry = entries[assetID], entry.generation == generation else { return }
        let clamped = min(max(fraction, 0), 1)
        for consumer in entry.consumers.values {
            consumer.continuation.yield(.progress(clamped))
        }
    }

    private func cancelConsumers(assetID: String) async {
        guard let entry = entries[assetID] else { return }
        for requestID in Array(entry.consumers.keys) {
            await cancel(requestID: requestID)
        }
        if let refreshed = entries[assetID] {
            cleanupIfUnused(assetID: assetID, generation: refreshed.generation)
        }
    }

    private func releasePrefetchesForLowDisk() async {
        for (assetID, entry) in entries {
            let hasPlayback = entry.consumers.values.contains { consumer in
                if case .playback = consumer.intent { return true }
                return false
            }
            guard !hasPlayback else { continue }
            for requestID in Array(entry.consumers.keys) {
                await cancel(requestID: requestID)
            }
            if let refreshed = entries[assetID], refreshed.leaseIDs.isEmpty {
                cleanupIfUnused(assetID: assetID, generation: refreshed.generation)
            }
        }
    }
}
