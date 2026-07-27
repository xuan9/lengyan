package org.fuxuan.classics.media

import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata

class Media3AudioCatalog private constructor(
    assets: List<ResolvedAndroidAudioAsset>,
    private val preferredLocale: String,
    private val defaultLocale: String,
) {
    private val assetsByID = assets.associateBy(ResolvedAndroidAudioAsset::artifactID)

    init {
        require(assets.isNotEmpty()) { "Media3 audio catalog must not be empty" }
        require(assetsByID.size == assets.size) { "Media3 audio artifact IDs must be unique" }
        require(preferredLocale.isNotBlank()) { "preferred audio locale must not be blank" }
        require(defaultLocale.isNotBlank()) { "default audio locale must not be blank" }
        require(assets.all { asset ->
            asset.titles.isNotEmpty() && asset.titles.values.none(String::isBlank)
        }) {
            "Media3 audio assets require localized titles"
        }
        require(assets.all { asset ->
            asset.uri.scheme.equals("https", ignoreCase = true) &&
                !asset.uri.host.isNullOrBlank() &&
                asset.uri.userInfo == null &&
                asset.uri.query == null &&
                asset.uri.fragment == null
        }) { "Media3 audio assets must use credential-free HTTPS URIs" }
    }

    internal fun resolveRequests(requests: List<MediaItem>): List<MediaItem> {
        if (requests.isEmpty()) return emptyList()

        val resolved = ArrayList<MediaItem>(requests.size)
        for (request in requests) {
            val asset = assetsByID[request.mediaId] ?: return emptyList()
            resolved += asset.asMediaItem()
        }
        return resolved
    }

    private fun ResolvedAndroidAudioAsset.asMediaItem(): MediaItem {
        val title = titles[preferredLocale]
            ?: titles[defaultLocale]
            ?: titles.toSortedMap().values.first()
        return MediaItem.Builder()
            .setMediaId(artifactID)
            .setUri(uri.toString())
            .setMimeType(rendition.mediaType)
            .setMediaMetadata(
                MediaMetadata.Builder()
                    .setTitle(title)
                    .build(),
            )
            .build()
    }

    companion object {
        fun from(
            resolution: AndroidAudioDeliveryResolution.Available,
            preferredLocale: String,
            defaultLocale: String,
        ): Media3AudioCatalog = Media3AudioCatalog(
            assets = resolution.assets,
            preferredLocale = preferredLocale,
            defaultLocale = defaultLocale,
        )
    }
}
