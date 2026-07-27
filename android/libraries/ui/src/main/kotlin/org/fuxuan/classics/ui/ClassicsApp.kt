package org.fuxuan.classics.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
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
import org.fuxuan.classics.core.behavior.LegacyLocationResolution
import org.fuxuan.classics.core.behavior.LegacyLocationUsage
import org.fuxuan.classics.core.behavior.ParagraphTextAnchor
import org.fuxuan.classics.core.behavior.OutlineDisclosurePolicy
import org.fuxuan.classics.core.behavior.ReadingAnchorOrigin
import org.fuxuan.classics.core.behavior.ReadingAnchorSelectionPolicy
import org.fuxuan.classics.core.behavior.ReadingMode
import org.fuxuan.classics.core.behavior.ScriptureSearchNavigationPolicy
import org.fuxuan.classics.core.behavior.ScriptureDeepLink
import org.fuxuan.classics.core.behavior.VolumeReadingDocument
import org.fuxuan.classics.core.content.BookManifest
import org.fuxuan.classics.core.content.ProductManifest
import org.fuxuan.classics.core.content.ScriptureContent
import org.fuxuan.classics.core.content.SourceManifest
import org.fuxuan.classics.core.persistence.Favorite
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
data object FavoritesRoute : NavKey

@Serializable
data object SettingsHomeRoute : NavKey

@Serializable
data object SourceInfoRoute : NavKey

@Serializable
data object PrivacyInfoRoute : NavKey

@Serializable
data class ShareRoute(val volumeID: String) : NavKey {
    init {
        require(volumeID.isNotBlank()) { "share route volumeID must not be blank" }
    }
}

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
    pendingDeepLink: ScriptureDeepLink? = null,
    onDeepLinkConsumed: (ScriptureDeepLink) -> Unit = {},
    onDarkThemeChanged: (Boolean) -> Unit = {},
    dailyVerseWidgetInstalled: Boolean = false,
    dailyVerseWidgetPinSupported: Boolean = false,
    onRequestDailyVerseWidgetPin: (() -> Boolean)? = null,
    privacyPolicyUris: Map<String, String> = emptyMap(),
    appVersion: String? = null,
    onOpenExternalUri: ((String) -> Unit)? = null,
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
                ContentNavigation(
                    container = container,
                    preferences = currentPreferences,
                    pendingDeepLink = pendingDeepLink,
                    onDeepLinkConsumed = onDeepLinkConsumed,
                    dailyVerseWidgetInstalled = dailyVerseWidgetInstalled,
                    dailyVerseWidgetPinSupported = dailyVerseWidgetPinSupported,
                    onRequestDailyVerseWidgetPin = onRequestDailyVerseWidgetPin,
                    privacyPolicyUris = privacyPolicyUris,
                    appVersion = appVersion,
                    onOpenExternalUri = onOpenExternalUri,
                )
            }
        }
    }
}

