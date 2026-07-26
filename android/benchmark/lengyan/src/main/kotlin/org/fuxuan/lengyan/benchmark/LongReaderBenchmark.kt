package org.fuxuan.lengyan.benchmark

import android.content.Intent
import android.net.Uri
import androidx.benchmark.macro.CompilationMode
import androidx.benchmark.macro.ExperimentalMetricApi
import androidx.benchmark.macro.FrameTimingMetric
import androidx.benchmark.macro.MacrobenchmarkScope
import androidx.benchmark.macro.MemoryUsageMetric
import androidx.benchmark.macro.junit4.MacrobenchmarkRule
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.LargeTest
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.Until
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@LargeTest
@RunWith(AndroidJUnit4::class)
@OptIn(ExperimentalMetricApi::class)
class LongReaderBenchmark {
    @get:Rule
    val benchmarkRule = MacrobenchmarkRule()

    @Test
    fun scrollLargestPackagedVolume() {
        clearBenchmarkAppData()
        benchmarkRule.measureRepeated(
            packageName = PACKAGE_NAME,
            metrics = listOf(
                FrameTimingMetric(),
                MemoryUsageMetric(MemoryUsageMetric.Mode.Max),
            ),
            compilationMode = CompilationMode.Partial(),
            iterations = 10,
            setupBlock = {
                killProcess()
                launchLargestVolume()
            },
            measureBlock = {
                val centerX = device.displayWidth / 2
                val startY = (device.displayHeight * 0.72f).toInt()
                val endY = (device.displayHeight * 0.28f).toInt()
                repeat(SWIPE_COUNT) {
                    check(device.swipe(centerX, startY, centerX, endY, SWIPE_STEPS)) {
                        "reader swipe injection failed"
                    }
                }
                device.waitForIdle()
            },
        )
    }

    private fun clearBenchmarkAppData() {
        val device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())
        val result = device.executeShellCommand("pm clear $PACKAGE_NAME").trim()
        check(result == "Success") { "could not reset benchmark app data: $result" }
    }

    private fun MacrobenchmarkScope.launchLargestVolume() {
        val uri = Uri.Builder()
            .scheme("lengyan")
            .authority("verse")
            .appendQueryParameter("path", VOLUME_NINE_LEGACY_PATH)
            .build()
        val intent = Intent(Intent.ACTION_VIEW, uri)
            .setPackage(PACKAGE_NAME)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)

        startActivityAndWait(intent)
        check(device.wait(Until.hasObject(By.textContains("卷九")), CONTENT_TIMEOUT_MILLIS)) {
            "volume nine reader did not become ready"
        }
        device.waitForIdle()
    }

    private companion object {
        const val PACKAGE_NAME = "org.fuxuan.lengyan.macrobenchmark"
        const val VOLUME_NINE_LEGACY_PATH = "/A2/B2/C1/D2/E2/F2/G6/H1/I2/J1/K1/L1/M1"
        const val CONTENT_TIMEOUT_MILLIS = 20_000L
        const val SWIPE_COUNT = 8
        const val SWIPE_STEPS = 20
    }
}
