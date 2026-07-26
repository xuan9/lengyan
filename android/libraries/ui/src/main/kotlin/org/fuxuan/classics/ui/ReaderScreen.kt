package org.fuxuan.classics.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.distinctUntilChanged
import org.fuxuan.classics.core.behavior.ParagraphTextAnchor
import org.fuxuan.classics.core.behavior.VolumeReadingDocument
import kotlin.math.roundToInt

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun ReaderScreen(
    document: VolumeReadingDocument,
    fontSizeLevel: Int,
    strings: AppStrings,
    initialAnchor: ParagraphTextAnchor?,
    highlightCharacterCount: Int = 0,
    favoriteParagraphIDs: Set<String> = emptySet(),
    showBackButton: Boolean = true,
    onBack: () -> Unit,
    onToggleFavorite: (ParagraphTextAnchor) -> Unit = {},
    onSaveProgress: suspend (ParagraphTextAnchor) -> Unit,
) {
    val scrollState = rememberScrollState()
    val topPadding = 20.dp
    val topPaddingPixels = with(LocalDensity.current) { topPadding.toPx() }
    var textLayout by remember(document) { mutableStateOf<TextLayoutResult?>(null) }
    var restoreCompleted by remember(document, initialAnchor) { mutableStateOf(false) }
    var reflowAnchor by remember(document) { mutableStateOf<ParagraphTextAnchor?>(null) }
    var lastSavedAnchor by remember(document, initialAnchor) { mutableStateOf(initialAnchor) }
    var currentAnchor by remember(document, initialAnchor) {
        mutableStateOf(
            initialAnchor
                ?.let(document::utf16OffsetFor)
                ?.let(document::anchorAtUtf16Offset)
                ?: document.anchorAtUtf16Offset(0),
        )
    }
    val highlightColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.20f)
    val readerText = remember(
        document,
        initialAnchor,
        highlightCharacterCount,
        highlightColor,
    ) {
        highlightedDocumentText(
            document = document,
            anchor = initialAnchor,
            characterCount = highlightCharacterCount,
            highlightColor = highlightColor,
        )
    }

    LaunchedEffect(textLayout, document, initialAnchor) {
        val layout = textLayout ?: return@LaunchedEffect
        if (restoreCompleted) return@LaunchedEffect
        val utf16Offset = initialAnchor?.let(document::utf16OffsetFor) ?: 0
        currentAnchor = document.anchorAtUtf16Offset(utf16Offset)
        scrollState.scrollTo(
            layout.scrollOffsetFor(
                utf16Offset = utf16Offset,
                textLength = document.text.length,
                topPaddingPixels = topPaddingPixels,
                maxScroll = { scrollState.maxValue },
            ),
        )
        restoreCompleted = true
    }

    LaunchedEffect(textLayout, reflowAnchor, restoreCompleted, document) {
        val layout = textLayout ?: return@LaunchedEffect
        val anchor = reflowAnchor ?: return@LaunchedEffect
        if (!restoreCompleted) return@LaunchedEffect
        val utf16Offset = document.utf16OffsetFor(anchor) ?: return@LaunchedEffect
        scrollState.scrollTo(
            layout.scrollOffsetFor(
                utf16Offset = utf16Offset,
                textLength = document.text.length,
                topPaddingPixels = topPaddingPixels,
                maxScroll = { scrollState.maxValue },
            ),
        )
        reflowAnchor = null
    }

    LaunchedEffect(scrollState, textLayout, restoreCompleted, document) {
        val layout = textLayout ?: return@LaunchedEffect
        if (!restoreCompleted) return@LaunchedEffect
        snapshotFlow { scrollState.isScrollInProgress to scrollState.value }
            .distinctUntilChanged()
            .collectLatest { (isScrolling, scrollOffset) ->
                if (isScrolling) return@collectLatest
                delay(250)
                val anchor = anchorAtScrollPosition(
                    document = document,
                    layout = layout,
                    scrollOffset = scrollOffset,
                    topPaddingPixels = topPaddingPixels,
                )
                currentAnchor = anchor
                if (anchor != lastSavedAnchor) {
                    onSaveProgress(anchor)
                    lastSavedAnchor = anchor
                }
            }
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = document.volume.title,
                        modifier = Modifier.semantics { heading() },
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        style = MaterialTheme.typography.titleMedium.copy(letterSpacing = 0.sp),
                    )
                },
                navigationIcon = {
                    if (showBackButton) BackButton(strings.back, onBack)
                },
                actions = {
                    val isFavorite = currentAnchor.paragraphID in favoriteParagraphIDs
                    IconButton(
                        onClick = {
                            val visibleAnchor = textLayout?.let { layout ->
                                anchorAtScrollPosition(
                                    document = document,
                                    layout = layout,
                                    scrollOffset = scrollState.value,
                                    topPaddingPixels = topPaddingPixels,
                                )
                            } ?: currentAnchor
                            currentAnchor = visibleAnchor
                            onToggleFavorite(visibleAnchor)
                        },
                        modifier = Modifier.testTag("reader.favorite"),
                    ) {
                        Icon(
                            imageVector = if (isFavorite) {
                                Icons.Default.Favorite
                            } else {
                                Icons.Default.FavoriteBorder
                            },
                            contentDescription = if (isFavorite) {
                                strings.removeFavorite
                            } else {
                                strings.addFavorite
                            },
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                ),
            )
        },
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
        ) {
            Column(
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .widthIn(max = 760.dp)
                    .fillMaxWidth()
                    .fillMaxHeight()
                    .testTag("reader.scroll")
                    .verticalScroll(scrollState)
                    .padding(
                        start = 24.dp,
                        top = topPadding,
                        end = 24.dp,
                        bottom = 36.dp,
                    ),
            ) {
                SelectionContainer {
                    ReaderText(
                        text = readerText,
                        fontSizeLevel = fontSizeLevel,
                        onTextLayout = { nextLayout ->
                            val previousLayout = textLayout
                            if (
                                restoreCompleted &&
                                previousLayout != null &&
                                previousLayout.layoutInput != nextLayout.layoutInput
                            ) {
                                reflowAnchor = anchorAtScrollPosition(
                                    document = document,
                                    layout = previousLayout,
                                    scrollOffset = scrollState.value,
                                    topPaddingPixels = topPaddingPixels,
                                )
                            }
                            textLayout = nextLayout
                        },
                    )
                }
            }
        }
    }
}

