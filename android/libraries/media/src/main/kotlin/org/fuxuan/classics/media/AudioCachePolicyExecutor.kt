package org.fuxuan.classics.media

import androidx.annotation.WorkerThread

data class AudioCacheReservation(
    val requestID: String,
    val key: AudioCacheKey,
    val renditionID: String,
    val expectedBytes: Long,
    val expectedSha256: String,
) {
    init {
        require(requestID.isNotBlank()) { "cache reservation requestID must not be blank" }
        require(renditionID.isNotBlank()) { "cache reservation renditionID must not be blank" }
        require(CACHE_KEY_SEPARATOR !in key.productID) {
            "cache reservation productID contains the request-key separator"
        }
        require(CACHE_KEY_SEPARATOR !in key.artifactID) {
            "cache reservation artifactID contains the request-key separator"
        }
        require(CACHE_KEY_SEPARATOR !in renditionID) {
            "cache reservation renditionID contains the request-key separator"
        }
        val expectedRequestID = listOf(key.productID, key.artifactID, renditionID)
            .joinToString(CACHE_KEY_SEPARATOR.toString())
        require(requestID == expectedRequestID) {
            "cache reservation requestID does not match its product, artifact, and rendition"
        }
        require(expectedBytes > 0) { "cache reservation bytes must be positive" }
        require(SHA_256_PATTERN.matches(expectedSha256)) {
            "cache reservation SHA-256 must be lowercase hexadecimal"
        }
    }
}

enum class AudioCacheRecordState {
    RESERVED,
    VERIFIED,
}

data class AudioCacheRecord(
    val reservation: AudioCacheReservation,
    val state: AudioCacheRecordState,
    val lastAccessEpochMilliseconds: Long,
) {
    init {
        require(lastAccessEpochMilliseconds >= 0) {
            "cached audio access time must not be negative"
        }
    }

    val requestID: String
        get() = reservation.requestID

    val key: AudioCacheKey
        get() = reservation.key

    val expectedBytes: Long
        get() = reservation.expectedBytes

    fun hasSameContract(other: AudioCacheReservation): Boolean = reservation == other
}

interface AudioCacheMetadataStore {
    fun records(): List<AudioCacheRecord>

    fun write(record: AudioCacheRecord)

    fun remove(requestID: String)
}

fun interface AudioCacheResourceEvictor {
    /** Returns only after both the indexed download and cached bytes are unavailable. */
    fun evict(requestID: String)
}

sealed interface AudioCacheAdmissionResult {
    val requestID: String

    data class Accepted(
        override val requestID: String,
        val evictedRequestIDs: List<String>,
        val projectedProductBytes: Long,
        val projectedGlobalBytes: Long,
        val alreadyVerified: Boolean,
    ) : AudioCacheAdmissionResult

    data class Rejected(
        override val requestID: String,
        val reason: AudioCacheAdmissionRejectionReason,
    ) : AudioCacheAdmissionResult

    data class Failed(
        override val requestID: String,
        val operation: AudioCachePolicyOperation,
        val exceptionType: String,
        val evictedRequestIDs: List<String>,
    ) : AudioCacheAdmissionResult
}

enum class AudioCacheAdmissionRejectionReason {
    PRODUCT_BUDGET_EXHAUSTED,
    GLOBAL_BUDGET_EXHAUSTED,
    CONFLICTING_CONTRACT,
    PROTECTED_REPLACEMENT,
    PROTECTED_DUPLICATE,
}

enum class AudioCachePolicyOperation {
    READ_METADATA,
    EVICT_RESOURCE,
    REMOVE_METADATA,
    WRITE_METADATA,
}

sealed interface AudioCacheMaintenanceResult {
    data class Completed(
        val evictedRequestIDs: List<String>,
    ) : AudioCacheMaintenanceResult

    data class Failed(
        val operation: AudioCachePolicyOperation,
        val exceptionType: String,
        val evictedRequestIDs: List<String>,
    ) : AudioCacheMaintenanceResult
}

