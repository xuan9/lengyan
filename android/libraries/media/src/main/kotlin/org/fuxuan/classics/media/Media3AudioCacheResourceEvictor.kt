package org.fuxuan.classics.media

import android.os.Handler
import android.os.Looper
import androidx.annotation.OptIn
import androidx.annotation.WorkerThread
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.offline.Download
import androidx.media3.exoplayer.offline.DownloadManager
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

@OptIn(UnstableApi::class)
class Media3AudioCacheResourceEvictor(
    runtime: Media3AudioDownloadRuntime,
    private val callbackTimeoutMilliseconds: Long = DEFAULT_CALLBACK_TIMEOUT_MILLISECONDS,
) : AudioCacheResourceEvictor {
    private val cache = runtime.cache
    private val downloadManager = runtime.downloadManager
    private val applicationLooper = downloadManager.applicationLooper
    private val applicationHandler = Handler(applicationLooper)

    init {
        require(callbackTimeoutMilliseconds > 0) {
            "cache eviction timeout must be positive"
        }
    }

    @WorkerThread
    override fun evict(requestID: String) {
        require(requestID.isNotBlank()) { "evicted audio requestID must not be blank" }
        check(Looper.myLooper() != applicationLooper) {
            "Media3 cache eviction must not block the DownloadManager application thread"
        }

        val removedLatch = CountDownLatch(1)
        val listener = object : DownloadManager.Listener {
            override fun onDownloadRemoved(
                downloadManager: DownloadManager,
                download: Download,
            ) {
                if (download.request.id == requestID) removedLatch.countDown()
            }
        }

        runOnApplicationThread {
            downloadManager.addListener(listener)
        }
        try {
            val indexedDownload = downloadManager.downloadIndex.getDownload(requestID)
            if (indexedDownload == null) {
                cache.removeResource(requestID)
                return
            }

            runOnApplicationThread {
                downloadManager.removeDownload(requestID)
            }
            check(
                removedLatch.await(callbackTimeoutMilliseconds, TimeUnit.MILLISECONDS),
            ) { "timed out removing Media3 audio download $requestID" }
            cache.removeResource(requestID)
        } finally {
            runOnApplicationThread {
                downloadManager.removeListener(listener)
            }
        }
    }

    private fun runOnApplicationThread(block: () -> Unit) {
        val completion = CountDownLatch(1)
        val failure = AtomicReference<Exception?>()
        check(
            applicationHandler.post {
                try {
                    block()
                } catch (exception: Exception) {
                    failure.set(exception)
                } finally {
                    completion.countDown()
                }
            },
        ) { "DownloadManager application looper rejected cache eviction work" }
        check(
            completion.await(callbackTimeoutMilliseconds, TimeUnit.MILLISECONDS),
        ) { "timed out dispatching Media3 cache eviction" }
        failure.get()?.let { throw it }
    }

    private companion object {
        const val DEFAULT_CALLBACK_TIMEOUT_MILLISECONDS = 15_000L
    }
}