@Composable
internal fun ReaderText(
    text: String,
    fontSizeLevel: Int,
    modifier: Modifier = Modifier,
    onTextLayout: (TextLayoutResult) -> Unit = {},
) = ReaderText(
    text = AnnotatedString(text),
    fontSizeLevel = fontSizeLevel,
    modifier = modifier,
    onTextLayout = onTextLayout,
)

@Composable
private fun ReaderText(
    text: AnnotatedString,
    fontSizeLevel: Int,
    modifier: Modifier = Modifier,
    onTextLayout: (TextLayoutResult) -> Unit = {},
) {
    val typography = readerTypography(fontSizeLevel)
    Text(
        text = text,
        modifier = modifier.fillMaxWidth(),
        color = MaterialTheme.colorScheme.onBackground,
        fontSize = typography.fontSize,
        fontWeight = FontWeight.Normal,
        lineHeight = typography.lineHeight,
        letterSpacing = 0.sp,
        textAlign = TextAlign.Start,
        onTextLayout = onTextLayout,
    )
}

private fun highlightedDocumentText(
    document: VolumeReadingDocument,
    anchor: ParagraphTextAnchor?,
    characterCount: Int,
    highlightColor: Color,
): AnnotatedString = buildAnnotatedString {
    append(document.text)
    if (anchor == null || characterCount <= 0) return@buildAnnotatedString
    val start = document.utf16OffsetFor(anchor) ?: return@buildAnnotatedString
    val end = document.utf16OffsetFor(
        anchor.copy(characterOffset = anchor.characterOffset + characterCount),
    ) ?: return@buildAnnotatedString
    if (end <= start) return@buildAnnotatedString
    addStyle(
        style = SpanStyle(background = highlightColor),
        start = start,
        end = end,
    )
}

private suspend fun TextLayoutResult.scrollOffsetFor(
    utf16Offset: Int,
    textLength: Int,
    topPaddingPixels: Float,
    maxScroll: () -> Int,
): Int {
    val targetLine = getLineForOffset(utf16Offset.coerceIn(0, textLength - 1))
    withFrameNanos { }
    return (topPaddingPixels + getLineTop(targetLine))
        .roundToInt()
        .coerceIn(0, maxScroll())
}

private fun anchorAtScrollPosition(
    document: VolumeReadingDocument,
    layout: TextLayoutResult,
    scrollOffset: Int,
    topPaddingPixels: Float,
): ParagraphTextAnchor {
    val textY = (scrollOffset - topPaddingPixels).coerceAtLeast(0f)
    val line = layout.getLineForVerticalPosition(textY)
    return document.anchorAtUtf16Offset(layout.getLineStart(line))
}

private data class ReaderTypography(
    val fontSize: TextUnit,
    val lineHeight: TextUnit,
)

private fun readerTypography(level: Int): ReaderTypography = when (level) {
    0 -> ReaderTypography(fontSize = 20.sp, lineHeight = 35.sp)
    1 -> ReaderTypography(fontSize = 22.sp, lineHeight = 39.sp)
    2 -> ReaderTypography(fontSize = 24.sp, lineHeight = 42.sp)
    3 -> ReaderTypography(fontSize = 27.sp, lineHeight = 47.sp)
    4 -> ReaderTypography(fontSize = 30.sp, lineHeight = 53.sp)
    else -> error("unsupported font size level: $level")
}
