package org.fuxuan.classics.media.harness

import android.app.Notification
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.offline.Download
import androidx.media3.exoplayer.offline.DownloadNotificationHelper
import androidx.media3.exoplayer.scheduler.Scheduler
import org.fuxuan.classics.media.ClassicsAudioDownloadService
import org.fuxuan.classics.media.Media3AudioDownloadRuntime

@OptIn(UnstableApi::class)
class HarnessAudioDownloadService : ClassicsAudioDownloadService(
    foregroundNotificationID = NOTIFICATION_ID,
    channelID = CHANNEL_ID,
    channelNameResourceID = R.string.download_channel_name,
    channelDescriptionResourceID = R.string.download_channel_description,
) {
    private val notificationHelper by lazy {
        DownloadNotificationHelper(this, CHANNEL_ID)
    }

    override fun audioDownloadRuntime(): Media3AudioDownloadRuntime =
        HarnessAudioDownloadEnvironment.requireRuntime(this)

    override fun getScheduler(): Scheduler? = null

    override fun getForegroundNotification(
        downloads: MutableList<Download>,
        notMetRequirements: Int,
    ): Notification = notificationHelper.buildProgressNotification(
        this,
        android.R.drawable.stat_sys_download,
        null,
        null,
        downloads,
        notMetRequirements,
    )

    companion object {
        const val NOTIFICATION_ID = 2_002
        const val CHANNEL_ID = "media3-download-test"
    }
}
