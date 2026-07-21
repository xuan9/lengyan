//
//  BackgroundDownloadHandler.swift
//  LengyanAssetDownloaderExtension
//
//  Apple-hosted Managed Background Assets download policy.
//

import BackgroundAssets
import ExtensionFoundation
import StoreKit

@main
struct DownloaderExtension: StoreDownloaderExtension {
    private static let m0AssetPackID = "org.fuxuan.lengyan.m0.smoke"
    private static let productionAssetPackIDs = Set(
        GeneratedAudioManifest.tracks.map {
            "\(GeneratedAudioManifest.appleAssetPackIDPrefix)\($0.id)"
        }
    )

    func shouldDownload(_ assetPack: AssetPack) -> Bool {
        assetPack.id == Self.m0AssetPackID
            || Self.productionAssetPackIDs.contains(assetPack.id)
    }
}
