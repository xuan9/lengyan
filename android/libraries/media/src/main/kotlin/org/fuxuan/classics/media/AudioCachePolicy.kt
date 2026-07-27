package org.fuxuan.classics.media

data class AudioCacheKey(
    val productID: String,
    val artifactID: String,
) {
    init {
        require(productID.isNotBlank()) { "cache productID must not be blank" }
        require(artifactID.isNotBlank()) { "cache artifactID must not be blank" }
    }
}

data class AudioCacheEntry(
    val key: AudioCacheKey,
    val bytes: Long,
    val lastAccessEpochMilliseconds: Long,
) {
    init {
        require(bytes > 0) { "cached audio bytes must be positive" }
        require(lastAccessEpochMilliseconds >= 0) {
            "cached audio access time must not be negative"
        }
    }
}

data class AudioCacheRequest(
    val key: AudioCacheKey,
    val bytes: Long,
) {
    init {
        require(bytes > 0) { "requested audio bytes must be positive" }
    }
}

sealed interface AudioCachePlan {
    data class Accepted(
        val evictions: List<AudioCacheKey>,
        val projectedProductBytes: Long,
        val projectedGlobalBytes: Long,
    ) : AudioCachePlan

    data class Rejected(
        val reason: AudioCacheRejectionReason,
    ) : AudioCachePlan
}

enum class AudioCacheRejectionReason {
    PRODUCT_BUDGET_EXHAUSTED,
    GLOBAL_BUDGET_EXHAUSTED,
}

object AudioCachePolicy {
    const val PRODUCT_BUDGET_BYTES: Long = 192L * 1024L * 1024L
    const val GLOBAL_BUDGET_BYTES: Long = 512L * 1024L * 1024L
    const val MAX_INACTIVE_MILLISECONDS: Long = 28L * 24L * 60L * 60L * 1000L

    fun plan(
        entries: List<AudioCacheEntry>,
        protectedKeys: Set<AudioCacheKey>,
        request: AudioCacheRequest,
        nowEpochMilliseconds: Long,
    ): AudioCachePlan {
        require(nowEpochMilliseconds >= 0) { "cache policy time must not be negative" }
        require(entries.map(AudioCacheEntry::key).toSet().size == entries.size) {
            "cached audio keys must be unique"
        }

        val existingEntries = entries.filterNot { it.key == request.key }
        val staleEntries = existingEntries
            .filter { entry ->
                entry.key !in protectedKeys &&
                    entry.hasBeenInactiveForMaximum(nowEpochMilliseconds)
            }
            .sortedWith(CACHE_ENTRY_LRU_ORDER)
        val plannedEvictions = staleEntries.mapTo(linkedSetOf(), AudioCacheEntry::key)

        fun remainingEntries(): List<AudioCacheEntry> =
            existingEntries.filterNot { it.key in plannedEvictions }

        fun projectedProductBytes(): Long = remainingEntries()
            .filter { it.key.productID == request.key.productID }
            .let { saturatedProjectedBytes(it, request.bytes) }

        fun projectedGlobalBytes(): Long = saturatedProjectedBytes(
            remainingEntries(),
            request.bytes,
        )

        val productCandidates = existingEntries
            .filter { entry ->
                entry.key.productID == request.key.productID &&
                    entry.key !in protectedKeys &&
                    entry.key !in plannedEvictions
            }
            .sortedWith(CACHE_ENTRY_LRU_ORDER)
            .iterator()
        while (projectedProductBytes() > PRODUCT_BUDGET_BYTES && productCandidates.hasNext()) {
            plannedEvictions += productCandidates.next().key
        }
        if (projectedProductBytes() > PRODUCT_BUDGET_BYTES) {
            return AudioCachePlan.Rejected(AudioCacheRejectionReason.PRODUCT_BUDGET_EXHAUSTED)
        }

        val globalCandidates = existingEntries
            .filter { entry ->
                entry.key !in protectedKeys && entry.key !in plannedEvictions
            }
            .sortedWith(CACHE_ENTRY_LRU_ORDER)
            .iterator()
        while (projectedGlobalBytes() > GLOBAL_BUDGET_BYTES && globalCandidates.hasNext()) {
            plannedEvictions += globalCandidates.next().key
        }
        if (projectedGlobalBytes() > GLOBAL_BUDGET_BYTES) {
            return AudioCachePlan.Rejected(AudioCacheRejectionReason.GLOBAL_BUDGET_EXHAUSTED)
        }

        return AudioCachePlan.Accepted(
            evictions = plannedEvictions.toList(),
            projectedProductBytes = projectedProductBytes(),
            projectedGlobalBytes = projectedGlobalBytes(),
        )
    }

    fun expiredUnprotectedKeys(
        entries: List<AudioCacheEntry>,
        protectedKeys: Set<AudioCacheKey>,
        nowEpochMilliseconds: Long,
    ): List<AudioCacheKey> {
        require(nowEpochMilliseconds >= 0) { "cache policy time must not be negative" }
        require(entries.map(AudioCacheEntry::key).toSet().size == entries.size) {
            "cached audio keys must be unique"
        }
        return entries
            .filter { entry ->
                entry.key !in protectedKeys &&
                    entry.hasBeenInactiveForMaximum(nowEpochMilliseconds)
            }
            .sortedWith(CACHE_ENTRY_LRU_ORDER)
            .map(AudioCacheEntry::key)
    }

    private val CACHE_ENTRY_LRU_ORDER = compareBy<AudioCacheEntry>(
        AudioCacheEntry::lastAccessEpochMilliseconds,
        { it.key.productID },
        { it.key.artifactID },
    )

    private fun AudioCacheEntry.hasBeenInactiveForMaximum(nowEpochMilliseconds: Long): Boolean =
        nowEpochMilliseconds >= lastAccessEpochMilliseconds &&
            nowEpochMilliseconds - lastAccessEpochMilliseconds >= MAX_INACTIVE_MILLISECONDS

    private fun saturatedProjectedBytes(
        entries: List<AudioCacheEntry>,
        requestedBytes: Long,
    ): Long = entries.fold(requestedBytes) { total, entry ->
        if (total > Long.MAX_VALUE - entry.bytes) Long.MAX_VALUE else total + entry.bytes
    }
}
