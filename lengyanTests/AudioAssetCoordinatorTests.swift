//
//  AudioAssetCoordinatorTests.swift
//  lengyanTests
//

import XCTest
@testable import lengyan

final class AudioAssetCoordinatorTests: XCTestCase {
    func testProviderRouterMatrix() {
        let enabled = AudioAssetProviderPolicy(
            managedEnabled: true,
            managedCatalogReady: true
        )
        let disabled = AudioAssetProviderPolicy(
            managedEnabled: false,
            managedCatalogReady: true
        )
        let notReady = AudioAssetProviderPolicy(
            managedEnabled: true,
            managedCatalogReady: false
        )

        XCTAssertEqual(
            AudioAssetProviderFactory.backendDecision(
                systemMajorVersion: 15,
                policy: enabled
            ),
            .legacyODR
        )
        XCTAssertEqual(
            AudioAssetProviderFactory.backendDecision(
                systemMajorVersion: 25,
                policy: enabled
            ),
            .legacyODR
        )
        XCTAssertEqual(
            AudioAssetProviderFactory.backendDecision(
                systemMajorVersion: 26,
                policy: enabled
            ),
            .managedBackgroundAssets
        )
        XCTAssertEqual(
            AudioAssetProviderFactory.backendDecision(
                systemMajorVersion: 27,
                policy: disabled
            ),
            .legacyODR
        )
        XCTAssertEqual(
            AudioAssetProviderFactory.backendDecision(
                systemMajorVersion: 27,
                policy: notReady
            ),
            .legacyODR
        )
    }

    func testRuntimeFactorySelectsBackendForCurrentOS() {
        let provider = AudioAssetProviderFactory.makeProvider()
        if #available(iOS 26.0, *) {
            XCTAssertEqual(provider.backendKind, .managedBackgroundAssets)
        } else {
            XCTAssertEqual(provider.backendKind, .legacyODR)
        }
    }

    func testLegacyODRDemotionRunsOnlyForFirstManagedLaunchOnIOS26OrLater() {
        XCTAssertFalse(
            AudioAssetProviderFactory.shouldDemoteLegacyODRTags(
                systemMajorVersion: 25,
                backend: .managedBackgroundAssets,
                alreadyCompleted: false
            )
        )
        XCTAssertFalse(
            AudioAssetProviderFactory.shouldDemoteLegacyODRTags(
                systemMajorVersion: 26,
                backend: .legacyODR,
                alreadyCompleted: false
            )
        )
        XCTAssertTrue(
            AudioAssetProviderFactory.shouldDemoteLegacyODRTags(
                systemMajorVersion: 26,
                backend: .managedBackgroundAssets,
                alreadyCompleted: false
            )
        )
        XCTAssertFalse(
            AudioAssetProviderFactory.shouldDemoteLegacyODRTags(
                systemMajorVersion: 27,
                backend: .managedBackgroundAssets,
                alreadyCompleted: true
            )
        )
    }

    func testCatalogIsOneToOneAndWrapsFromMantraToVolumeOne() {
        XCTAssertNil(AudioAssetCatalog.validationError)
        XCTAssertEqual(AudioAssetCatalog.descriptors.count, 11)
        XCTAssertEqual(AudioAssetCatalog.next(after: "lyz1")?.id, "ly01")
        XCTAssertEqual(
            Set(AudioAssetCatalog.descriptors.map(\.managedPackID)).count,
            11
        )
        XCTAssertEqual(
            Set(AudioAssetCatalog.descriptors.map(\.managedRelativePath)).count,
            11
        )
    }

    func testPrefetchPromotionReusesOneUnderlyingRequest() async throws {
        let provider = FakeAudioAssetProvider()
        let coordinator = AudioAssetCoordinator(provider: provider)
        let asset = try XCTUnwrap(AudioAssetCatalog.descriptor(for: "ly02"))

        await coordinator.startPrefetch(asset, ownerID: "ly01-generation")
        let handle = await coordinator.requestPlayback(asset, generation: UUID())

        let requestCount = await provider.requestCount(for: asset.id)
        let promotionCount = await provider.promotionCount
        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(promotionCount, 1)

        let url = URL(fileURLWithPath: "/tmp/ly02.m4a")
        await provider.complete(assetID: asset.id, url: url)
        let lease = try await readyLease(from: handle)
        await coordinator.commitPlayback(lease)

        let snapshot = await coordinator.snapshot()
        XCTAssertEqual(snapshot.playingAssetID, "ly02")
        XCTAssertNil(snapshot.prefetchedAssetID)
        XCTAssertEqual(snapshot.activeLeaseCount, 1)
    }

    func testPrefetchCanFinishWhilePromotionIsAwaiting() async throws {
        let provider = FakeAudioAssetProvider()
        let coordinator = AudioAssetCoordinator(provider: provider)
        let asset = try XCTUnwrap(AudioAssetCatalog.descriptor(for: "ly02"))
        let url = URL(fileURLWithPath: "/tmp/ly02-during-promotion.m4a")

        await coordinator.startPrefetch(asset, ownerID: "ly01-generation")
        await provider.completeDuringNextPromotion(assetID: asset.id, url: url)

        let handle = await coordinator.requestPlayback(asset, generation: UUID())
        let lease = try await readyLease(from: handle)
        await coordinator.commitPlayback(lease)

        let snapshot = await coordinator.snapshot()
        XCTAssertNil(snapshot.pendingAssetID)
        XCTAssertEqual(snapshot.playingAssetID, asset.id)
        XCTAssertEqual(snapshot.activeLeaseCount, 1)
    }

    func testLateFirstSelectionCannotBecomeCurrentAfterSecondSelection() async throws {
        let provider = FakeAudioAssetProvider()
        let coordinator = AudioAssetCoordinator(provider: provider)
        let first = try XCTUnwrap(AudioAssetCatalog.descriptor(for: "ly01"))
        let second = try XCTUnwrap(AudioAssetCatalog.descriptor(for: "ly02"))

        let firstHandle = await coordinator.requestPlayback(first, generation: UUID())
        let secondHandle = await coordinator.requestPlayback(second, generation: UUID())

        await provider.complete(
            assetID: first.id,
            url: URL(fileURLWithPath: "/tmp/late-ly01.m4a")
        )
        await provider.complete(
            assetID: second.id,
            url: URL(fileURLWithPath: "/tmp/ly02.m4a")
        )

        do {
            _ = try await readyLease(from: firstHandle)
            XCTFail("The superseded first selection must be cancelled")
        } catch {
            // Expected cancellation from requestPlayback(second).
        }

        let secondLease = try await readyLease(from: secondHandle)
        await coordinator.commitPlayback(secondLease)
        let snapshot = await coordinator.snapshot()
        XCTAssertEqual(snapshot.playingAssetID, "ly02")
        XCTAssertNotEqual(snapshot.playingAssetID, "ly01")
    }

    private func readyLease(
        from handle: AudioAssetRequestHandle
    ) async throws -> AudioAssetLease {
        for try await event in handle.events {
            if case .ready(let lease) = event { return lease }
        }
        throw AudioAssetError.cancelled
    }
}

