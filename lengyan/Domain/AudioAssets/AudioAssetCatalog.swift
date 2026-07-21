//
//  AudioAssetCatalog.swift
//  lengyan
//

import Foundation

enum AudioAssetCatalog {
    static let orderedIDs = GeneratedAudioManifest.tracks.map(\.id)

    static let descriptors: [AudioAssetDescriptor] = GeneratedAudioManifest.tracks.map { track in
        let fileWithExtension = "\(track.id).\(GeneratedAudioManifest.fileExtension)"
        let managedPackID = "\(GeneratedAudioManifest.appleAssetPackIDPrefix)\(track.id)"
        let managedRelativePath = "\(GeneratedAudioManifest.appleRelativeDirectory)/\(fileWithExtension)"
        let cdnRelativePath = [
            GeneratedAudioManifest.cdnPathPrefix,
            GeneratedAudioManifest.catalogVersion,
            track.sha256,
            fileWithExtension
        ].joined(separator: "/")

        return AudioAssetDescriptor(
            id: track.id,
            fileName: track.id,
            fileExtension: GeneratedAudioManifest.fileExtension,
            odrTag: track.id,
            managedPackID: managedPackID,
            managedRelativePath: managedRelativePath,
            cdnRelativePath: cdnRelativePath,
            contentSHA256: track.sha256,
            contentByteCount: track.bytes
        )
    }

    private static let byID = Dictionary(
        uniqueKeysWithValues: descriptors.map { ($0.id, $0) }
    )

    static var managedPacksReady: Bool {
        Bundle.main.object(
            forInfoDictionaryKey: "LengyanManagedAudioCatalogReady"
        ) as? Bool == true
    }

    static func descriptor(for id: String) -> AudioAssetDescriptor? {
        byID[id]
    }

    static func next(after id: String) -> AudioAssetDescriptor? {
        guard let index = orderedIDs.firstIndex(of: id) else { return nil }
        return descriptor(for: orderedIDs[(index + 1) % orderedIDs.count])
    }

    static var validationError: String? {
        let expectedCount = GeneratedAudioManifest.tracks.count
        guard expectedCount > 0,
              descriptors.count == expectedCount,
              Set(descriptors.map(\.id)).count == expectedCount,
              Set(descriptors.map(\.odrTag)).count == expectedCount,
              Set(descriptors.map(\.managedPackID)).count == expectedCount,
              Set(descriptors.map(\.managedRelativePath)).count == expectedCount,
              Set(descriptors.map(\.cdnRelativePath)).count == expectedCount,
              Set(descriptors.map(\.contentSHA256)).count == expectedCount,
              descriptors.allSatisfy({ $0.contentByteCount > 0 }) else {
            return "Audio asset catalog identifiers must be one-to-one"
        }
        guard descriptors.map(\.id) == orderedIDs else {
            return "Audio asset catalog order is invalid"
        }
        return nil
    }
}
