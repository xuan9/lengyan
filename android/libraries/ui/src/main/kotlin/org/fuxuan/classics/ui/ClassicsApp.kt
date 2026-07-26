package org.fuxuan.classics.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation3.runtime.NavKey
import androidx.navigation3.runtime.entryProvider
import androidx.navigation3.runtime.rememberNavBackStack
import androidx.navigation3.ui.NavDisplay
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import org.fuxuan.classics.core.AppContainer
import org.fuxuan.classics.core.behavior.ParagraphTextAnchor
import org.fuxuan.classics.core.behavior.ReadingAnchorOrigin
import org.fuxuan.classics.core.behavior.ReadingAnchorSelectionPolicy
import org.fuxuan.classics.core.behavior.ReadingMode
import org.fuxuan.classics.core.behavior.ScriptureSearchNavigationPolicy
import org.fuxuan.classics.core.behavior.VolumeReadingDocument
import org.fuxuan.classics.core.content.BookManifest
import org.fuxuan.classics.core.content.ProductManifest
import org.fuxuan.classics.core.content.ScriptureContent
import org.fuxuan.classics.core.persistence.ProductPreferences
import org.fuxuan.classics.core.persistence.ReadingProgress
import org.fuxuan.classics.core.persistence.ThemePreference

@Serializable
data object HomeRoute : NavKey

@Serializable
data object VolumeListRoute : NavKey

@Serializable
data object SearchRoute : NavKey

@Serializable
data class VolumeReaderRoute(
    val volumeID: String,
    val paragraphID: String? = null,
    val characterOffset: Int = 0,
    val requestedAtEpochMilliseconds: Long = 0,
    val highlightCharacterCount: Int = 0,
) : NavKey {
    init {
        require(volumeID.isNotBlank()) { "reader route volumeID must not be blank" }
        require(paragraphID == null || paragraphID.isNotBlank()) {
            "reader route paragraphID must not be blank"
        }
        require(characterOffset >= 0) { "reader route offset must not be negative" }
        require(requestedAtEpochMilliseconds >= 0) {
            "reader route timestamp must not be negative"
        }
        require(highlightCharacterCount >= 0) {
            "reader route highlight length must not be negative"
        }
    }
}

@Composable
fun ClassicsApp(
    container: AppContainer,
    modifier: Modifier = Modifier,
    onDarkThemeChanged: (Boolean) -> Unit = {},
) {
    val preferences by container.userPreferencesRepository.preferences.collectAsState(initial = null)
    val systemDarkTheme = isSystemInDarkTheme()
    val darkTheme = when (preferences?.theme) {
        ThemePreference.LIGHT -> false
        ThemePreference.DARK -> true
        ThemePreference.SYSTEM, null -> systemDarkTheme
    }
    LaunchedEffect(darkTheme) { onDarkThemeChanged(darkTheme) }

    ClassicsTheme(darkTheme = darkTheme) {
        Surface(
            color = MaterialTheme.colorScheme.background,
            modifier = modifier.fillMaxSize(),
        ) {
            val currentPreferences = preferences
            if (currentPreferences == null) {
                LoadingScreen(title = container.product.displayName)
            } else {
                ContentNavigation(container = container, preferences = currentPreferences)
            }
        }
    }
}

@Composable
private fun ContentNavigation(
    container: AppContainer,
    preferences: ProductPreferences,
) {
    var retryKey by remember { mutableIntStateOf(0) }
    val loadState by produceState<ContentLoadState>(
        initialValue = ContentLoadState.Loading,
        container.bookRepository,
        preferences.locale,
        retryKey,
    ) {
        value = ContentLoadState.Loading
        value = runCatching {
            LoadedContent(
                product = container.bookRepository.product(),
                book = container.bookRepository.book(),
                content = container.bookRepository.content(preferences.locale),
            )
        }.fold(
            onSuccess = ContentLoadState::Ready,
            onFailure = { ContentLoadState.Failed },
        )
    }

    when (val state = loadState) {
        ContentLoadState.Loading -> LoadingScreen(title = container.product.displayName)
        ContentLoadState.Failed -> ErrorScreen(
            locale = preferences.locale,
            onRetry = { retryKey += 1 },
        )
        is ContentLoadState.Ready -> LoadedContentNavigation(
            container = container,
            loaded = state.value,
            preferences = preferences,
        )
    }
}

