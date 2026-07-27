package org.fuxuan.classics.media

import android.net.Uri
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.offline.DownloadRequest
import java.net.URI

@OptIn(UnstableApi::class)
class Media3AudioDownloadSpec private constructor(
    val key: AudioCacheKey,
    val renditionID: String,
    val uri: URI,
    val mediaType: String,
    val expectedBytes: Long,
    val expectedSha256: String,
) {
    val requestID: String = buildRequestID(key, renditionID)

    fun toDownloadRequest(
        transferPurpose: AudioTransferPurpose? = null,
    ): DownloadRequest = DownloadRequest.Builder(
        requestID,
        Uri.parse(uri.toString()),
    )
        .setMimeType(mediaType)
        .setCustomCacheKey(requestID)
        .apply {
            transferPurpose?.let { purpose ->
                setData(AudioTransferRequestMetadata.encode(purpose))
            }
        }
        .build()

    companion object {
        fun from(
            productID: String,
            asset: ResolvedAndroidAudioAsset,
        ): Media3AudioDownloadSpec {
            val key = AudioCacheKey(productID, asset.artifactID)
            require(CACHE_KEY_SEPARATOR !in key.productID) {
                "audio productID contains the Media3 cache-key separator"
            }
            require(CACHE_KEY_SEPARATOR !in key.artifactID) {
                "audio artifactID contains the Media3 cache-key separator"
            }
            require(CACHE_KEY_SEPARATOR !in asset.rendition.renditionID) {
                "audio renditionID contains the Media3 cache-key separator"
            }
            require(
                asset.uri.scheme.equals("https", ignoreCase = true) &&
                    !asset.uri.host.isNullOrBlank() &&
                    asset.uri.userInfo == null &&
                    asset.uri.query == null &&
                    asset.uri.fragment == null,
            ) { "downloadable audio assets must use credential-free HTTPS URIs" }

            return Media3AudioDownloadSpec(
                key = key,
                renditionID = asset.rendition.renditionID,
                uri = asset.uri,
                mediaType = asset.rendition.mediaType,
                expectedBytes = asset.rendition.bytes,
                expectedSha256 = asset.rendition.sha256,
            )
        }

        private const val CACHE_KEY_SEPARATOR = ':'

        private fun buildRequestID(
            key: AudioCacheKey,
            renditionID: String,
        ): String = buildString {
            append(key.productID)
            append(CACHE_KEY_SEPARATOR)
            append(key.artifactID)
            append(CACHE_KEY_SEPARATOR)
            append(renditionID)
        }
    }
}
