package org.fuxuan.classics.media

import android.os.Looper
import androidx.annotation.OptIn
import androidx.annotation.WorkerThread
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.offline.Download
import androidx.media3.exoplayer.offline.DownloadIndex

enum class AudioStartupTransferState {
    QUEUED,
    STOPPED,
    DOWNLOADING,
    COMPLETED,
    FAILED,
    REMOVING,
    RESTARTING,
}

data class ReconciledAudioStartupTransfer(
    val requestID: String,
    val purpose: AudioTransferPurpose,
    val state: AudioStartupTransferState,
    val stopReason: Int,
    val metadataWasVerified: Boolean,
)

sealed interface AudioStartupReconciliationIssue {
    val requestID: String

    data class CatalogEntryMissing(
        override val requestID: String,
    ) : AudioStartupReconciliationIssue

    data class ConflictingRequestContract(
        override val requestID: String,
    ) : AudioStartupReconciliationIssue

    data class UnsupportedRequestMetadata(
        override val requestID: String,
    ) : AudioStartupReconciliationIssue

    data class TransitionalDownloadState(
        override val requestID: String,
        val state: AudioStartupTransferState,
    ) : AudioStartupReconciliationIssue

    data class DuplicateDownloadIndexEntry(
        override val requestID: String,
    ) : AudioStartupReconciliationIssue

    data class CacheAdmissionRejected(
        override val requestID: String,
        val reason: AudioCacheAdmissionRejectionReason,
    ) : AudioStartupReconciliationIssue

    data class CacheAdmissionFailed(
        override val requestID: String,
        val operation: AudioCachePolicyOperation,
        val exceptionType: String,
        val evictedRequestIDs: List<String>,
    ) : AudioStartupReconciliationIssue
}

enum class AudioStartupReconciliationOperation {
    READ_DOWNLOAD_INDEX,
}

sealed interface AudioStartupReconciliationResult {
    data class Completed(
        val transfers: List<ReconciledAudioStartupTransfer>,
        val issues: List<AudioStartupReconciliationIssue>,
        val evictedRequestIDs: List<String>,
    ) : AudioStartupReconciliationResult {
        val readyToResume: Boolean
            get() = issues.isEmpty()
    }

    data class Failed(
        val operation: AudioStartupReconciliationOperation,
        val exceptionType: String,
    ) : AudioStartupReconciliationResult
}

@OptIn(UnstableApi::class)
class Media3AudioStartupReconciler(
    runtime: Media3AudioDownloadRuntime,
    cachePolicyExecutor: AudioCachePolicyExecutor,
) {
    private val downloadManager = runtime.downloadManager
    private val applicationLooper = downloadManager.applicationLooper
    private val reconciler = AudioStartupReservationReconciler(
        downloadIndex = Media3AudioStartupDownloadIndex(downloadManager.downloadIndex),
        cachePolicyExecutor = cachePolicyExecutor,
    )

    init {
        check(Looper.myLooper() == applicationLooper) {
            "audio startup reconciler must be created on the DownloadManager application thread"
        }
        check(downloadManager.isInitialized) {
            "audio startup reconciler requires an initialized DownloadManager"
        }
        check(downloadManager.downloadsPaused) {
            "audio startup reconciler requires DownloadManager to remain paused"
        }
        check(downloadManager.isIdle) {
            "audio startup reconciler requires an idle DownloadManager"
        }
    }

    /**
     * Rebuilds catalog-backed reservations while DownloadManager is still paused.
     * Product code must inspect readyToResume before it resumes downloads.
     */
    @WorkerThread
    fun reconcile(
        catalog: List<Media3AudioDownloadSpec>,
        protectedKeys: Set<AudioCacheKey>,
        nowEpochMilliseconds: Long,
    ): AudioStartupReconciliationResult {
        check(Looper.myLooper() != applicationLooper) {
            "audio startup reconciliation must not block the DownloadManager application thread"
        }
        return reconciler.reconcile(catalog, protectedKeys, nowEpochMilliseconds)
    }
}

internal data class IndexedAudioStartupTransfer(
    val contract: AudioTransferRequestContract,
    val ownership: AudioTransferRequestOwnership,
    val state: AudioStartupTransferState,
    val stopReason: Int,
)

