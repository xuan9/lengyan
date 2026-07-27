package org.fuxuan.classics.reminder

import android.content.ComponentName
import android.content.Intent
import org.fuxuan.classics.core.AppContainer

data class DailyReminderConfiguration(
    val channelID: String,
    val notificationID: Int,
    val channelNameResourceID: Int,
    val channelDescriptionResourceID: Int,
    val notificationTitleResourceID: Int,
    val notificationBodyResourceID: Int,
    val smallIconResourceID: Int,
) {
    init {
        require(channelID.isNotBlank()) { "reminder channel ID must not be blank" }
        require(notificationID > 0) { "reminder notification ID must be positive" }
        require(channelNameResourceID != 0) { "reminder channel name resource is required" }
        require(channelDescriptionResourceID != 0) {
            "reminder channel description resource is required"
        }
        require(notificationTitleResourceID != 0) { "reminder title resource is required" }
        require(notificationBodyResourceID != 0) { "reminder body resource is required" }
        require(smallIconResourceID != 0) { "reminder small icon resource is required" }
    }
}

interface DailyReminderHost {
    val dailyReminderContainer: AppContainer
    val dailyReminderConfiguration: DailyReminderConfiguration
    val dailyReminderReceiverComponent: ComponentName

    fun dailyReminderLaunchIntent(
        paragraphID: String?,
        characterOffset: Int,
        requestID: Long,
    ): Intent
}
