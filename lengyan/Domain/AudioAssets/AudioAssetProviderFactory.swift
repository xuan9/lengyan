//
//  AudioAssetProviderFactory.swift
//  lengyan
//
//  This is the only production version/router boundary. Callers never branch
//  on OS version or import BackgroundAssets.
//

import Foundation

struct AudioAssetProviderPolicy: Sendable {
    let managedEnabled: Bool
    let managedCatalogReady: Bool

    static var production: AudioAssetProviderPolicy {
        let enabled = Bundle.main.object(
            forInfoDictionaryKey: "LengyanManagedAudioEnabled"
        ) as? Bool == true
        return AudioAssetProviderPolicy(
            managedEnabled: enabled,
            managedCatalogReady: AudioAssetCatalog.managedPacksReady
        )
    }
}

enum AudioAssetProviderFactory {
    private static let legacyODRDemotionKey =
        "audioAssets.didDemoteLegacyODRTagsForManagedV1"

    static func backendDecision(
        systemMajorVersion: Int,
        policy: AudioAssetProviderPolicy
    ) -> AudioAssetBackendKind {
        if systemMajorVersion >= 26,
           policy.managedEnabled,
           policy.managedCatalogReady {
            return .managedBackgroundAssets
        }
        return .legacyODR
    }

    static func makeProvider(
        policy: AudioAssetProviderPolicy = .production
    ) -> any AudioAssetProvider {
        let systemMajorVersion = ProcessInfo.processInfo.operatingSystemVersion.majorVersion
        let backend = backendDecision(
            systemMajorVersion: systemMajorVersion,
            policy: policy
        )

        let primary: any AudioAssetProvider
        if #available(iOS 26.0, *), backend == .managedBackgroundAssets {
            demoteLegacyODRTagsIfNeeded()
            primary = ManagedBackgroundAssetsAudioAssetProvider()
        } else {
            primary = LegacyODRAudioAssetProvider()
        }

        guard let fallbackConfiguration = CDNAudioFallbackConfiguration.production else {
            return primary
        }
        let fallback = CDNAudioAssetProvider(configuration: fallbackConfiguration)
        return FailoverAudioAssetProvider(
            primary: primary,
            fallback: fallback,
            stallTimeout: fallbackConfiguration.stallTimeout
        )
    }

    static func shouldDemoteLegacyODRTags(
        systemMajorVersion: Int,
        backend: AudioAssetBackendKind,
        alreadyCompleted: Bool
    ) -> Bool {
        systemMajorVersion >= 26
            && backend == .managedBackgroundAssets
            && !alreadyCompleted
    }

    private static func demoteLegacyODRTagsIfNeeded(
        bundle: Bundle = .main,
        defaults: UserDefaults = .standard
    ) {
        guard shouldDemoteLegacyODRTags(
            systemMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
            backend: .managedBackgroundAssets,
            alreadyCompleted: defaults.bool(forKey: legacyODRDemotionKey)
        ) else { return }

        // ODR has no force-delete API. Priority zero makes every legacy audio
        // tag an early purge candidate once no NSBundleResourceRequest retains
        // it. Managed packs remain independently owned by AssetPackManager.
        bundle.setPreservationPriority(
            0,
            forTags: Set(AudioAssetCatalog.descriptors.map(\.odrTag))
        )
        defaults.set(true, forKey: legacyODRDemotionKey)
    }
}
