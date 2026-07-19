//
//  AudioAssetModels.swift
//  lengyan
//
//  Backend-neutral audio delivery contracts. A lease, rather than a bare URL,
//  keeps legacy ODR resources valid for as long as AVPlayer needs them.
//

import Foundation

struct AudioAssetDescriptor: Hashable, Sendable {
    let id: String
    let fileName: String
    let fileExtension: String
    let odrTag: String
    let managedPackID: String
    let managedRelativePath: String
}

enum AudioAssetIntent: Equatable, Sendable {
    case playback
    case prefetch(ownerID: String)
}

enum AudioAssetEvent: Sendable {
    case queued
    case progress(Double)
    case ready(AudioAssetLease)
}

struct AudioAssetRequestHandle: Sendable {
    let requestID: UUID
    let assetID: String
    let events: AsyncThrowingStream<AudioAssetEvent, Error>
}

final class AudioAssetLease: @unchecked Sendable {
    let id: UUID
    let assetID: String
    let localURL: URL

    init(id: UUID = UUID(), assetID: String, localURL: URL) {
        self.id = id
        self.assetID = assetID
        self.localURL = localURL
    }
}

enum AudioAssetBackendKind: String, Sendable {
    case legacyODR
    case managedBackgroundAssets
}

enum AudioAssetEvictionResult: Sendable {
    case removed
    case releasedToSystem
}

enum AudioAssetError: LocalizedError, Sendable {
    case unknownAsset(String)
    case missingLocalFile(String)
    case cancelled
    case packIsInUse(String)

    var errorDescription: String? {
        switch self {
        case .unknownAsset(let id):
            return "Unknown audio asset: \(id)"
        case .missingLocalFile(let path):
            return "Audio asset is not readable at \(path)"
        case .cancelled:
            return "Audio asset request was cancelled"
        case .packIsInUse(let id):
            return "Audio asset is currently in use: \(id)"
        }
    }
}

struct AudioAssetCoordinatorSnapshot: Sendable {
    let backend: AudioAssetBackendKind
    let requestedAssetID: String?
    let pendingAssetID: String?
    let playingAssetID: String?
    let prefetchedAssetID: String?
    let prefetchedLocalURL: URL?
    let activeLeaseCount: Int
}
