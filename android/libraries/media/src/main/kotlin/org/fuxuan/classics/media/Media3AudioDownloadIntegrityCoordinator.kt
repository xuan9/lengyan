package org.fuxuan.classics.media

import android.os.Handler
import android.os.Looper
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.offline.Download
import androidx.media3.exoplayer.offline.DownloadManager
import java.util.concurrent.Executor

sealed interface AudioDownloadIntegrityIssue {
    data class CacheVerification(
        val result: CachedAudioVerification,
    ) : AudioDownloadIntegrityIssue {
        init {
            require(result !is CachedAudioVerification.Verified) {
                "verified audio is not an integrity issue"
            }
        }
    }

    data class OperationFailure(
        val operation: AudioDownloadIntegrityOperation,
        val exceptionType: String,
    ) : AudioDownloadIntegrityIssue {
        init {
            require(exceptionType.isNotBlank()) { "integrity failure type must not be blank" }
        }
    }
}

enum class AudioDownloadIntegrityOperation {
    VERIFY_CACHE,
    REMOVE_CORRUPT_DOWNLOAD,
    ENQUEUE_REPAIR,
}

sealed interface AudioDownloadIntegrityEvent {
    val requestID: String

    data class Repairing(
        override val requestID: String,
        val issue: AudioDownloadIntegrityIssue,
        val repairAttempt: Int,
    ) : AudioDownloadIntegrityEvent {
        init {
            require(repairAttempt > 0) { "repair attempt must be positive" }
        }
    }

    data class Verified(
        override val requestID: String,
        val bytes: Long,
        val sha256: String,
        val repairAttempts: Int,
    ) : AudioDownloadIntegrityEvent {
        init {
            require(bytes > 0) { "verified audio bytes must be positive" }
            require(repairAttempts >= 0) { "repair attempts must not be negative" }
        }
    }

    data class Rejected(
        override val requestID: String,
        val issue: AudioDownloadIntegrityIssue,
        val repairAttempts: Int,
    ) : AudioDownloadIntegrityEvent {
        init {
            require(repairAttempts >= 0) { "repair attempts must not be negative" }
        }
    }
}

fun interface AudioDownloadRepairEnqueuer {
    fun enqueue(
        spec: Media3AudioDownloadSpec,
        transferPurpose: AudioTransferPurpose?,
    )
}

fun interface AudioDownloadIntegrityListener {
    fun onIntegrityEvent(event: AudioDownloadIntegrityEvent)
}

