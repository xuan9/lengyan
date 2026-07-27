package org.fuxuan.classics.ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.text.LineBreaker
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import androidx.core.graphics.createBitmap
import androidx.core.graphics.withClip
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.UUID
import kotlin.coroutines.coroutineContext
import kotlin.math.max

internal data class ShareImagePagePlan(
    val pageNumber: Int,
    val startUtf16Offset: Int,
    val endUtf16Offset: Int,
    val bodyHeightPixels: Int,
    val imageHeightPixels: Int,
) {
    init {
        require(pageNumber > 0)
        require(startUtf16Offset >= 0)
        require(endUtf16Offset > startUtf16Offset)
        require(bodyHeightPixels > 0)
        require(imageHeightPixels > 0)
    }
}

internal data class ShareImagePlan(
    val widthPixels: Int,
    val bodyFontSizePixels: Float,
    val bodyLineHeightPixels: Float,
    val pages: List<ShareImagePagePlan>,
) {
    init {
        require(widthPixels > 0)
        require(bodyFontSizePixels > 0)
        require(bodyLineHeightPixels >= bodyFontSizePixels)
        require(pages.isNotEmpty())
    }

    val totalPixels: Long
        get() = pages.sumOf { widthPixels.toLong() * it.imageHeightPixels }

    val maximumBitmapBytes: Long
        get() = widthPixels.toLong() * pages.maxOf { it.imageHeightPixels } * BYTES_PER_PIXEL

    private companion object {
        const val BYTES_PER_PIXEL = 2L
    }
}

internal data class ShareImageExportProgress(
    val completedPageCount: Int,
    val pageCount: Int,
) {
    init {
        require(pageCount > 0)
        require(completedPageCount in 0..pageCount)
    }
}

internal data class ShareImageExport(
    val files: List<File>,
    val plan: ShareImagePlan,
    val totalFileBytes: Long,
) {
    init {
        require(files.isNotEmpty())
        require(files.size == plan.pages.size)
        require(totalFileBytes >= 0)
    }
}

internal fun interface ShareImageExporter {
    suspend fun export(
        document: ShareDocument,
        onProgress: suspend (ShareImageExportProgress) -> Unit,
    ): ShareImageExport
}

