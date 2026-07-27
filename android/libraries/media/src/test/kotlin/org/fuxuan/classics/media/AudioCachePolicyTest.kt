package org.fuxuan.classics.media

import org.junit.Assert.assertEquals
import org.junit.Test

class AudioCachePolicyTest {
    @Test
    fun freezesTheAcceptedCacheBudgetsAndExpiry() {
        assertEquals(201_326_592L, AudioCachePolicy.PRODUCT_BUDGET_BYTES)
        assertEquals(536_870_912L, AudioCachePolicy.GLOBAL_BUDGET_BYTES)
        assertEquals(2_419_200_000L, AudioCachePolicy.MAX_INACTIVE_MILLISECONDS)
    }

    @Test
    fun expiresOnlyUnprotectedEntriesAfterTwentyEightDays() {
        val expired = entry("lengyan", "old", 10, lastAccessDays = 1)
        val protected = entry("lengyan", "next", 10, lastAccessDays = 1)
        val recent = entry("lengyan", "recent", 10, lastAccessDays = 2)
        val beforeExpiry = AudioCachePolicy.expiredUnprotectedKeys(
            entries = listOf(entry("lengyan", "epoch", 10, lastAccessDays = 0)),
            protectedKeys = emptySet(),
            nowEpochMilliseconds = 27.days,
        )
        val atExpiry = AudioCachePolicy.expiredUnprotectedKeys(
            entries = listOf(expired, protected, recent),
            protectedKeys = setOf(protected.key),
            nowEpochMilliseconds = 29.days,
        )

        assertEquals(emptyList<AudioCacheKey>(), beforeExpiry)
        assertEquals(listOf(expired.key), atExpiry)
    }

    @Test
    fun evictsLeastRecentlyUsedUnprotectedProductEntryBeforeAccepting() {
        val oldest = entry("lengyan", "oldest", 80, lastAccessDays = 90)
        val newer = entry("lengyan", "newer", 80, lastAccessDays = 91)
        val current = entry("lengyan", "current", 20, lastAccessDays = 80)

        val plan = AudioCachePolicy.plan(
            entries = listOf(oldest, newer, current),
            protectedKeys = setOf(current.key),
            request = request("lengyan", "requested", 60),
            nowEpochMilliseconds = 100.days,
        ) as AudioCachePlan.Accepted

        assertEquals(listOf(oldest.key), plan.evictions)
        assertEquals(160.mebibytes, plan.projectedProductBytes)
        assertEquals(160.mebibytes, plan.projectedGlobalBytes)
    }

    @Test
    fun removesExpiredEntriesBeforeAdditionalBudgetEviction() {
        val expired = entry("lengyan", "expired", 30, lastAccessDays = 1)
        val lru = entry("lengyan", "lru", 100, lastAccessDays = 80)
        val recent = entry("lengyan", "recent", 80, lastAccessDays = 90)

        val plan = AudioCachePolicy.plan(
            entries = listOf(expired, lru, recent),
            protectedKeys = emptySet(),
            request = request("lengyan", "requested", 50),
            nowEpochMilliseconds = 100.days,
        ) as AudioCachePlan.Accepted

        assertEquals(listOf(expired.key, lru.key), plan.evictions)
        assertEquals(130.mebibytes, plan.projectedProductBytes)
    }

    @Test
    fun appliesGlobalLRUAfterEveryProductFitsItsOwnBudget() {
        val oldest = entry("jingang", "oldest", 140, lastAccessDays = 10)
        val entries = listOf(
            oldest,
            entry("lengyan", "one", 180, lastAccessDays = 20),
            entry("yuanjue", "one", 180, lastAccessDays = 30),
        )

        val plan = AudioCachePolicy.plan(
            entries = entries,
            protectedKeys = emptySet(),
            request = request("tanjing", "requested", 40),
            nowEpochMilliseconds = 35.days,
        ) as AudioCachePlan.Accepted

        assertEquals(listOf(oldest.key), plan.evictions)
        assertEquals(40.mebibytes, plan.projectedProductBytes)
        assertEquals(400.mebibytes, plan.projectedGlobalBytes)
    }