@Composable
private fun ContentNavigation(
    container: AppContainer,
    preferences: ProductPreferences,
    pendingDeepLink: ScriptureDeepLink?,
    onDeepLinkConsumed: (ScriptureDeepLink) -> Unit,
    dailyVerseWidgetInstalled: Boolean,
    dailyVerseWidgetPinSupported: Boolean,
    onRequestDailyVerseWidgetPin: (() -> Boolean)?,
    privacyPolicyUris: Map<String, String>,
    appVersion: String?,
    onOpenExternalUri: ((String) -> Unit)?,
) {
    var retryKey by remember { mutableIntStateOf(0) }
    val loadState by produceState<ContentLoadState>(
        initialValue = ContentLoadState.Loading,
        container.bookRepository,
        preferences.locale,
        retryKey,
    ) {
        value = runCatching {
            LoadedContent(
                product = container.bookRepository.product(),
                book = container.bookRepository.book(),
                content = container.bookRepository.content(preferences.locale),
                sourceManifest = container.bookRepository.sourceManifest(),
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
            pendingDeepLink = pendingDeepLink,
            onDeepLinkConsumed = onDeepLinkConsumed,
            dailyVerseWidgetInstalled = dailyVerseWidgetInstalled,
            dailyVerseWidgetPinSupported = dailyVerseWidgetPinSupported,
            onRequestDailyVerseWidgetPin = onRequestDailyVerseWidgetPin,
            privacyPolicyUris = privacyPolicyUris,
            appVersion = appVersion,
            onOpenExternalUri = onOpenExternalUri,
        )
    }
}

@Composable
private fun LoadedContentNavigation(
    container: AppContainer,
    loaded: LoadedContent,
    preferences: ProductPreferences,
    pendingDeepLink: ScriptureDeepLink?,
    onDeepLinkConsumed: (ScriptureDeepLink) -> Unit,
    dailyVerseWidgetInstalled: Boolean,
    dailyVerseWidgetPinSupported: Boolean,
    onRequestDailyVerseWidgetPin: (() -> Boolean)?,
    privacyPolicyUris: Map<String, String>,
    appVersion: String?,
    onOpenExternalUri: ((String) -> Unit)?,
) {
    val readBackStack = rememberNavBackStack(HomeRoute)
    val favoritesBackStack = rememberNavBackStack(FavoritesRoute)
    val settingsBackStack = rememberNavBackStack(SettingsHomeRoute)
    val navigationScope = rememberCoroutineScope()
    var selectedDestination by rememberSaveable {
        mutableStateOf(TopLevelDestination.READING)
    }
    val strings = remember(preferences.locale) { AppStrings(preferences.locale) }
    val resumeRoute = remember(loaded, preferences.readingProgress) {
        loaded.resumeRoute(preferences.readingProgress)
    }
    val expandedSectionIDs = remember(loaded.content, preferences.expandedSectionIDs) {
        OutlineDisclosurePolicy.sanitizeExpandedSectionIDs(
            content = loaded.content,
            sectionIDs = preferences.expandedSectionIDs,
        )
    }
    LaunchedEffect(loaded.content, preferences.expandedSectionIDs, expandedSectionIDs) {
        if (expandedSectionIDs != preferences.expandedSectionIDs) {
            container.userPreferencesRepository.setExpandedSectionIDs(expandedSectionIDs)
        }
    }
    val favoritesFlow = remember(container.favoriteRepository, loaded.book.editionID) {
        container.favoriteRepository.favorites(loaded.book.editionID)
    }
    val favorites by favoritesFlow.collectAsState(initial = emptyList())
    val favoriteParagraphIDs = remember(favorites) {
        favorites.mapNotNullTo(mutableSetOf(), Favorite::paragraphID)
    }

    LaunchedEffect(pendingDeepLink, loaded) {
        val deepLink = pendingDeepLink ?: return@LaunchedEffect
        try {
            if (deepLink.productID != loaded.product.productID) return@LaunchedEffect
            val directParagraph = deepLink.paragraphID?.let(loaded.content::paragraph)
            val paragraph = directParagraph
                ?: deepLink.legacyPath?.let { legacyPath ->
                    val resolution = container.bookRepository.resolveLegacyLocation(
                        legacyPath = legacyPath,
                        usage = LegacyLocationUsage.RESUME,
                    )
                    (resolution as? LegacyLocationResolution.Mapped)
                        ?.paragraphID
                        ?.let(loaded.content::paragraph)
                }
                ?: return@LaunchedEffect
            val volumeID = paragraph.volumeID ?: return@LaunchedEffect
            val characterOffset = if (directParagraph != null) {
                deepLink.characterOffset.coerceAtMost(
                    paragraph.text.codePointCount(0, paragraph.text.length),
                )
            } else {
                0
            }
            val openedAt = timestampAfter(
                preferences.readingProgress?.updatedAtEpochMilliseconds,
            )
            selectedDestination = TopLevelDestination.READING
            readBackStack.popToRoot()
            readBackStack.add(
                VolumeReaderRoute(
                    volumeID = volumeID,
                    paragraphID = paragraph.paragraphID,
                    characterOffset = characterOffset,
                    requestedAtEpochMilliseconds = openedAt,
                ),
            )
            container.userPreferencesRepository.saveReadingProgress(
                ReadingProgress(
                    productID = loaded.product.productID,
                    editionID = loaded.book.editionID,
                    paragraphID = paragraph.paragraphID,
                    characterOffset = characterOffset,
                    mode = ReadingMode.CHAPTER,
                    updatedAtEpochMilliseconds = openedAt,
                ),
            )
        } finally {
            onDeepLinkConsumed(deepLink)
        }
    }

    fun toggleFavorite(anchor: ParagraphTextAnchor) {
        navigationScope.launch {
            val matchingFavorites = favorites.filter { it.paragraphID == anchor.paragraphID }
            if (matchingFavorites.isNotEmpty()) {
                matchingFavorites.forEach { favorite ->
                    container.favoriteRepository.remove(
                        loaded.book.editionID,
                        favorite.favoriteID,
                    )
                }
                return@launch
            }
            val paragraph = loaded.content.paragraph(anchor.paragraphID) ?: return@launch
            container.favoriteRepository.add(
                Favorite.paragraph(
                    productID = loaded.product.productID,
                    editionID = loaded.book.editionID,
                    sectionID = paragraph.sectionID,
                    paragraphID = paragraph.paragraphID,
                    legacyPath = paragraph.legacyIDs.firstOrNull { it.startsWith("/") },
                    createdAtEpochMilliseconds = timestampAfter(
                        favorites.maxOfOrNull(Favorite::createdAtEpochMilliseconds),
                    ),
                ),
            )
        }
    }

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        bottomBar = {
            BottomRegion(
                selected = selectedDestination,
                strings = strings,
                onSelect = { destination ->
                    if (destination == selectedDestination) {
                        when (destination) {
                            TopLevelDestination.READING -> readBackStack.popToRoot()
                            TopLevelDestination.FAVORITES -> favoritesBackStack.popToRoot()
                            TopLevelDestination.SETTINGS -> settingsBackStack.popToRoot()
                        }
                    }
                    selectedDestination = destination
                },
            )
        },
    ) { shellPadding ->
        val contentModifier = Modifier
            .fillMaxSize()
            .padding(shellPadding)
            .consumeWindowInsets(shellPadding)

        when (selectedDestination) {
            TopLevelDestination.READING -> NavDisplay(
                backStack = readBackStack,
                modifier = contentModifier,
                onBack = { readBackStack.removeLastOrNull() },
                entryProvider = entryProvider {
                    entry<HomeRoute> {
                        HomeScreen(
                            loaded = loaded,
                            strings = strings,
                            resumeRoute = resumeRoute,
                            onRead = {
                                readBackStack.add(
                                    resumeRoute ?: VolumeReaderRoute(
                                        loaded.content.volumesInReadingOrder().first().volumeID,
                                    ),
                                )
                            },
                            onBrowseVolumes = { readBackStack.add(VolumeListRoute) },
                            onSearch = { readBackStack.add(SearchRoute) },
                        )
                    }
                    entry<VolumeListRoute> {
                        ContentBrowserScreen(
                            content = loaded.content,
                            strings = strings,
                            resumeRoute = resumeRoute,
                            expandedSectionIDs = expandedSectionIDs,
                            onExpandedSectionIDsChanged = { sectionIDs ->
                                navigationScope.launch {
                                    container.userPreferencesRepository.setExpandedSectionIDs(
                                        OutlineDisclosurePolicy.sanitizeExpandedSectionIDs(
                                            content = loaded.content,
                                            sectionIDs = sectionIDs,
                                        ),
                                    )
                                }
                            },
                            onBack = { readBackStack.removeLastOrNull() },
                            onOpenVolume = { volumeID ->
                                readBackStack.add(
                                    resumeRoute?.takeIf { it.volumeID == volumeID }
                                        ?: VolumeReaderRoute(volumeID),
                                )
                            },
                            onOpenParagraph = { paragraph ->
                                val volumeID = paragraph.volumeID
                                if (volumeID != null) {
                                    val openedAt = timestampAfter(
                                        resumeRoute?.requestedAtEpochMilliseconds,
                                    )
                                    readBackStack.add(
                                        VolumeReaderRoute(
                                            volumeID = volumeID,
                                            paragraphID = paragraph.paragraphID,
                                            requestedAtEpochMilliseconds = openedAt,
                                        ),
                                    )
                                    navigationScope.launch {
                                        container.userPreferencesRepository.saveReadingProgress(
                                            ReadingProgress(
                                                productID = loaded.product.productID,
                                                editionID = loaded.book.editionID,
                                                paragraphID = paragraph.paragraphID,
                                                characterOffset = 0,
                                                mode = ReadingMode.CHAPTER,
                                                updatedAtEpochMilliseconds = openedAt,
                                            ),
                                        )
                                    }
                                }
                            },
                        )
                    }
                    entry<SearchRoute> {
                        SearchScreen(
                            repository = container.bookRepository,
                            content = loaded.content,
                            strings = strings,
                            onBack = { readBackStack.removeLastOrNull() },
                            onOpenResult = { result ->
                                ScriptureSearchNavigationPolicy.target(loaded.content, result)
                                    ?.let { target ->
                                        val openedAt = timestampAfter(
                                            resumeRoute?.requestedAtEpochMilliseconds,
                                        )
                                        readBackStack.add(
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
                        ReaderDestination(
                            container = container,
                            loaded = loaded,
                            preferences = preferences,
                            strings = strings,
                            route = route,
                            resumeRoute = resumeRoute,
                            favoriteParagraphIDs = favoriteParagraphIDs,
                            onBack = { readBackStack.removeLastOrNull() },
                            onShare = { readBackStack.add(ShareRoute(route.volumeID)) },
                            onToggleFavorite = ::toggleFavorite,
                        )
                    }
                    entry<ShareRoute> { route ->
                        ShareDestination(
                            loaded = loaded,
                            preferences = preferences,
                            strings = strings,
                            route = route,
                            onBack = { readBackStack.removeLastOrNull() },
                        )
                    }
                },
            )
            TopLevelDestination.FAVORITES -> NavDisplay(
                backStack = favoritesBackStack,
                modifier = contentModifier,
                onBack = { favoritesBackStack.removeLastOrNull() },
                entryProvider = entryProvider {
                    entry<FavoritesRoute> {
                        FavoritesScreen(
                            content = loaded.content,
                            favorites = favorites,
                            strings = strings,
                            onOpenFavorite = { target ->
                                val openedAt = timestampAfter(
                                    resumeRoute?.requestedAtEpochMilliseconds,
                                )
                                favoritesBackStack.add(
                                    VolumeReaderRoute(
                                        volumeID = target.volumeID,
                                        paragraphID = target.anchor.paragraphID,
                                        characterOffset = target.anchor.characterOffset,
                                        requestedAtEpochMilliseconds = openedAt,
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
                            },
                            onRemoveFavorite = { favorite ->
                                navigationScope.launch {
                                    container.favoriteRepository.remove(
                                        loaded.book.editionID,
                                        favorite.favoriteID,
                                    )
                                }
                            },
                            detailContent = { target ->
                                val detailRoute = remember(target) {
                                    VolumeReaderRoute(
                                        volumeID = target.volumeID,
                                        paragraphID = target.anchor.paragraphID,
                                        characterOffset = target.anchor.characterOffset,
                                        requestedAtEpochMilliseconds = timestampAfter(
                                            resumeRoute?.requestedAtEpochMilliseconds,
                                        ),
                                    )
                                }
                                ReaderDestination(
                                    container = container,
                                    loaded = loaded,
                                    preferences = preferences,
                                    strings = strings,
                                    route = detailRoute,
                                    resumeRoute = resumeRoute,
                                    favoriteParagraphIDs = favoriteParagraphIDs,
                                    showBackButton = false,
                                    onBack = {},
                                    onShare = {
                                        favoritesBackStack.add(ShareRoute(detailRoute.volumeID))
                                    },
                                    onToggleFavorite = ::toggleFavorite,
                                )
                            },
                        )
                    }
                    entry<VolumeReaderRoute> { route ->
                        ReaderDestination(
                            container = container,
                            loaded = loaded,
                            preferences = preferences,
                            strings = strings,
                            route = route,
                            resumeRoute = resumeRoute,
                            favoriteParagraphIDs = favoriteParagraphIDs,
                            onBack = { favoritesBackStack.removeLastOrNull() },
                            onShare = { favoritesBackStack.add(ShareRoute(route.volumeID)) },
                            onToggleFavorite = ::toggleFavorite,
                        )
                    }
                    entry<ShareRoute> { route ->
                        ShareDestination(
                            loaded = loaded,
                            preferences = preferences,
                            strings = strings,
                            route = route,
                            onBack = { favoritesBackStack.removeLastOrNull() },
                        )
                    }
                },
            )
            TopLevelDestination.SETTINGS -> NavDisplay(
                backStack = settingsBackStack,
                modifier = contentModifier,
                onBack = { settingsBackStack.removeLastOrNull() },
                entryProvider = entryProvider {
                    entry<SettingsHomeRoute> {
                        SettingsScreen(
                            preferences = preferences,
                            supportedLocales = loaded.product.supportedLocales,
                            productTitle = loaded.product.title(preferences.locale),
                            strings = strings,
                            dailyVerseWidgetInstalled = dailyVerseWidgetInstalled,
                            dailyVerseWidgetPinSupported = dailyVerseWidgetPinSupported,
                            onRequestDailyVerseWidgetPin = onRequestDailyVerseWidgetPin,
                            sourceReviewStatus = loaded.sourceManifest.reviewStatus,
                            sourceReleaseEligibility = loaded.sourceManifest.releaseEligibility,
                            appVersion = appVersion,
                            onOpenSourceInformation = {
                                settingsBackStack.add(SourceInfoRoute)
                            },
                            onOpenPrivacy = { settingsBackStack.add(PrivacyInfoRoute) },
                            onSelectTheme = { theme ->
                                navigationScope.launch {
                                    container.userPreferencesRepository.setTheme(theme)
                                }
                            },
                            onSelectLocale = { locale ->
                                navigationScope.launch {
                                    container.userPreferencesRepository.setLocale(locale)
                                }
                            },
                            onSelectFontSize = { level ->
                                navigationScope.launch {
                                    container.userPreferencesRepository.setFontSizeLevel(level)
                                }
                            },
                            onSetReminder = { reminder ->
                                navigationScope.launch {
                                    container.userPreferencesRepository.setReminder(reminder)
                                }
                            },
                        )
                    }
                    entry<SourceInfoRoute> {
                        SourceInfoScreen(
                            manifest = loaded.sourceManifest,
                            productTitle = loaded.product.title(preferences.locale),
                            locale = preferences.locale,
                            strings = strings,
                            onBack = { settingsBackStack.removeLastOrNull() },
                            onOpenExternalUri = onOpenExternalUri,
                        )
                    }
                    entry<PrivacyInfoRoute> {
                        PrivacyInfoScreen(
                            strings = strings,
                            privacyPolicyUri = privacyPolicyUris[preferences.locale]
                                ?: privacyPolicyUris[loaded.product.defaultLocale],
                            onBack = { settingsBackStack.removeLastOrNull() },
                            onOpenExternalUri = onOpenExternalUri,
                        )
                    }
                },
            )
        }
    }
}

@Composable
private fun ReaderDestination(
    container: AppContainer,
    loaded: LoadedContent,
    preferences: ProductPreferences,
    strings: AppStrings,
    route: VolumeReaderRoute,
    resumeRoute: VolumeReaderRoute?,
    favoriteParagraphIDs: Set<String>,
    showBackButton: Boolean = true,
    onBack: () -> Unit,
    onShare: () -> Unit,
    onToggleFavorite: (ParagraphTextAnchor) -> Unit,
) {
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
        favoriteParagraphIDs = favoriteParagraphIDs,
        showBackButton = showBackButton,
        onBack = onBack,
        onShare = onShare,
        onToggleFavorite = onToggleFavorite,
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

@Composable
private fun ShareDestination(
    loaded: LoadedContent,
    preferences: ProductPreferences,
    strings: AppStrings,
    route: ShareRoute,
    onBack: () -> Unit,
) {
    val document = remember(loaded.content, route.volumeID) {
        VolumeReadingDocument.from(loaded.content, route.volumeID)
    }
    val shareDocument = remember(
        document,
        loaded.product,
        preferences.locale,
        preferences.fontSizeLevel,
    ) {
        ShareDocument(
            locale = preferences.locale,
            productTitle = loaded.product.title(preferences.locale),
            volumeTitle = document.volume.title,
            text = document.text,
            fontSizeLevel = preferences.fontSizeLevel,
        )
    }
    ShareScreen(
        document = shareDocument,
        strings = strings,
        onBack = onBack,
    )
}

private fun MutableList<NavKey>.popToRoot() {
    while (size > 1) removeLastOrNull()
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
    val sourceManifest: SourceManifest,
)
