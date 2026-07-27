package org.fuxuan.classics.ui

import android.graphics.BitmapFactory
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.runBlocking
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.io.FileInputStream
import kotlin.system.measureTimeMillis

@RunWith(AndroidJUnit4::class)
class ShareImageExporterTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val exportRoot by lazy {
        File(context.cacheDir, AndroidShareImageExporter.EXPORT_ROOT_DIRECTORY)
    }
    private val realVolumeText by lazy(::loadLongestLengyanVolume)

    @Before
    fun clearPreviousExports() {
        exportRoot.deleteRecursively()
    }

    @Test
    fun paginationPreservesEveryCharacterAtReaderTypography() {
        val exporter = AndroidShareImageExporter(context)

        REFERENCE_CHARACTER_COUNTS.forEach { characterCount ->
            val document = document(characterCount)
            val plan = exporter.plan(document)
            var expectedStart = 0

            plan.pages.forEachIndexed { index, page ->
                assertEquals(index + 1, page.pageNumber)
                assertEquals(expectedStart, page.startUtf16Offset)
                assertTrue(page.endUtf16Offset > page.startUtf16Offset)
                assertTrue(
                    page.imageHeightPixels <= AndroidShareImageExporter.MAXIMUM_PAGE_HEIGHT_PIXELS,
                )
                expectedStart = page.endUtf16Offset
            }

            assertEquals(document.text.length, expectedStart)
            assertEquals(
                document.text,
                plan.pages.joinToString(separator = "") { page ->
                    document.text.substring(page.startUtf16Offset, page.endUtf16Offset)
                },
            )
            assertEquals(1080, plan.widthPixels)
            assertEquals(24f * 1080f / 393f, plan.bodyFontSizePixels, 0.01f)
            assertEquals(42f * 1080f / 393f, plan.bodyLineHeightPixels, 0.01f)
            assertTrue(plan.maximumBitmapBytes <= 1080L * 13500L * 2L)
        }
    }

    @Test
    fun exportsReferenceLengthsAsBoundedSemanticJpegs() = runBlocking {
        val exporter = AndroidShareImageExporter(context)

        REFERENCE_CHARACTER_COUNTS.forEach { characterCount ->
            val document = document(characterCount)
            val budget = EXPORT_BUDGETS.getValue(characterCount)
            lateinit var result: ShareImageExport
            val elapsedMilliseconds = measureTimeMillis {
                result = exporter.export(document) { progress ->
                    assertTrue(progress.completedPageCount in 0..progress.pageCount)
                }
            }

            assertEquals(result.plan.pages.size, result.files.size)
            assertEquals(result.files.sumOf(File::length), result.totalFileBytes)
            assertTrue(result.totalFileBytes > 0)
            assertTrue(
                "$characterCount characters produced ${result.files.size} pages",
                result.files.size <= budget.maximumPageCount,
            )
            assertTrue(
                "$characterCount characters produced ${result.totalFileBytes} bytes",
                result.totalFileBytes <= budget.maximumTotalFileBytes,
            )
            result.files.forEachIndexed { index, file ->
                assertTrue(file.exists())
                assertEquals(
                    document.imageFileName(index + 1, result.files.size),
                    file.name,
                )
                assertFalse(file.name.contains(Regex("\\d{8}-\\d{6}")))
                assertJpegDimensions(
                    file = file,
                    expectedHeight = result.plan.pages[index].imageHeightPixels,
                )
            }
            val firstFile = result.files.first()
            val firstUri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.share-files",
                firstFile,
            )
            assertEquals("content", firstUri.scheme)
            context.contentResolver.query(firstUri, null, null, null, null).use { cursor ->
                requireNotNull(cursor)
                assertTrue(cursor.moveToFirst())
                assertEquals(
                    firstFile.name,
                    cursor.getString(cursor.getColumnIndexOrThrow(OpenableColumns.DISPLAY_NAME)),
                )
            }

            println(
                "SHARE_EXPORT_METRIC characters=$characterCount " +
                    "pages=${result.files.size} pixels=${result.plan.totalPixels} " +
                    "bytes=${result.totalFileBytes} elapsedMs=$elapsedMilliseconds " +
                    "peakBitmapBytes=${result.plan.maximumBitmapBytes}",
            )
        }
    }

    @Test
    fun cancellationDeletesPartiallyGeneratedFiles() = runBlocking {
        val exporter = AndroidShareImageExporter(context)
        var cancelled = false

        try {
            exporter.export(document(20_000)) { progress ->
                if (progress.completedPageCount == 1) throw CancellationException("test")
            }
        } catch (_: CancellationException) {
            cancelled = true
        }

        assertTrue(cancelled)
        assertTrue(exportRoot.listFiles().isNullOrEmpty())
    }

    @Test(expected = IllegalArgumentException::class)
    fun pageHeightCannotBeLowerThanTheMinimumImageHeight() {
        AndroidShareImageExporter(
            context = context,
            maximumPageHeightPixels = AndroidShareImageExporter.MINIMUM_PAGE_HEIGHT_PIXELS - 1,
        )
    }

    private fun assertJpegDimensions(file: File, expectedHeight: Int) {
        FileInputStream(file).use { input ->
            assertEquals(0xFF, input.read())
            assertEquals(0xD8, input.read())
        }
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, options)
        assertEquals("image/jpeg", options.outMimeType)
        assertEquals(AndroidShareImageExporter.CANVAS_WIDTH_PIXELS, options.outWidth)
        assertEquals(expectedHeight, options.outHeight)
    }

    private fun document(characterCount: Int): ShareDocument {
        val text = buildString(characterCount + realVolumeText.length) {
            while (codePointCount(0, length) < characterCount) {
                if (isNotEmpty()) append("\n\n")
                append(realVolumeText)
            }
        }.takeCodePoints(characterCount)
        assertEquals(characterCount, text.codePointCount(0, text.length))
        return ShareDocument(
            locale = "zh-Hant",
            productTitle = "楞嚴經",
            volumeTitle = "楞嚴經 卷一",
            text = text,
            fontSizeLevel = 2,
        )
    }

    private fun loadLongestLengyanVolume(): String {
        val root = context.assets.open("content-zh-Hant.json")
            .bufferedReader(Charsets.UTF_8)
            .use { reader -> JSONObject(reader.readText()) }
        val paragraphs = root.getJSONArray("paragraphs")
        val text = buildList {
            for (index in 0 until paragraphs.length()) {
                val paragraph = paragraphs.getJSONObject(index)
                if (paragraph.optString("volumeID") == "lengyan.v000009") {
                    add(paragraph.getString("text"))
                }
            }
        }.joinToString("\n\n")
        assertTrue(text.codePointCount(0, text.length) >= 9_000)
        return text
    }

    private fun String.takeCodePoints(count: Int): String {
        val end = offsetByCodePoints(0, count.coerceAtMost(codePointCount(0, length)))
        return substring(0, end)
    }

    private companion object {
        val REFERENCE_CHARACTER_COUNTS = listOf(1_800, 9_000, 20_000)
        val EXPORT_BUDGETS = mapOf(
            1_800 to ExportBudget(maximumPageCount = 2, maximumTotalFileBytes = 4L * MEBIBYTE),
            9_000 to ExportBudget(maximumPageCount = 9, maximumTotalFileBytes = 18L * MEBIBYTE),
            20_000 to ExportBudget(maximumPageCount = 20, maximumTotalFileBytes = 40L * MEBIBYTE),
        )
        const val MEBIBYTE = 1024 * 1024
    }
}

private data class ExportBudget(
    val maximumPageCount: Int,
    val maximumTotalFileBytes: Long,
)
