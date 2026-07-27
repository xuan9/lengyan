package org.fuxuan.classics.media

import org.fuxuan.classics.core.content.AudioRendition
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.net.URI

class AudioStartupReservationReconcilerTest {
    @Test
    fun restoresKnownUserAndPrefetchReservationsWithoutLosingVerifiedMetadata() {
        val user = downloadSpec("user")
        val prefetch = downloadSpec("prefetch")
        val verifiedUser = AudioCacheRecord(
            reservation = user.toCacheReservation(),
            state = AudioCacheRecordState.VERIFIED,
            lastAccessEpochMilliseconds = 10,
        )
        val store = FakeMetadataStore(listOf(verifiedUser))
        val reconciler = AudioStartupReservationReconciler(
            downloadIndex = FakeDownloadIndex(
                listOf(
                    indexedTransfer(
                        user,
                        AudioTransferRequestOwnership.LEGACY_USER_PLAYBACK,
                        AudioStartupTransferState.COMPLETED,
                    ),
                    indexedTransfer(
                        prefetch,
                        AudioTransferRequestOwnership.MANAGED_AUTOMATIC_PREFETCH,
                        AudioStartupTransferState.STOPPED,
                        stopReason = AUTOMATIC_PREFETCH_POLICY_STOP_REASON,
                    ),
                ),
            ),
            cachePolicyExecutor = AudioCachePolicyExecutor(store, FakeEvictor()),
        )

        val result = reconciler.reconcile(
            catalog = listOf(prefetch, user),
            protectedKeys = setOf(user.key),
            nowEpochMilliseconds = 20,
        ) as AudioStartupReconciliationResult.Completed

        assertTrue(result.readyToResume)
        assertEquals(emptyList<AudioStartupReconciliationIssue>(), result.issues)
        assertEquals(emptyList<String>(), result.evictedRequestIDs)
        assertEquals(
            listOf(
                ReconciledAudioStartupTransfer(
                    requestID = prefetch.requestID,
                    purpose = AudioTransferPurpose.AUTOMATIC_NEXT_PREFETCH,
                    state = AudioStartupTransferState.STOPPED,
                    stopReason = AUTOMATIC_PREFETCH_POLICY_STOP_REASON,
                    metadataWasVerified = false,
                ),
                ReconciledAudioStartupTransfer(
                    requestID = user.requestID,
                    purpose = AudioTransferPurpose.USER_PLAYBACK,
                    state = AudioStartupTransferState.COMPLETED,
                    stopReason = 0,
                    metadataWasVerified = true,
                ),
            ).sortedBy(ReconciledAudioStartupTransfer::requestID),
            result.transfers,
        )
        assertEquals(
            setOf(prefetch.requestID, user.requestID),
            store.records().mapTo(mutableSetOf(), AudioCacheRecord::requestID),
        )
        assertEquals(
            AudioCacheRecordState.VERIFIED,
            store.records().single { it.requestID == user.requestID }.state,
        )
        assertEquals(
            10,
            store.records().single { it.requestID == user.requestID }
                .lastAccessEpochMilliseconds,
        )
        assertEquals(
            AudioCacheRecordState.RESERVED,
            store.records().single { it.requestID == prefetch.requestID }.state,
        )
    }

    @Test
    fun blocksUnknownConflictingUnsupportedAndTransitionalDownloads() {
        val conflicting = downloadSpec("conflicting")
        val unsupported = downloadSpec("unsupported")
        val removing = downloadSpec("removing")
        val missing = downloadSpec("missing")
        val duplicate = downloadSpec("duplicate")
        val otherwiseValid = downloadSpec("otherwise-valid")
        val store = FakeMetadataStore(emptyList())
        val reconciler = AudioStartupReservationReconciler(
            downloadIndex = FakeDownloadIndex(
                listOf(
                    indexedTransfer(conflicting).copy(
                        contract = conflicting.toTransferRequestContract().copy(
                            uri = "https://other.example.invalid/conflicting.m4a",
                        ),
                    ),
                    indexedTransfer(
                        unsupported,
                        AudioTransferRequestOwnership.UNSUPPORTED_METADATA,
                    ),
                    indexedTransfer(
                        removing,
                        state = AudioStartupTransferState.REMOVING,
                    ),
                    indexedTransfer(missing),
                    indexedTransfer(duplicate),
                    indexedTransfer(duplicate),
                    indexedTransfer(otherwiseValid),
                ),
            ),
            cachePolicyExecutor = AudioCachePolicyExecutor(store, FakeEvictor()),
        )

        val result = reconciler.reconcile(
            catalog = listOf(
                conflicting,
                unsupported,
                removing,
                duplicate,
                otherwiseValid,
            ),
            protectedKeys = emptySet(),
            nowEpochMilliseconds = 20,
        ) as AudioStartupReconciliationResult.Completed

        assertFalse(result.readyToResume)
        assertEquals(emptyList<ReconciledAudioStartupTransfer>(), result.transfers)
        assertTrue(store.records().isEmpty())
        val issues = result.issues.associateBy(AudioStartupReconciliationIssue::requestID)
        assertTrue(
            issues[conflicting.requestID] is
                AudioStartupReconciliationIssue.ConflictingRequestContract,
        )
        assertTrue(
            issues[unsupported.requestID] is
                AudioStartupReconciliationIssue.UnsupportedRequestMetadata,
        )
        assertEquals(
            AudioStartupReconciliationIssue.TransitionalDownloadState(
                removing.requestID,
                AudioStartupTransferState.REMOVING,
            ),
            issues[removing.requestID],
        )
        assertTrue(
            issues[missing.requestID] is AudioStartupReconciliationIssue.CatalogEntryMissing,
        )
        assertTrue(
            issues[duplicate.requestID] is
                AudioStartupReconciliationIssue.DuplicateDownloadIndexEntry,
        )
        assertEquals(null, issues[otherwiseValid.requestID])
    }

