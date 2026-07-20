//
//  AudioAssetCoordinatorTests.swift
//  lengyanTests
//

import CryptoKit
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
        XCTAssertEqual(
            Set(AudioAssetCatalog.descriptors.map(\.cdnRelativePath)).count,
            11
        )
        XCTAssertTrue(
            AudioAssetCatalog.descriptors.allSatisfy {
                $0.contentSHA256.count == 64 && $0.contentByteCount > 0
            }
        )
    }

    func testCDNConfigurationRejectsNonHTTPSAndBuildsImmutableURL() throws {
        XCTAssertNil(CDNAudioFallbackConfiguration.validatedBaseURL(""))
        XCTAssertNil(CDNAudioFallbackConfiguration.validatedBaseURL("http://audio.example.com"))
        XCTAssertNil(CDNAudioFallbackConfiguration.validatedBaseURL("https://user:pass@audio.example.com"))
        let baseURL = try XCTUnwrap(
            CDNAudioFallbackConfiguration.validatedBaseURL("https://audio.example.com/root")
        )
        let asset = makeTestDescriptor(payload: Data("fallback".utf8))
        let configuration = CDNAudioFallbackConfiguration(
            baseURL: baseURL,
            cacheDirectory: URL(fileURLWithPath: "/tmp/audio-fallback-test"),
            stallTimeout: 15,
            resourceTimeout: 60
        )
        XCTAssertEqual(
            configuration.remoteURL(for: asset).absoluteString,
            "https://audio.example.com/root/\(asset.cdnRelativePath)"
        )
    }

    func testCDNDownloadPolicyStopsResponsesLargerThanCatalog() {
        XCTAssertFalse(
            CDNAudioDownloadPolicy.exceedsExpectedSize(
                totalBytesWritten: 512,
                totalBytesExpectedToWrite: NSURLSessionTransferSizeUnknown,
                catalogByteCount: 1_024
            )
        )
        XCTAssertFalse(
            CDNAudioDownloadPolicy.exceedsExpectedSize(
                totalBytesWritten: 1_024,
                totalBytesExpectedToWrite: 1_024,
                catalogByteCount: 1_024
            )
        )
        XCTAssertTrue(
            CDNAudioDownloadPolicy.exceedsExpectedSize(
                totalBytesWritten: 1_025,
                totalBytesExpectedToWrite: NSURLSessionTransferSizeUnknown,
                catalogByteCount: 1_024
            )
        )
        XCTAssertTrue(
            CDNAudioDownloadPolicy.exceedsExpectedSize(
                totalBytesWritten: 1,
                totalBytesExpectedToWrite: 1_025,
                catalogByteCount: 1_024
            )
        )
    }

    func testFallbackCacheMigratesToCachesAndKeepsTwoMostRecentFiles() throws {
        let root = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let defaultsSuite = "lengyan-cdn-cache-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuite))
        defaults.removePersistentDomain(forName: defaultsSuite)
        defer { defaults.removePersistentDomain(forName: defaultsSuite) }
        let cacheDirectory = root.appendingPathComponent("Caches/AudioFallback")
        let legacyDirectory = root.appendingPathComponent(
            "ApplicationSupport/AudioFallback"
        )
        try FileManager.default.createDirectory(
            at: legacyDirectory,
            withIntermediateDirectories: true
        )
        let marker = legacyDirectory.appendingPathComponent("migration-marker")
        try Data("cached".utf8).write(to: marker)
        let configuration = CDNAudioFallbackConfiguration(
            baseURL: URL(string: "https://audio.example.com")!,
            cacheDirectory: cacheDirectory,
            legacyCacheDirectory: legacyDirectory,
            stallTimeout: 15,
            resourceTimeout: 60
        )

        CDNAudioCache.prepareStorage(
            configuration: configuration,
            defaults: defaults
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyDirectory.path))
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: cacheDirectory
                    .appendingPathComponent("migration-marker")
                    .path
            )
        )

        let assets = Array(AudioAssetCatalog.descriptors.prefix(3))
        for (index, asset) in assets.enumerated() {
            let url = CDNAudioCache.destinationURL(
                for: asset,
                configuration: configuration
            )
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data(repeating: UInt8(index), count: 16).write(to: url)
            CDNAudioCache.touch(assetID: asset.id, defaults: defaults)
        }

        CDNAudioCache.trim(
            configuration: configuration,
            protecting: [],
            defaults: defaults,
            maximumFileCount: 2,
            maximumByteCount: .max
        )

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: CDNAudioCache.destinationURL(
                    for: assets[0],
                    configuration: configuration
                ).path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: CDNAudioCache.destinationURL(
                    for: assets[1],
                    configuration: configuration
                ).path
            )
        )
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: CDNAudioCache.destinationURL(
                    for: assets[2],
                    configuration: configuration
                ).path
            )
        )
    }

    func testProductionCDNFallbackIsEnabledAtVerifiedWorkersDevOrigin() throws {
        let configuration = try XCTUnwrap(CDNAudioFallbackConfiguration.production)
        XCTAssertEqual(
            configuration.baseURL.absoluteString,
            "https://lengyan-audio-fallback.dhyana9.workers.dev"
        )
        XCTAssertEqual(configuration.stallTimeout, 15)
        XCTAssertEqual(configuration.baseURL.scheme, "https")
    }

    func testPlaybackFailureSwitchesToVerifiedCDNFallback() async throws {
        let payload = Data("verified fallback audio".utf8)
        let asset = makeTestDescriptor(payload: payload)
        let cacheDirectory = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }

        let downloader = FakeCDNAudioDownloader(payload: payload)
        let fallback = CDNAudioAssetProvider(
            configuration: makeCDNConfiguration(cacheDirectory: cacheDirectory),
            downloader: downloader
        )
        let primary = FakeAudioAssetProvider()
        let provider = FailoverAudioAssetProvider(
            primary: primary,
            fallback: fallback,
            stallTimeout: 60
        )

        let handle = await provider.request(asset, intent: .playback)
        await waitForRequest(assetID: asset.id, provider: primary)
        await primary.fail(
            assetID: asset.id,
            error: URLError(.cannotConnectToHost)
        )

        var activatedFallback = false
        var readyLease: AudioAssetLease?
        for try await event in handle.events {
            switch event {
            case .fallbackActivated:
                activatedFallback = true
            case .ready(let lease):
                readyLease = lease
            default:
                break
            }
        }

        let lease = try XCTUnwrap(readyLease)
        XCTAssertTrue(activatedFallback)
        XCTAssertEqual(try Data(contentsOf: lease.localURL), payload)
        let downloadCount = await downloader.downloadCount
        XCTAssertEqual(downloadCount, 1)
        await provider.release(lease)
    }

    func testPrefetchFailureDoesNotConsumeCDNFallbackTraffic() async throws {
        let payload = Data("prefetch must stay on Apple".utf8)
        let asset = makeTestDescriptor(payload: payload)
        let cacheDirectory = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }

        let downloader = FakeCDNAudioDownloader(payload: payload)
        let fallback = CDNAudioAssetProvider(
            configuration: makeCDNConfiguration(cacheDirectory: cacheDirectory),
            downloader: downloader
        )
        let primary = FakeAudioAssetProvider()
        let provider = FailoverAudioAssetProvider(
            primary: primary,
            fallback: fallback,
            stallTimeout: 0.05
        )

        let handle = await provider.request(
            asset,
            intent: .prefetch(ownerID: "test-owner")
        )
        await waitForRequest(assetID: asset.id, provider: primary)
        await primary.fail(
            assetID: asset.id,
            error: URLError(.cannotConnectToHost)
        )

        do {
            for try await _ in handle.events {}
            XCTFail("A failed prefetch must finish with the primary error")
        } catch {
            // Expected: prefetch is intentionally not promoted to CDN traffic.
        }
        let downloadCount = await downloader.downloadCount
        XCTAssertEqual(downloadCount, 0)
    }

    func testStalledPlaybackCancelsPrimaryBeforeUsingFallback() async throws {
        let payload = Data("stall watchdog fallback".utf8)
        let asset = makeTestDescriptor(payload: payload)
        let cacheDirectory = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }

        let downloader = FakeCDNAudioDownloader(payload: payload)
        let fallback = CDNAudioAssetProvider(
            configuration: makeCDNConfiguration(cacheDirectory: cacheDirectory),
            downloader: downloader
        )
        let primary = FakeAudioAssetProvider()
        let provider = FailoverAudioAssetProvider(
            primary: primary,
            fallback: fallback,
            stallTimeout: 0.05
        )

        let handle = await provider.request(asset, intent: .playback)
        var activatedFallback = false
        var lease: AudioAssetLease?
        for try await event in handle.events {
            if case .fallbackActivated = event { activatedFallback = true }
            if case .ready(let value) = event { lease = value }
        }

        XCTAssertTrue(activatedFallback)
        let cancellationCount = await primary.cancellationCount
        let downloadCount = await downloader.downloadCount
        XCTAssertEqual(cancellationCount, 1)
        XCTAssertEqual(downloadCount, 1)
        if let lease { await provider.release(lease) }
    }

    func testCancellingPlaybackNeverActivatesFallback() async throws {
        let payload = Data("cancelled request".utf8)
        let asset = makeTestDescriptor(payload: payload)
        let cacheDirectory = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }

        let downloader = FakeCDNAudioDownloader(payload: payload)
        let fallback = CDNAudioAssetProvider(
            configuration: makeCDNConfiguration(cacheDirectory: cacheDirectory),
            downloader: downloader
        )
        let primary = FakeAudioAssetProvider()
        let provider = FailoverAudioAssetProvider(
            primary: primary,
            fallback: fallback,
            stallTimeout: 60
        )

        let handle = await provider.request(asset, intent: .playback)
        await waitForRequest(assetID: asset.id, provider: primary)
        await provider.cancel(requestID: handle.requestID)

        do {
            for try await _ in handle.events {}
            XCTFail("A cancelled playback request must throw")
        } catch {
            // Expected cancellation; it must not be reinterpreted as failure.
        }
        let downloadCount = await downloader.downloadCount
        let cancellationCount = await primary.cancellationCount
        XCTAssertEqual(downloadCount, 0)
        XCTAssertEqual(cancellationCount, 1)
    }

    func testOutOfSpaceFailureNeverActivatesFallback() async throws {
        let payload = Data("out of space".utf8)
        let asset = makeTestDescriptor(payload: payload)
        let cacheDirectory = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }

        let downloader = FakeCDNAudioDownloader(payload: payload)
        let fallback = CDNAudioAssetProvider(
            configuration: makeCDNConfiguration(cacheDirectory: cacheDirectory),
            downloader: downloader
        )
        let primary = FakeAudioAssetProvider()
        let provider = FailoverAudioAssetProvider(
            primary: primary,
            fallback: fallback,
            stallTimeout: 60
        )

        let handle = await provider.request(asset, intent: .playback)
        await waitForRequest(assetID: asset.id, provider: primary)
        await primary.fail(
            assetID: asset.id,
            error: NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileWriteOutOfSpaceError
            )
        )

        do {
            for try await _ in handle.events {}
            XCTFail("Out-of-space must remain a terminal local error")
        } catch {
            // Expected: another download cannot fix unavailable local storage.
        }
        let downloadCount = await downloader.downloadCount
        XCTAssertEqual(downloadCount, 0)
    }

    func testODROutOfSpaceFailureNeverActivatesFallback() async throws {
        let payload = Data("ODR out of space".utf8)
        let asset = makeTestDescriptor(payload: payload)
        let cacheDirectory = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }

        let downloader = FakeCDNAudioDownloader(payload: payload)
        let fallback = CDNAudioAssetProvider(
            configuration: makeCDNConfiguration(cacheDirectory: cacheDirectory),
            downloader: downloader
        )
        let primary = FakeAudioAssetProvider()
        let provider = FailoverAudioAssetProvider(
            primary: primary,
            fallback: fallback,
            stallTimeout: 60
        )

        let handle = await provider.request(asset, intent: .playback)
        await waitForRequest(assetID: asset.id, provider: primary)
        await primary.fail(
            assetID: asset.id,
            error: NSError(
                domain: NSCocoaErrorDomain,
                code: NSBundleOnDemandResourceOutOfSpaceError
            )
        )

        do {
            for try await _ in handle.events {}
            XCTFail("ODR out-of-space must remain a terminal local error")
        } catch {
            // Expected: Cloudflare cannot solve unavailable local storage.
        }
        let downloadCount = await downloader.downloadCount
        XCTAssertEqual(downloadCount, 0)
    }

    func testCorruptFallbackIsRejectedAndNeverInstalled() async throws {
        let expectedPayload = Data("VALID".utf8)
        let corruptPayload = Data("WRONG".utf8)
        let asset = makeTestDescriptor(payload: expectedPayload)
        let cacheDirectory = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }

        let downloader = FakeCDNAudioDownloader(payload: corruptPayload)
        let configuration = makeCDNConfiguration(cacheDirectory: cacheDirectory)
        let fallback = CDNAudioAssetProvider(
            configuration: configuration,
            downloader: downloader
        )
        let primary = FakeAudioAssetProvider()
        let provider = FailoverAudioAssetProvider(
            primary: primary,
            fallback: fallback,
            stallTimeout: 60
        )

        let handle = await provider.request(asset, intent: .playback)
        await waitForRequest(assetID: asset.id, provider: primary)
        await primary.fail(assetID: asset.id, error: URLError(.cannotFindHost))

        var rejected = false
        do {
            for try await _ in handle.events {}
            XCTFail("Corrupt fallback data must not become playable")
        } catch AudioAssetError.invalidDownloadedFile(let id) {
            rejected = id == asset.id
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertTrue(rejected)
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: CDNAudioCache.destinationURL(
                    for: asset,
                    configuration: configuration
                ).path
            )
        )
    }

    func testVerifiedCachedFallbackSkipsAppleAndNetwork() async throws {
        let payload = Data("cached fallback".utf8)
        let asset = makeTestDescriptor(payload: payload)
        let cacheDirectory = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }
        let configuration = makeCDNConfiguration(cacheDirectory: cacheDirectory)
        let destination = CDNAudioCache.destinationURL(
            for: asset,
            configuration: configuration
        )
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try payload.write(to: destination)

        let downloader = FakeCDNAudioDownloader(payload: payload)
        let fallback = CDNAudioAssetProvider(
            configuration: configuration,
            downloader: downloader
        )
        let primary = FakeAudioAssetProvider()
        let provider = FailoverAudioAssetProvider(
            primary: primary,
            fallback: fallback,
            stallTimeout: 0.05
        )

        let handle = await provider.request(asset, intent: .playback)
        let lease = try await readyLease(from: handle)
        XCTAssertEqual(lease.localURL, destination)
        let primaryRequestCount = await primary.requestCount(for: asset.id)
        let downloadCount = await downloader.downloadCount
        XCTAssertEqual(primaryRequestCount, 0)
        XCTAssertEqual(downloadCount, 0)
        await provider.release(lease)
    }

    func testPrimaryProgressKeepsResettingPlaybackWatchdog() async throws {
        let payload = Data("primary progress".utf8)
        let asset = makeTestDescriptor(payload: payload)
        let cacheDirectory = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }

        let downloader = FakeCDNAudioDownloader(payload: payload)
        let fallback = CDNAudioAssetProvider(
            configuration: makeCDNConfiguration(cacheDirectory: cacheDirectory),
            downloader: downloader
        )
        let primary = FakeAudioAssetProvider()
        let provider = FailoverAudioAssetProvider(
            primary: primary,
            fallback: fallback,
            stallTimeout: 0.12
        )

        let handle = await provider.request(asset, intent: .playback)
        await waitForRequest(assetID: asset.id, provider: primary)
        for fraction in [0.1, 0.2, 0.3, 0.4] {
            try await Task.sleep(nanoseconds: 40_000_000)
            await primary.publishProgress(assetID: asset.id, fraction: fraction)
        }
        let primaryURL = cacheDirectory.appendingPathComponent("primary.m4a")
        await primary.complete(assetID: asset.id, url: primaryURL)
        let lease = try await readyLease(from: handle)

        XCTAssertEqual(lease.localURL, primaryURL)
        let cancellationCount = await primary.cancellationCount
        let downloadCount = await downloader.downloadCount
        XCTAssertEqual(cancellationCount, 0)
        XCTAssertEqual(downloadCount, 0)
        await provider.release(lease)
    }

    func testPromotedPrefetchStartsWatchdogAndCanFailOver() async throws {
        let payload = Data("promoted prefetch".utf8)
        let asset = makeTestDescriptor(payload: payload)
        let cacheDirectory = temporaryCacheDirectory()
        defer { try? FileManager.default.removeItem(at: cacheDirectory) }

        let downloader = FakeCDNAudioDownloader(payload: payload)
        let fallback = CDNAudioAssetProvider(
            configuration: makeCDNConfiguration(cacheDirectory: cacheDirectory),
            downloader: downloader
        )
        let primary = FakeAudioAssetProvider()
        let provider = FailoverAudioAssetProvider(
            primary: primary,
            fallback: fallback,
            stallTimeout: 0.05
        )

        let handle = await provider.request(
            asset,
            intent: .prefetch(ownerID: "current-volume")
        )
        await waitForRequest(assetID: asset.id, provider: primary)
        try await Task.sleep(nanoseconds: 80_000_000)
        let prePromotionDownloadCount = await downloader.downloadCount
        let prePromotionCancellationCount = await primary.cancellationCount
        XCTAssertEqual(prePromotionDownloadCount, 0)
        XCTAssertEqual(prePromotionCancellationCount, 0)

        await provider.promote(requestID: handle.requestID)
        let lease = try await readyLease(from: handle)
        let promotionCount = await primary.promotionCount
        let cancellationCount = await primary.cancellationCount
        let downloadCount = await downloader.downloadCount
        XCTAssertEqual(promotionCount, 1)
        XCTAssertEqual(cancellationCount, 1)
        XCTAssertEqual(downloadCount, 1)
        await provider.release(lease)
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

    func testForcedManagedMaintenanceProtectsCurrentAndPendingVolumes() async throws {
        let provider = FakeAudioAssetProvider(
            backendKind: .managedBackgroundAssets
        )
        let coordinator = AudioAssetCoordinator(provider: provider)
        let current = try XCTUnwrap(AudioAssetCatalog.descriptor(for: "ly01"))
        let selected = try XCTUnwrap(AudioAssetCatalog.descriptor(for: "ly02"))

        let currentHandle = await coordinator.requestPlayback(
            current,
            generation: UUID()
        )
        await provider.complete(
            assetID: current.id,
            url: URL(fileURLWithPath: "/tmp/managed-ly01.m4a")
        )
        let currentLease = try await readyLease(from: currentHandle)
        await coordinator.commitPlayback(currentLease)

        let selectedHandle = await coordinator.requestPlayback(
            selected,
            generation: UUID()
        )
        await coordinator.reclaimUnusedManagedPacks()

        let evicted = await provider.evictedAssetIDs
        XCTAssertFalse(evicted.contains(current.id))
        XCTAssertFalse(evicted.contains(selected.id))
        XCTAssertEqual(
            Set(evicted),
            Set(AudioAssetCatalog.orderedIDs).subtracting(
                Set([current.id, selected.id])
            )
        )
        await coordinator.cancelPending()
        do {
            _ = try await readyLease(from: selectedHandle)
            XCTFail("Cancelling the protected pending request must still cancel it")
        } catch {
            // Expected.
        }
    }

    func testManagedOutOfSpaceFailureReclaimsUnusedVolumes() async throws {
        let provider = FakeAudioAssetProvider(
            backendKind: .managedBackgroundAssets
        )
        let coordinator = AudioAssetCoordinator(provider: provider)
        let current = try XCTUnwrap(AudioAssetCatalog.descriptor(for: "ly01"))
        let next = try XCTUnwrap(AudioAssetCatalog.descriptor(for: "ly02"))

        let currentHandle = await coordinator.requestPlayback(
            current,
            generation: UUID()
        )
        await provider.complete(
            assetID: current.id,
            url: URL(fileURLWithPath: "/tmp/managed-current-ly01.m4a")
        )
        let currentLease = try await readyLease(from: currentHandle)
        await coordinator.commitPlayback(currentLease)

        await coordinator.startPrefetch(next, ownerID: UUID().uuidString)
        await waitForRequest(assetID: next.id, provider: provider)
        await provider.fail(
            assetID: next.id,
            error: NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileWriteOutOfSpaceError
            )
        )

        for _ in 0..<200 {
            if await provider.evictedAssetIDs.count
                == AudioAssetCatalog.orderedIDs.count - 1 {
                break
            }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        let evicted = await provider.evictedAssetIDs
        XCTAssertFalse(evicted.contains(current.id))
        XCTAssertEqual(
            Set(evicted),
            Set(AudioAssetCatalog.orderedIDs).subtracting([current.id])
        )
    }

    private func readyLease(
        from handle: AudioAssetRequestHandle
    ) async throws -> AudioAssetLease {
        for try await event in handle.events {
            if case .ready(let lease) = event { return lease }
        }
        throw AudioAssetError.cancelled
    }

    private func makeTestDescriptor(payload: Data) -> AudioAssetDescriptor {
        let hash = SHA256.hash(data: payload).map {
            String(format: "%02x", $0)
        }.joined()
        return AudioAssetDescriptor(
            id: "test-audio",
            fileName: "test-audio",
            fileExtension: "m4a",
            odrTag: "test-audio",
            managedPackID: "org.fuxuan.lengyan.audio.test",
            managedRelativePath: "Audio/test-audio.m4a",
            cdnRelativePath: "audio/v1/\(hash)/test-audio.m4a",
            contentSHA256: hash,
            contentByteCount: Int64(payload.count)
        )
    }

    private func temporaryCacheDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "lengyan-cdn-tests-\(UUID().uuidString)",
            isDirectory: true
        )
    }

    private func makeCDNConfiguration(
        cacheDirectory: URL
    ) -> CDNAudioFallbackConfiguration {
        CDNAudioFallbackConfiguration(
            baseURL: URL(string: "https://audio.example.com")!,
            cacheDirectory: cacheDirectory,
            stallTimeout: 15,
            resourceTimeout: 60
        )
    }

    private func waitForRequest(
        assetID: String,
        provider: FakeAudioAssetProvider
    ) async {
        for _ in 0..<200 {
            if await provider.requestCount(for: assetID) > 0 { return }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTFail("Timed out waiting for primary audio request")
    }
}

