package org.fuxuan.lengyan

import android.app.Application
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import org.fuxuan.classics.core.AppContainer
import org.fuxuan.classics.core.persistence.ProductPreferenceDefaults
import org.fuxuan.classics.core.persistence.ReminderPreferences
import org.fuxuan.classics.data.persistence.ProductPersistenceFactory
import org.fuxuan.classics.data.repository.AssetContractSource
import org.fuxuan.classics.data.repository.DefaultBookRepository
import org.fuxuan.classics.reminder.DailyReminderConfiguration
import org.fuxuan.classics.reminder.DailyReminderCoordinator
import org.fuxuan.classics.reminder.DailyReminderHost
import org.fuxuan.classics.reminder.R as ReminderResources
import org.fuxuan.classics.widget.DailyVerseWidgetHost
import org.fuxuan.classics.widget.DailyVerseWidgetUpdater

class LengyanApplication : Application(), DailyReminderHost, DailyVerseWidgetHost {
    private val applicationScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    val container: LengyanAppContainer by lazy {
        val persistence = ProductPersistenceFactory.create(
            context = this,
            productID = PRODUCT_ID,
            defaults = ProductPreferenceDefaults(
                locale = "zh-Hant",
                supportedLocales = setOf("zh-Hant", "zh-Hans"),
            ),
        )
        LengyanAppContainer(
            bookRepository = DefaultBookRepository(
                source = AssetContractSource(
                    assetManager = assets,
                    productAssetRoot = "classics/$PRODUCT_ID",
                ),
            ),
            userPreferencesRepository = persistence.userPreferencesRepository,
            favoriteRepository = persistence.favoriteRepository,
        )
    }

    override val dailyVerseWidgetContainer: AppContainer
        get() = container

    override val dailyVerseWidgetLaunchComponent: ComponentName
        get() = ComponentName(this, MainActivity::class.java)

    override val dailyVerseWidgetReceiverComponent: ComponentName
        get() = ComponentName(this, LengyanDailyVerseWidgetReceiver::class.java)

    override val dailyReminderContainer: AppContainer
        get() = container

    override val dailyReminderConfiguration = DailyReminderConfiguration(
        channelID = "daily-reading-reminder",
        notificationID = 8_041,
        channelNameResourceID = R.string.daily_reminder_channel_name,
        channelDescriptionResourceID = R.string.daily_reminder_channel_description,
        notificationTitleResourceID = R.string.daily_reminder_notification_title,
        notificationBodyResourceID = R.string.daily_reminder_notification_body,
        smallIconResourceID = ReminderResources.drawable.ic_daily_reading_reminder,
    )

    override val dailyReminderReceiverComponent: ComponentName
        get() = ComponentName(this, LengyanDailyReminderReceiver::class.java)

    override fun dailyReminderLaunchIntent(
        paragraphID: String?,
        characterOffset: Int,
        requestID: Long,
    ): Intent = Intent(this, MainActivity::class.java)
        .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        .apply {
            paragraphID?.takeIf(String::isNotBlank)?.let { targetID ->
                putExtra(MainActivity.EXTRA_PARAGRAPH_ID, targetID)
                putExtra(MainActivity.EXTRA_CHARACTER_OFFSET, characterOffset.coerceAtLeast(0))
                putExtra(MainActivity.EXTRA_DEEP_LINK_REQUEST_ID, requestID.coerceAtLeast(0))
            }
        }

    override fun onCreate() {
        super.onCreate()
        observeDailyVerseWidgetInputs()
        observeDailyReminderInputs()
    }

    private fun observeDailyVerseWidgetInputs() {
        applicationScope.launch {
            container.userPreferencesRepository.preferences
                .map { preferences ->
                    WidgetRefreshFingerprint(
                        theme = preferences.theme.name,
                        locale = preferences.locale,
                    )
                }
                .distinctUntilChanged()
                .collect {
                    if (!hasInstalledDailyVerseWidget()) return@collect
                    try {
                        DailyVerseWidgetUpdater.updateAll(this@LengyanApplication)
                    } catch (exception: CancellationException) {
                        throw exception
                    } catch (_: Exception) {
                        // The provider's scheduled update remains available after a transient failure.
                    }
                }
        }
    }

    private fun hasInstalledDailyVerseWidget(): Boolean {
        return AppWidgetManager.getInstance(this)
            .getAppWidgetIds(dailyVerseWidgetReceiverComponent)
            .isNotEmpty()
    }

    private fun observeDailyReminderInputs() {
        applicationScope.launch {
            container.userPreferencesRepository.preferences
                .map { preferences ->
                    ReminderRefreshFingerprint(
                        reminder = preferences.reminder,
                        locale = preferences.locale,
                    )
                }
                .distinctUntilChanged()
                .collect { fingerprint ->
                    try {
                        DailyReminderCoordinator(
                            context = this@LengyanApplication,
                            host = this@LengyanApplication,
                        ).reconcile(fingerprint.reminder, fingerprint.locale)
                    } catch (exception: CancellationException) {
                        throw exception
                    } catch (_: Exception) {
                        // Protected system broadcasts provide an additional reconciliation path.
                    }
                }
        }
    }

    private data class WidgetRefreshFingerprint(
        val theme: String,
        val locale: String,
    )

    private data class ReminderRefreshFingerprint(
        val reminder: ReminderPreferences,
        val locale: String,
    )

    private companion object {
        const val PRODUCT_ID = "lengyan"
    }
}
