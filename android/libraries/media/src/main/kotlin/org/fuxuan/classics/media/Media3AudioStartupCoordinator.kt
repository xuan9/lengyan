package org.fuxuan.classics.media

import android.os.Handler
import android.os.Looper
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import java.util.concurrent.Executor

enum class AudioStartupActivationOperation {
    SCHEDULE_RECONCILIATION,
    RECONCILE,
    VALIDATE_DOWNLOAD_MANAGER,
    REGISTER_INTEGRITY,
    RESUME_DOWNLOADS,
}

sealed interface AudioStartupActivationResult {
    data class Activated(
        val reconciliation: AudioStartupReconciliationResult.Completed,
        val completedIntegrityRequestIDs: List<String>,
    ) : AudioStartupActivationResult

    data class Blocked(
        val reconciliation: AudioStartupReconciliationResult,
    ) : AudioStartupActivationResult

    data class Failed(
        val operation: AudioStartupActivationOperation,
        val exceptionType: String,
    ) : AudioStartupActivationResult {
        init {
            require(exceptionType.isNotBlank()) {
                "audio startup activation failure type must not be blank"
            }
        }
    }
}

fun interface AudioStartupActivationListener {
    fun onActivationResult(result: AudioStartupActivationResult)
}

/**
 * Activates a paused runtime once. Release suppresses a pending worker result and never resumes.
 */
@OptIn(UnstableApi::class)
class Media3AudioStartupCoordinator(
    runtime: Media3AudioDownloadRuntime,
    cachePolicyExecutor: AudioCachePolicyExecutor,
    private val integrityCoordinator: Media3AudioDownloadIntegrityCoordinator,
    private val reconciliationExecutor: Executor,
    private val listener: AudioStartupActivationListener,
) {
    private val downloadManager = runtime.downloadManager
    private val applicationLooper = downloadManager.applicationLooper
    private val applicationHandler = Handler(applicationLooper)
    private val reconciler = Media3AudioStartupReconciler(runtime, cachePolicyExecutor)
    private var state = ActivationState.READY

    init {
        requireApplicationThread()
    }

    fun start(
        catalog: List<Media3AudioDownloadSpec>,
        protectedKeys: Set<AudioCacheKey>,
        nowEpochMilliseconds: Long,
    ) {
        requireApplicationThread()
        check(state == ActivationState.READY) {
            "audio startup activation can only be started once"
        }
        state = ActivationState.RUNNING
        val catalogSnapshot = catalog.toList()
        val protectedKeysSnapshot = protectedKeys.toSet()
        try {
            reconciliationExecutor.execute {
                val outcome = try {
                    ReconciliationOutcome.Result(
                        reconciler.reconcile(
                            catalog = catalogSnapshot,
                            protectedKeys = protectedKeysSnapshot,
                            nowEpochMilliseconds = nowEpochMilliseconds,
                        ),
                    )
                } catch (exception: Exception) {
                    ReconciliationOutcome.Failure(
                        operation = AudioStartupActivationOperation.RECONCILE,
                        exceptionType = exception.typeName(),
                    )
                }
                applicationHandler.post {
                    complete(catalogSnapshot, outcome)
                }
            }
        } catch (exception: Exception) {
            finish(
                AudioStartupActivationResult.Failed(
                    operation = AudioStartupActivationOperation.SCHEDULE_RECONCILIATION,
                    exceptionType = exception.typeName(),
                ),
            )
        }
    }

    fun release() {
        requireApplicationThread()
        if (state == ActivationState.RELEASED) return
        state = ActivationState.RELEASED
    }

    private fun complete(
        catalog: List<Media3AudioDownloadSpec>,
        outcome: ReconciliationOutcome,
    ) {
        requireApplicationThread()
        if (state != ActivationState.RUNNING) return
        when (outcome) {
            is ReconciliationOutcome.Failure -> finish(
                AudioStartupActivationResult.Failed(
                    operation = outcome.operation,
                    exceptionType = outcome.exceptionType,
                ),
            )
            is ReconciliationOutcome.Result -> activate(catalog, outcome.result)
        }
    }

    private fun activate(
        catalog: List<Media3AudioDownloadSpec>,
        reconciliation: AudioStartupReconciliationResult,
    ) {
        val completed = reconciliation as? AudioStartupReconciliationResult.Completed
        if (completed == null || !completed.readyToResume) {
            finish(AudioStartupActivationResult.Blocked(reconciliation))
            return
        }
        if (
            !downloadManager.isInitialized ||
            !downloadManager.downloadsPaused
        ) {
            finish(
                AudioStartupActivationResult.Failed(
                    operation = AudioStartupActivationOperation.VALIDATE_DOWNLOAD_MANAGER,
                    exceptionType = IllegalStateException::class.java.simpleName,
                ),
            )
            return
        }

        val completedRequestIDs = try {
            integrityCoordinator.trackStartupTransfers(catalog, completed.transfers)
        } catch (exception: Exception) {
            finish(
                AudioStartupActivationResult.Failed(
                    operation = AudioStartupActivationOperation.REGISTER_INTEGRITY,
                    exceptionType = exception.typeName(),
                ),
            )
            return
        }

        try {
            downloadManager.resumeDownloads()
        } catch (exception: Exception) {
            finish(
                AudioStartupActivationResult.Failed(
                    operation = AudioStartupActivationOperation.RESUME_DOWNLOADS,
                    exceptionType = exception.typeName(),
                ),
            )
            return
        }
        finish(
            AudioStartupActivationResult.Activated(
                reconciliation = completed,
                completedIntegrityRequestIDs = completedRequestIDs,
            ),
        )
    }

    private fun finish(result: AudioStartupActivationResult) {
        requireApplicationThread()
        if (state != ActivationState.RUNNING) return
        state = ActivationState.FINISHED
        listener.onActivationResult(result)
    }

    private fun requireApplicationThread() {
        check(Looper.myLooper() == applicationLooper) {
            "audio startup coordinator must use the DownloadManager application thread"
        }
    }

    private fun Exception.typeName(): String =
        this::class.java.simpleName.ifBlank { "unknown" }

    private enum class ActivationState {
        READY,
        RUNNING,
        FINISHED,
        RELEASED,
    }

    private sealed interface ReconciliationOutcome {
        data class Result(
            val result: AudioStartupReconciliationResult,
        ) : ReconciliationOutcome

        data class Failure(
            val operation: AudioStartupActivationOperation,
            val exceptionType: String,
        ) : ReconciliationOutcome
    }
}
