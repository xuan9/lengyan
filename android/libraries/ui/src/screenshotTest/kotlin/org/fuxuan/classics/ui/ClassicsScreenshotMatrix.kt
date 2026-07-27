package org.fuxuan.classics.ui

import android.content.res.Configuration
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import com.android.tools.screenshot.PreviewTest
import org.fuxuan.classics.core.behavior.ReadingMode
import org.fuxuan.classics.core.behavior.VolumeReadingDocument
import org.fuxuan.classics.core.content.BookManifest
import org.fuxuan.classics.core.content.ProductFeatures
import org.fuxuan.classics.core.content.ProductManifest
import org.fuxuan.classics.core.content.ScriptureContent
import org.fuxuan.classics.core.content.ScriptureParagraph
import org.fuxuan.classics.core.content.ScriptureSection
import org.fuxuan.classics.core.content.ScriptureVolume
import org.fuxuan.classics.core.content.SourceReference
import org.fuxuan.classics.core.persistence.AudioPreferences
import org.fuxuan.classics.core.persistence.Favorite
import org.fuxuan.classics.core.persistence.ProductPreferences
import org.fuxuan.classics.core.persistence.ReminderPreferences
import org.fuxuan.classics.core.persistence.ThemePreference

private const val NIGHT = Configuration.UI_MODE_NIGHT_YES
private const val DAY = Configuration.UI_MODE_NIGHT_NO

@PreviewTest
@Preview(name = "compact-light-100", widthDp = 320, heightDp = 700, fontScale = 1f, uiMode = DAY)
@Preview(name = "phone-dark-130", widthDp = 393, heightDp = 852, fontScale = 1.3f, uiMode = NIGHT)
@Preview(name = "foldable-dark-100", widthDp = 673, heightDp = 841, fontScale = 1f, uiMode = NIGHT)
@Preview(name = "tablet-light-200", widthDp = 1_000, heightDp = 700, fontScale = 2f, uiMode = DAY)
@Composable
fun homeTraditionalScreenshot() {
    val loaded = screenshotContent("zh-Hant")
    ScreenshotShell(
        selected = TopLevelDestination.READING,
        strings = AppStrings("zh-Hant"),
    ) {
        HomeScreen(
            loaded = loaded,
            strings = AppStrings("zh-Hant"),
            resumeRoute = VolumeReaderRoute(
                volumeID = "screenshot.v000007",
                paragraphID = "screenshot.p000007",
            ),
            onRead = {},
            onBrowseVolumes = {},
            onSearch = {},
        )
    }
}

@PreviewTest
@Preview(name = "compact-dark-200", widthDp = 320, heightDp = 700, fontScale = 2f, uiMode = NIGHT)
@Preview(name = "phone-light-100", widthDp = 393, heightDp = 852, fontScale = 1f, uiMode = DAY)
@Preview(name = "foldable-light-200", widthDp = 673, heightDp = 841, fontScale = 2f, uiMode = DAY)
@Preview(name = "tablet-dark-130", widthDp = 1_000, heightDp = 700, fontScale = 1.3f, uiMode = NIGHT)
@Composable
fun homeSimplifiedScreenshot() {
    val loaded = screenshotContent("zh-Hans")
    ScreenshotShell(
        selected = TopLevelDestination.READING,
        strings = AppStrings("zh-Hans"),
    ) {
        HomeScreen(
            loaded = loaded,
            strings = AppStrings("zh-Hans"),
            resumeRoute = null,
            onRead = {},
            onBrowseVolumes = {},
            onSearch = {},
        )
    }
}

@PreviewTest
@Preview(name = "phone-light-100", widthDp = 393, heightDp = 852, fontScale = 1f, uiMode = DAY)
@Preview(name = "phone-dark-200", widthDp = 393, heightDp = 852, fontScale = 2f, uiMode = NIGHT)
@Preview(name = "tablet-light-130", widthDp = 1_000, heightDp = 700, fontScale = 1.3f, uiMode = DAY)
@Composable
fun readerTraditionalScreenshot() {
    val loaded = screenshotContent("zh-Hant")
    ScreenshotShell(
        selected = TopLevelDestination.READING,
        strings = AppStrings("zh-Hant"),
    ) {
        ReaderScreen(
            document = VolumeReadingDocument.from(loaded.content, "screenshot.v000001"),
            fontSizeLevel = 2,
            strings = AppStrings("zh-Hant"),
            initialAnchor = null,
            onBack = {},
            onShare = {},
            onSaveProgress = {},
        )
    }
}