class AudioCachePolicyExecutor(
    private val metadataStore: AudioCacheMetadataStore,
    private val resourceEvictor: AudioCacheResourceEvictor,
) {
    @WorkerThread
    @Synchronized
    fun admit(
        reservation: AudioCacheReservation,
        protectedKeys: Set<AudioCacheKey>,
        nowEpochMilliseconds: Long,
    ): AudioCacheAdmissionResult {
        require(nowEpochMilliseconds >= 0) { "cache policy time must not be negative" }

        val records = try {
            metadataStore.records().validated()
        } catch (exception: Exception) {
            return admissionFailure(
                reservation.requestID,
                AudioCachePolicyOperation.READ_METADATA,
                exception,
            )
        }

        val sameRequest = records.firstOrNull { it.requestID == reservation.requestID }
        if (sameRequest != null && !sameRequest.hasSameContract(reservation)) {
            return AudioCacheAdmissionResult.Rejected(
                reservation.requestID,
                AudioCacheAdmissionRejectionReason.CONFLICTING_CONTRACT,
            )
        }

        val normalization = normalizeRecords(
            records = records,
            reservation = reservation,
            protectedKeys = protectedKeys,
        )
        if (normalization is CacheRecordNormalization.Rejected) {
            return AudioCacheAdmissionResult.Rejected(
                reservation.requestID,
                normalization.reason,
            )
        }
        val normalized = normalization as CacheRecordNormalization.Accepted

        val policyPlan = AudioCachePolicy.plan(
            entries = normalized.canonicalRecords.map { record ->
                AudioCacheEntry(
                    key = record.key,
                    bytes = record.expectedBytes,
                    lastAccessEpochMilliseconds = record.lastAccessEpochMilliseconds,
                )
            },
            protectedKeys = protectedKeys,
            request = AudioCacheRequest(
                key = reservation.key,
                bytes = reservation.expectedBytes,
            ),
            nowEpochMilliseconds = nowEpochMilliseconds,
        )
        if (policyPlan is AudioCachePlan.Rejected) {
            return AudioCacheAdmissionResult.Rejected(
                reservation.requestID,
                policyPlan.reason.toAdmissionReason(),
            )
        }
        policyPlan as AudioCachePlan.Accepted

        val plannedRecordsByKey = normalized.canonicalRecords.associateBy(AudioCacheRecord::key)
        val recordsToEvict = buildList {
            addAll(normalized.mandatoryEvictions)
            policyPlan.evictions.mapNotNullTo(this) { key -> plannedRecordsByKey[key] }
        }.distinctBy(AudioCacheRecord::requestID)

        val evictedRequestIDs = mutableListOf<String>()
        recordsToEvict.forEach { record ->
            try {
                resourceEvictor.evict(record.requestID)
            } catch (exception: Exception) {
                return admissionFailure(
                    reservation.requestID,
                    AudioCachePolicyOperation.EVICT_RESOURCE,
                    exception,
                    evictedRequestIDs,
                )
            }
            try {
                metadataStore.remove(record.requestID)
            } catch (exception: Exception) {
                return admissionFailure(
                    reservation.requestID,
                    AudioCachePolicyOperation.REMOVE_METADATA,
                    exception,
                    evictedRequestIDs + record.requestID,
                )
            }
            evictedRequestIDs += record.requestID
        }

        val existing = sameRequest?.takeUnless { it.requestID in evictedRequestIDs }
        val record = if (existing == null) {
            AudioCacheRecord(
                reservation = reservation,
                state = AudioCacheRecordState.RESERVED,
                lastAccessEpochMilliseconds = nowEpochMilliseconds,
            )
        } else {
            existing.copy(
                lastAccessEpochMilliseconds = maxOf(
                    existing.lastAccessEpochMilliseconds,
                    nowEpochMilliseconds,
                ),
            )
        }
        try {
            metadataStore.write(record)
        } catch (exception: Exception) {
            return admissionFailure(
                reservation.requestID,
                AudioCachePolicyOperation.WRITE_METADATA,
                exception,
                evictedRequestIDs,
            )
        }

        return AudioCacheAdmissionResult.Accepted(
            requestID = reservation.requestID,
            evictedRequestIDs = evictedRequestIDs,
            projectedProductBytes = policyPlan.projectedProductBytes,
            projectedGlobalBytes = policyPlan.projectedGlobalBytes,
            alreadyVerified = record.state == AudioCacheRecordState.VERIFIED,
        )
    }

    @WorkerThread
    @Synchronized
    fun markVerified(
        reservation: AudioCacheReservation,
        verification: CachedAudioVerification.Verified,
        nowEpochMilliseconds: Long,
    ) {
        require(nowEpochMilliseconds >= 0) { "cache verification time must not be negative" }
        require(verification.bytes == reservation.expectedBytes) {
            "verified audio bytes do not match the cache reservation"
        }
        require(verification.sha256 == reservation.expectedSha256) {
            "verified audio SHA-256 does not match the cache reservation"
        }
        val existing = metadataStore.records()
            .validated()
            .firstOrNull { it.requestID == reservation.requestID }
            ?: error("verified audio does not have a cache reservation")
        check(existing.hasSameContract(reservation)) {
            "verified audio conflicts with its cache reservation"
        }
        metadataStore.write(
            existing.copy(
                state = AudioCacheRecordState.VERIFIED,
                lastAccessEpochMilliseconds = maxOf(
                    existing.lastAccessEpochMilliseconds,
                    nowEpochMilliseconds,
                ),
            ),
        )
    }

    @WorkerThread
    @Synchronized
    fun recordAccess(
        requestID: String,
        nowEpochMilliseconds: Long,
    ): Boolean {
        require(requestID.isNotBlank()) { "accessed audio requestID must not be blank" }
        require(nowEpochMilliseconds >= 0) { "cache access time must not be negative" }
        val existing = metadataStore.records()
            .validated()
            .firstOrNull { it.requestID == requestID }
            ?: return false
        check(existing.state == AudioCacheRecordState.VERIFIED) {
            "unverified audio must not be recorded as played"
        }
        metadataStore.write(
            existing.copy(
                lastAccessEpochMilliseconds = maxOf(
                    existing.lastAccessEpochMilliseconds,
                    nowEpochMilliseconds,
                ),
            ),
        )
        return true
    }

    @WorkerThread
    @Synchronized
    fun removeExpired(
        protectedKeys: Set<AudioCacheKey>,
        nowEpochMilliseconds: Long,
    ): AudioCacheMaintenanceResult {
        require(nowEpochMilliseconds >= 0) { "cache policy time must not be negative" }
        val records = try {
            metadataStore.records().validated()
        } catch (exception: Exception) {
            return maintenanceFailure(AudioCachePolicyOperation.READ_METADATA, exception)
        }
        val expiredRecords = records
            .filter { record ->
                record.key !in protectedKeys &&
                    nowEpochMilliseconds >= record.lastAccessEpochMilliseconds &&
                    nowEpochMilliseconds - record.lastAccessEpochMilliseconds >=
                    AudioCachePolicy.MAX_INACTIVE_MILLISECONDS
            }
            .sortedWith(CACHE_RECORD_ORDER)

        val evictedRequestIDs = mutableListOf<String>()
        expiredRecords.forEach { record ->
            try {
                resourceEvictor.evict(record.requestID)
            } catch (exception: Exception) {
                return maintenanceFailure(
                    AudioCachePolicyOperation.EVICT_RESOURCE,
                    exception,
                    evictedRequestIDs,
                )
            }
            try {
                metadataStore.remove(record.requestID)
            } catch (exception: Exception) {
                return maintenanceFailure(
                    AudioCachePolicyOperation.REMOVE_METADATA,
                    exception,
                    evictedRequestIDs + record.requestID,
                )
            }
            evictedRequestIDs += record.requestID
        }
        return AudioCacheMaintenanceResult.Completed(evictedRequestIDs)
    }

    private fun normalizeRecords(
        records: List<AudioCacheRecord>,
        reservation: AudioCacheReservation,
        protectedKeys: Set<AudioCacheKey>,
    ): CacheRecordNormalization {
        val mandatoryEvictions = mutableListOf<AudioCacheRecord>()
        val canonicalRecords = mutableListOf<AudioCacheRecord>()

        records.groupBy(AudioCacheRecord::key)
            .toSortedMap(compareBy(AudioCacheKey::productID, AudioCacheKey::artifactID))
            .forEach { (key, group) ->
                val requestedRecord = group.firstOrNull { it.requestID == reservation.requestID }
                if (key == reservation.key) {
                    val superseded = group.filterNot { it.requestID == reservation.requestID }
                    if (superseded.isNotEmpty() && key in protectedKeys) {
                        return CacheRecordNormalization.Rejected(
                            AudioCacheAdmissionRejectionReason.PROTECTED_REPLACEMENT,
                        )
                    }
                    mandatoryEvictions += superseded
                    requestedRecord?.let(canonicalRecords::add)
                    return@forEach
                }

                if (group.size == 1) {
                    canonicalRecords += group.single()
                    return@forEach
                }
                if (key in protectedKeys) {
                    return CacheRecordNormalization.Rejected(
                        AudioCacheAdmissionRejectionReason.PROTECTED_DUPLICATE,
                    )
                }
                val retained = group.maxWithOrNull(
                    compareBy<AudioCacheRecord>(AudioCacheRecord::lastAccessEpochMilliseconds)
                        .thenBy(AudioCacheRecord::requestID),
                ) ?: return@forEach
                canonicalRecords += retained
                mandatoryEvictions += group.filterNot { it.requestID == retained.requestID }
            }

        return CacheRecordNormalization.Accepted(
            canonicalRecords = canonicalRecords,
            mandatoryEvictions = mandatoryEvictions.sortedWith(CACHE_RECORD_ORDER),
        )
    }

    private fun List<AudioCacheRecord>.validated(): List<AudioCacheRecord> = also { records ->
        require(records.map(AudioCacheRecord::requestID).toSet().size == records.size) {
            "cached audio request IDs must be unique"
        }
    }

    private fun AudioCacheRejectionReason.toAdmissionReason(): AudioCacheAdmissionRejectionReason =
        when (this) {
            AudioCacheRejectionReason.PRODUCT_BUDGET_EXHAUSTED ->
                AudioCacheAdmissionRejectionReason.PRODUCT_BUDGET_EXHAUSTED
            AudioCacheRejectionReason.GLOBAL_BUDGET_EXHAUSTED ->
                AudioCacheAdmissionRejectionReason.GLOBAL_BUDGET_EXHAUSTED
        }

    private fun admissionFailure(
        requestID: String,
        operation: AudioCachePolicyOperation,
        exception: Exception,
        evictedRequestIDs: List<String> = emptyList(),
    ) = AudioCacheAdmissionResult.Failed(
        requestID = requestID,
        operation = operation,
        exceptionType = exception.typeName(),
        evictedRequestIDs = evictedRequestIDs,
    )

    private fun maintenanceFailure(
        operation: AudioCachePolicyOperation,
        exception: Exception,
        evictedRequestIDs: List<String> = emptyList(),
    ) = AudioCacheMaintenanceResult.Failed(
        operation = operation,
        exceptionType = exception.typeName(),
        evictedRequestIDs = evictedRequestIDs,
    )

    private fun Exception.typeName(): String = this::class.java.simpleName.ifBlank { "unknown" }

    private sealed interface CacheRecordNormalization {
        data class Accepted(
            val canonicalRecords: List<AudioCacheRecord>,
            val mandatoryEvictions: List<AudioCacheRecord>,
        ) : CacheRecordNormalization

        data class Rejected(
            val reason: AudioCacheAdmissionRejectionReason,
        ) : CacheRecordNormalization
    }

    private companion object {
        val CACHE_RECORD_ORDER = compareBy<AudioCacheRecord>(
            AudioCacheRecord::lastAccessEpochMilliseconds,
            { it.key.productID },
            { it.key.artifactID },
            AudioCacheRecord::requestID,
        )
    }
}

fun Media3AudioDownloadSpec.toCacheReservation(): AudioCacheReservation = AudioCacheReservation(
    requestID = requestID,
    key = key,
    renditionID = renditionID,
    expectedBytes = expectedBytes,
    expectedSha256 = expectedSha256,
)

private const val CACHE_KEY_SEPARATOR = ':'
private val SHA_256_PATTERN = Regex("^[0-9a-f]{64}$")
