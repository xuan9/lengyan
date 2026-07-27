package org.fuxuan.lengyan

import android.app.Application
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import org.fuxuan.classics.core.AppContainer
import org.fuxuan.classics.core.persistence.ProductPreferenceDefaults
import org.fuxuan.classics.data.persistence.ProductPersistenceFactory
import org.fuxuan.classics.data.repository.AssetContractSource
import org.fuxuan.classics.data.repository.DefaultBookRepository
import org.fuxuan.classics.widget.DailyVerseWidgetHost
import org.fuxuan.classics.widget.DailyVerseWidgetUpdater

class LengyanApplication : Application(), DailyVerseWidgetHost {
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

    override fun onCreate() {
        super.onCreate()
        observeDailyVerseWidgetInputs()
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
        val component = ComponentName(this, LengyanDailyVerseWidgetReceiver::class.java)
        return AppWidgetManager.getInstance(this).getAppWidgetIds(component).isNotEmpty()
    }

    private data class WidgetRefreshFingerprint(
        val theme: String,
        val locale: String,
    )

    private companion object {
        const val PRODUCT_ID = "lengyan"
    }
}
