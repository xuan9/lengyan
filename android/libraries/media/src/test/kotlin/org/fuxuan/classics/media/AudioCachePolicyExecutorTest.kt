package org.fuxuan.classics.media

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class AudioCachePolicyExecutorTest {
    @Test
    fun admitsAndPersistsAReservationAfterEvictingExpiredAudio() {
        val expired = record("lengyan", "old", "aac", 40, 1, verified = true)
        val recent = record("lengyan", "recent", "aac", 80, 90, verified = true)
        val store = FakeMetadataStore(listOf(expired, recent))
        val evictor = FakeEvictor()
        val executor = AudioCachePolicyExecutor(store, evictor)
        val requested = reservation("lengyan", "requested", "aac", 50)

        val result = executor.admit(
            reservation = requested,
            protectedKeys = emptySet(),
            nowEpochMilliseconds = 100.days,
        ) as AudioCacheAdmissionResult.Accepted

        assertEquals(listOf(expired.requestID), result.evictedRequestIDs)
        assertEquals(listOf(expired.requestID), evictor.evictedRequestIDs)
        assertEquals(130.mebibytes, result.projectedProductBytes)
        assertFalse(result.alreadyVerified)
        assertEquals(
            AudioCacheRecord(
                reservation = requested,
                state = AudioCacheRecordState.RESERVED,
                lastAccessEpochMilliseconds = 100.days,
            ),
            store.records().single { it.requestID == requested.requestID },
        )
    }

    @Test
    fun preservesAnExistingVerifiedReservationAndItsContract() {
        val verified = record("lengyan", "current", "aac", 80, 4, verified = true)
        val store = FakeMetadataStore(listOf(verified))
        val evictor = FakeEvictor()
        val executor = AudioCachePolicyExecutor(store, evictor)

        val result = executor.admit(
            reservation = verified.reservation,
            protectedKeys = setOf(verified.key),
            nowEpochMilliseconds = 7.days,
        ) as AudioCacheAdmissionResult.Accepted

        assertTrue(result.alreadyVerified)
        assertEquals(emptyList<String>(), result.evictedRequestIDs)
        assertEquals(emptyList<String>(), evictor.evictedRequestIDs)
        assertEquals(AudioCacheRecordState.VERIFIED, store.records().single().state)
        assertEquals(7.days, store.records().single().lastAccessEpochMilliseconds)
    }

    @Test
    fun rejectsAChangedImmutableContractWithTheSameRequestID() {
        val existing = record("lengyan", "current", "aac", 80, 1)
        val changed = existing.reservation.copy(expectedSha256 = "f".repeat(64))
        val store = FakeMetadataStore(listOf(existing))
        val executor = AudioCachePolicyExecutor(store, FakeEvictor())

        val result = executor.admit(changed, emptySet(), 2.days)

        assertEquals(
            AudioCacheAdmissionResult.Rejected(
                requestID = changed.requestID,
                reason = AudioCacheAdmissionRejectionReason.CONFLICTING_CONTRACT,
            ),
            result,
        )
        assertEquals(listOf(existing), store.records())
    }

    @Test
    fun refusesToPersistAVerificationThatDoesNotMatchTheReservation() {
        val requested = reservation("lengyan", "current", "aac", 80)
        val store = FakeMetadataStore(emptyList())
        val executor = AudioCachePolicyExecutor(store, FakeEvictor())
        executor.admit(requested, emptySet(), 1.days)

        assertThrows(IllegalArgumentException::class.java) {
            executor.markVerified(
                reservation = requested,
                verification = CachedAudioVerification.Verified(
                    bytes = requested.expectedBytes,
                    sha256 = "f".repeat(64),
                ),
                nowEpochMilliseconds = 1.days,
            )
        }
        assertEquals(AudioCacheRecordState.RESERVED, store.records().single().state)
    }

    @Test
    fun refusesToReplaceAProtectedArtifactWithAnotherRendition() {
        val existing = record("lengyan", "current", "aac", 80, 1, verified = true)
        val replacement = reservation("lengyan", "current", "opus", 60)
        val store = FakeMetadataStore(listOf(existing))
        val executor = AudioCachePolicyExecutor(store, FakeEvictor())

        val result = executor.admit(
            replacement,
            protectedKeys = setOf(existing.key),
            nowEpochMilliseconds = 2.days,
        )

        assertEquals(
            AudioCacheAdmissionResult.Rejected(
                requestID = replacement.requestID,
                reason = AudioCacheAdmissionRejectionReason.PROTECTED_REPLACEMENT,
            ),
            result,
        )
        assertEquals(listOf(existing), store.records())
    }

    @Test
    fun rejectsDuplicatePersistentRecordsForAnotherProtectedArtifact() {
        val older = record("lengyan", "protected", "aac", 60, 1)
        val newer = record("lengyan", "protected", "opus", 50, 2)
        val requested = reservation("lengyan", "requested", "aac", 20)
        val store = FakeMetadataStore(listOf(older, newer))
        val executor = AudioCachePolicyExecutor(store, FakeEvictor())

        val result = executor.admit(
            requested,
            protectedKeys = setOf(older.key),
            nowEpochMilliseconds = 3.days,
        )

        assertEquals(
            AudioCacheAdmissionResult.Rejected(
                requestID = requested.requestID,
                reason = AudioCacheAdmissionRejectionReason.PROTECTED_DUPLICATE,
            ),
            result,
        )
        assertEquals(2, store.records().size)
    }

    @Test
    fun removesSupersededAndLeastRecentlyUsedRecordsBeforeReservation() {
        val superseded = record("lengyan", "current", "aac", 70, 30)
        val oldest = record("lengyan", "oldest", "aac", 100, 40)
        val recent = record("lengyan", "recent", "aac", 80, 50)
        val requested = reservation("lengyan", "current", "opus", 60)
        val store = FakeMetadataStore(listOf(superseded, oldest, recent))
        val evictor = FakeEvictor()
        val executor = AudioCachePolicyExecutor(store, evictor)

        val result = executor.admit(requested, emptySet(), 55.days)
            as AudioCacheAdmissionResult.Accepted

        assertEquals(
            listOf(superseded.requestID, oldest.requestID),
            result.evictedRequestIDs,
        )
        assertEquals(140.mebibytes, result.projectedProductBytes)
        assertEquals(setOf(recent.requestID, requested.requestID), store.records().map {
            it.requestID
        }.toSet())
    }

    @Test
    fun reportsPartialEvictionFailureWithoutWritingTheReservation() {
        val first = record("lengyan", "first", "aac", 80, 1)
        val second = record("lengyan", "second", "aac", 80, 2)
        val store = FakeMetadataStore(listOf(first, second))
        val evictor = FakeEvictor(failOnRequestID = second.requestID)
        val executor = AudioCachePolicyExecutor(store, evictor)
        val requested = reservation("lengyan", "requested", "aac", 80)

        val result = executor.admit(requested, emptySet(), 40.days)
            as AudioCacheAdmissionResult.Failed

        assertEquals(AudioCachePolicyOperation.EVICT_RESOURCE, result.operation)
        assertEquals("IllegalStateException", result.exceptionType)
        assertEquals(listOf(first.requestID), result.evictedRequestIDs)
        assertFalse(store.records().any { it.requestID == requested.requestID })
    }

    @Test
    fun verifiesTouchesAndExpiresOnlyUnprotectedPersistentRecords() {
        val current = record("lengyan", "current", "aac", 30, 1)
        val expired = record("lengyan", "expired", "aac", 30, 1, verified = true)
        val store = FakeMetadataStore(listOf(current, expired))
        val evictor = FakeEvictor()
        val executor = AudioCachePolicyExecutor(store, evictor)

        executor.markVerified(
            reservation = current.reservation,
            verification = CachedAudioVerification.Verified(
                bytes = current.expectedBytes,
                sha256 = current.reservation.expectedSha256,
            ),
            nowEpochMilliseconds = 2.days,
        )
        assertTrue(executor.recordAccess(current.requestID, 3.days))
        assertFalse(executor.recordAccess("missing", 3.days))
        val result = executor.removeExpired(
            protectedKeys = setOf(current.key),
            nowEpochMilliseconds = 30.days,
        ) as AudioCacheMaintenanceResult.Completed

        assertEquals(listOf(expired.requestID), result.evictedRequestIDs)
        val retained = store.records().single()
        assertEquals(current.requestID, retained.requestID)
        assertEquals(AudioCacheRecordState.VERIFIED, retained.state)
        assertEquals(3.days, retained.lastAccessEpochMilliseconds)
    }

    @Test
    fun maintenanceCanExpireOneOfTwoUnprotectedRenditionsAfterAInterruptedMigration() {
        val expired = record("lengyan", "duplicate", "aac", 30, 1, verified = true)
        val recent = record("lengyan", "duplicate", "opus", 20, 5, verified = true)
        val store = FakeMetadataStore(listOf(expired, recent))
        val evictor = FakeEvictor()
        val executor = AudioCachePolicyExecutor(store, evictor)

        val result = executor.removeExpired(
            protectedKeys = emptySet(),
            nowEpochMilliseconds = 30.days,
        ) as AudioCacheMaintenanceResult.Completed

        assertEquals(listOf(expired.requestID), result.evictedRequestIDs)
        assertEquals(listOf(recent), store.records())
    }

    private fun record(
        productID: String,
        artifactID: String,
        renditionID: String,
        mebibytes: Long,
        lastAccessDays: Long,
        verified: Boolean = false,
    ) = AudioCacheRecord(
        reservation = reservation(productID, artifactID, renditionID, mebibytes),
        state = if (verified) AudioCacheRecordState.VERIFIED else AudioCacheRecordState.RESERVED,
        lastAccessEpochMilliseconds = lastAccessDays.days,
    )

    private fun reservation(
        productID: String,
        artifactID: String,
        renditionID: String,
        mebibytes: Long,
    ) = AudioCacheReservation(
        requestID = "$productID:$artifactID:$renditionID",
        key = AudioCacheKey(productID, artifactID),
        renditionID = renditionID,
        expectedBytes = mebibytes.mebibytes,
        expectedSha256 = "a".repeat(64),
    )

    private class FakeMetadataStore(
        initialRecords: List<AudioCacheRecord>,
    ) : AudioCacheMetadataStore {
        private val stored = initialRecords.associateByTo(mutableMapOf()) { it.requestID }

        override fun records(): List<AudioCacheRecord> = stored.values.sortedBy { it.requestID }

        override fun write(record: AudioCacheRecord) {
            stored[record.requestID] = record
        }

        override fun remove(requestID: String) {
            stored.remove(requestID)
        }
    }

    private class FakeEvictor(
        private val failOnRequestID: String? = null,
    ) : AudioCacheResourceEvictor {
        val evictedRequestIDs = mutableListOf<String>()

        override fun evict(requestID: String) {
            check(requestID != failOnRequestID) { "injected eviction failure" }
            evictedRequestIDs += requestID
        }
    }

    private val Long.mebibytes: Long
        get() = this * 1024L * 1024L

    private val Int.mebibytes: Long
        get() = toLong().mebibytes

    private val Long.days: Long
        get() = this * 24L * 60L * 60L * 1000L

    private val Int.days: Long
        get() = toLong().days
}
