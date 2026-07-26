package org.fuxuan.lengyan

import android.content.Intent
import android.net.Uri
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.fuxuan.classics.core.behavior.LegacyLocationResolution
import org.fuxuan.classics.core.behavior.LegacyLocationUsage
import org.fuxuan.classics.core.behavior.ReadingMode
import org.fuxuan.classics.core.persistence.ReadingProgress
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class LengyanDeepLinkLifecycleTest {
    @Test
    fun coldDeepLinkIsNotReplayedAfterActivityRecreation() {
        val application = InstrumentationRegistry.getInstrumentation()
            .targetContext.applicationContext as LengyanApplication
        val container = application.container
        val legacyPath = "/A2/B1/C1"
        val resolution = runBlocking {
            container.bookRepository.resolveLegacyLocation(
                legacyPath = legacyPath,
                usage = LegacyLocationUsage.RESUME,
            )
        } as LegacyLocationResolution.Mapped
        val linkedParagraphID = requireNotNull(resolution.paragraphID)
        val content = runBlocking { container.bookRepository.content("zh-Hant") }
        val linkedParagraph = requireNotNull(content.paragraph(linkedParagraphID))
        val volumeParagraphs = content.paragraphsInReadingOrder()
            .filter { it.volumeID == linkedParagraph.volumeID }
        val linkedIndex = volumeParagraphs.indexOfFirst {
            it.paragraphID == linkedParagraphID
        }
        val laterParagraph = volumeParagraphs.getOrNull(linkedIndex + 1)
            ?: volumeParagraphs.getOrNull(linkedIndex - 1)
            ?: error("deep-link volume needs another paragraph for recreation testing")
        runBlocking { container.userPreferencesRepository.saveReadingProgress(null) }

        val intent = Intent(
            Intent.ACTION_VIEW,
            Uri.Builder()
                .scheme("lengyan")
                .authority("verse")
                .appendQueryParameter("path", legacyPath)
                .build(),
            application,
            MainActivity::class.java,
        )

        try {
            ActivityScenario.launch<MainActivity>(intent).use { scenario ->
                val linkedProgress = awaitProgress(application) {
                    it?.paragraphID == linkedParagraphID
                }
                val laterProgress = ReadingProgress(
                    productID = content.productID,
                    editionID = content.editionID,
                    paragraphID = laterParagraph.paragraphID,
                    characterOffset = 0,
                    mode = ReadingMode.CHAPTER,
                    updatedAtEpochMilliseconds = linkedProgress.updatedAtEpochMilliseconds + 10_000,
                )
                runBlocking {
                    container.userPreferencesRepository.saveReadingProgress(laterProgress)
                }

                scenario.recreate()
                scenario.onActivity { }
                val deadline = System.currentTimeMillis() + 1_000
                while (System.currentTimeMillis() < deadline) {
                    assertEquals(
                        laterParagraph.paragraphID,
                        runBlocking {
                            container.userPreferencesRepository.preferences.first()
                                .readingProgress?.paragraphID
                        },
                    )
                    Thread.sleep(50)
                }
            }
        } finally {
            runBlocking { container.userPreferencesRepository.saveReadingProgress(null) }
        }
    }

    private fun awaitProgress(
        application: LengyanApplication,
        predicate: (ReadingProgress?) -> Boolean,
    ): ReadingProgress {
        val deadline = System.currentTimeMillis() + 10_000
        while (System.currentTimeMillis() < deadline) {
            val progress = runBlocking {
                application.container.userPreferencesRepository.preferences.first().readingProgress
            }
            if (predicate(progress)) return requireNotNull(progress)
            Thread.sleep(50)
        }
        error("timed out waiting for reading progress")
    }
}
