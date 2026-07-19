//
//  ManagedBackgroundAssetsAudioAssetProvider.swift
//  lengyan
//

import BackgroundAssets
import Foundation
import System

@available(iOS 26.0, *)
actor ManagedBackgroundAssetsAudioAssetProvider: AudioAssetProvider {
    nonisolated let backendKind: AudioAssetBackendKind = .managedBackgroundAssets

    private struct Consumer {
        var intent: AudioAssetIntent
        let continuation: AsyncThrowingStream<AudioAssetEvent, Error>.Continuation
    }

    private struct Entry {
        let asset: AudioAssetDescriptor
        let generation: UUID
        var consumers: [UUID: Consumer]
        var leaseIDs: Set<UUID>
        var downloadTask: Task<Void, Never>?
        var statusTask: Task<Void, Never>?
        var activeProgress: Progress?
        var progressObservation: NSKeyValueObservation?
    }

    private var entries: [String: Entry] = [:]
    private var requestToAsset: [UUID: String] = [:]
    private var leaseToAsset: [UUID: String] = [:]
    private var isShutdown = false

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

        requestToAsset[requestID] = asset.id
        let consumer = Consumer(intent: intent, continuation: output.continuation)
        output.continuation.yield(.queued)

        if var entry = entries[asset.id] {
            entry.consumers[requestID] = consumer
            entries[asset.id] = entry
        } else {
            let generation = UUID()
            var entry = Entry(
                asset: asset,
                generation: generation,
                consumers: [requestID: consumer],
                leaseIDs: [],
                downloadTask: nil,
                statusTask: nil,
                activeProgress: nil,
                progressObservation: nil
            )
            entry.statusTask = makeStatusTask(asset: asset, generation: generation)
            entry.downloadTask = makeDownloadTask(asset: asset, generation: generation)
            entries[asset.id] = entry
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
        entries[assetID] = entry
    }

    func cancel(requestID: UUID) async {
        guard let assetID = requestToAsset.removeValue(forKey: requestID),
              var entry = entries[assetID],
              let consumer = entry.consumers.removeValue(forKey: requestID) else {
            return
        }
        consumer.continuation.finish(throwing: AudioAssetError.cancelled)
        entries[assetID] = entry
        cleanupIfUnused(assetID: assetID, generation: entry.generation, cancelDownload: true)
    }

    func release(_ lease: AudioAssetLease) async {
        guard let assetID = leaseToAsset.removeValue(forKey: lease.id),
              var entry = entries[assetID] else { return }
        entry.leaseIDs.remove(lease.id)
        entries[assetID] = entry
        cleanupIfUnused(assetID: assetID, generation: entry.generation, cancelDownload: false)
    }

    func evict(assetID: String) async throws -> AudioAssetEvictionResult {
        if let entry = entries[assetID],
           !entry.leaseIDs.isEmpty || !entry.consumers.isEmpty {
            throw AudioAssetError.packIsInUse(assetID)
        }
        guard let descriptor = AudioAssetCatalog.descriptor(for: assetID) else {
            throw AudioAssetError.unknownAsset(assetID)
        }
        try await AssetPackManager.shared.remove(assetPackWithID: descriptor.managedPackID)
        return .removed
    }

    func shutdown() async {
        guard !isShutdown else { return }
        isShutdown = true
        for assetID in Array(entries.keys) {
            guard var entry = entries[assetID] else { continue }
            for (requestID, consumer) in entry.consumers {
                requestToAsset.removeValue(forKey: requestID)
                consumer.continuation.finish(throwing: AudioAssetError.cancelled)
            }
            entry.consumers.removeAll()
            entries[assetID] = entry
            cleanupIfUnused(assetID: assetID, generation: entry.generation, cancelDownload: true)
        }
    }

    private func makeDownloadTask(
        asset: AudioAssetDescriptor,
        generation: UUID
    ) -> Task<Void, Never> {
        Task { [weak self] in
            do {
                let manager = AssetPackManager.shared
                let pack = try await manager.assetPack(withID: asset.managedPackID)
                if #available(iOS 26.4, *) {
                    try await manager.ensureLocalAvailability(
                        of: pack,
                        requireLatestVersion: false
                    )
                } else {
                    try await manager.ensureLocalAvailability(of: pack)
                }

                guard !Task.isCancelled else {
                    await self?.finishFailure(
                        assetID: asset.id,
                        generation: generation,
                        error: AudioAssetError.cancelled
                    )
                    return
                }

                let url = try manager.url(for: FilePath(asset.managedRelativePath))
                guard FileManager.default.isReadableFile(atPath: url.path) else {
                    throw AudioAssetError.missingLocalFile(asset.managedRelativePath)
                }
                await self?.deliverReady(assetID: asset.id, generation: generation, url: url)
            } catch {
                await self?.finishFailure(assetID: asset.id, generation: generation, error: error)
            }
        }
    }

    private func makeStatusTask(
        asset: AudioAssetDescriptor,
        generation: UUID
    ) -> Task<Void, Never> {
        Task { [weak self] in
            let updates = AssetPackManager.shared.statusUpdates(
                forAssetPackWithID: asset.managedPackID
            )
            for await update in updates {
                guard !Task.isCancelled else { return }
                let terminal = await self?.receiveStatus(
                    update,
                    assetID: asset.id,
                    generation: generation
                ) ?? true
                if terminal { return }
            }
        }
    }

    private func receiveStatus(
        _ update: AssetPackManager.DownloadStatusUpdate,
        assetID: String,
        generation: UUID
    ) -> Bool {
        guard var entry = entries[assetID], entry.generation == generation else { return true }
        switch update {
        case .began, .paused:
            return false
        case .downloading(_, let progress):
            entry.activeProgress = progress
            entry.progressObservation?.invalidate()
            entry.progressObservation = progress.observe(
                \.fractionCompleted,
                options: [.initial, .new]
            ) { [weak self] progress, _ in
                Task {
                    await self?.publishProgress(
                        assetID: assetID,
                        generation: generation,
                        fraction: progress.fractionCompleted
                    )
                }
            }
            entries[assetID] = entry
            return false
        case .finished:
            publishProgress(assetID: assetID, generation: generation, fraction: 1)
            return true
        case .failed(_, let error):
            finishFailure(assetID: assetID, generation: generation, error: error)
            return true
        @unknown default:
            return false
        }
    }

    private func publishProgress(assetID: String, generation: UUID, fraction: Double) {
        guard let entry = entries[assetID], entry.generation == generation else { return }
        let clamped = min(max(fraction, 0), 1)
        for consumer in entry.consumers.values {
            consumer.continuation.yield(.progress(clamped))
        }
    }

    private func deliverReady(assetID: String, generation: UUID, url: URL) {
        guard var entry = entries[assetID], entry.generation == generation else { return }
        entry.statusTask?.cancel()
        entry.progressObservation?.invalidate()
        entry.statusTask = nil
        entry.downloadTask = nil
        entry.progressObservation = nil
        entry.activeProgress = nil
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
        cleanupIfUnused(assetID: assetID, generation: generation, cancelDownload: false)
    }

    private func finishFailure(assetID: String, generation: UUID, error: Error) {
        guard var entry = entries[assetID], entry.generation == generation else { return }
        entry.statusTask?.cancel()
        entry.progressObservation?.invalidate()
        let consumers = entry.consumers
        entry.consumers.removeAll()
        for (requestID, consumer) in consumers {
            requestToAsset.removeValue(forKey: requestID)
            consumer.continuation.finish(throwing: error)
        }
        entries[assetID] = entry
        cleanupIfUnused(assetID: assetID, generation: generation, cancelDownload: false)
    }

    private func cleanupIfUnused(
        assetID: String,
        generation: UUID,
        cancelDownload: Bool
    ) {
        guard let entry = entries[assetID],
              entry.generation == generation,
              entry.consumers.isEmpty,
              entry.leaseIDs.isEmpty else { return }
        if cancelDownload {
            entry.activeProgress?.cancel()
            entry.downloadTask?.cancel()
        }
        entry.statusTask?.cancel()
        entry.progressObservation?.invalidate()
        entries.removeValue(forKey: assetID)
    }
}
