package org.fuxuan.classics.media

import org.fuxuan.classics.core.content.AudioRendition
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import java.net.URI

class AudioStartupIntegrityRegistrationPlannerTest {
    @Test
    fun plansEveryKnownTransferAndSortsCompletedIntegrityWork() {
        val completedZ = downloadSpec("z-completed")
        val stopped = downloadSpec("stopped")
        val completedA = downloadSpec("a-completed")
        val transfers = listOf(
            transfer(completedZ, AudioStartupTransferState.COMPLETED),
            transfer(stopped, AudioStartupTransferState.STOPPED),
            transfer(completedA, AudioStartupTransferState.COMPLETED),
        )

        val plan = AudioStartupIntegrityRegistrationPlanner.plan(
            catalog = listOf(stopped, completedA, completedZ),
            transfers = transfers,
        )

        assertEquals(transfers, plan.registrations.map { registration -> registration.transfer })
        assertEquals(
            listOf(completedA.requestID, completedZ.requestID),
            plan.completedRequestIDs,
        )
    }

    @Test
    fun rejectsCatalogOrTransferDuplicatesBeforeProducingAPlan() {
        val spec = downloadSpec("duplicate")

        assertThrows(IllegalArgumentException::class.java) {
            AudioStartupIntegrityRegistrationPlanner.plan(
                catalog = listOf(spec, spec),
                transfers = emptyList(),
            )
        }
        assertThrows(IllegalArgumentException::class.java) {
            AudioStartupIntegrityRegistrationPlanner.plan(
                catalog = listOf(spec),
                transfers = listOf(transfer(spec), transfer(spec)),
            )
        }
    }

    @Test
    fun rejectsMissingAndTransitionalTransfersBeforeProducingAPlan() {
        val known = downloadSpec("known")
        val missing = downloadSpec("missing")

        assertThrows(IllegalArgumentException::class.java) {
            AudioStartupIntegrityRegistrationPlanner.plan(
                catalog = listOf(known),
                transfers = listOf(transfer(missing)),
            )
        }
        listOf(
            AudioStartupTransferState.REMOVING,
            AudioStartupTransferState.RESTARTING,
        ).forEach { state ->
            assertThrows(IllegalArgumentException::class.java) {
                AudioStartupIntegrityRegistrationPlanner.plan(
                    catalog = listOf(known),
                    transfers = listOf(transfer(known, state)),
                )
            }
        }
    }

    private fun transfer(
        spec: Media3AudioDownloadSpec,
        state: AudioStartupTransferState = AudioStartupTransferState.QUEUED,
    ) = ReconciledAudioStartupTransfer(
        requestID = spec.requestID,
        purpose = AudioTransferPurpose.USER_PLAYBACK,
        state = state,
        stopReason = 0,
        metadataWasVerified = false,
    )

    private fun downloadSpec(id: String): Media3AudioDownloadSpec =
        Media3AudioDownloadSpec.from(
            productID = "lengyan",
            asset = ResolvedAndroidAudioAsset(
                artifactID = "lengyan.audio.$id",
                volumeID = "lengyan.v000001",
                titles = mapOf("zh-Hant" to "test"),
                rendition = AudioRendition(
                    renditionID = "android.test.$id",
                    fileName = "$id.m4a",
                    artifactKey = "audio/$id.m4a",
                    mediaType = "audio/mp4",
                    fileExtension = "m4a",
                    codec = "mp4a.40.2",
                    durationMilliseconds = 60_000,
                    sampleRateHertz = 44_100,
                    channels = 1,
                    bytes = 128 * 1024,
                    sha256 = "a".repeat(64),
                ),
                uri = URI("https://media.example.invalid/audio/$id.m4a"),
            ),
        )
}
