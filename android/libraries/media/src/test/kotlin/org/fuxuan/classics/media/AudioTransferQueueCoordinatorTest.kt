package org.fuxuan.classics.media

import org.fuxuan.classics.core.content.AudioRendition
import org.fuxuan.classics.core.persistence.AudioPreferences
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.net.URI

class AudioTransferQueueCoordinatorTest {
    @Test
    fun meteredAutomaticPrefetchIsRetainedWithoutStarting() {
        val queue = FakeAudioTransferQueue()
        val coordinator = AudioTransferQueueCoordinator(queue)
        val spec = downloadSpec("metered")

        val result = coordinator.request(
            spec = spec,
            purpose = AudioTransferPurpose.AUTOMATIC_NEXT_PREFETCH,
            policyContext = policyContext(isMetered = true),
        ) as AudioTransferRequestResult.Accepted

        assertEquals(
            AudioNetworkDecision.Blocked(AudioNetworkBlockReason.METERED_NETWORK),
            result.networkDecision,
        )
        assertFalse(result.reusedExistingTask)
        assertEquals(
            AUTOMATIC_PREFETCH_POLICY_STOP_REASON,
            result.effectiveStopReason,
        )
        assertEquals(
            AudioTransferRequestOwnership.MANAGED_AUTOMATIC_PREFETCH,
            queue.requireTransfer(spec).ownership,
        )
        assertEquals(
            AUTOMATIC_PREFETCH_POLICY_STOP_REASON,
            queue.requireTransfer(spec).stopReason,
        )
    }

    @Test
    fun offlineUserPlaybackRemainsQueuedWithoutAPrefetchStopReason() {
        val queue = FakeAudioTransferQueue()
        val coordinator = AudioTransferQueueCoordinator(queue)
        val spec = downloadSpec("offline-user")

        val result = coordinator.request(
            spec = spec,
            purpose = AudioTransferPurpose.USER_PLAYBACK,
            policyContext = policyContext(isConnected = false),
        ) as AudioTransferRequestResult.Accepted

        assertEquals(
            AudioNetworkDecision.Blocked(AudioNetworkBlockReason.OFFLINE),
            result.networkDecision,
        )
        assertEquals(0, result.effectiveStopReason)
        assertEquals(
            AudioTransferRequestOwnership.MANAGED_USER_PLAYBACK,
            queue.requireTransfer(spec).ownership,
        )
    }

    @Test
    fun disabledAutomaticPrefetchDoesNotCreateANewTask() {
        val providerDisabledQueue = FakeAudioTransferQueue()
        val providerDisabled = AudioTransferQueueCoordinator(providerDisabledQueue).request(
            spec = downloadSpec("provider-disabled"),
            purpose = AudioTransferPurpose.AUTOMATIC_NEXT_PREFETCH,
            policyContext = policyContext(providerAllowsPrefetch = false),
        )
        assertEquals(
            AudioTransferRequestResult.NotScheduled(
                requestID = "lengyan:lengyan.audio.provider-disabled:android.test.provider-disabled",
                reason = AudioNetworkBlockReason.PROVIDER_DISALLOWS_PREFETCH,
            ),
            providerDisabled,
        )
        assertTrue(providerDisabledQueue.transfers.isEmpty())

        val preferenceDisabledQueue = FakeAudioTransferQueue()
        val preferenceDisabled = AudioTransferQueueCoordinator(preferenceDisabledQueue).request(
            spec = downloadSpec("preference-disabled"),
            purpose = AudioTransferPurpose.AUTOMATIC_NEXT_PREFETCH,
            policyContext = policyContext(
                preferences = AudioPreferences(automaticNextVolumePrefetch = false),
            ),
        )
        assertEquals(
            AudioTransferRequestResult.NotScheduled(
                requestID =
                    "lengyan:lengyan.audio.preference-disabled:android.test.preference-disabled",
                reason = AudioNetworkBlockReason.AUTOMATIC_PREFETCH_DISABLED,
            ),
            preferenceDisabled,
        )
        assertTrue(preferenceDisabledQueue.transfers.isEmpty())
    }

