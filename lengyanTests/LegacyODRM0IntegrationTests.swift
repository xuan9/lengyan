//
//  LegacyODRM0IntegrationTests.swift
//  lengyanTests
//
//  M0 evidence for the pre-iOS-26 ODR path. The Debug test host embeds the
//  development ODR packs, so this exercises real NSBundleResourceRequest
//  access without depending on App Store hosting.
//

import AVFoundation
import XCTest
@testable import lengyan

final class LegacyODRM0IntegrationTests: XCTestCase {
    override func tearDown() {
        let manager = AudioManager.shared
        manager.stopAndReleaseAudio()
        super.tearDown()
    }

    func testCurrentPlaybackStartsAndNextTrackIsPrefetched() async throws {
        if #available(iOS 26.0, *) {
            throw XCTSkip("This M0 integration test is specifically for the legacy ODR route")
        }

        if !Book.shared.loaded {
            let result = Book.shared.loadDataSyncWithCompletionHandler { _ in }
            guard case .success = result else {
                XCTFail("The bundled media catalog must load before exercising ODR")
                return
            }
        }

        let manager = await MainActor.run { AudioManager.shared }
        await MainActor.run {
            manager.loadMediaData()
            manager.selectMode(.repeatAll)
        }

        guard let group = await MainActor.run(body: { manager.mediaGroups.first }),
              group.files.count >= 2,
              group.names.count >= 2 else {
            XCTFail("The first media group must contain at least two tracks")
            return
        }

        let currentFile = group.files[0]
        let nextFile = group.files[1]
        XCTAssertEqual(currentFile, "ly01", "M0 must exercise the first production ODR volume")
        XCTAssertEqual(nextFile, "ly02", "M0 must prefetch the immediately following ODR volume")
        await MainActor.run {
            manager.downloadStatus[currentFile] = .notDownloaded
            manager.downloadStatus[nextFile] = .notDownloaded
            manager.downloadProgress.removeValue(forKey: currentFile)
            manager.downloadProgress.removeValue(forKey: nextFile)
            manager.handleMediaItemTap(
                name: group.names[0],
                file: currentFile,
                fileExtension: group.fileExtension
            )
        }

        let currentStarted = await waitUntil(timeout: 20) {
            await MainActor.run {
                manager.downloadStatus[currentFile] == .downloaded &&
                    manager.audioObserver.lastPlayFile?.1 == currentFile &&
                    manager.audioObserver.queuePlayer?.currentItem != nil
            }
        }
        XCTAssertTrue(
            currentStarted,
            "The current ODR track should become available and enter the player"
        )

        let nextPrefetched = await waitUntil(timeout: 20) {
            let snapshot = await manager.audioAssetSnapshot()
            return snapshot.backend == .legacyODR &&
                snapshot.playingAssetID == currentFile &&
                snapshot.prefetchedAssetID == nextFile &&
                snapshot.prefetchedLocalURL != nil &&
                snapshot.activeLeaseCount == 2
        }
        XCTAssertTrue(
            nextPrefetched,
            "repeatAll playback should silently retain a ready lease for the next ODR track"
        )

        let currentURL = await MainActor.run {
            (manager.audioObserver.queuePlayer?.currentItem?.asset as? AVURLAsset)?.url
        }
        let nextURL = (await manager.audioAssetSnapshot()).prefetchedLocalURL
        XCTAssertNotNil(currentURL, "The current ODR request should expose its audio URL")
        XCTAssertNotNil(nextURL, "The prefetched next ODR request should expose its audio URL")
        if let currentURL {
            XCTAssertTrue(
                FileManager.default.isReadableFile(atPath: currentURL.path),
                "The current ODR audio file should be readable"
            )
        }
        if let nextURL {
            XCTAssertTrue(
                FileManager.default.isReadableFile(atPath: nextURL.path),
                "The prefetched next ODR audio file should be readable"
            )
        }
    }

    private func waitUntil(
        timeout: TimeInterval,
        pollInterval: TimeInterval = 0.05,
        condition: () async -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if await condition() { return true }
            try? await Task.sleep(
                nanoseconds: UInt64(pollInterval * 1_000_000_000)
            )
        } while Date() < deadline
        return await condition()
    }
}