@PreviewTest
@Preview(name = "phone-light-100", widthDp = 393, heightDp = 852, fontScale = 1f, uiMode = DAY)
@Preview(name = "compact-dark-200", widthDp = 320, heightDp = 700, fontScale = 2f, uiMode = NIGHT)
@Composable
fun shareTraditionalScreenshot() {
    val loaded = screenshotContent("zh-Hant")
    val document = VolumeReadingDocument.from(loaded.content, "screenshot.v000001")
    ScreenshotShell(
        selected = TopLevelDestination.READING,
        strings = AppStrings("zh-Hant"),
    ) {
        ShareScreenContent(
            document = ShareDocument(
                locale = "zh-Hant",
                productTitle = loaded.product.title("zh-Hant"),
                volumeTitle = document.volume.title,
                text = document.text,
                fontSizeLevel = 2,
            ),
            strings = AppStrings("zh-Hant"),
            generationState = ShareImageGenerationState.Idle,
            statusMessage = null,
            onBack = {},
            onShareImage = {},
            onShareText = {},
            onSaveText = {},
            onCopyText = {},
            onCancelImageExport = {},
        )
    }
}

@PreviewTest
@Preview(name = "compact-light-200", widthDp = 320, heightDp = 700, fontScale = 2f, uiMode = DAY)
@Preview(name = "phone-dark-100", widthDp = 393, heightDp = 852, fontScale = 1f, uiMode = NIGHT)
@Preview(name = "tablet-light-130", widthDp = 1_000, heightDp = 700, fontScale = 1.3f, uiMode = DAY)
@Composable
fun directoryTraditionalScreenshot() {
    val loaded = screenshotContent("zh-Hant")
    ScreenshotShell(
        selected = TopLevelDestination.READING,
        strings = AppStrings("zh-Hant"),
    ) {
        ContentBrowserScreen(
            content = loaded.content,
            strings = AppStrings("zh-Hant"),
            resumeRoute = VolumeReaderRoute(
                volumeID = "screenshot.v000001",
                paragraphID = "screenshot.p000001",
            ),
            expandedSectionIDs = setOf("screenshot.s000001"),
            onExpandedSectionIDsChanged = {},
            onBack = {},
            onOpenVolume = {},
            onOpenParagraph = {},
        )
    }
}

@PreviewTest
@Preview(name = "compact-empty-light-130", widthDp = 320, heightDp = 700, fontScale = 1.3f, uiMode = DAY)
@Composable
fun favoritesEmptyScreenshot() {
    val loaded = screenshotContent("zh-Hant")
    ScreenshotShell(
        selected = TopLevelDestination.FAVORITES,
        strings = AppStrings("zh-Hant"),
    ) {
        FavoritesScreen(
            content = loaded.content,
            favorites = emptyList(),
            strings = AppStrings("zh-Hant"),
            onOpenFavorite = {},
            onRemoveFavorite = {},
        )
    }
}

@PreviewTest
@Preview(name = "tablet-populated-dark-200", widthDp = 1_000, heightDp = 700, fontScale = 2f, uiMode = NIGHT)
@Composable
fun favoritesTabletScreenshot() {
    val loaded = screenshotContent("zh-Hant")
    val paragraph = requireNotNull(loaded.content.paragraph("screenshot.p000001"))
    ScreenshotShell(
        selected = TopLevelDestination.FAVORITES,
        strings = AppStrings("zh-Hant"),
    ) {
        FavoritesScreen(
            content = loaded.content,
            favorites = listOf(
                Favorite.paragraph(
                    productID = loaded.content.productID,
                    editionID = loaded.content.editionID,
                    sectionID = paragraph.sectionID,
                    paragraphID = paragraph.paragraphID,
                    createdAtEpochMilliseconds = 1,
                ),
            ),
            strings = AppStrings("zh-Hant"),
            onOpenFavorite = {},
            onRemoveFavorite = {},
            detailContent = { target ->
                ReaderScreen(
                    document = VolumeReadingDocument.from(loaded.content, target.volumeID),
                    fontSizeLevel = 2,
                    strings = AppStrings("zh-Hant"),
                    initialAnchor = target.anchor,
                    showBackButton = false,
                    onBack = {},
                    onShare = {},
                    onSaveProgress = {},
                )
            },
        )
    }
}

@PreviewTest
@Preview(name = "compact-dark-200", widthDp = 320, heightDp = 700, fontScale = 2f, uiMode = NIGHT)
@Preview(name = "tablet-light-130", widthDp = 1_000, heightDp = 700, fontScale = 1.3f, uiMode = DAY)
@Composable
fun settingsTraditionalScreenshot() {
    ScreenshotShell(
        selected = TopLevelDestination.SETTINGS,
        strings = AppStrings("zh-Hant"),
    ) {
        SettingsScreen(
            preferences = ProductPreferences(
                theme = ThemePreference.SYSTEM,
                locale = "zh-Hant",
                fontSizeLevel = 2,
                readingMode = ReadingMode.CHAPTER,
                reminder = ReminderPreferences(),
                audio = AudioPreferences(),
                readingProgress = null,
                audioProgress = null,
                expandedSectionIDs = emptySet(),
            ),
            supportedLocales = listOf("zh-Hant", "zh-Hans"),
            strings = AppStrings("zh-Hant"),
            onSelectTheme = {},
            onSelectLocale = {},
            onSelectFontSize = {},
        )
    }
}

