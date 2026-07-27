package org.fuxuan.classics.media

import org.fuxuan.classics.core.content.AudioArtifact
import org.fuxuan.classics.core.content.AudioByteRangeSupport
import org.fuxuan.classics.core.content.AudioCatalog
import org.fuxuan.classics.core.content.AudioContentMapping
import org.fuxuan.classics.core.content.AudioDelivery
import org.fuxuan.classics.core.content.AudioDeliveryPlatform
import org.fuxuan.classics.core.content.AudioProviderRole
import org.fuxuan.classics.core.content.AudioRendition
import org.fuxuan.classics.core.content.AudioRights
import org.fuxuan.classics.core.content.HttpsAudioActivation
import org.fuxuan.classics.core.content.HttpsAudioProvider
import org.fuxuan.classics.core.content.ProductPlatformState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.net.URI

class AndroidAudioDeliveryResolverTest {
    @Test
    fun resolvesEverySelectedRenditionAgainstTheConfiguredHTTPSBaseURL() {
        val resolution = AndroidAudioDeliveryResolver.resolve(
            delivery = activeDelivery(),
            catalog = catalog(),
            osMajor = 36,
            configuration = mapOf(BASE_URL_KEY to "https://audio.example.test/releases/v1"),
        )

        val available = resolution as AndroidAudioDeliveryResolution.Available
        assertEquals("primary-cdn", available.provider.providerID)
        assertEquals(2, available.assets.size)
        assertEquals(
            URI("https://audio.example.test/releases/v1/audio/v1/track-1.m4a"),
            available.assets.first().uri,
        )
        assertEquals("test-book.v000001", available.assets.first().volumeID)
        assertEquals(1_024L, available.assets.first().rendition.bytes)
    }

    @Test
    fun plannedDeliveryStopsBeforeHostOrRenditionResolution() {
        val releaseBlockers = listOf("Select a verified Android audio host.")
        val resolution = AndroidAudioDeliveryResolver.resolve(
            delivery = AudioDelivery(
                schemaVersion = 1,
                productID = PRODUCT_ID,
                platform = AudioDeliveryPlatform.ANDROID,
                deliveryVersion = "planned-v1",
                state = ProductPlatformState.PLANNED,
                artifactManifestPath = "audio-artifacts.json",
                selectedRenditionID = null,
                providers = emptyList(),
                releaseBlockers = releaseBlockers,
            ),
            catalog = catalog(rightsEligible = false),
            osMajor = 36,
            configuration = emptyMap(),
        )

        val unavailable = resolution as AndroidAudioDeliveryResolution.Unavailable
        assertEquals(
            listOf(
                AndroidAudioUnavailableReason.DeliveryInactive(
                    ProductPlatformState.PLANNED,
                    releaseBlockers,
                ),
            ),
            unavailable.reasons,
        )
    }

    @Test
    fun refusesActiveDeliveryUntilRightsAndByteRangeAreReleaseEligible() {
        val resolution = AndroidAudioDeliveryResolver.resolve(
            delivery = activeDelivery(byteRangeSupport = AudioByteRangeSupport.UNVERIFIED),
            catalog = catalog(rightsEligible = false),
            osMajor = 36,
            configuration = mapOf(BASE_URL_KEY to "https://audio.example.test"),
        )

        val unavailable = resolution as AndroidAudioDeliveryResolution.Unavailable
        assertEquals(
            listOf(
                AndroidAudioUnavailableReason.RightsNotEligible,
                AndroidAudioUnavailableReason.CatalogNotReleaseReady("legacy-migration"),
                AndroidAudioUnavailableReason.ByteRangeNotSupported(
                    AudioByteRangeSupport.UNVERIFIED,
                ),
            ),
            unavailable.reasons,
        )
    }

    @Test
    fun rejectsMissingAndNonHTTPSBaseURLs() {
        val missing = AndroidAudioDeliveryResolver.resolve(
            delivery = activeDelivery(),
            catalog = catalog(),
            osMajor = 36,
            configuration = emptyMap(),
        ) as AndroidAudioDeliveryResolution.Unavailable
        val invalid = AndroidAudioDeliveryResolver.resolve(
            delivery = activeDelivery(),
            catalog = catalog(),
            osMajor = 36,
            configuration = mapOf(BASE_URL_KEY to "http://audio.example.test"),
        ) as AndroidAudioDeliveryResolution.Unavailable

        assertEquals(
            listOf(AndroidAudioUnavailableReason.BaseURLMissing(BASE_URL_KEY)),
            missing.reasons,
        )
        assertEquals(
            listOf(AndroidAudioUnavailableReason.BaseURLInvalid(BASE_URL_KEY)),
            invalid.reasons,
        )
    }

    @Test
    fun rejectsUnsafeHTTPSBaseURLs() {
        listOf(
            "https://user@audio.example.test/releases",
            "https://audio.example.test/releases?channel=test",
            "https://audio.example.test/releases#preview",
            "https://audio.example.test/releases/../private",
            "https://audio.example.test/releases/%2e%2e/private",
        ).forEach { baseURL ->
            val resolution = AndroidAudioDeliveryResolver.resolve(
                delivery = activeDelivery(),
                catalog = catalog(),
                osMajor = 36,
                configuration = mapOf(BASE_URL_KEY to baseURL),
            ) as AndroidAudioDeliveryResolution.Unavailable

            assertEquals(
                "unexpected resolution for $baseURL",
                listOf(AndroidAudioUnavailableReason.BaseURLInvalid(BASE_URL_KEY)),
                resolution.reasons,
            )
        }
    }