internal fun interface AudioStartupDownloadIndex {
    fun downloads(): List<IndexedAudioStartupTransfer>
}

internal class AudioStartupReservationReconciler(
    private val downloadIndex: AudioStartupDownloadIndex,
    private val cachePolicyExecutor: AudioCachePolicyExecutor,
) {
    fun reconcile(
        catalog: List<Media3AudioDownloadSpec>,
        protectedKeys: Set<AudioCacheKey>,
        nowEpochMilliseconds: Long,
    ): AudioStartupReconciliationResult {
        require(nowEpochMilliseconds >= 0) {
            "audio startup reconciliation time must not be negative"
        }
        require(catalog.isNotEmpty()) { "audio startup catalog must not be empty" }
        val catalogByRequestID = catalog.associateBy(Media3AudioDownloadSpec::requestID)
        require(catalogByRequestID.size == catalog.size) {
            "audio startup catalog request IDs must be unique"
        }
        val productIDs = catalog.mapTo(mutableSetOf()) { spec -> spec.key.productID }
        require(productIDs.size == 1) {
            "audio startup catalog must belong to exactly one product"
        }
        val productID = productIDs.single()
        require(protectedKeys.all { key -> key.productID == productID }) {
            "protected audio startup keys must belong to the catalog product"
        }
        val catalogKeys = catalog.mapTo(mutableSetOf()) { spec -> spec.key }
        require(protectedKeys.all(catalogKeys::contains)) {
            "protected audio startup keys must exist in the catalog"
        }

        val indexedTransfers = try {
            downloadIndex.downloads().sortedBy { transfer -> transfer.contract.requestID }
        } catch (exception: Exception) {
            return AudioStartupReconciliationResult.Failed(
                operation = AudioStartupReconciliationOperation.READ_DOWNLOAD_INDEX,
                exceptionType = exception.typeName(),
            )
        }

        val issues = indexedTransfers
            .groupBy { transfer -> transfer.contract.requestID }
            .filterValues { transfers -> transfers.size > 1 }
            .keys
            .mapTo(mutableListOf<AudioStartupReconciliationIssue>()) { requestID ->
                AudioStartupReconciliationIssue.DuplicateDownloadIndexEntry(requestID)
            }
        val duplicateRequestIDs = issues.mapTo(mutableSetOf()) { issue -> issue.requestID }
        val candidates = indexedTransfers.mapNotNull { transfer ->
            val requestID = transfer.contract.requestID
            if (requestID in duplicateRequestIDs) return@mapNotNull null
            if (transfer.state.isTransitional) {
                issues += AudioStartupReconciliationIssue.TransitionalDownloadState(
                    requestID = requestID,
                    state = transfer.state,
                )
                return@mapNotNull null
            }
            val spec = catalogByRequestID[requestID]
            if (spec == null) {
                issues += AudioStartupReconciliationIssue.CatalogEntryMissing(requestID)
                return@mapNotNull null
            }
            if (transfer.contract != spec.toTransferRequestContract()) {
                issues += AudioStartupReconciliationIssue.ConflictingRequestContract(requestID)
                return@mapNotNull null
            }
            val purpose = transfer.ownership.recoverablePurpose
            if (purpose == null) {
                issues += AudioStartupReconciliationIssue.UnsupportedRequestMetadata(requestID)
                return@mapNotNull null
            }
            ReconciliationCandidate(spec, transfer, purpose)
        }

        if (issues.isNotEmpty()) {
            return AudioStartupReconciliationResult.Completed(
                transfers = emptyList(),
                issues = issues.sortedBy(AudioStartupReconciliationIssue::requestID),
                evictedRequestIDs = emptyList(),
            )
        }

        val startupProtectedKeys = protectedKeys + candidates.map { candidate ->
            candidate.spec.key
        }
        val transfers = mutableListOf<ReconciledAudioStartupTransfer>()
        val evictedRequestIDs = mutableListOf<String>()
        candidates.forEach { candidate ->
            when (val admission = cachePolicyExecutor.restoreReservation(
                reservation = candidate.spec.toCacheReservation(),
                protectedKeys = startupProtectedKeys,
                nowEpochMilliseconds = nowEpochMilliseconds,
            )) {
                is AudioCacheAdmissionResult.Accepted -> {
                    evictedRequestIDs += admission.evictedRequestIDs
                    transfers += ReconciledAudioStartupTransfer(
                        requestID = candidate.spec.requestID,
                        purpose = candidate.purpose,
                        state = candidate.transfer.state,
                        stopReason = candidate.transfer.stopReason,
                        metadataWasVerified = admission.alreadyVerified,
                    )
                }

                is AudioCacheAdmissionResult.Rejected -> {
                    issues += AudioStartupReconciliationIssue.CacheAdmissionRejected(
                        requestID = admission.requestID,
                        reason = admission.reason,
                    )
                }

                is AudioCacheAdmissionResult.Failed -> {
                    evictedRequestIDs += admission.evictedRequestIDs
                    issues += AudioStartupReconciliationIssue.CacheAdmissionFailed(
                        requestID = admission.requestID,
                        operation = admission.operation,
                        exceptionType = admission.exceptionType,
                        evictedRequestIDs = admission.evictedRequestIDs,
                    )
                }
            }
        }

        return AudioStartupReconciliationResult.Completed(
            transfers = transfers.sortedBy(ReconciledAudioStartupTransfer::requestID),
            issues = issues.sortedBy(AudioStartupReconciliationIssue::requestID),
            evictedRequestIDs = evictedRequestIDs.distinct(),
        )
    }

    private data class ReconciliationCandidate(
        val spec: Media3AudioDownloadSpec,
        val transfer: IndexedAudioStartupTransfer,
        val purpose: AudioTransferPurpose,
    )

    private val AudioStartupTransferState.isTransitional: Boolean
        get() = this == AudioStartupTransferState.REMOVING ||
            this == AudioStartupTransferState.RESTARTING

    private val AudioTransferRequestOwnership.recoverablePurpose: AudioTransferPurpose?
        get() = when (this) {
            AudioTransferRequestOwnership.MANAGED_AUTOMATIC_PREFETCH ->
                AudioTransferPurpose.AUTOMATIC_NEXT_PREFETCH
            AudioTransferRequestOwnership.MANAGED_USER_PLAYBACK,
            AudioTransferRequestOwnership.LEGACY_USER_PLAYBACK ->
                AudioTransferPurpose.USER_PLAYBACK
            AudioTransferRequestOwnership.UNSUPPORTED_METADATA -> null
        }

    private fun Exception.typeName(): String =
        this::class.java.simpleName.ifBlank { "unknown" }
}

