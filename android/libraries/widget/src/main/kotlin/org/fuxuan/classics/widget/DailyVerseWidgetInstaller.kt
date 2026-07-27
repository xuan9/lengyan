package org.fuxuan.classics.widget

import android.appwidget.AppWidgetManager
import android.content.Context

data class DailyVerseWidgetInstallationState(
    val isInstalled: Boolean,
    val pinRequestSupported: Boolean,
)

enum class DailyVerseWidgetPinResult {
    REQUESTED,
    FALLBACK_GUIDE_REQUIRED,
}

class DailyVerseWidgetInstaller(
    context: Context,
    host: DailyVerseWidgetHost,
) {
    private val context = context.applicationContext
    private val receiverComponent = host.dailyVerseWidgetReceiverComponent
    private val appWidgetManager = AppWidgetManager.getInstance(this.context)

    init {
        require(receiverComponent.packageName == this.context.packageName) {
            "daily verse Widget receiver must belong to the host application"
        }
    }

    fun installationState(): DailyVerseWidgetInstallationState =
        DailyVerseWidgetInstallationState(
            isInstalled = appWidgetManager.getAppWidgetIds(receiverComponent).isNotEmpty(),
            pinRequestSupported = appWidgetManager.isRequestPinAppWidgetSupported,
        )

    fun requestPin(): DailyVerseWidgetPinResult {
        if (!appWidgetManager.isRequestPinAppWidgetSupported) {
            return DailyVerseWidgetPinResult.FALLBACK_GUIDE_REQUIRED
        }
        val requested = try {
            appWidgetManager.requestPinAppWidget(receiverComponent, null, null)
        } catch (_: IllegalArgumentException) {
            false
        } catch (_: SecurityException) {
            false
        }
        return if (requested) {
            DailyVerseWidgetPinResult.REQUESTED
        } else {
            DailyVerseWidgetPinResult.FALLBACK_GUIDE_REQUIRED
        }
    }
}
