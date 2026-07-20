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
    let cdnRelativePath: String
    let contentSHA256: String
    let contentByteCount: Int64
}

enum AudioAssetIntent: Equatable, Sendable {
    case playback
    case prefetch(ownerID: String)
}

enum AudioAssetEvent: Sendable {
    case queued
    case fallbackActivated
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
    case cloudflareCDN
}

enum AudioAssetEvictionResult: Sendable {
    case removed
    case releasedToSystem
}

enum AudioAssetError: LocalizedError, Sendable {
    case unknownAsset(String)
    case missingLocalFile(String)
    case invalidDownloadedFile(String)
    case invalidRemoteResponse(Int)
    case insecureRemoteResponse
    case cancelled
    case packIsInUse(String)

    var errorDescription: String? {
        switch self {
        case .unknownAsset(let id):
            return "Unknown audio asset: \(id)"
        case .missingLocalFile(let path):
            return "Audio asset is not readable at \(path)"
        case .invalidDownloadedFile(let id):
            return "Downloaded audio asset failed integrity validation: \(id)"
        case .invalidRemoteResponse(let statusCode):
            return "Audio fallback server returned HTTP \(statusCode)"
        case .insecureRemoteResponse:
            return "Audio fallback server redirected to an insecure URL"
        case .cancelled:
            return "Audio asset request was cancelled"
        case .packIsInUse(let id):
            return "Audio asset is currently in use: \(id)"
        }
    }
}

enum AudioAssetFailurePolicy {
    static func isLocalOutOfSpace(_ error: Error, depth: Int = 0) -> Bool {
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