@Composable
private fun ScreenshotShell(
    selected: TopLevelDestination,
    strings: AppStrings,
    content: @Composable () -> Unit,
) {
    ClassicsTheme(darkTheme = isSystemInDarkTheme()) {
        Scaffold(
            modifier = Modifier.fillMaxSize(),
            containerColor = MaterialTheme.colorScheme.background,
            contentWindowInsets = WindowInsets(0, 0, 0, 0),
            bottomBar = {
                BottomRegion(
                    selected = selected,
                    strings = strings,
                    onSelect = {},
                )
            },
        ) { padding ->
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .consumeWindowInsets(padding),
            ) {
                content()
            }
        }
    }
}

private fun screenshotContent(locale: String): LoadedContent {
    val simplified = locale == "zh-Hans"
    val source = SourceReference("screenshot.source", "fixture#1")
    val numerals = listOf("一", "二", "三", "四", "五", "六", "七", "八", "九", "十")
    val volumes = numerals.mapIndexed { index, numeral ->
        ScriptureVolume(
            volumeID = "screenshot.v${(index + 1).toString().padStart(6, '0')}",
            number = index + 1,
            order = index,
            title = "楞嚴經 卷$numeral",
            sourceReferences = listOf(source),
        )
    }
    val root = ScriptureSection(
        sectionID = "screenshot.s000001",
        parentSectionID = null,
        order = 0,
        title = if (simplified) "大佛顶首楞严经科判" else "大佛頂首楞嚴經科判",
        subtitle = null,
        sourceReferences = listOf(source),
        legacyIDs = emptyList(),
    )
    val leaf = ScriptureSection(
        sectionID = "screenshot.s000002",
        parentSectionID = root.sectionID,
        order = 0,
        title = if (simplified) "序分：大众云集，启请妙法" else "序分：大眾雲集，啟請妙法",
        subtitle = null,
        sourceReferences = listOf(source),
        legacyIDs = emptyList(),
    )
    val paragraphs = volumes.mapIndexed { index, volume ->
        ScriptureParagraph(
            paragraphID = "screenshot.p${(index + 1).toString().padStart(6, '0')}",
            sectionID = leaf.sectionID,
            volumeID = volume.volumeID,
            order = index,
            textRole = "sutra",
            text = if (simplified) {
                "如是我闻。一时大众云集，闻法欢喜，依教奉行。此段文字用于验证阅读排版与大字显示。"
            } else {
                "如是我聞。一時大眾雲集，聞法歡喜，依教奉行。此段文字用於驗證閱讀排版與大字顯示。"
            },
            sourceReferences = listOf(source),
            legacyIDs = emptyList(),
            legacyVolumeHint = index + 1,
        )
    }
    val content = ScriptureContent(
        schemaVersion = 1,
        productID = "screenshot",
        bookID = "screenshot-book",
        editionID = "screenshot-edition-v1",
        contentVersion = "2026.07.26",
        contentStatus = "legacy-migration",
        locale = locale,
        normalization = "utf8-nfc-lf-v1",
        contentHash = "0".repeat(64),
        volumes = volumes,
        sections = listOf(root, leaf),
        paragraphs = paragraphs,
    )
    return LoadedContent(
        product = ProductManifest(
            schemaVersion = 1,
            productID = "screenshot",
            lifecycle = "development",
            titles = mapOf(
                "zh-Hant" to "楞嚴經",
                "zh-Hans" to "楞严经",
            ),
            defaultLocale = "zh-Hant",
            supportedLocales = listOf("zh-Hant", "zh-Hans"),
            navigationMode = "hierarchy-and-volumes",
            bookManifestPath = "Book/book.json",
            sourceManifestPath = "Sources/source.json",
            audioManifestPath = null,
            androidAudioDeliveryPath = null,
            features = ProductFeatures(
                audio = false,
                dailyVerse = false,
                guidedReading = false,
                personIndex = false,
            ),
        ),
        book = BookManifest(
            schemaVersion = 1,
            productID = "screenshot",
            bookID = "screenshot-book",
            editionID = "screenshot-edition-v1",
            contractState = "legacy-migration",
            titles = mapOf(
                "zh-Hant" to "大佛頂如來密因修證了義諸菩薩萬行首楞嚴經",
                "zh-Hans" to "大佛顶如来密因修证了义诸菩萨万行首楞严经",
            ),
            canonicalLocale = "zh-Hant",
            supportedLocales = listOf("zh-Hant", "zh-Hans"),
            contentVersion = "2026.07.26",
            stableIDScheme = "fuxuan-classics-v1",
            normalization = "utf8-nfc-lf-v1",
            sourceManifestPath = "Sources/source.json",
            contentPackagePaths = mapOf(
                "zh-Hant" to "Content/zh-Hant/content.json",
                "zh-Hans" to "Content/zh-Hans/content.json",
            ),
            legacyMapPath = null,
        ),
        content = content,
    )
}