@Composable
private fun LoadedContentNavigation(
    container: AppContainer,
    loaded: LoadedContent,
    preferences: ProductPreferences,
) {
    val backStack = rememberNavBackStack(HomeRoute)
    val navigationScope = rememberCoroutineScope()
    val strings = remember(preferences.locale) { AppStrings(preferences.locale) }
    val resumeRoute = remember(loaded, preferences.readingProgress) {
        loaded.resumeRoute(preferences.readingProgress)
    }

    NavDisplay(
        backStack = backStack,
        modifier = Modifier.fillMaxSize(),
        onBack = { backStack.removeLastOrNull() },
        entryProvider = entryProvider {
            entry<HomeRoute> {
                HomeScreen(
                    loaded = loaded,
                    strings = strings,
                    resumeRoute = resumeRoute,
                    onRead = {
                        backStack.add(
                            resumeRoute ?: VolumeReaderRoute(
                                loaded.content.volumesInReadingOrder().first().volumeID,
                            ),
                        )
                    },
                    onBrowseVolumes = { backStack.add(VolumeListRoute) },
                    onSearch = { backStack.add(SearchRoute) },
                )
            }
            entry<VolumeListRoute> {
                VolumeListScreen(
                    content = loaded.content,
                    strings = strings,
                    resumeRoute = resumeRoute,
                    onBack = { backStack.removeLastOrNull() },
                    onOpenVolume = { volumeID ->
                        backStack.add(
                            resumeRoute?.takeIf { it.volumeID == volumeID }
                                ?: VolumeReaderRoute(volumeID),
                        )
                    },
                )
            }
            entry<SearchRoute> {
                SearchScreen(
                    repository = container.bookRepository,
                    content = loaded.content,
                    strings = strings,
                    onBack = { backStack.removeLastOrNull() },
                    onOpenResult = { result ->
                        ScriptureSearchNavigationPolicy.target(loaded.content, result)
                            ?.let { target ->
                                val openedAt = timestampAfter(
                                    resumeRoute?.requestedAtEpochMilliseconds,
                                )
                                backStack.add(
                                    VolumeReaderRoute(
                                        volumeID = target.volumeID,
                                        paragraphID = target.anchor.paragraphID,
                                        characterOffset = target.anchor.characterOffset,
                                        requestedAtEpochMilliseconds = openedAt,
                                        highlightCharacterCount = target.highlightCharacterCount,
                                    ),
                                )
                                navigationScope.launch {
                                    container.userPreferencesRepository.saveReadingProgress(
                                        ReadingProgress(
                                            productID = loaded.product.productID,
                                            editionID = loaded.book.editionID,
                                            paragraphID = target.anchor.paragraphID,
                                            characterOffset = target.anchor.characterOffset,
                                            mode = ReadingMode.CHAPTER,
                                            updatedAtEpochMilliseconds = openedAt,
                                        ),
                                    )
                                }
                            }
                    },
                )
            }
            entry<VolumeReaderRoute> { route ->
                val document = remember(loaded.content, route.volumeID) {
                    VolumeReadingDocument.from(loaded.content, route.volumeID)
                }
                val launchState = remember(route, loaded.content) {
                    loaded.readerLaunchState(route, resumeRoute)
                }
                ReaderScreen(
                    document = document,
                    fontSizeLevel = preferences.fontSizeLevel,
                    strings = strings,
                    initialAnchor = launchState.anchor,
                    highlightCharacterCount = launchState.highlightCharacterCount,
                    onBack = { backStack.removeLastOrNull() },
                    onSaveProgress = { anchor ->
                        container.userPreferencesRepository.saveReadingProgress(
                            ReadingProgress(
                                productID = loaded.product.productID,
                                editionID = loaded.book.editionID,
                                paragraphID = anchor.paragraphID,
                                characterOffset = anchor.characterOffset,
                                mode = ReadingMode.CHAPTER,
                                updatedAtEpochMilliseconds = timestampAfter(
                                    maxOf(
                                        route.requestedAtEpochMilliseconds,
                                        resumeRoute?.requestedAtEpochMilliseconds ?: 0,
                                    ),
                                ),
                            ),
                        )
                    },
                )
            }
        },
    )
}

@Composable
private fun LoadingScreen(title: String) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = Modifier
            .fillMaxSize()
            .windowInsetsPadding(WindowInsets.safeDrawing)
            .padding(horizontal = 24.dp),
    ) {
        Text(
            text = title,
            color = MaterialTheme.colorScheme.primary,
            style = MaterialTheme.typography.headlineMedium.copy(letterSpacing = 0.sp),
        )
        CircularProgressIndicator(
            modifier = Modifier
                .padding(top = 24.dp)
                .size(28.dp),
            strokeWidth = 2.dp,
        )
    }
}

@Composable
private fun ErrorScreen(locale: String, onRetry: () -> Unit) {
    val strings = remember(locale) { AppStrings(locale) }
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = Modifier
            .fillMaxSize()
            .windowInsetsPadding(WindowInsets.safeDrawing)
            .padding(horizontal = 24.dp),
    ) {
        Text(
            text = strings.contentUnavailable,
            textAlign = TextAlign.Center,
            style = MaterialTheme.typography.titleLarge.copy(letterSpacing = 0.sp),
        )
        Button(
            onClick = onRetry,
            modifier = Modifier.padding(top = 20.dp),
            shape = RoundedCornerShape(8.dp),
        ) {
            Text(
                text = strings.retry,
                style = MaterialTheme.typography.labelLarge.copy(letterSpacing = 0.sp),
            )
        }
    }
}