@OptIn(UnstableApi::class)
private class Media3AudioStartupDownloadIndex(
    private val downloadIndex: DownloadIndex,
) : AudioStartupDownloadIndex {
    override fun downloads(): List<IndexedAudioStartupTransfer> =
        downloadIndex.getDownloads().use { cursor ->
            buildList {
                while (cursor.moveToNext()) {
                    val download = cursor.download
                    add(
                        IndexedAudioStartupTransfer(
                            contract = download.request.toAudioTransferRequestContract(),
                            ownership = AudioTransferRequestMetadata.ownership(
                                download.request.data,
                            ),
                            state = download.state.toStartupTransferState(),
                            stopReason = download.stopReason,
                        ),
                    )
                }
            }
        }

    private fun Int.toStartupTransferState(): AudioStartupTransferState = when (this) {
        Download.STATE_QUEUED -> AudioStartupTransferState.QUEUED
        Download.STATE_STOPPED -> AudioStartupTransferState.STOPPED
        Download.STATE_DOWNLOADING -> AudioStartupTransferState.DOWNLOADING
        Download.STATE_COMPLETED -> AudioStartupTransferState.COMPLETED
        Download.STATE_FAILED -> AudioStartupTransferState.FAILED
        Download.STATE_REMOVING -> AudioStartupTransferState.REMOVING
        Download.STATE_RESTARTING -> AudioStartupTransferState.RESTARTING
        else -> error("unknown Media3 audio download state $this")
    }
}