    @Test
    fun refusesToEvictCurrentOrNextWhenProtectedDataExhaustsTheProductBudget() {
        val current = entry("lengyan", "current", 100, lastAccessDays = 1)
        val next = entry("lengyan", "next", 92, lastAccessDays = 1)

        val plan = AudioCachePolicy.plan(
            entries = listOf(current, next),
            protectedKeys = setOf(current.key, next.key),
            request = request("lengyan", "requested", 1),
            nowEpochMilliseconds = 40.days,
        )

        assertEquals(
            AudioCachePlan.Rejected(AudioCacheRejectionReason.PRODUCT_BUDGET_EXHAUSTED),
            plan,
        )
    }

    @Test
    fun replacingAnExistingArtifactDoesNotDoubleCountItsOldBytes() {
        val key = AudioCacheKey("lengyan", "current")
        val plan = AudioCachePolicy.plan(
            entries = listOf(
                AudioCacheEntry(key, 100.mebibytes, 1.days),
                entry("lengyan", "other", 50, lastAccessDays = 2),
            ),
            protectedKeys = setOf(key),
            request = AudioCacheRequest(key, 120.mebibytes),
            nowEpochMilliseconds = 3.days,
        ) as AudioCachePlan.Accepted

        assertEquals(emptyList<AudioCacheKey>(), plan.evictions)
        assertEquals(170.mebibytes, plan.projectedProductBytes)
    }

    @Test
    fun evictsAnOversizedUnprotectedEntryWithoutOverflowingAccounting() {
        val oversized = AudioCacheEntry(
            key = AudioCacheKey("lengyan", "oversized"),
            bytes = Long.MAX_VALUE,
            lastAccessEpochMilliseconds = 2.days,
        )

        val plan = AudioCachePolicy.plan(
            entries = listOf(oversized),
            protectedKeys = emptySet(),
            request = request("lengyan", "requested", 1),
            nowEpochMilliseconds = 3.days,
        ) as AudioCachePlan.Accepted

        assertEquals(listOf(oversized.key), plan.evictions)
        assertEquals(1.mebibytes, plan.projectedProductBytes)
        assertEquals(1.mebibytes, plan.projectedGlobalBytes)
    }

    @Test
    fun rejectsWhenOversizedProtectedAccountingCannotBeRecovered() {
        val protected = AudioCacheEntry(
            key = AudioCacheKey("lengyan", "protected"),
            bytes = Long.MAX_VALUE,
            lastAccessEpochMilliseconds = 2.days,
        )

        val plan = AudioCachePolicy.plan(
            entries = listOf(protected),
            protectedKeys = setOf(protected.key),
            request = request("lengyan", "requested", 1),
            nowEpochMilliseconds = 3.days,
        )

        assertEquals(
            AudioCachePlan.Rejected(AudioCacheRejectionReason.PRODUCT_BUDGET_EXHAUSTED),
            plan,
        )
    }

    private fun entry(
        productID: String,
        artifactID: String,
        mebibytes: Long,
        lastAccessDays: Long,
    ) = AudioCacheEntry(
        key = AudioCacheKey(productID, artifactID),
        bytes = mebibytes.mebibytes,
        lastAccessEpochMilliseconds = lastAccessDays.days,
    )

    private fun request(
        productID: String,
        artifactID: String,
        mebibytes: Long,
    ) = AudioCacheRequest(
        key = AudioCacheKey(productID, artifactID),
        bytes = mebibytes.mebibytes,
    )

    private val Long.mebibytes: Long
        get() = this * 1024L * 1024L

    private val Int.mebibytes: Long
        get() = toLong().mebibytes

    private val Long.days: Long
        get() = this * 24L * 60L * 60L * 1000L

    private val Int.days: Long
        get() = toLong().days
}
