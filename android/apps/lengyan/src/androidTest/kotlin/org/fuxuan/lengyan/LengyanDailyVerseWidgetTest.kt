package org.fuxuan.lengyan

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.glance.appwidget.compose
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.fuxuan.classics.widget.DailyVerseAppWidget
import org.fuxuan.classics.widget.DailyVerseWidgetDataLoader
import org.fuxuan.classics.widget.DailyVerseWidgetStateStore
import org.fuxuan.classics.core.persistence.ReadingProgress
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.time.Clock
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

@RunWith(AndroidJUnit4::class)
class LengyanDailyVerseWidgetTest {
    @Test
    fun providerIsDiscoverableWithResponsiveDailyUpdateMetadata() {
        val context = targetContext()
        val component = ComponentName(context, LengyanDailyVerseWidgetReceiver::class.java)
        val provider = AppWidgetManager.getInstance(context).installedProviders
            .firstOrNull { it.provider == component }

        assertNotNull("daily verse widget receiver is not discoverable", provider)
        requireNotNull(provider)
        assertTrue(provider.minWidth > 0)
        assertTrue(provider.minHeight > 0)
        assertEquals(3_600_000, provider.updatePeriodMillis)
        assertTrue(provider.resizeMode and AppWidgetProviderInfo.RESIZE_HORIZONTAL != 0)
        assertTrue(provider.resizeMode and AppWidgetProviderInfo.RESIZE_VERTICAL != 0)
    }

    @Test
    fun packagedContentProducesAStableLocalVerseAndExplicitLaunchIntent() = runBlocking {
        val application = targetContext().applicationContext as LengyanApplication
        val product = application.container.bookRepository.product()
        val book = application.container.bookRepository.book()
        val favoriteParagraphIDs = application.container.favoriteRepository
            .favorites(book.editionID)
            .first()
            .mapNotNull { it.paragraphID }
        val content = DailyVerseWidgetDataLoader(
            clock = Clock.fixed(
                Instant.parse("2026-07-27T10:00:00Z"),
                ZoneId.of("Europe/Oslo"),
            ),
        ).load(application.container)

        assertTrue(content.paragraphID in product.featuredParagraphIDs + favoriteParagraphIDs)
        assertTrue(content.text.isNotBlank())
        assertTrue(content.source.isNotBlank())
        assertEquals(
            ComponentName(application, MainActivity::class.java),
            application.dailyVerseWidgetLaunchComponent,
        )
    }

    @Test
    fun stableParagraphIntentOpensTheWidgetVerse() {
        val application = targetContext().applicationContext as LengyanApplication
        val repository = application.container.userPreferencesRepository
        val originalProgress = runBlocking { repository.preferences.first().readingProgress }
        val product = runBlocking { application.container.bookRepository.product() }
        val targetParagraphID = product.featuredParagraphIDs.first {
            it != originalProgress?.paragraphID
        }
        val intent = Intent(application, MainActivity::class.java)
            .putExtra(MainActivity.EXTRA_PARAGRAPH_ID, targetParagraphID)

        try {
            ActivityScenario.launch<MainActivity>(intent).use {
                val deadline = System.currentTimeMillis() + 10_000
                while (System.currentTimeMillis() < deadline) {
                    val paragraphID = runBlocking {
                        repository.preferences.first().readingProgress?.paragraphID
                    }
                    if (paragraphID == targetParagraphID) return@use
                    Thread.sleep(50)
                }
                error("timed out waiting for widget paragraph navigation")
            }
        } finally {
            runBlocking { repository.saveReadingProgress(originalProgress) }
        }
    }

    @Test
    fun dailySelectionAndFallbackSnapshotSurviveReadingProgressChanges() = runBlocking {
        val application = targetContext().applicationContext as LengyanApplication
        val repository = application.container.userPreferencesRepository
        val originalPreferences = repository.preferences.first()
        val book = application.container.bookRepository.book()
        val zone = ZoneId.of("Europe/Oslo")
        val localDate = LocalDate.of(2199, 7, 27)
        val instant = localDate.atTime(12, 0).atZone(zone).toInstant()
        val loader = DailyVerseWidgetDataLoader(Clock.fixed(instant, zone))
        val stateStore = DailyVerseWidgetStateStore(application)

        try {
            val first = loader.load(application.container, stateStore)
            val selectedID = requireNotNull(first.paragraphID)
            repository.saveReadingProgress(
                ReadingProgress(
                    productID = "lengyan",
                    editionID = book.editionID,
                    paragraphID = selectedID,
                    characterOffset = 0,
                    mode = originalPreferences.readingMode,
                    updatedAtEpochMilliseconds = instant.toEpochMilli(),
                ),
            )

            val second = loader.load(application.container, stateStore)

            assertEquals(selectedID, second.paragraphID)
            assertEquals(second, stateStore.lastSnapshot())
        } finally {
            repository.saveReadingProgress(originalPreferences.readingProgress)
        }
    }

    @Test
    fun realGlanceCompositionContainsScriptureAtCompactAndExpandedSizes() = runBlocking {
        val context = targetContext()
        for (size in listOf(
            DpSize(180.dp, 110.dp),
            DpSize(196.dp, 240.dp),
            DpSize(320.dp, 320.dp),
        )) {
            val remoteViews = DailyVerseAppWidget().compose(context = context, size = size)
            val root = applyRemoteViews(context, remoteViews)
            val texts = root.descendants()
                .filterIsInstance<TextView>()
                .map { it.text.toString() }

            assertTrue("widget header was not composed at $size", texts.any { "今日" in it })
            assertTrue(
                "widget scripture was not composed at $size",
                texts.any { candidate -> candidate.length >= 10 && "今日" !in candidate },
            )
        }
    }

    private fun applyRemoteViews(context: Context, remoteViews: android.widget.RemoteViews): View {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        lateinit var result: View
        instrumentation.runOnMainSync {
            result = remoteViews.apply(context, FrameLayout(context))
        }
        return result
    }

    private fun View.descendants(): Sequence<View> = sequence {
        yield(this@descendants)
        if (this@descendants is ViewGroup) {
            for (index in 0 until childCount) {
                yieldAll(getChildAt(index).descendants())
            }
        }
    }

    private fun targetContext(): Context =
        InstrumentationRegistry.getInstrumentation().targetContext
}
