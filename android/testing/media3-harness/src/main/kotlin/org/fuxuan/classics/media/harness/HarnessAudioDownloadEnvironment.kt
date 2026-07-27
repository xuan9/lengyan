package org.fuxuan.classics.media.harness

import android.content.Context
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.scheduler.Requirements
import org.fuxuan.classics.media.Media3AudioDownloadRuntime
import java.io.File

@OptIn(UnstableApi::class)
object HarnessAudioDownloadEnvironment {
    private var runtime: Media3AudioDownloadRuntime? = null

    @Synchronized
    fun installForTest(
        context: Context,
        upstreamFactory: DataSource.Factory,
    ): Media3AudioDownloadRuntime {
        check(runtime == null) { "audio download test runtime was already installed" }
        cacheDirectory(context).deleteRecursively()
        return createRuntime(context, upstreamFactory).also { runtime = it }
    }

    @Synchronized
    fun restoreForTest(
        context: Context,
        upstreamFactory: DataSource.Factory,
    ): Media3AudioDownloadRuntime {
        check(runtime == null) { "audio download test runtime was already installed" }
        return createRuntime(context, upstreamFactory).also { runtime = it }
    }

    @Synchronized
    fun requireRuntime(context: Context): Media3AudioDownloadRuntime =
        runtime ?: createRuntime(
            context,
            DefaultHttpDataSource.Factory(),
        ).also { runtime = it }

    fun cacheDirectory(context: Context): File =
        File(context.cacheDir, CACHE_DIRECTORY_NAME)

    @Synchronized
    fun releaseForTest() {
        runtime?.release()
        runtime = null
    }

    private fun createRuntime(
        context: Context,
        upstreamFactory: DataSource.Factory,
    ): Media3AudioDownloadRuntime = Media3AudioDownloadRuntime.create(
        context = context,
        cacheDirectory = cacheDirectory(context),
        upstreamFactory = upstreamFactory,
        requirements = Requirements(0),
        maxParallelDownloads = 1,
    )

    private const val CACHE_DIRECTORY_NAME = "media3-audio-downloads"
}