    @Test
    fun rejectsProvidersThatDoNotSupportTheRunningOS() {
        val resolution = AndroidAudioDeliveryResolver.resolve(
            delivery = activeDelivery(minimumOSMajor = 37),
            catalog = catalog(),
            osMajor = 36,
            configuration = mapOf(BASE_URL_KEY to "https://audio.example.test"),
        )

        val unavailable = resolution as AndroidAudioDeliveryResolution.Unavailable
        assertEquals(
            listOf(AndroidAudioUnavailableReason.CompatiblePrimaryProviderMissing),
            unavailable.reasons,
        )
    }

    @Test
    fun reportsEveryArtifactMissingTheSelectedRendition() {
        val incompleteCatalog = catalog().let { original ->
            AudioCatalog(
                schemaVersion = original.schemaVersion,
                productID = original.productID,
                catalogID = original.catalogID,
                catalogVersion = original.catalogVersion,
                contractState = original.contractState,
                contentVersion = original.contentVersion,
                supportedLocales = original.supportedLocales,
                performers = original.performers,
                rights = original.rights,
                artifacts = original.artifacts.mapIndexed { index, artifact ->
                    if (index == 0) artifact else artifact.copy(
                        renditions = listOf(
                            artifact.renditions.single().copy(renditionID = "other-rendition"),
                        ),
                    )
                },
            )
        }
        val resolution = AndroidAudioDeliveryResolver.resolve(
            delivery = activeDelivery(),
            catalog = incompleteCatalog,
            osMajor = 36,
            configuration = mapOf(BASE_URL_KEY to "https://audio.example.test"),
        )

        val unavailable = resolution as AndroidAudioDeliveryResolution.Unavailable
        assertTrue(
            unavailable.reasons.contains(
                AndroidAudioUnavailableReason.RenditionMissingFromArtifacts(
                    listOf("test-product.audio.002"),
                ),
            ),
        )
    }

    private fun activeDelivery(
        minimumOSMajor: Int = 26,
        byteRangeSupport: AudioByteRangeSupport = AudioByteRangeSupport.SUPPORTED,
    ) = AudioDelivery(
        schemaVersion = 1,
        productID = PRODUCT_ID,
        platform = AudioDeliveryPlatform.ANDROID,
        deliveryVersion = "production-v1",
        state = ProductPlatformState.PRODUCTION,
        artifactManifestPath = "audio-artifacts.json",
        selectedRenditionID = RENDITION_ID,
        providers = listOf(
            HttpsAudioProvider(
                providerID = "primary-cdn",
                role = AudioProviderRole.PRIMARY,
                minimumOSMajor = minimumOSMajor,
                baseURLConfigurationKey = BASE_URL_KEY,
                enabledConfigurationKey = null,
                activation = HttpsAudioActivation.ALWAYS,
                stallTimeoutConfigurationKey = null,
                byteRangeSupport = byteRangeSupport,
                prefetchAllowed = true,
            ),
        ),
        releaseBlockers = emptyList(),
    )

    private fun catalog(rightsEligible: Boolean = true): AudioCatalog {
        val rights = AudioRights(
            rightsID = "test-product.audio-rights",
            status = if (rightsEligible) "product-license" else "legacy-unverified",
            reuseEligibility = if (rightsEligible) "eligible" else "blocked",
            statement = "Synthetic test rights.",
            evidenceReference = if (rightsEligible) "test-evidence" else null,
        )
        return AudioCatalog(
            schemaVersion = 1,
            productID = PRODUCT_ID,
            catalogID = "test-product.audio-catalog",
            catalogVersion = "test-v1",
            contractState = if (rightsEligible) "release-ready" else "legacy-migration",
            contentVersion = "test-v1",
            supportedLocales = listOf("zh-Hant"),
            performers = mapOf("zh-Hant" to "Test performer"),
            rights = rights,
            artifacts = (1..2).map { number ->
                AudioArtifact(
                    artifactID = "test-product.audio.${number.toString().padStart(3, '0')}",
                    legacyTrackID = null,
                    kind = "recitation",
                    titles = mapOf("zh-Hant" to "Track $number"),
                    contentMapping = AudioContentMapping(
                        status = "mapped",
                        bookID = "test-book",
                        legacyVolume = number,
                        volumeID = "test-book.v${number.toString().padStart(6, '0')}",
                        paragraphStartID = null,
                        paragraphEndID = null,
                    ),
                    rightsReference = rights.rightsID,
                    renditions = listOf(
                        AudioRendition(
                            renditionID = RENDITION_ID,
                            fileName = "track-$number.m4a",
                            artifactKey = "audio/v1/track-$number.m4a",
                            mediaType = "audio/mp4",
                            fileExtension = "m4a",
                            codec = "mp4a.40.2",
                            durationMilliseconds = 60_000,
                            sampleRateHertz = 44_100,
                            channels = 2,
                            bytes = 1_024L * number,
                            sha256 = number.toString().repeat(64),
                        ),
                    ),
                )
            },
        )
    }

    private companion object {
        const val PRODUCT_ID = "test-product"
        const val RENDITION_ID = "m4a-test"
        const val BASE_URL_KEY = "TestAudioBaseURL"
    }
}
