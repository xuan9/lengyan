//
//  AudioAssetCoordinator.swift
//  lengyan
//
//  Owns the one current lease and at most one next-prefetch lease. It also
//  turns an in-flight prefetch into a foreground request without starting a
//  second provider transfer.
//

import Foundation

enum AudioAssetAutomaticStoragePolicy {
    // Audio prefetch is opportunistic. Keep enough room for normal device
    // operation in addition to the next (at most 21 MiB) audio pack.
    static let minimumHeadroomBytes: Int64 = 512 * 1_024 * 1_024

    static func shouldReclaim(availableCapacity: Int64?) -> Bool {
        guard let availableCapacity else { return false }
        return availableCapacity < minimumHeadroomBytes
    }

    static func allowsPrefetch(
        assetByteCount: Int64,
        availableCapacity: Int64?
    ) -> Bool {
        guard assetByteCount > 0 else { return false }
        guard let availableCapacity else { return true }
        return availableCapacity >= minimumHeadroomBytes + assetByteCount
    }

    static func currentOpportunisticCapacity(
        fileManager: FileManager = .default
    ) -> Int64? {
        guard let cachesURL = fileManager.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first,
        let values = try? cachesURL.resourceValues(
            forKeys: [.volumeAvailableCapacityForOpportunisticUsageKey]
        ) else { return nil }
        return values.volumeAvailableCapacityForOpportunisticUsage
    }
}

actor AudioAssetCoordinator {
    private static let accessTimesDefaultsKey =
        "audioAssets.managedPackLastAccessTimesV1"

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
    private let availableCapacityProvider: @Sendable () -> Int64?
    private var pending: PendingRequest?
    private var prefetch: PrefetchRequest?
    private var currentLease: AudioAssetLease?
    private var requestedAssetID: String?
    private var lastAccessTimes: [String: TimeInterval]

    init(
        provider: any AudioAssetProvider,
        availableCapacityProvider: @escaping @Sendable () -> Int64? = {
            AudioAssetAutomaticStoragePolicy.currentOpportunisticCapacity()
        }
    ) {
        self.provider = provider
        self.availableCapacityProvider = availableCapacityProvider
        let stored = UserDefaults.standard.dictionary(
            forKey: Self.accessTimesDefaultsKey
        ) ?? [:]
        lastAccessTimes = stored.reduce(into: [:]) { result, entry in
            if let value = entry.value as? NSNumber {
                result[entry.key] = value.doubleValue
            }
        }
    }

    func requestPlayback(
        _ asset: AudioAssetDescriptor,
        generation: UUID
    ) async -> AudioAssetRequestHandle {
        await cancelPending()
        requestedAssetID = asset.id
        await performAutomaticStorageMaintenance(
            additionallyProtecting: [asset.id]
        )

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
        let capacity = availableCapacityProvider()
        guard AudioAssetAutomaticStoragePolicy.allowsPrefetch(
            assetByteCount: asset.contentByteCount,
            availableCapacity: capacity
        ) else {
            await performAutomaticStorageMaintenance(
                force: AudioAssetAutomaticStoragePolicy.shouldReclaim(
                    availableCapacity: capacity
                )
            )
            return
        }
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
        recordAccess(for: lease.assetID)
        if let oldLease {
            await provider.release(oldLease)
        }
        await performAutomaticStorageMaintenance()
    }

    func discard(_ lease: AudioAssetLease) async {
        if currentLease?.id == lease.id { return }
        await provider.release(lease)
    }

    func cancelPending() async {
        guard let pending else { return }
        self.pending = nil
        requestedAssetID = currentLease?.assetID
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

    func performAutomaticStorageMaintenance(
        force: Bool = false,
        additionallyProtecting additionalIDs: Set<String> = []
    ) async {
        guard provider.backendKind == .managedBackgroundAssets else { return }

        let capacity = availableCapacityProvider()
        guard force || AudioAssetAutomaticStoragePolicy.shouldReclaim(
            availableCapacity: capacity
        ) else { return }

        var protectedIDs = additionalIDs
        if let currentLease { protectedIDs.insert(currentLease.assetID) }
        if let pending { protectedIDs.insert(pending.asset.id) }
        if let requestedAssetID { protectedIDs.insert(requestedAssetID) }
        if let mostRecentID = lastAccessTimes.max(by: { $0.value < $1.value })?.key {
            protectedIDs.insert(mostRecentID)
        }

        // A prefetched volume is expendable under storage pressure unless the
        // person just selected that exact volume. In that case keep the work
        // and let requestPlayback promote it instead of downloading it again.
        if let prefetch, !protectedIDs.contains(prefetch.asset.id) {
            await cancelPrefetch()
        }

        let catalogIndex = Dictionary(
            uniqueKeysWithValues: AudioAssetCatalog.orderedIDs.enumerated().map {
                ($0.element, $0.offset)
            }
        )
        let candidates = AudioAssetCatalog.orderedIDs
            .filter { !protectedIDs.contains($0) }
            .sorted { lhs, rhs in
                let lhsAccess = lastAccessTimes[lhs] ?? 0
                let rhsAccess = lastAccessTimes[rhs] ?? 0
                if lhsAccess != rhsAccess { return lhsAccess < rhsAccess }
                return catalogIndex[lhs, default: 0] < catalogIndex[rhs, default: 0]
            }

        for assetID in candidates {
            do {
                _ = try await provider.evict(assetID: assetID)
                lastAccessTimes.removeValue(forKey: assetID)
            } catch {
                // A newly-started request can race maintenance while an await
                // is suspended. In-use and transient removal failures are safe
                // to retry during the next maintenance pass.
            }

            if !force,
               !AudioAssetAutomaticStoragePolicy.shouldReclaim(
                   availableCapacity: availableCapacityProvider()
               ) {
                break
            }
        }
        persistAccessTimes()
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

    private func recordAccess(for assetID: String) {
        lastAccessTimes[assetID] = Date().timeIntervalSince1970
        persistAccessTimes()
    }

    private func persistAccessTimes() {
        UserDefaults.standard.set(
            lastAccessTimes,
            forKey: Self.accessTimesDefaultsKey
        )
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
            requestedAssetID = currentLease?.assetID
            pending.continuation.finish(throwing: error)
            return
        }
        if let prefetch, prefetch.requestID == requestID {
            self.prefetch = nil
        }
    }
}
