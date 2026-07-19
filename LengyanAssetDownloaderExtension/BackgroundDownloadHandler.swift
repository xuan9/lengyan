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
        ["ly01", "ly02", "ly03", "ly04", "ly05", "ly06",
         "ly07", "ly08", "ly09", "ly10", "lyz1"].map {
            "org.fuxuan.lengyan.audio.\($0)"
        }
    )

    func shouldDownload(_ assetPack: AssetPack) -> Bool {
        assetPack.id == Self.m0AssetPackID
            || Self.productionAssetPackIDs.contains(assetPack.id)
    }
}
