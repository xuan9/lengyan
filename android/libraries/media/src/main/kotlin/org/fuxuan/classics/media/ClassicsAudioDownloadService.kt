package org.fuxuan.classics.media

import androidx.annotation.OptIn
import androidx.annotation.StringRes
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.offline.DownloadManager
import androidx.media3.exoplayer.offline.DownloadService

@OptIn(UnstableApi::class)
abstract class ClassicsAudioDownloadService protected constructor(
    foregroundNotificationID: Int,
    foregroundNotificationUpdateInterval: Long =
        DEFAULT_FOREGROUND_NOTIFICATION_UPDATE_INTERVAL,
    channelID: String? = null,
    @StringRes channelNameResourceID: Int = 0,
    @StringRes channelDescriptionResourceID: Int = 0,
) : DownloadService(
    foregroundNotificationID,
    foregroundNotificationUpdateInterval,
    channelID,
    channelNameResourceID,
    channelDescriptionResourceID,
) {
    init {
        require(foregroundNotificationID > FOREGROUND_NOTIFICATION_ID_NONE) {
            "audio downloads require a foreground notification"
        }
        require(foregroundNotificationUpdateInterval > 0) {
            "foreground notification update interval must be positive"
        }
        require(
            channelID == null ||
                channelID.isNotBlank() && channelNameResourceID != 0,
        ) { "audio download notification channels require an ID and name" }
    }

    protected abstract fun audioDownloadRuntime(): Media3AudioDownloadRuntime

    final override fun getDownloadManager(): DownloadManager =
        audioDownloadRuntime().downloadManager
}
