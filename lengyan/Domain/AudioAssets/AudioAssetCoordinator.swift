//
//  AudioAssetCoordinator.swift
//  lengyan
//
//  Owns the one current lease and at most one next-prefetch lease. It also
//  turns an in-flight prefetch into a foreground request without starting a
//  second provider transfer.
//

import Foundation

actor AudioAssetCoordinator {
    private struct PendingRequest {
        let requestID: UUID
        let asset: AudioAssetDescriptor
        let generation: UUID
        let continuation: AsyncThrowingStream<AudioAssetEvent, Error>.Continuation
        var task: Task<Void, Never>?
    }

    private struct PrefetchRequest {
        let requestID: UUID
        let asset: AudioAssetDescriptor
        var task: Task<Void, Never>?
        var lease: AudioAssetLease?
    }

    private let provider: any AudioAssetProvider
    private var pending: PendingRequest?
    private var prefetch: PrefetchRequest?
    private var currentLease: AudioAssetLease?
    private var requestedAssetID: String?

    init(provider: any AudioAssetProvider) {
        self.provider = provider
    }

    func requestPlayback(
        _ asset: AudioAssetDescriptor,
        generation: UUID
    ) async -> AudioAssetRequestHandle {
        await cancelPending()
        requestedAssetID = asset.id

        let output = AsyncThrowingStream<AudioAssetEvent, Error>.audioAssetStream()

        if let currentLease, currentLease.assetID == asset.id {
            output.continuation.yield(.queued)
            output.continuation.yield(.ready(currentLease))
            output.continuation.finish()
            return AudioAssetRequestHandle(
                requestID: UUID(),
                assetID: asset.id,
                events: output.stream
            )
        }

        if let existingPrefetch = prefetch,
           existingPrefetch.asset.id == asset.id {
            prefetch = nil
            if let lease = existingPrefetch.lease {
                output.continuation.yield(.queued)
                output.continuation.yield(.ready(lease))
                output.continuation.finish()
                return AudioAssetRequestHandle(
                    requestID: existingPrefetch.requestID,
                    assetID: asset.id,
                    events: output.stream
                )
            }

            let promoted = PendingRequest(
                requestID: existingPrefetch.requestID,
                asset: asset,
                generation: generation,
                continuation: output.continuation,
                task: existingPrefetch.task
            )
            pending = promoted
            output.continuation.yield(.queued)
            // Keep pending installed before the await. The provider can finish
            // during promotion; receive(_:requestID:) must then be allowed to
            // clear it without this method writing the completed request back.
            await provider.promote(requestID: promoted.requestID)
            return AudioAssetRequestHandle(
                requestID: promoted.requestID,
                assetID: asset.id,
                events: output.stream
            )
        }

        await cancelPrefetch()
        let providerHandle = await provider.request(asset, intent: .playback)
        var newPending = PendingRequest(
            requestID: providerHandle.requestID,
            asset: asset,
            generation: generation,
            continuation: output.continuation,
            task: nil
        )
        let task = consumeProviderEvents(providerHandle)
        newPending.task = task
        pending = newPending
        output.continuation.yield(.queued)
        return AudioAssetRequestHandle(
            requestID: providerHandle.requestID,
            assetID: asset.id,
            events: output.stream
        )
    }

    func startPrefetch(
        _ asset: AudioAssetDescriptor,
        ownerID: String
    ) async {
        guard currentLease?.assetID != asset.id else { return }
        if prefetch?.asset.id == asset.id { return }

        await cancelPrefetch()
        let handle = await provider.request(
            asset,
            intent: .prefetch(ownerID: ownerID)
        )
        var newPrefetch = PrefetchRequest(
            requestID: handle.requestID,
            asset: asset,
            task: nil,
            lease: nil
        )
        let task = consumeProviderEvents(handle)
        newPrefetch.task = task
        prefetch = newPrefetch
    }

    func commitPlayback(_ lease: AudioAssetLease) async {
        if currentLease?.id == lease.id { return }
        let oldLease = currentLease
        currentLease = lease
        if let oldLease {
            await provider.release(oldLease)
        }
    }

    func discard(_ lease: AudioAssetLease) async {
        if currentLease?.id == lease.id { return }
        await provider.release(lease)
    }

    func cancelPending() async {
        guard let pending else { return }
        self.pending = nil
        pending.task?.cancel()
        pending.continuation.finish(throwing: AudioAssetError.cancelled)
        await provider.cancel(requestID: pending.requestID)
    }

    func cancelPrefetch() async {
        guard let prefetch else { return }
        self.prefetch = nil
        prefetch.task?.cancel()
        if let lease = prefetch.lease {
            await provider.release(lease)
        } else {
            await provider.cancel(requestID: prefetch.requestID)
        }
    }

    func stopAndReleaseAll() async {
        await cancelPending()
        await cancelPrefetch()
        if let currentLease {
            self.currentLease = nil
            await provider.release(currentLease)
        }
        requestedAssetID = nil
    }

    func evict(assetID: String) async throws -> AudioAssetEvictionResult {
        if currentLease?.assetID == assetID {
            throw AudioAssetError.packIsInUse(assetID)
        }
        if prefetch?.asset.id == assetID {
            await cancelPrefetch()
        }
        return try await provider.evict(assetID: assetID)
    }

    func shutdown() async {
        await stopAndReleaseAll()
        await provider.shutdown()
    }

    func snapshot() -> AudioAssetCoordinatorSnapshot {
        AudioAssetCoordinatorSnapshot(
            backend: provider.backendKind,
            requestedAssetID: requestedAssetID,
            pendingAssetID: pending?.asset.id,
            playingAssetID: currentLease?.assetID,
            prefetchedAssetID: prefetch?.asset.id,
            prefetchedLocalURL: prefetch?.lease?.localURL,
            activeLeaseCount: (currentLease == nil ? 0 : 1) + (prefetch?.lease == nil ? 0 : 1)
        )
    }

    private func consumeProviderEvents(
        _ handle: AudioAssetRequestHandle
    ) -> Task<Void, Never> {
        Task { [weak self] in
            do {
                for try await event in handle.events {
                    guard !Task.isCancelled else { return }
                    await self?.receive(event, requestID: handle.requestID)
                }
            } catch {
                await self?.fail(error, requestID: handle.requestID)
            }
        }
    }

    private func receive(_ event: AudioAssetEvent, requestID: UUID) async {
        if let pending, pending.requestID == requestID {
            switch event {
            case .ready:
                self.pending = nil
                pending.continuation.yield(event)
                pending.continuation.finish()
            default:
                pending.continuation.yield(event)
            }
            return
        }

        if var prefetch, prefetch.requestID == requestID {
            if case .ready(let lease) = event {
                prefetch.lease = lease
                prefetch.task = nil
                self.prefetch = prefetch
            }
            return
        }

        if case .ready(let lease) = event {
            await provider.release(lease)
        }
    }

    private func fail(_ error: Error, requestID: UUID) async {
        if let pending, pending.requestID == requestID {
            self.pending = nil
            pending.continuation.finish(throwing: error)
            return
        }
        if let prefetch, prefetch.requestID == requestID {
            self.prefetch = nil
        }
    }
}