private actor FakeAudioAssetProvider: AudioAssetProvider {
    nonisolated let backendKind: AudioAssetBackendKind = .legacyODR

    private struct Request {
        let assetID: String
        var intent: AudioAssetIntent
        let continuation: AsyncThrowingStream<AudioAssetEvent, Error>.Continuation
    }

    private var requests: [UUID: Request] = [:]
    private var requestCounts: [String: Int] = [:]
    private(set) var promotionCount = 0
    private var releasedLeaseIDs: Set<UUID> = []
    private var promotionCompletion: (assetID: String, url: URL)?

    func request(
        _ asset: AudioAssetDescriptor,
        intent: AudioAssetIntent
    ) async -> AudioAssetRequestHandle {
        let requestID = UUID()
        let output = AsyncThrowingStream<AudioAssetEvent, Error>.audioAssetStream()
        let hasUnderlyingRequest = requests.values.contains {
            $0.assetID == asset.id
        }
        if !hasUnderlyingRequest {
            requestCounts[asset.id, default: 0] += 1
        }
        requests[requestID] = Request(
            assetID: asset.id,
            intent: intent,
            continuation: output.continuation
        )
        output.continuation.yield(.queued)
        return AudioAssetRequestHandle(
            requestID: requestID,
            assetID: asset.id,
            events: output.stream
        )
    }

    func promote(requestID: UUID) async {
        guard var request = requests[requestID] else { return }
        request.intent = .playback
        requests[requestID] = request
        promotionCount += 1
        if let promotionCompletion,
           promotionCompletion.assetID == request.assetID {
            self.promotionCompletion = nil
            complete(assetID: request.assetID, url: promotionCompletion.url)
            await Task.yield()
        }
    }

    func cancel(requestID: UUID) async {
        guard let request = requests.removeValue(forKey: requestID) else { return }
        request.continuation.finish(throwing: AudioAssetError.cancelled)
    }

    func release(_ lease: AudioAssetLease) async {
        releasedLeaseIDs.insert(lease.id)
    }

    func evict(assetID: String) async throws -> AudioAssetEvictionResult {
        .releasedToSystem
    }

    func shutdown() async {
        for requestID in Array(requests.keys) {
            await cancel(requestID: requestID)
        }
    }

    func requestCount(for assetID: String) -> Int {
        requestCounts[assetID, default: 0]
    }

    func completeDuringNextPromotion(assetID: String, url: URL) {
        promotionCompletion = (assetID, url)
    }

    func complete(assetID: String, url: URL) {
        let matching = requests.filter { $0.value.assetID == assetID }
        for (requestID, request) in matching {
            requests.removeValue(forKey: requestID)
            request.continuation.yield(
                .ready(AudioAssetLease(assetID: assetID, localURL: url))
            )
            request.continuation.finish()
        }
    }
}
