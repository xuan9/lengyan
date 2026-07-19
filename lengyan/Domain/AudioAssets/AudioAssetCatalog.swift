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

    private static let cdnMetadata: [String: (sha256: String, bytes: Int64)] = [
        "ly01": ("981ed4e96be6bf23694d3ad4dda4958fc987295fa895d229df1138f87674ae5a", 11_408_933),
        "ly02": ("86e26f96f26f51c7d94bb9763ae8da5cdc2d7c29f4e3f963ffbc19629725f472", 14_772_155),
        "ly03": ("b2170f364da0d44dd7b1242c73b784eb0f8243e19946591cbdeee90a7b670d55", 15_582_450),
        "ly04": ("34dbd536f603b32ac4fc0316201cd65fe8fbbee504196470fce2b4ac4fa7c840", 16_602_673),
        "ly05": ("f8669fe34c8bd95093679c7d25e16dfdb72cc8d15601987dbaf49bb3dde6151c", 13_012_100),
        "ly06": ("53ce455f3a20cc09e49f05ae2632fafd8c1c686529d5bf9ecdd32f3465a39828", 14_330_690),
        "ly07": ("c4b879afc23d06fbcf4af2ed81d5b9680797fa0860a0f9804531da95668813a7", 16_483_037),
        "ly08": ("7a31de382ed9bfc523ec4a49792055249d378a32c8d5cde8b8b3bea928b01e96", 15_602_303),
        "ly09": ("a0f8ad5c1cdde15243d150e510368f43d327fe42f5ef1e362e704971cedde801", 21_116_150),
        "ly10": ("e531560f540e74fd3088201de8e164007dfb71434ec55f43d751c92b11feff2c", 16_590_672),
        "lyz1": ("33734314186b1229a08b85169c6b481ed9401cf94ae636f4b36340f11d1db2e0", 5_919_555)
    ]

    static let descriptors: [AudioAssetDescriptor] = orderedIDs.map { id in
        let metadata = cdnMetadata[id]!
        return AudioAssetDescriptor(
            id: id,
            fileName: id,
            fileExtension: "m4a",
            odrTag: id,
            managedPackID: "org.fuxuan.lengyan.audio.\(id)",
            managedRelativePath: "Audio/\(id).m4a",
            cdnRelativePath: "audio/v1/\(metadata.sha256)/\(id).m4a",
            contentSHA256: metadata.sha256,
            contentByteCount: metadata.bytes
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
              Set(descriptors.map(\.managedRelativePath)).count == 11,
              Set(descriptors.map(\.cdnRelativePath)).count == 11,
              Set(descriptors.map(\.contentSHA256)).count == 11,
              descriptors.allSatisfy({ $0.contentByteCount > 0 }) else {
            return "Audio asset catalog identifiers must be one-to-one"
        }
        guard descriptors.map(\.id) == orderedIDs else {
            return "Audio asset catalog order is invalid"
        }
        return nil
    }
}
