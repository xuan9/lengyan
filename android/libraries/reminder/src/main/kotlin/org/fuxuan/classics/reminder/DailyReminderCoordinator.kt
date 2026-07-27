package org.fuxuan.classics.reminder

import android.Manifest
import android.annotation.SuppressLint
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import kotlinx.coroutines.flow.first
import org.fuxuan.classics.core.persistence.ReminderPreferences
import java.time.Clock
import java.util.Locale

class DailyReminderCoordinator(
    context: Context,
    private val host: DailyReminderHost,
    private val clock: Clock = Clock.systemDefaultZone(),
) {
    private val context = context.applicationContext
    private val configuration = host.dailyReminderConfiguration
    private val alarmManager = context.getSystemService(AlarmManager::class.java)
    private val notificationManager = context.getSystemService(NotificationManager::class.java)

    init {
        require(host.dailyReminderReceiverComponent.packageName == this.context.packageName) {
            "daily reminder receiver must belong to the host application"
        }
    }

    suspend fun reconcileCurrent() {
        val preferences = host.dailyReminderContainer.userPreferencesRepository.preferences.first()
        reconcile(preferences.reminder, preferences.locale)
    }

    fun reconcile(
        reminder: ReminderPreferences,
        locale: String,
    ) {
        if (!reminder.enabled) {
            cancel()
            return
        }
        ensureNotificationChannel(locale)
        scheduleNext(reminder)
    }

    suspend fun deliver() {
        val preferences = host.dailyReminderContainer.userPreferencesRepository.preferences.first()
        val reminder = preferences.reminder
        if (!reminder.enabled) {
            cancel()
            return
        }

        ensureNotificationChannel(preferences.locale)
        scheduleNext(reminder)
        if (!canPostNotifications()) return

        val readingProgress = preferences.readingProgress
        val launchIntent = host.dailyReminderLaunchIntent(
            paragraphID = readingProgress?.paragraphID,
            characterOffset = readingProgress?.characterOffset ?: 0,
            requestID = clock.millis(),
        )
        require(launchIntent.component?.packageName == context.packageName) {
            "daily reminder launch intent must explicitly target the host application"
        }
        val contentIntent = PendingIntent.getActivity(
            context,
            configuration.notificationID,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(context, configuration.channelID)
            .setSmallIcon(configuration.smallIconResourceID)
            .setContentTitle(localizedString(configuration.notificationTitleResourceID, preferences.locale))
            .setContentText(localizedString(configuration.notificationBodyResourceID, preferences.locale))
            .setStyle(
                NotificationCompat.BigTextStyle().bigText(
                    localizedString(configuration.notificationBodyResourceID, preferences.locale),
                ),
            )
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setWhen(clock.millis())
            .build()
        try {
            NotificationManagerCompat.from(context).notify(
                configuration.notificationID,
                notification,
            )
        } catch (_: SecurityException) {
            // Permission can be revoked after the explicit check above.
        }
    }

    fun cancel() {
        val pendingIntent = alarmPendingIntent()
        alarmManager.cancel(pendingIntent)
        pendingIntent.cancel()
        notificationManager.cancel(configuration.notificationID)
    }

    private fun scheduleNext(reminder: ReminderPreferences) {
        val trigger = DailyReminderSchedulePolicy.nextTrigger(
            instant = clock.instant(),
            timeZone = clock.zone,
            hour = reminder.hour,
            minute = reminder.minute,
        )
        alarmManager.setAndAllowWhileIdle(
            AlarmManager.RTC_WAKEUP,
            trigger.toEpochMilli(),
            alarmPendingIntent(),
        )
    }

    private fun alarmPendingIntent(): PendingIntent = PendingIntent.getBroadcast(
        context,
        configuration.notificationID,
        Intent(alarmAction(context)).setComponent(host.dailyReminderReceiverComponent),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    private fun ensureNotificationChannel(locale: String) {
        val channel = NotificationChannel(
            configuration.channelID,
            localizedString(configuration.channelNameResourceID, locale),
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = localizedString(configuration.channelDescriptionResourceID, locale)
            lockscreenVisibility = Notification.VISIBILITY_PRIVATE
        }
        notificationManager.createNotificationChannel(channel)
    }

    private fun canPostNotifications(): Boolean {
        val permissionGranted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        return permissionGranted && NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    @SuppressLint("AppBundleLocaleChanges")
    private fun localizedString(resourceID: Int, locale: String): String {
        val configuration = Configuration(context.resources.configuration).apply {
            setLocale(Locale.forLanguageTag(locale))
        }
        return context.createConfigurationContext(configuration).getString(resourceID)
    }

    companion object {
        fun alarmAction(context: Context): String =
            "${context.applicationContext.packageName}.action.DAILY_READING_REMINDER"
    }
}