    @Test
    fun policyChangesStopAndResumeOnlyOwnedPrefetchTasks() {
        val queue = FakeAudioTransferQueue()
        val ordinaryPrefetch = downloadSpec("ordinary-prefetch")
        val externallyStoppedPrefetch = downloadSpec("external-stop")
        val userPlayback = downloadSpec("user-playback")
        val legacyPlayback = downloadSpec("legacy-playback")
        queue.put(
            ordinaryPrefetch,
            AudioTransferRequestOwnership.MANAGED_AUTOMATIC_PREFETCH,
        )
        queue.put(
            externallyStoppedPrefetch,
            AudioTransferRequestOwnership.MANAGED_AUTOMATIC_PREFETCH,
            stopReason = EXTERNAL_STOP_REASON,
        )
        queue.put(userPlayback, AudioTransferRequestOwnership.MANAGED_USER_PLAYBACK)
        queue.put(legacyPlayback, AudioTransferRequestOwnership.LEGACY_USER_PLAYBACK)
        val coordinator = AudioTransferQueueCoordinator(queue)

        val blocked = coordinator.updatePolicy(policyContext(isMetered = true))

        assertEquals(listOf(ordinaryPrefetch.requestID), blocked.stoppedRequestIDs)
        assertEquals(
            listOf(externallyStoppedPrefetch.requestID),
            blocked.externallyStoppedRequestIDs,
        )
        assertEquals(
            AUTOMATIC_PREFETCH_POLICY_STOP_REASON,
            queue.requireTransfer(ordinaryPrefetch).stopReason,
        )
        assertEquals(EXTERNAL_STOP_REASON, queue.requireTransfer(externallyStoppedPrefetch).stopReason)
        assertEquals(0, queue.requireTransfer(userPlayback).stopReason)
        assertEquals(0, queue.requireTransfer(legacyPlayback).stopReason)

        val allowed = coordinator.updatePolicy(policyContext(isMetered = false))

        assertEquals(listOf(ordinaryPrefetch.requestID), allowed.resumedRequestIDs)
        assertEquals(
            listOf(externallyStoppedPrefetch.requestID),
            allowed.externallyStoppedRequestIDs,
        )
        assertEquals(0, queue.requireTransfer(ordinaryPrefetch).stopReason)
        assertEquals(EXTERNAL_STOP_REASON, queue.requireTransfer(externallyStoppedPrefetch).stopReason)
    }

    @Test
    fun userPlaybackPromotesTheSamePrefetchAndClearsOnlyTheOwnedReason() {
        val queue = FakeAudioTransferQueue()
        val spec = downloadSpec("promotion")
        queue.put(
            spec,
            AudioTransferRequestOwnership.MANAGED_AUTOMATIC_PREFETCH,
            stopReason = AUTOMATIC_PREFETCH_POLICY_STOP_REASON,
        )
        val coordinator = AudioTransferQueueCoordinator(queue)

        val result = coordinator.request(
            spec = spec,
            purpose = AudioTransferPurpose.USER_PLAYBACK,
            policyContext = policyContext(isMetered = true),
        ) as AudioTransferRequestResult.Accepted

        assertTrue(result.reusedExistingTask)
        assertTrue(result.promotedExistingPrefetch)
        assertEquals(AudioTransferPurpose.USER_PLAYBACK, result.effectivePurpose)
        assertEquals(0, result.effectiveStopReason)
        assertEquals(listOf(spec.requestID), queue.replacedPurposeRequestIDs)
        assertEquals(
            AudioTransferRequestOwnership.MANAGED_USER_PLAYBACK,
            queue.requireTransfer(spec).ownership,
        )
        assertEquals(0, queue.requireTransfer(spec).stopReason)
    }