private fun LoadedContent.resumeRoute(progress: ReadingProgress?): VolumeReaderRoute? {
    if (progress == null) return null
    if (progress.productID != product.productID || progress.editionID != book.editionID) return null
    val paragraph = content.paragraph(progress.paragraphID) ?: return null
    val volumeID = paragraph.volumeID ?: return null
    return VolumeReaderRoute(
        volumeID = volumeID,
        paragraphID = paragraph.paragraphID,
        characterOffset = progress.characterOffset,
        requestedAtEpochMilliseconds = progress.updatedAtEpochMilliseconds,
    )
}

private fun LoadedContent.readerLaunchState(
    route: VolumeReaderRoute,
    resumeRoute: VolumeReaderRoute?,
): ReaderLaunchState {
    val requestedAnchor = route.toAnchor()?.takeIf { anchor ->
        content.paragraph(anchor.paragraphID)?.volumeID == route.volumeID
    }
    val persistedRoute = resumeRoute?.takeIf { it.volumeID == route.volumeID }
    val selection = ReadingAnchorSelectionPolicy.select(
        destinationVolumeID = route.volumeID,
        requestedAnchor = requestedAnchor,
        requestedAtEpochMilliseconds = route.requestedAtEpochMilliseconds,
        persistedVolumeID = persistedRoute?.volumeID,
        persistedAnchor = persistedRoute?.toAnchor(),
        persistedAtEpochMilliseconds = persistedRoute?.requestedAtEpochMilliseconds,
    )
    return ReaderLaunchState(
        anchor = selection.anchor,
        highlightCharacterCount = if (selection.origin == ReadingAnchorOrigin.REQUESTED) {
            route.highlightCharacterCount
        } else {
            0
        },
    )
}

private fun VolumeReaderRoute.toAnchor(): ParagraphTextAnchor? = paragraphID?.let { paragraphID ->
    ParagraphTextAnchor(paragraphID = paragraphID, characterOffset = characterOffset)
}

private fun timestampAfter(existing: Long?): Long {
    val now = System.currentTimeMillis()
    if (existing == null || now > existing) return now
    return if (existing == Long.MAX_VALUE) Long.MAX_VALUE else existing + 1
}

private data class ReaderLaunchState(
    val anchor: ParagraphTextAnchor?,
    val highlightCharacterCount: Int,
)

private sealed interface ContentLoadState {
    data object Loading : ContentLoadState
    data object Failed : ContentLoadState
    data class Ready(val value: LoadedContent) : ContentLoadState
}

internal data class LoadedContent(
    val product: ProductManifest,
    val book: BookManifest,
    val content: ScriptureContent,
)

internal class AppStrings(locale: String) {
    private val simplified = locale == "zh-Hans"

    val startReading = if (simplified) "开始阅读" else "開始閱讀"
    val continueReading = if (simplified) "继续阅读" else "繼續閱讀"
    val chooseVolume = if (simplified) "选择卷目" else "選擇卷目"
    val volumes = "卷目"
    val search = "搜索"
    val clearSearch = if (simplified) "清除搜索" else "清除搜索"
    val commonKeywords = if (simplified) "常用关键词" else "常用關鍵詞"
    val searchUnavailable = if (simplified) "搜索暂时无法使用" else "搜索暫時無法使用"
    val outlineResult = "科判"
    val scriptureResult = if (simplified) "经文" else "經文"
    val searchResultLimit = if (simplified) "仅显示前 50 项，请输入更完整的关键词" else "僅顯示前 50 項，請輸入更完整的關鍵詞"
    val searchKeywords = if (simplified) {
        listOf(
            "如来藏", "真心", "妙明", "妙真如性", "因缘", "和合", "虚空",
            "客尘", "生灭", "菩提", "涅槃", "妄想", "圆通", "反闻闻自性", "歇即菩提",
        )
    } else {
        listOf(
            "如來藏", "真心", "妙明", "妙真如性", "因緣", "和合", "虛空",
            "客塵", "生滅", "菩提", "涅槃", "妄想", "圓通", "反聞聞自性", "歇即菩提",
        )
    }
    val lastRead = if (simplified) "上次读到" else "上次讀到"
    val back = "返回"
    val contentUnavailable = if (simplified) "经文暂时无法打开" else "經文暫時無法打開"
    val retry = if (simplified) "重试" else "重試"

    fun volumeCount(count: Int): String = "全文 $count 卷"

    fun noSearchResults(query: String): String = if (simplified) {
        "没有找到“$query”"
    } else {
        "沒有找到「$query」"
    }
}
