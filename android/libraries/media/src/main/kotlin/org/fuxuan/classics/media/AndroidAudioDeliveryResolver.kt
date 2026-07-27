package org.fuxuan.classics.media

import org.fuxuan.classics.core.content.AudioByteRangeSupport
import org.fuxuan.classics.core.content.AudioCatalog
import org.fuxuan.classics.core.content.AudioDelivery
import org.fuxuan.classics.core.content.AudioDeliveryPlatform
import org.fuxuan.classics.core.content.AudioProviderRole
import org.fuxuan.classics.core.content.AudioRendition
import org.fuxuan.classics.core.content.HttpsAudioActivation
import org.fuxuan.classics.core.content.HttpsAudioProvider
import org.fuxuan.classics.core.content.ProductPlatformState
import java.net.URI

data class ResolvedAndroidAudioAsset(
    val artifactID: String,
    val volumeID: String?,
    val titles: Map<String, String>,
    val rendition: AudioRendition,
    val uri: URI,
)

sealed interface AndroidAudioDeliveryResolution {
    data class Available(
        val provider: HttpsAudioProvider,
        val assets: List<ResolvedAndroidAudioAsset>,
    ) : AndroidAudioDeliveryResolution

    data class Unavailable(
        val reasons: List<AndroidAudioUnavailableReason>,
    ) : AndroidAudioDeliveryResolution {
        init {
            require(reasons.isNotEmpty()) { "unavailable audio delivery requires a reason" }
        }
    }
}

sealed interface AndroidAudioUnavailableReason {
    data class DeliveryInactive(
        val state: ProductPlatformState,
        val releaseBlockers: List<String>,
    ) : AndroidAudioUnavailableReason

    data object RightsNotEligible : AndroidAudioUnavailableReason

    data class CatalogNotReleaseReady(
        val contractState: String,
    ) : AndroidAudioUnavailableReason

    data object SelectedRenditionMissing : AndroidAudioUnavailableReason

    data class RenditionMissingFromArtifacts(
        val artifactIDs: List<String>,
    ) : AndroidAudioUnavailableReason

    data object CompatiblePrimaryProviderMissing : AndroidAudioUnavailableReason
    data object MultipleCompatiblePrimaryProviders : AndroidAudioUnavailableReason

    data class ByteRangeNotSupported(
        val support: AudioByteRangeSupport,
    ) : AndroidAudioUnavailableReason

    data class BaseURLMissing(
        val configurationKey: String,
    ) : AndroidAudioUnavailableReason

    data class BaseURLInvalid(
        val configurationKey: String,
    ) : AndroidAudioUnavailableReason
}

object AndroidAudioDeliveryResolver {
    fun resolve(
        delivery: AudioDelivery,
        catalog: AudioCatalog,
        osMajor: Int,
        configuration: Map<String, String>,
    ): AndroidAudioDeliveryResolution {
        require(delivery.platform == AudioDeliveryPlatform.ANDROID) {
            "Android audio resolver requires Android delivery"
        }
        require(delivery.productID == catalog.productID) {
            "audio delivery and catalog product IDs disagree"
        }
        require(osMajor > 0) { "Android OS major must be positive" }

        if (!delivery.state.isActive) {
            return AndroidAudioDeliveryResolution.Unavailable(
                listOf(
                    AndroidAudioUnavailableReason.DeliveryInactive(
                        state = delivery.state,
                        releaseBlockers = delivery.releaseBlockers,
                    ),
                ),
            )
        }

        val reasons = mutableListOf<AndroidAudioUnavailableReason>()
        if (catalog.rights.reuseEligibility != "eligible") {
            reasons += AndroidAudioUnavailableReason.RightsNotEligible
        }
        if (catalog.contractState != "release-ready") {
            reasons += AndroidAudioUnavailableReason.CatalogNotReleaseReady(
                catalog.contractState,
            )
        }

        val renditionID = delivery.selectedRenditionID
        if (renditionID == null) {
            reasons += AndroidAudioUnavailableReason.SelectedRenditionMissing
        }
        val selectedRenditions = renditionID?.let { selectedID ->
            catalog.artifacts.mapNotNull { artifact ->
                artifact.renditions.firstOrNull { it.renditionID == selectedID }
                    ?.let { artifact to it }
            }
        }.orEmpty()
        if (renditionID != null && selectedRenditions.size != catalog.artifacts.size) {
            val resolvedArtifactIDs = selectedRenditions.mapTo(mutableSetOf()) { it.first.artifactID }
            reasons += AndroidAudioUnavailableReason.RenditionMissingFromArtifacts(
                catalog.artifacts
                    .map { it.artifactID }
                    .filterNot(resolvedArtifactIDs::contains),
            )
        }

        val compatibleProviders = delivery.providers.filterIsInstance<HttpsAudioProvider>()
            .filter { provider ->
                provider.role == AudioProviderRole.PRIMARY &&
                    provider.activation == HttpsAudioActivation.ALWAYS &&
                    provider.minimumOSMajor <= osMajor
            }
        val provider = compatibleProviders.singleOrNull()
        when {
            compatibleProviders.isEmpty() -> {
                reasons += AndroidAudioUnavailableReason.CompatiblePrimaryProviderMissing
            }

            compatibleProviders.size > 1 -> {
                reasons += AndroidAudioUnavailableReason.MultipleCompatiblePrimaryProviders
            }
        }

        if (provider != null && provider.byteRangeSupport != AudioByteRangeSupport.SUPPORTED) {
            reasons += AndroidAudioUnavailableReason.ByteRangeNotSupported(
                provider.byteRangeSupport,
            )
        }

        val baseURI = provider?.let { selectedProvider ->
            val configuredURL = configuration[selectedProvider.baseURLConfigurationKey]
            when {
                configuredURL == null -> {
                    reasons += AndroidAudioUnavailableReason.BaseURLMissing(
                        selectedProvider.baseURLConfigurationKey,
                    )
                    null
                }

                else -> parseHTTPSBaseURI(configuredURL) ?: run {
                    reasons += AndroidAudioUnavailableReason.BaseURLInvalid(
                        selectedProvider.baseURLConfigurationKey,
                    )
                    null
                }
            }
        }

        if (reasons.isNotEmpty()) {
            return AndroidAudioDeliveryResolution.Unavailable(reasons)
        }

        checkNotNull(provider)
        checkNotNull(baseURI)
        return AndroidAudioDeliveryResolution.Available(
            provider = provider,
            assets = selectedRenditions.map { (artifact, rendition) ->
                ResolvedAndroidAudioAsset(
                    artifactID = artifact.artifactID,
                    volumeID = artifact.contentMapping.volumeID,
                    titles = artifact.titles,
                    rendition = rendition,
                    uri = baseURI.resolve(rendition.artifactKey),
                )
            },
        )
    }

    private fun parseHTTPSBaseURI(value: String): URI? = runCatching {
        val source = value.trim()
        require(source.isNotEmpty())
        val withTrailingSlash = if (source.endsWith('/')) source else "$source/"
        val uri = URI(withTrailingSlash)
        require(uri.isAbsolute)
        require(uri.scheme.equals("https", ignoreCase = true))
        require(!uri.host.isNullOrBlank())
        require(uri.userInfo == null)
        require(uri.query == null)
        require(uri.fragment == null)
        require(uri.normalize() == uri)
        require(uri.path.split('/').none { it == "." || it == ".." })
        uri
    }.getOrNull()
}