@OptIn(UnstableApi::class)
class Media3AudioDownloadIntegrityCoordinator(
    runtime: Media3AudioDownloadRuntime,
    private val verificationExecutor: Executor,
    private val repairEnqueuer: AudioDownloadRepairEnqueuer,
    private val listener: AudioDownloadIntegrityListener,
    private val maximumRepairAttempts: Int = 1,
) : DownloadManager.Listener {
    private val cache = runtime.cache
    private val downloadManager = runtime.downloadManager
    private val applicationLooper = downloadManager.applicationLooper
    private val applicationHandler = Handler(applicationLooper)
    private val tracked = mutableMapOf<String, TrackedDownload>()
    private var nextGeneration = 0L
    private var released = false

    init {
        requireApplicationThread()
        require(maximumRepairAttempts >= 0) {
            "maximum integrity repair attempts must not be negative"
        }
        downloadManager.addListener(this)
    }

    fun track(
        spec: Media3AudioDownloadSpec,
        transferPurpose: AudioTransferPurpose? = null,
    ) {
        requireApplicationThread()
        check(!released) { "audio download integrity coordinator is released" }

        tracked[spec.requestID]?.let { existing ->
            require(existing.spec.hasSameContract(spec)) {
                "audio download request ID maps to conflicting integrity contracts"
            }
            existing.transferPurpose = existing.transferPurpose.promotedWith(transferPurpose)
            return
        }
        tracked[spec.requestID] = TrackedDownload(
            spec = spec,
            generation = nextGeneration++,
            transferPurpose = transferPurpose,
        )
    }

    fun untrack(requestID: String) {
        requireApplicationThread()
        check(!released) { "audio download integrity coordinator is released" }
        tracked.remove(requestID)
    }

    fun isVerified(requestID: String): Boolean {
        requireApplicationThread()
        check(!released) { "audio download integrity coordinator is released" }
        return tracked[requestID]?.phase == IntegrityPhase.VERIFIED
    }

    fun release() {
        requireApplicationThread()
        if (released) return
        released = true
        tracked.clear()
        downloadManager.removeListener(this)
    }

    override fun onDownloadChanged(
        downloadManager: DownloadManager,
        download: Download,
        finalException: Exception?,
    ) {
        if (!isActiveCallback(downloadManager)) return
        tracked[download.request.id]?.let { entry ->
            entry.transferPurpose = entry.transferPurpose.promotedWith(
                download.request.classicsAudioTransferPurpose(),
            )
        }
        if (download.state == Download.STATE_COMPLETED) {
            beginVerification(download.request.id)
        }
    }

    override fun onDownloadRemoved(
        downloadManager: DownloadManager,
        download: Download,
    ) {
        if (!isActiveCallback(downloadManager)) return
        val entry = tracked[download.request.id] ?: return
        when (entry.phase) {
            IntegrityPhase.REMOVING_FOR_REPAIR -> enqueueRepair(entry)
            IntegrityPhase.REMOVING_FOR_REJECTION -> rejectAfterRemoval(entry)
            IntegrityPhase.IDLE,
            IntegrityPhase.VERIFYING,
            IntegrityPhase.VERIFIED -> resetUnavailable(entry)
            IntegrityPhase.REJECTED -> Unit
        }
    }

    private fun beginVerification(requestID: String) {
        val entry = tracked[requestID] ?: return
        if (entry.phase != IntegrityPhase.IDLE) return

        entry.phase = IntegrityPhase.VERIFYING
        val generation = entry.generation
        try {
            verificationExecutor.execute {
                val outcome = try {
                    VerificationOutcome.Result(
                        Media3CachedAudioVerifier.verify(cache, entry.spec),
                    )
                } catch (exception: Exception) {
                    VerificationOutcome.Failure(
                        exception.asOperationIssue(
                            AudioDownloadIntegrityOperation.VERIFY_CACHE,
                        ),
                    )
                }
                applicationHandler.post {
                    completeVerification(requestID, generation, outcome)
                }
            }
        } catch (exception: Exception) {
            removeForRejection(
                entry,
                exception.asOperationIssue(AudioDownloadIntegrityOperation.VERIFY_CACHE),
            )
        }
    }

    private fun completeVerification(
        requestID: String,
        generation: Long,
        outcome: VerificationOutcome,
    ) {
        requireApplicationThread()
        val entry = tracked[requestID] ?: return
        if (entry.generation != generation || entry.phase != IntegrityPhase.VERIFYING) return

        when (outcome) {
            is VerificationOutcome.Failure -> removeForRejection(entry, outcome.issue)
            is VerificationOutcome.Result -> {
                val verification = outcome.verification
                if (verification is CachedAudioVerification.Verified) {
                    entry.phase = IntegrityPhase.VERIFIED
                    listener.onIntegrityEvent(
                        AudioDownloadIntegrityEvent.Verified(
                            requestID = requestID,
                            bytes = verification.bytes,
                            sha256 = verification.sha256,
                            repairAttempts = entry.repairAttempts,
                        ),
                    )
                } else {
                    handleVerificationIssue(
                        entry,
                        AudioDownloadIntegrityIssue.CacheVerification(verification),
                    )
                }
            }
        }
    }

    private fun handleVerificationIssue(
        entry: TrackedDownload,
        issue: AudioDownloadIntegrityIssue,
    ) {
        if (entry.repairAttempts >= maximumRepairAttempts) {
            removeForRejection(entry, issue)
            return
        }

        entry.repairAttempts += 1
        entry.pendingIssue = issue
        entry.phase = IntegrityPhase.REMOVING_FOR_REPAIR
        if (removeTrackedDownload(entry)) {
            listener.onIntegrityEvent(
                AudioDownloadIntegrityEvent.Repairing(
                    requestID = entry.spec.requestID,
                    issue = issue,
                    repairAttempt = entry.repairAttempts,
                ),
            )
        }
    }

    private fun removeForRejection(
        entry: TrackedDownload,
        issue: AudioDownloadIntegrityIssue,
    ) {
        entry.pendingIssue = issue
        entry.phase = IntegrityPhase.REMOVING_FOR_REJECTION
        removeTrackedDownload(entry)
    }

    private fun removeTrackedDownload(entry: TrackedDownload): Boolean =
        try {
            downloadManager.removeDownload(entry.spec.requestID)
            true
        } catch (exception: Exception) {
            entry.phase = IntegrityPhase.REJECTED
            listener.onIntegrityEvent(
                AudioDownloadIntegrityEvent.Rejected(
                    requestID = entry.spec.requestID,
                    issue = exception.asOperationIssue(
                        AudioDownloadIntegrityOperation.REMOVE_CORRUPT_DOWNLOAD,
                    ),
                    repairAttempts = entry.repairAttempts,
                ),
            )
            false
        }

    private fun enqueueRepair(entry: TrackedDownload) {
        entry.phase = IntegrityPhase.IDLE
        entry.pendingIssue = null
        try {
            repairEnqueuer.enqueue(entry.spec, entry.transferPurpose)
        } catch (exception: Exception) {
            entry.phase = IntegrityPhase.REJECTED
            listener.onIntegrityEvent(
                AudioDownloadIntegrityEvent.Rejected(
                    requestID = entry.spec.requestID,
                    issue = exception.asOperationIssue(
                        AudioDownloadIntegrityOperation.ENQUEUE_REPAIR,
                    ),
                    repairAttempts = entry.repairAttempts,
                ),
            )
        }
    }

    private fun rejectAfterRemoval(entry: TrackedDownload) {
        val issue = checkNotNull(entry.pendingIssue)
        entry.pendingIssue = null
        entry.phase = IntegrityPhase.REJECTED
        listener.onIntegrityEvent(
            AudioDownloadIntegrityEvent.Rejected(
                requestID = entry.spec.requestID,
                issue = issue,
                repairAttempts = entry.repairAttempts,
            ),
        )
    }

    private fun resetUnavailable(entry: TrackedDownload) {
        entry.generation = nextGeneration++
        entry.phase = IntegrityPhase.IDLE
        entry.repairAttempts = 0
        entry.pendingIssue = null
    }

    private fun isActiveCallback(manager: DownloadManager): Boolean {
        requireApplicationThread()
        check(manager === downloadManager) { "integrity callback came from another manager" }
        return !released
    }

    private fun requireApplicationThread() {
        check(Looper.myLooper() == applicationLooper) {
            "audio download integrity coordinator must use the DownloadManager application thread"
        }
    }

    private fun Media3AudioDownloadSpec.hasSameContract(
        other: Media3AudioDownloadSpec,
    ): Boolean = requestID == other.requestID &&
        uri == other.uri &&
        mediaType == other.mediaType &&
        expectedBytes == other.expectedBytes &&
        expectedSha256 == other.expectedSha256

    private fun Exception.asOperationIssue(
        operation: AudioDownloadIntegrityOperation,
    ): AudioDownloadIntegrityIssue.OperationFailure =
        AudioDownloadIntegrityIssue.OperationFailure(
            operation = operation,
            exceptionType = this::class.java.simpleName.ifBlank { "unknown" },
        )

    private data class TrackedDownload(
        val spec: Media3AudioDownloadSpec,
        var generation: Long,
        var transferPurpose: AudioTransferPurpose?,
        var phase: IntegrityPhase = IntegrityPhase.IDLE,
        var repairAttempts: Int = 0,
        var pendingIssue: AudioDownloadIntegrityIssue? = null,
    )

    private enum class IntegrityPhase {
        IDLE,
        VERIFYING,
        REMOVING_FOR_REPAIR,
        REMOVING_FOR_REJECTION,
        VERIFIED,
        REJECTED,
    }

    private sealed interface VerificationOutcome {
        data class Result(
            val verification: CachedAudioVerification,
        ) : VerificationOutcome

        data class Failure(
            val issue: AudioDownloadIntegrityIssue.OperationFailure,
        ) : VerificationOutcome
    }

    private fun AudioTransferPurpose?.promotedWith(
        incoming: AudioTransferPurpose?,
    ): AudioTransferPurpose? = when {
        this == AudioTransferPurpose.USER_PLAYBACK ||
            incoming == AudioTransferPurpose.USER_PLAYBACK -> AudioTransferPurpose.USER_PLAYBACK
        this == AudioTransferPurpose.AUTOMATIC_NEXT_PREFETCH ||
            incoming == AudioTransferPurpose.AUTOMATIC_NEXT_PREFETCH ->
            AudioTransferPurpose.AUTOMATIC_NEXT_PREFETCH
        else -> null
    }
}