    @Test
    fun reportsCacheAdmissionRejectionWithoutClaimingStartupIsReady() {
        val oversized = downloadSpec(
            id = "oversized",
            bytes = AudioCachePolicy.PRODUCT_BUDGET_BYTES + 1,
        )
        val store = FakeMetadataStore(emptyList())
        val reconciler = AudioStartupReservationReconciler(
            downloadIndex = FakeDownloadIndex(listOf(indexedTransfer(oversized))),
            cachePolicyExecutor = AudioCachePolicyExecutor(store, FakeEvictor()),
        )

        val result = reconciler.reconcile(
            catalog = listOf(oversized),
            protectedKeys = emptySet(),
            nowEpochMilliseconds = 20,
        ) as AudioStartupReconciliationResult.Completed

        assertFalse(result.readyToResume)
        assertEquals(emptyList<ReconciledAudioStartupTransfer>(), result.transfers)
        assertEquals(
            listOf(
                AudioStartupReconciliationIssue.CacheAdmissionRejected(
                    requestID = oversized.requestID,
                    reason = AudioCacheAdmissionRejectionReason.PRODUCT_BUDGET_EXHAUSTED,
                ),
            ),
            result.issues,
        )
        assertTrue(store.records().isEmpty())
    }

    @Test
    fun reportsCacheMetadataFailureWithoutClaimingStartupIsReady() {
        val spec = downloadSpec("metadata-failure")
        val store = FakeMetadataStore(
            initialRecords = emptyList(),
            readFailure = IllegalStateException("broken metadata"),
        )
        val reconciler = AudioStartupReservationReconciler(
            downloadIndex = FakeDownloadIndex(listOf(indexedTransfer(spec))),
            cachePolicyExecutor = AudioCachePolicyExecutor(store, FakeEvictor()),
        )

        val result = reconciler.reconcile(
            catalog = listOf(spec),
            protectedKeys = emptySet(),
            nowEpochMilliseconds = 20,
        ) as AudioStartupReconciliationResult.Completed

        assertFalse(result.readyToResume)
        assertEquals(emptyList<ReconciledAudioStartupTransfer>(), result.transfers)
        assertEquals(
            listOf(
                AudioStartupReconciliationIssue.CacheAdmissionFailed(
                    requestID = spec.requestID,
                    operation = AudioCachePolicyOperation.READ_METADATA,
                    exceptionType = "IllegalStateException",
                    evictedRequestIDs = emptyList(),
                ),
            ),
            result.issues,
        )
    }

    @Test
    fun reportsDownloadIndexFailureBeforeChangingCacheMetadata() {
        val spec = downloadSpec("index-failure")
        val store = FakeMetadataStore(emptyList())
        val reconciler = AudioStartupReservationReconciler(
            downloadIndex = AudioStartupDownloadIndex {
                throw IllegalStateException("broken index")
            },
            cachePolicyExecutor = AudioCachePolicyExecutor(store, FakeEvictor()),
        )

        val result = reconciler.reconcile(
            catalog = listOf(spec),
            protectedKeys = emptySet(),
            nowEpochMilliseconds = 20,
        )

        assertEquals(
            AudioStartupReconciliationResult.Failed(
                operation = AudioStartupReconciliationOperation.READ_DOWNLOAD_INDEX,
                exceptionType = "IllegalStateException",
            ),
            result,
        )
        assertTrue(store.records().isEmpty())
    }

    private fun indexedTransfer(
        spec: Media3AudioDownloadSpec,
        ownership: AudioTransferRequestOwnership =
            AudioTransferRequestOwnership.MANAGED_USER_PLAYBACK,
        state: AudioStartupTransferState = AudioStartupTransferState.QUEUED,
        stopReason: Int = 0,
    ) = IndexedAudioStartupTransfer(
        contract = spec.toTransferRequestContract(),
        ownership = ownership,
        state = state,
        stopReason = stopReason,
    )

    private fun downloadSpec(
        id: String,
        bytes: Long = 128 * 1024,
    ): Media3AudioDownloadSpec = Media3AudioDownloadSpec.from(
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
                bytes = bytes,
                sha256 = "a".repeat(64),
            ),
            uri = URI("https://media.example.invalid/audio/$id.m4a"),
        ),
    )

    private class FakeDownloadIndex(
        private val transfers: List<IndexedAudioStartupTransfer>,
    ) : AudioStartupDownloadIndex {
        override fun downloads(): List<IndexedAudioStartupTransfer> = transfers
    }

    private class FakeMetadataStore(
        initialRecords: List<AudioCacheRecord>,
        private val readFailure: Exception? = null,
    ) : AudioCacheMetadataStore {
        private val recordsByRequestID = initialRecords.associateByTo(mutableMapOf()) {
            it.requestID
        }

        override fun records(): List<AudioCacheRecord> {
            readFailure?.let { throw it }
            return recordsByRequestID.values.sortedBy(AudioCacheRecord::requestID)
        }

        override fun write(record: AudioCacheRecord) {
            recordsByRequestID[record.requestID] = record
        }

        override fun remove(requestID: String) {
            recordsByRequestID.remove(requestID)
        }
    }

    private class FakeEvictor : AudioCacheResourceEvictor {
        override fun evict(requestID: String) = Unit
    }
}
