//
//  AudioAssetCatalog.swift
//  lengyan
//

import Foundation

enum AudioAssetCatalog {
    static let orderedIDs = [
        "ly01", "ly02", "ly03", "ly04", "ly05", "ly06",
        "ly07", "ly08", "ly09", "ly10", "lyz1"
    ]

    static let descriptors: [AudioAssetDescriptor] = orderedIDs.map { id in
        AudioAssetDescriptor(
            id: id,
            fileName: id,
            fileExtension: "m4a",
            odrTag: id,
            managedPackID: "org.fuxuan.lengyan.audio.\(id)",
            managedRelativePath: "Audio/\(id).m4a"
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
        guard descriptors.count == 11,
              Set(descriptors.map(\.id)).count == 11,
              Set(descriptors.map(\.odrTag)).count == 11,
              Set(descriptors.map(\.managedPackID)).count == 11,
              Set(descriptors.map(\.managedRelativePath)).count == 11 else {
            return "Audio asset catalog identifiers must be one-to-one"
        }
        guard descriptors.map(\.id) == orderedIDs else {
            return "Audio asset catalog order is invalid"
        }
        return nil
    }
}