    @Test
    fun latePrefetchCallbackCannotDemoteOrRestopPromotedUserPlayback() {
        val queue = FakeAudioTransferQueue()
        val spec = downloadSpec("late-prefetch-callback")
        val coordinator = AudioTransferQueueCoordinator(queue)
        coordinator.request(
            spec = spec,
            purpose = AudioTransferPurpose.AUTOMATIC_NEXT_PREFETCH,
            policyContext = policyContext(isMetered = false),
        )
        coordinator.request(
            spec = spec,
            purpose = AudioTransferPurpose.USER_PLAYBACK,
            policyContext = policyContext(isMetered = true),
        )

        coordinator.onTransferChanged(
            QueuedAudioTransfer(
                contract = spec.contract(),
                ownership = AudioTransferRequestOwnership.MANAGED_AUTOMATIC_PREFETCH,
                stopReason = AUTOMATIC_PREFETCH_POLICY_STOP_REASON,
            ),
        )

        assertEquals(
            AudioTransferRequestOwnership.MANAGED_USER_PLAYBACK,
            queue.requireTransfer(spec).ownership,
        )
        assertEquals(0, queue.requireTransfer(spec).stopReason)
        assertEquals(
            listOf(spec.requestID, spec.requestID),
            queue.replacedPurposeRequestIDs,
        )
    }

    @Test
    fun promotionPreservesAnotherSubsystemsStopReason() {
        val queue = FakeAudioTransferQueue()
        val spec = downloadSpec("external-promotion")
        queue.put(
            spec,
            AudioTransferRequestOwnership.MANAGED_AUTOMATIC_PREFETCH,
            stopReason = EXTERNAL_STOP_REASON,
        )

        val result = AudioTransferQueueCoordinator(queue).request(
            spec = spec,
            purpose = AudioTransferPurpose.USER_PLAYBACK,
            policyContext = policyContext(isMetered = true),
        ) as AudioTransferRequestResult.Accepted

        assertTrue(result.promotedExistingPrefetch)
        assertEquals(EXTERNAL_STOP_REASON, result.effectiveStopReason)
        assertEquals(EXTERNAL_STOP_REASON, queue.requireTransfer(spec).stopReason)
    }

    @Test
    fun automaticRequestNeverDemotesAnExistingUserTask() {
        val queue = FakeAudioTransferQueue()
        val spec = downloadSpec("no-demotion")
        queue.put(spec, AudioTransferRequestOwnership.MANAGED_USER_PLAYBACK)

        val result = AudioTransferQueueCoordinator(queue).request(
            spec = spec,
            purpose = AudioTransferPurpose.AUTOMATIC_NEXT_PREFETCH,
            policyContext = policyContext(isMetered = true),
        ) as AudioTransferRequestResult.Accepted

        assertEquals(AudioTransferPurpose.USER_PLAYBACK, result.effectivePurpose)
        assertEquals(0, result.effectiveStopReason)
        assertTrue(queue.replacedPurposeRequestIDs.isEmpty())
        assertTrue(queue.stopReasonChanges.isEmpty())
    }

    @Test
    fun conflictingContractAndUnknownMetadataAreRejected() {
        val conflictingQueue = FakeAudioTransferQueue()
        val expected = downloadSpec("conflict")
        conflictingQueue.transfers[expected.requestID] = QueuedAudioTransfer(
            contract = expected.contract().copy(uri = "https://other.example.invalid/audio.m4a"),
            ownership = AudioTransferRequestOwnership.MANAGED_AUTOMATIC_PREFETCH,
            stopReason = 0,
        )
        val conflicting = AudioTransferQueueCoordinator(conflictingQueue).request(
            expected,
            AudioTransferPurpose.USER_PLAYBACK,
            policyContext(),
        )
        assertEquals(
            AudioTransferRequestResult.Rejected(
                expected.requestID,
                AudioTransferRequestRejectionReason.CONFLICTING_REQUEST_CONTRACT,
            ),
            conflicting,
        )

        val unknownQueue = FakeAudioTransferQueue()
        val unknown = downloadSpec("unknown-metadata")
        unknownQueue.put(unknown, AudioTransferRequestOwnership.UNSUPPORTED_METADATA)
        val unsupported = AudioTransferQueueCoordinator(unknownQueue).request(
            unknown,
            AudioTransferPurpose.USER_PLAYBACK,
            policyContext(),
        )
        assertEquals(
            AudioTransferRequestResult.Rejected(
                unknown.requestID,
                AudioTransferRequestRejectionReason.UNSUPPORTED_REQUEST_METADATA,
            ),
            unsupported,
        )
    }

