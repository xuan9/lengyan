package org.fuxuan.lengyan

import android.Manifest
import android.app.Notification
import android.app.NotificationManager
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.ParcelFileDescriptor
import androidx.core.content.ContextCompat
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.fuxuan.classics.core.behavior.ReadingMode
import org.fuxuan.classics.core.persistence.ReadingProgress
import org.fuxuan.classics.core.persistence.ReminderPreferences
import org.fuxuan.classics.reminder.DailyReminderCoordinator
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.time.Clock
import java.time.Instant
import java.time.ZoneId

@RunWith(AndroidJUnit4::class)
class LengyanDailyReminderTest {
    @Test
    fun manifestUsesOnlyThePermissionsRequiredForInexactReminders() {
        val context = targetContext()
        val packageInfo = context.packageManager.getPackageInfo(
            context.packageName,
            PackageManager.GET_PERMISSIONS,
        )
        val permissions = packageInfo.requestedPermissions.orEmpty().toSet()

        assertTrue(Manifest.permission.POST_NOTIFICATIONS in permissions)
        assertTrue(Manifest.permission.RECEIVE_BOOT_COMPLETED in permissions)
        assertFalse(Manifest.permission.SCHEDULE_EXACT_ALARM in permissions)
        assertFalse(Manifest.permission.USE_EXACT_ALARM in permissions)

        val receiver = context.packageManager.getReceiverInfo(
            ComponentName(context, LengyanDailyReminderReceiver::class.java),
            0,
        )
        assertTrue(receiver.enabled)
        assertFalse(receiver.exported)
    }

    @Test
    fun notificationUsesLocalizedProductCopyAndCurrentReadingAnchor() = runBlocking {
        val application = targetContext().applicationContext as LengyanApplication
        grantNotificationPermission(application)
        assertEquals(
            PackageManager.PERMISSION_GRANTED,
            ContextCompat.checkSelfPermission(application, Manifest.permission.POST_NOTIFICATIONS),
        )

        val repository = application.container.userPreferencesRepository
        val original = repository.preferences.first()
        val book = application.container.bookRepository.book()
        val product = application.container.bookRepository.product()
        val paragraphID = product.featuredParagraphIDs.first()
        val paragraph = requireNotNull(
            application.container.bookRepository.content("zh-Hant").paragraph(paragraphID),
        )
        val offset = minOf(7, paragraph.text.codePointCount(0, paragraph.text.length))
        val coordinator = DailyReminderCoordinator(
            context = application,
            host = application,
            clock = Clock.fixed(
                Instant.parse("2026-07-27T06:30:00Z"),
                ZoneId.of("Europe/Oslo"),
            ),
        )
        val notificationManager = application.getSystemService(NotificationManager::class.java)

        try {
            repository.setLocale("zh-Hant")
            repository.saveReadingProgress(
                ReadingProgress(
                    productID = product.productID,
                    editionID = book.editionID,
                    paragraphID = paragraphID,
                    characterOffset = offset,
                    mode = ReadingMode.CHAPTER,
                    updatedAtEpochMilliseconds = 1_753_594_200_000,
                ),
            )
            repository.setReminder(ReminderPreferences(enabled = true, hour = 8, minute = 30))

            coordinator.deliver()

            val statusBarNotification = awaitNotification(
                notificationManager = notificationManager,
                notificationID = application.dailyReminderConfiguration.notificationID,
            )
            val notification = statusBarNotification.notification
            assertEquals(application.dailyReminderConfiguration.channelID, notification.channelId)
            assertEquals(
                "今日讀經",
                notification.extras.getCharSequence(Notification.EXTRA_TITLE).toString(),
            )
            assertEquals(
                "靜下片刻，繼續讀一段《楞嚴經》。",
                notification.extras.getCharSequence(Notification.EXTRA_TEXT).toString(),
            )
            assertEquals(application.packageName, notification.contentIntent.creatorPackage)
            assertEquals(
                "每日讀經提醒",
                notificationManager.getNotificationChannel(notification.channelId).name.toString(),
            )

            val launchIntent = application.dailyReminderLaunchIntent(
                paragraphID = paragraphID,
                characterOffset = offset,
                requestID = 1_753_620_600_000,
            )
            assertEquals(ComponentName(application, MainActivity::class.java), launchIntent.component)
            assertEquals(paragraphID, launchIntent.getStringExtra(MainActivity.EXTRA_PARAGRAPH_ID))
            assertEquals(offset, launchIntent.getIntExtra(MainActivity.EXTRA_CHARACTER_OFFSET, -1))
            assertEquals(
                1_753_620_600_000,
                launchIntent.getLongExtra(MainActivity.EXTRA_DEEP_LINK_REQUEST_ID, -1),
            )
        } finally {
            notificationManager.cancel(application.dailyReminderConfiguration.notificationID)
            repository.saveReadingProgress(original.readingProgress)
            repository.setLocale(original.locale)
            repository.setReminder(original.reminder)
            coordinator.reconcile(original.reminder, original.locale)
        }
    }

    @Test
    fun reminderIntentOpensTheExactSavedTextOffset() {
        val application = targetContext().applicationContext as LengyanApplication
        val repository = application.container.userPreferencesRepository
        val originalProgress = runBlocking { repository.preferences.first().readingProgress }
        val product = runBlocking { application.container.bookRepository.product() }
        val paragraphID = product.featuredParagraphIDs.first()
        val offset = 7
        val intent = application.dailyReminderLaunchIntent(
            paragraphID = paragraphID,
            characterOffset = offset,
            requestID = System.currentTimeMillis(),
        )

        try {
            ActivityScenario.launch<MainActivity>(intent).use {
                val deadline = System.currentTimeMillis() + 10_000
                while (System.currentTimeMillis() < deadline) {
                    val progress = runBlocking { repository.preferences.first().readingProgress }
                    if (progress?.paragraphID == paragraphID && progress.characterOffset == offset) {
                        return@use
                    }
                    Thread.sleep(50)
                }
                val progress = runBlocking { repository.preferences.first().readingProgress }
                error("timed out waiting for reminder text-anchor navigation; progress=$progress")
            }
        } finally {
            runBlocking { repository.saveReadingProgress(originalProgress) }
        }
    }

    private suspend fun awaitNotification(
        notificationManager: NotificationManager,
        notificationID: Int,
    ) = buildList {
        repeat(100) {
            notificationManager.activeNotifications
                .firstOrNull { it.id == notificationID }
                ?.let {
                    add(it)
                    return@buildList
                }
            delay(50)
        }
    }.singleOrNull().also {
        assertNotNull("daily reminder notification was not posted", it)
    }!!

    private fun grantNotificationPermission(context: Context) {
        if (ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        val command = "pm grant ${context.packageName} ${Manifest.permission.POST_NOTIFICATIONS}"
        val descriptor = InstrumentationRegistry.getInstrumentation()
            .uiAutomation
            .executeShellCommand(command)
        ParcelFileDescriptor.AutoCloseInputStream(descriptor).bufferedReader().use { reader ->
            reader.readText()
        }
    }

    private fun targetContext(): Context =
        InstrumentationRegistry.getInstrumentation().targetContext
}
