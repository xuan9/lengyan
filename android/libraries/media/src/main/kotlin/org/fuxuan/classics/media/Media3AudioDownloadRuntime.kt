package org.fuxuan.classics.media

import android.content.Context
import android.os.Looper
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.cache.Cache
import androidx.media3.datasource.cache.NoOpCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import androidx.media3.exoplayer.offline.DownloadManager
import androidx.media3.exoplayer.scheduler.Requirements
import java.io.File
import java.util.concurrent.Executor

@OptIn(UnstableApi::class)
class Media3AudioDownloadRuntime private constructor(
    val cache: Cache,
    val downloadManager: DownloadManager,
) {
    private var released = false

    fun release() {
        requireMainThread()
        if (released) return
        released = true
        try {
            downloadManager.release()
        } finally {
            cache.release()
        }
    }

    companion object {
        fun create(
            context: Context,
            cacheDirectory: File,
            upstreamFactory: DataSource.Factory,
            downloadExecutor: Executor = Executor(Runnable::run),
            requirements: Requirements = Requirements(Requirements.NETWORK),
            maxParallelDownloads: Int = 1,
        ): Media3AudioDownloadRuntime {
            requireMainThread()
            require(maxParallelDownloads > 0) {
                "maximum parallel audio downloads must be positive"
            }

            val applicationContext = context.applicationContext
            val databaseProvider = StandaloneDatabaseProvider(applicationContext)
            val cache = SimpleCache(
                cacheDirectory,
                NoOpCacheEvictor(),
                databaseProvider,
            )
            try {
                val manager = DownloadManager(
                    applicationContext,
                    databaseProvider,
                    cache,
                    upstreamFactory,
                    downloadExecutor,
                ).apply {
                    setRequirements(requirements)
                    setMaxParallelDownloads(maxParallelDownloads)
                }
                return Media3AudioDownloadRuntime(cache, manager)
            } catch (exception: Exception) {
                cache.release()
                throw exception
            }
        }

        private fun requireMainThread() {
            check(Looper.myLooper() == Looper.getMainLooper()) {
                "Media3 audio download runtime must be accessed on the main thread"
            }
        }
    }
}
