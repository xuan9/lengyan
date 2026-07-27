package org.fuxuan.classics.media

import android.os.Looper
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.offline.Download
import androidx.media3.exoplayer.offline.DownloadManager
import androidx.media3.exoplayer.offline.DownloadRequest
import java.nio.charset.StandardCharsets

internal object AudioTransferRequestMetadata {
    private val userPlayback = encodeValue("user")
    private val automaticPrefetch = encodeValue("prefetch")

    fun encode(purpose: AudioTransferPurpose): ByteArray = when (purpose) {
        AudioTransferPurpose.USER_PLAYBACK -> userPlayback.copyOf()
        AudioTransferPurpose.AUTOMATIC_NEXT_PREFETCH -> automaticPrefetch.copyOf()
    }

    fun ownership(data: ByteArray): AudioTransferRequestOwnership = when {
        data.isEmpty() -> AudioTransferRequestOwnership.LEGACY_USER_PLAYBACK
        data.contentEquals(userPlayback) ->
            AudioTransferRequestOwnership.MANAGED_USER_PLAYBACK
        data.contentEquals(automaticPrefetch) ->
            AudioTransferRequestOwnership.MANAGED_AUTOMATIC_PREFETCH
        else -> AudioTransferRequestOwnership.UNSUPPORTED_METADATA
    }

    fun purpose(data: ByteArray): AudioTransferPurpose? = when (ownership(data)) {
        AudioTransferRequestOwnership.MANAGED_USER_PLAYBACK ->
            AudioTransferPurpose.USER_PLAYBACK
        AudioTransferRequestOwnership.MANAGED_AUTOMATIC_PREFETCH ->
            AudioTransferPurpose.AUTOMATIC_NEXT_PREFETCH
        AudioTransferRequestOwnership.LEGACY_USER_PLAYBACK,
        AudioTransferRequestOwnership.UNSUPPORTED_METADATA -> null
    }

    private fun encodeValue(value: String): ByteArray =
        "$SCHEMA_PREFIX$value".toByteArray(StandardCharsets.US_ASCII)

    private const val SCHEMA_PREFIX = "classics-audio-transfer/v1:"
}

@OptIn(UnstableApi::class)
fun DownloadRequest.classicsAudioTransferPurpose(): AudioTransferPurpose? =
    AudioTransferRequestMetadata.purpose(data)

@OptIn(UnstableApi::class)
class Media3AudioTransferCoordinator(
    runtime: Media3AudioDownloadRuntime,
    initialPolicyContext: AudioPrefetchPolicyContext,
) : DownloadManager.Listener {
    private val downloadManager = runtime.downloadManager
    private val applicationLooper = downloadManager.applicationLooper
    private val queue = Media3AudioTransferQueue(downloadManager)
    private val coordinator = AudioTransferQueueCoordinator(queue)
    private var released = false

    init {
        requireApplicationThread()
        downloadManager.addListener(this)
        coordinator.updatePolicy(initialPolicyContext)
    }

    fun request(
        spec: Media3AudioDownloadSpec,
        purpose: AudioTransferPurpose,
        policyContext: AudioPrefetchPolicyContext,
    ): AudioTransferRequestResult {
        requireApplicationThread()
        check(!released) { "audio transfer coordinator is released" }
        return coordinator.request(spec, purpose, policyContext)
    }

    fun updatePolicy(
        policyContext: AudioPrefetchPolicyContext,
    ): AudioPrefetchPolicyUpdateResult {
        requireApplicationThread()
        check(!released) { "audio transfer coordinator is released" }
        return coordinator.updatePolicy(policyContext)
    }

    fun release() {
        requireApplicationThread()
        if (released) return
        released = true
        downloadManager.removeListener(this)
    }

    override fun onInitialized(downloadManager: DownloadManager) {
        if (!isActiveCallback(downloadManager)) return
        coordinator.onQueueInitialized()
    }

    override fun onDownloadChanged(
        downloadManager: DownloadManager,
        download: Download,
        finalException: Exception?,
    ) {
        if (!isActiveCallback(downloadManager)) return
        if (
            download.isTerminalState ||
            download.state == Download.STATE_REMOVING ||
            download.state == Download.STATE_RESTARTING
        ) {
            coordinator.onTransferUnavailable(download.request.id)
        } else {
            coordinator.onTransferChanged(download.toQueuedAudioTransfer())
        }
    }

    override fun onDownloadRemoved(
        downloadManager: DownloadManager,
        download: Download,
    ) {
        if (!isActiveCallback(downloadManager)) return
        coordinator.onTransferUnavailable(download.request.id)
    }

    private fun isActiveCallback(manager: DownloadManager): Boolean {
        requireApplicationThread()
        check(manager === downloadManager) { "audio transfer callback came from another manager" }
        return !released
    }

    private fun requireApplicationThread() {
        check(Looper.myLooper() == applicationLooper) {
            "audio transfer coordinator must use the DownloadManager application thread"
        }
    }
}

@OptIn(UnstableApi::class)
private class Media3AudioTransferQueue(
    private val downloadManager: DownloadManager,
) : AudioTransferQueue {
    override fun currentTransfers(): List<QueuedAudioTransfer> =
        downloadManager.currentDownloads.map(Download::toQueuedAudioTransfer)

    override fun add(
        spec: Media3AudioDownloadSpec,
        purpose: AudioTransferPurpose,
        initialStopReason: Int,
    ) {
        downloadManager.addDownload(
            spec.toDownloadRequest(purpose),
            initialStopReason,
        )
    }

    override fun replacePurpose(
        spec: Media3AudioDownloadSpec,
        purpose: AudioTransferPurpose,
        preservedStopReason: Int,
    ) {
        downloadManager.addDownload(
            spec.toDownloadRequest(purpose),
            preservedStopReason,
        )
    }

    override fun setStopReason(requestID: String, stopReason: Int) {
        downloadManager.setStopReason(requestID, stopReason)
    }
}

@OptIn(UnstableApi::class)
private fun Download.toQueuedAudioTransfer(): QueuedAudioTransfer {
    val request = request
    return QueuedAudioTransfer(
        contract = AudioTransferRequestContract(
            requestID = request.id,
            uri = request.uri.toString(),
            mediaType = request.mimeType,
            customCacheKey = request.customCacheKey,
            isFullProgressiveAsset = request.streamKeys.isEmpty() &&
                request.keySetId == null &&
                request.byteRange == null &&
                request.timeRange == null,
        ),
        ownership = AudioTransferRequestMetadata.ownership(request.data),
        stopReason = stopReason,
    )
}