internal class AndroidShareImageExporter(
    context: Context,
    private val workerDispatcher: CoroutineDispatcher = Dispatchers.Default,
    private val maximumPageHeightPixels: Int = MAXIMUM_PAGE_HEIGHT_PIXELS,
) : ShareImageExporter {
    private val applicationContext = context.applicationContext

    init {
        require(maximumPageHeightPixels >= MINIMUM_PAGE_HEIGHT_PIXELS) {
            "share page height must accommodate the minimum image height"
        }
    }

    override suspend fun export(
        document: ShareDocument,
        onProgress: suspend (ShareImageExportProgress) -> Unit,
    ): ShareImageExport = withContext(workerDispatcher) {
        cleanupExpiredExports()
        val plan = plan(document)
        onProgress(ShareImageExportProgress(completedPageCount = 0, pageCount = plan.pages.size))
        val exportDirectory = createExportDirectory()
        val files = ArrayList<File>(plan.pages.size)

        try {
            plan.pages.forEach { page ->
                coroutineContext.ensureActive()
                val file = File(
                    exportDirectory,
                    document.imageFileName(page.pageNumber, plan.pages.size),
                )
                renderPage(
                    document = document,
                    page = page,
                    pageCount = plan.pages.size,
                    destination = file,
                )
                files += file
                onProgress(
                    ShareImageExportProgress(
                        completedPageCount = files.size,
                        pageCount = plan.pages.size,
                    ),
                )
            }
            ShareImageExport(
                files = files,
                plan = plan,
                totalFileBytes = files.sumOf(File::length),
            )
        } catch (cancellation: CancellationException) {
            exportDirectory.deleteRecursively()
            throw cancellation
        } catch (failure: Throwable) {
            exportDirectory.deleteRecursively()
            throw failure
        }
    }

    internal fun plan(document: ShareDocument): ShareImagePlan {
        val layout = bodyLayout(document.text, document.fontSizeLevel)
        val availableBodyHeight = maximumPageHeightPixels - BODY_TOP_PIXELS - FOOTER_HEIGHT_PIXELS
        val pages = mutableListOf<ShareImagePagePlan>()
        var startLine = 0

        while (startLine < layout.lineCount) {
            val pageTop = layout.getLineTop(startLine)
            var endLine = startLine
            while (
                endLine + 1 < layout.lineCount &&
                layout.getLineBottom(endLine + 1) - pageTop <= availableBodyHeight
            ) {
                endLine += 1
            }

            val bodyHeight = layout.getLineBottom(endLine) - pageTop
            val startOffset = layout.getLineStart(startLine)
            val endOffset = layout.getLineEnd(endLine)
            check(endOffset > startOffset) { "share page must advance through source text" }
            pages += ShareImagePagePlan(
                pageNumber = pages.size + 1,
                startUtf16Offset = startOffset,
                endUtf16Offset = endOffset,
                bodyHeightPixels = bodyHeight,
                imageHeightPixels = max(
                    MINIMUM_PAGE_HEIGHT_PIXELS,
                    BODY_TOP_PIXELS + bodyHeight + FOOTER_HEIGHT_PIXELS,
                ),
            )
            startLine = endLine + 1
        }

        check(pages.last().endUtf16Offset == document.text.length) {
            "share pagination must include the complete source text"
        }
        val typography = readerTypography(document.fontSizeLevel)
        return ShareImagePlan(
            widthPixels = CANVAS_WIDTH_PIXELS,
            bodyFontSizePixels = typography.fontSize.value * CANVAS_DENSITY,
            bodyLineHeightPixels = typography.lineHeight.value * CANVAS_DENSITY,
            pages = pages,
        )
    }

    private fun renderPage(
        document: ShareDocument,
        page: ShareImagePagePlan,
        pageCount: Int,
        destination: File,
    ) {
        val bitmap = createBitmap(
            CANVAS_WIDTH_PIXELS,
            page.imageHeightPixels,
            Bitmap.Config.RGB_565,
        )
        try {
            val canvas = Canvas(bitmap)
            canvas.drawColor(BACKGROUND_COLOR)
            drawHeader(canvas, document.productTitle)
            drawBody(canvas, document, page)
            drawFooter(canvas, document.volumeTitle, page.pageNumber, pageCount, page.imageHeightPixels)
            FileOutputStream(destination).use { output ->
                if (!bitmap.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, output)) {
                    throw IOException("failed to encode share JPEG")
                }
            }
        } finally {
            bitmap.recycle()
        }
    }

    private fun drawHeader(canvas: Canvas, productTitle: String) {
        val titlePaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = PRIMARY_COLOR
            textSize = HEADER_TEXT_SIZE_PIXELS
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            textAlign = Paint.Align.CENTER
            letterSpacing = 0f
        }
        val title = TextUtils.ellipsize(
            productTitle,
            titlePaint,
            CANVAS_WIDTH_PIXELS - HORIZONTAL_PADDING_PIXELS * 2f,
            TextUtils.TruncateAt.END,
        ).toString()
        canvas.drawText(title, CANVAS_WIDTH_PIXELS / 2f, HEADER_BASELINE_PIXELS, titlePaint)

        val dividerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = DIVIDER_COLOR
            strokeWidth = DIVIDER_WIDTH_PIXELS
        }
        canvas.drawLine(
            HORIZONTAL_PADDING_PIXELS.toFloat(),
            HEADER_DIVIDER_Y_PIXELS,
            (CANVAS_WIDTH_PIXELS - HORIZONTAL_PADDING_PIXELS).toFloat(),
            HEADER_DIVIDER_Y_PIXELS,
            dividerPaint,
        )
    }

    private fun drawBody(
        canvas: Canvas,
        document: ShareDocument,
        page: ShareImagePagePlan,
    ) {
        val pageText = document.text.substring(page.startUtf16Offset, page.endUtf16Offset)
        val layout = bodyLayout(pageText, document.fontSizeLevel)
        canvas.withClip(
            HORIZONTAL_PADDING_PIXELS,
            BODY_TOP_PIXELS,
            CANVAS_WIDTH_PIXELS - HORIZONTAL_PADDING_PIXELS,
            BODY_TOP_PIXELS + page.bodyHeightPixels,
        ) {
            translate(HORIZONTAL_PADDING_PIXELS.toFloat(), BODY_TOP_PIXELS.toFloat())
            layout.draw(this)
        }
    }

    private fun drawFooter(
        canvas: Canvas,
        volumeTitle: String,
        pageNumber: Int,
        pageCount: Int,
        imageHeight: Int,
    ) {
        val dividerY = imageHeight - FOOTER_DIVIDER_BOTTOM_OFFSET_PIXELS
        val dividerPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = DIVIDER_COLOR
            strokeWidth = DIVIDER_WIDTH_PIXELS
        }
        canvas.drawLine(
            HORIZONTAL_PADDING_PIXELS.toFloat(),
            dividerY.toFloat(),
            (CANVAS_WIDTH_PIXELS - HORIZONTAL_PADDING_PIXELS).toFloat(),
            dividerY.toFloat(),
            dividerPaint,
        )

        val footerPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            color = SECONDARY_TEXT_COLOR
            textSize = FOOTER_TEXT_SIZE_PIXELS
            typeface = Typeface.create("sans-serif", Typeface.NORMAL)
            letterSpacing = 0f
        }
        val pageLabel = "$pageNumber / $pageCount"
        footerPaint.textAlign = Paint.Align.RIGHT
        canvas.drawText(
            pageLabel,
            (CANVAS_WIDTH_PIXELS - HORIZONTAL_PADDING_PIXELS).toFloat(),
            (imageHeight - FOOTER_BASELINE_BOTTOM_OFFSET_PIXELS).toFloat(),
            footerPaint,
        )
        val pageLabelWidth = footerPaint.measureText(pageLabel)
        val sourceWidth = CANVAS_WIDTH_PIXELS - HORIZONTAL_PADDING_PIXELS * 2f - pageLabelWidth - FOOTER_GAP_PIXELS
        val source = TextUtils.ellipsize(
            volumeTitle,
            footerPaint,
            sourceWidth,
            TextUtils.TruncateAt.END,
        ).toString()
        footerPaint.textAlign = Paint.Align.LEFT
        canvas.drawText(
            source,
            HORIZONTAL_PADDING_PIXELS.toFloat(),
            (imageHeight - FOOTER_BASELINE_BOTTOM_OFFSET_PIXELS).toFloat(),
            footerPaint,
        )
    }

    private fun bodyLayout(text: String, fontSizeLevel: Int): StaticLayout {
        val typography = readerTypography(fontSizeLevel)
        val fontSizePixels = typography.fontSize.value * CANVAS_DENSITY
        val targetLineHeight = typography.lineHeight.value * CANVAS_DENSITY
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG or Paint.SUBPIXEL_TEXT_FLAG).apply {
            color = BODY_TEXT_COLOR
            textSize = fontSizePixels
            typeface = Typeface.create("sans-serif", Typeface.NORMAL)
            letterSpacing = 0f
        }
        val naturalLineHeight = paint.fontMetrics.descent - paint.fontMetrics.ascent
        return StaticLayout.Builder.obtain(
            text,
            0,
            text.length,
            paint,
            CANVAS_WIDTH_PIXELS - HORIZONTAL_PADDING_PIXELS * 2,
        )
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setIncludePad(false)
            .setLineSpacing(max(0f, targetLineHeight - naturalLineHeight), 1f)
            .setBreakStrategy(LineBreaker.BREAK_STRATEGY_SIMPLE)
            .setHyphenationFrequency(Layout.HYPHENATION_FREQUENCY_NONE)
            .build()
    }

    private fun createExportDirectory(): File {
        val root = File(applicationContext.cacheDir, EXPORT_ROOT_DIRECTORY)
        if (!root.exists() && !root.mkdirs()) {
            throw IOException("failed to create share cache root")
        }
        val directory = File(root, UUID.randomUUID().toString())
        if (!directory.mkdir()) throw IOException("failed to create share export directory")
        return directory
    }

    private fun cleanupExpiredExports() {
        val root = File(applicationContext.cacheDir, EXPORT_ROOT_DIRECTORY)
        val cutoff = System.currentTimeMillis() - EXPORT_RETENTION_MILLISECONDS
        var retainedBytes = 0L
        root.listFiles()
            ?.sortedByDescending(File::lastModified)
            ?.forEachIndexed { index, entry ->
                val entryBytes = entry.directorySize()
                val expired = entry.lastModified() < cutoff
                val overBudget = index >= MINIMUM_RETAINED_EXPORT_COUNT &&
                    retainedBytes + entryBytes > EXPORT_CACHE_BUDGET_BYTES
                if (expired || overBudget) {
                    entry.deleteRecursively()
                } else {
                    retainedBytes += entryBytes
                }
        }
    }

    internal companion object {
        const val CANVAS_WIDTH_PIXELS = 1080
        const val MAXIMUM_PAGE_HEIGHT_PIXELS = 13500
        const val MINIMUM_PAGE_HEIGHT_PIXELS = 810
        const val JPEG_QUALITY = 90
        const val EXPORT_ROOT_DIRECTORY = "classics-shares"

        private const val CANONICAL_CANVAS_WIDTH_DP = 393f
        private const val CANVAS_DENSITY = CANVAS_WIDTH_PIXELS / CANONICAL_CANVAS_WIDTH_DP
        private const val HORIZONTAL_PADDING_PIXELS = 86
        private const val BODY_TOP_PIXELS = 190
        private const val FOOTER_HEIGHT_PIXELS = 150
        private const val HEADER_TEXT_SIZE_PIXELS = 42f
        private const val HEADER_BASELINE_PIXELS = 92f
        private const val HEADER_DIVIDER_Y_PIXELS = 142f
        private const val DIVIDER_WIDTH_PIXELS = 2f
        private const val FOOTER_TEXT_SIZE_PIXELS = 34f
        private const val FOOTER_DIVIDER_BOTTOM_OFFSET_PIXELS = 104
        private const val FOOTER_BASELINE_BOTTOM_OFFSET_PIXELS = 48
        private const val FOOTER_GAP_PIXELS = 32f
        private const val EXPORT_RETENTION_MILLISECONDS = 24L * 60 * 60 * 1000
        private const val EXPORT_CACHE_BUDGET_BYTES = 128L * 1024 * 1024
        private const val MINIMUM_RETAINED_EXPORT_COUNT = 2

        private val BACKGROUND_COLOR = Color.rgb(250, 249, 244)
        private val BODY_TEXT_COLOR = Color.rgb(32, 35, 31)
        private val SECONDARY_TEXT_COLOR = Color.rgb(95, 99, 92)
        private val PRIMARY_COLOR = Color.rgb(70, 107, 60)
        private val DIVIDER_COLOR = Color.rgb(211, 213, 205)
    }
}

private fun File.directorySize(): Long = if (isFile) {
    length()
} else {
    listFiles()?.sumOf(File::directorySize) ?: 0
}
