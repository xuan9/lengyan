package org.fuxuan.classics.media.harness

import org.fuxuan.classics.core.content.AudioByteRangeSupport
import org.fuxuan.classics.core.content.AudioProviderRole
import org.fuxuan.classics.core.content.AudioRendition
import org.fuxuan.classics.core.content.HttpsAudioActivation
import org.fuxuan.classics.core.content.HttpsAudioProvider
import org.fuxuan.classics.media.AndroidAudioDeliveryResolution
import org.fuxuan.classics.media.ClassicsMediaSessionService
import org.fuxuan.classics.media.Media3AudioCatalog
import org.fuxuan.classics.media.ResolvedAndroidAudioAsset
import java.net.URI

class HarnessMediaSessionService : ClassicsMediaSessionService() {
    override fun createAudioCatalog(): Media3AudioCatalog = Media3AudioCatalog.from(
        resolution = AndroidAudioDeliveryResolution.Available(
            provider = HttpsAudioProvider(
                providerID = "android.test.primary",
                role = AudioProviderRole.PRIMARY,
                minimumOSMajor = 26,
                baseURLConfigurationKey = "TEST_AUDIO_BASE_URL",
                enabledConfigurationKey = null,
                activation = HttpsAudioActivation.ALWAYS,
                stallTimeoutConfigurationKey = null,
                byteRangeSupport = AudioByteRangeSupport.SUPPORTED,
                prefetchAllowed = true,
            ),
            assets = listOf(
                ResolvedAndroidAudioAsset(
                    artifactID = KNOWN_ARTIFACT_ID,
                    volumeID = "lengyan.v000001",
                    titles = mapOf(
                        "zh-Hans" to "楞严经 第一卷",
                        "zh-Hant" to "楞嚴經 第一卷",
                    ),
                    rendition = AudioRendition(
                        renditionID = "android.test.rendition",
                        fileName = "ly01.m4a",
                        artifactKey = "audio/ly01.m4a",
                        mediaType = "audio/mp4",
                        fileExtension = "m4a",
                        codec = "mp4a.40.2",
                        durationMilliseconds = 60_000,
                        sampleRateHertz = 44_100,
                        channels = 1,
                        bytes = 1_024,
                        sha256 = "a".repeat(64),
                    ),
                    uri = URI(TRUSTED_URI),
                ),
            ),
        ),
        preferredLocale = "zh-Hant",
        defaultLocale = "zh-Hant",
    )

    companion object {
        const val KNOWN_ARTIFACT_ID = "lengyan.audio.ly01"
        const val TRUSTED_URI = "https://media.example.invalid/audio/ly01.m4a"
        const val TRUSTED_TITLE = "楞嚴經 第一卷"
    }
}