    @Test
    fun transferMetadataCodecIsVersionedAndStrict() {
        assertEquals(
            AudioTransferRequestOwnership.LEGACY_USER_PLAYBACK,
            AudioTransferRequestMetadata.ownership(byteArrayOf()),
        )
        AudioTransferPurpose.entries.forEach { purpose ->
            val encoded = AudioTransferRequestMetadata.encode(purpose)
            assertEquals(purpose, AudioTransferRequestMetadata.purpose(encoded))
            assertEquals(
                purpose,
                AudioTransferRequestMetadata.purpose(encoded.copyOf()),
            )
        }
        assertEquals(
            AudioTransferRequestOwnership.UNSUPPORTED_METADATA,
            AudioTransferRequestMetadata.ownership(
                "classics-audio-transfer/v2:prefetch".encodeToByteArray(),
            ),
        )
    }

    private fun policyContext(
        isConnected: Boolean = true,
        isMetered: Boolean = false,
        providerAllowsPrefetch: Boolean = true,
        preferences: AudioPreferences = AudioPreferences(),
    ) = AudioPrefetchPolicyContext(
        network = AudioNetworkState(
            isConnected = isConnected,
            isMetered = isMetered,
        ),
        providerAllowsPrefetch = providerAllowsPrefetch,
        preferences = preferences,
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

    private class FakeAudioTransferQueue : AudioTransferQueue {
        val transfers = mutableMapOf<String, QueuedAudioTransfer>()
        val replacedPurposeRequestIDs = mutableListOf<String>()
        val stopReasonChanges = mutableListOf<Pair<String, Int>>()

        override fun currentTransfers(): List<QueuedAudioTransfer> = transfers.values.toList()

        override fun add(
            spec: Media3AudioDownloadSpec,
            purpose: AudioTransferPurpose,
            initialStopReason: Int,
        ) {
            transfers[spec.requestID] = QueuedAudioTransfer(
                contract = spec.contract(),
                ownership = purpose.ownership,
                stopReason = initialStopReason,
            )
        }

        override fun replacePurpose(
            spec: Media3AudioDownloadSpec,
            purpose: AudioTransferPurpose,
            preservedStopReason: Int,
        ) {
            replacedPurposeRequestIDs += spec.requestID
            transfers[spec.requestID] = QueuedAudioTransfer(
                contract = spec.contract(),
                ownership = purpose.ownership,
                stopReason = preservedStopReason,
            )
        }

        override fun setStopReason(requestID: String, stopReason: Int) {
            stopReasonChanges += requestID to stopReason
            transfers[requestID] = checkNotNull(transfers[requestID]).copy(
                stopReason = stopReason,
            )
        }

        fun put(
            spec: Media3AudioDownloadSpec,
            ownership: AudioTransferRequestOwnership,
            stopReason: Int = 0,
        ) {
            transfers[spec.requestID] = QueuedAudioTransfer(
                contract = spec.contract(),
                ownership = ownership,
                stopReason = stopReason,
            )
        }

        fun requireTransfer(spec: Media3AudioDownloadSpec): QueuedAudioTransfer =
            checkNotNull(transfers[spec.requestID])

        private val AudioTransferPurpose.ownership: AudioTransferRequestOwnership
            get() = when (this) {
                AudioTransferPurpose.USER_PLAYBACK ->
                    AudioTransferRequestOwnership.MANAGED_USER_PLAYBACK
                AudioTransferPurpose.AUTOMATIC_NEXT_PREFETCH ->
                    AudioTransferRequestOwnership.MANAGED_AUTOMATIC_PREFETCH
            }
    }

    private companion object {
        const val EXTERNAL_STOP_REASON = 73
    }
}

private fun Media3AudioDownloadSpec.contract() = AudioTransferRequestContract(
    requestID = requestID,
    uri = uri.toString(),
    mediaType = mediaType,
    customCacheKey = requestID,
    isFullProgressiveAsset = true,
)