private actor FakeAudioAssetProvider: AudioAssetProvider {
    nonisolated let backendKind: AudioAssetBackendKind

    private struct Request {
        let assetID: String
        var intent: AudioAssetIntent
        let continuation: AsyncThrowingStream<AudioAssetEvent, Error>.Continuation
    }

    private var requests: [UUID: Request] = [:]
    private var requestCounts: [String: Int] = [:]
    private(set) var promotionCount = 0
    private(set) var cancellationCount = 0
    private(set) var evictedAssetIDs: [String] = []
    private var releasedLeaseIDs: Set<UUID> = []
    private var promotionCompletion: (assetID: String, url: URL)?

    init(backendKind: AudioAssetBackendKind = .legacyODR) {
        self.backendKind = backendKind
    }

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
        cancellationCount += 1
        request.continuation.finish(throwing: AudioAssetError.cancelled)
    }

    func release(_ lease: AudioAssetLease) async {
        releasedLeaseIDs.insert(lease.id)
    }

    func evict(assetID: String) async throws -> AudioAssetEvictionResult {
        evictedAssetIDs.append(assetID)
        return .releasedToSystem
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

    func fail(assetID: String, error: Error) {
        let matching = requests.filter { $0.value.assetID == assetID }
        for (requestID, request) in matching {
            requests.removeValue(forKey: requestID)
            request.continuation.finish(throwing: error)
        }
    }

    func publishProgress(assetID: String, fraction: Double) {
        let matching = requests.values.filter { $0.assetID == assetID }
        for request in matching {
            request.continuation.yield(.progress(fraction))
        }
    }
}

private actor FakeCDNAudioDownloader: CDNAudioDownloading {
    private let payload: Data
    private(set) var downloadCount = 0

    init(payload: Data) {
        self.payload = payload
    }

    func download(
        from remoteURL: URL,
        to stagingURL: URL,
        expectedByteCount: Int64,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        downloadCount += 1
        progress(0.5)
        try payload.write(to: stagingURL, options: .atomic)
        progress(1)
    }
}
