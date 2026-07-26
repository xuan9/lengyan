package org.fuxuan.classics.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import org.fuxuan.classics.core.behavior.ScriptureSearchIndex
import org.fuxuan.classics.core.behavior.ScriptureSearchNavigationPolicy
import org.fuxuan.classics.core.behavior.ScriptureSearchResult
import org.fuxuan.classics.core.behavior.SearchDocumentKind
import org.fuxuan.classics.core.content.BookRepository
import org.fuxuan.classics.core.content.ScriptureContent

private const val SEARCH_RESULT_LIMIT = 50

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
internal fun SearchScreen(
    repository: BookRepository,
    content: ScriptureContent,
    strings: AppStrings,
    onBack: () -> Unit,
    onOpenResult: (ScriptureSearchResult) -> Unit,
) {
    var retryKey by remember { mutableIntStateOf(0) }
    val indexState by produceState<SearchIndexState>(
        initialValue = SearchIndexState.Loading,
        repository,
        retryKey,
    ) {
        value = SearchIndexState.Loading
        value = runCatching { repository.searchIndex() }.fold(
            onSuccess = SearchIndexState::Ready,
            onFailure = { SearchIndexState.Failed },
        )
    }
    var query by rememberSaveable { mutableStateOf("") }
    var searchState by remember { mutableStateOf<SearchResultsState>(SearchResultsState.Idle) }
    val focusRequester = remember { FocusRequester() }
    val keyboardController = LocalSoftwareKeyboardController.current

    LaunchedEffect(Unit) { focusRequester.requestFocus() }
    LaunchedEffect(query, indexState, content.locale) {
        val trimmedQuery = query.trim()
        val index = (indexState as? SearchIndexState.Ready)?.index
        if (trimmedQuery.isEmpty() || index == null) {
            searchState = SearchResultsState.Idle
            return@LaunchedEffect
        }
        searchState = SearchResultsState.Searching
        delay(250)
        val matches = withContext(Dispatchers.Default) {
            index.search(
                query = trimmedQuery,
                displayLocale = content.locale,
                limit = SEARCH_RESULT_LIMIT + 1,
            )
        }
        searchState = SearchResultsState.Complete(
            results = matches.take(SEARCH_RESULT_LIMIT),
            hasMore = matches.size > SEARCH_RESULT_LIMIT,
        )
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = {
                    OutlinedTextField(
                        value = query,
                        onValueChange = { query = it },
                        modifier = Modifier
                            .widthIn(max = 720.dp)
                            .fillMaxWidth()
                            .padding(end = 8.dp)
                            .focusRequester(focusRequester),
                        placeholder = { Text(strings.search) },
                        leadingIcon = {
                            Icon(
                                imageVector = Icons.Default.Search,
                                contentDescription = null,
                            )
                        },
                        trailingIcon = if (query.isEmpty()) {
                            null
                        } else {
                            {
                                IconButton(onClick = { query = "" }) {
                                    Icon(
                                        imageVector = Icons.Default.Close,
                                        contentDescription = strings.clearSearch,
                                    )
                                }
                            }
                        },
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                        keyboardActions = KeyboardActions(
                            onSearch = { keyboardController?.hide() },
                        ),
                        singleLine = true,
                        shape = RoundedCornerShape(8.dp),
                        textStyle = MaterialTheme.typography.bodyLarge.copy(letterSpacing = 0.sp),
                    )
                },
                navigationIcon = { BackButton(strings.back, onBack) },
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
            when (val currentIndexState = indexState) {
                SearchIndexState.Loading -> CircularProgressIndicator(
                    modifier = Modifier.align(Alignment.Center),
                    strokeWidth = 2.dp,
                )
                SearchIndexState.Failed -> Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier
                        .align(Alignment.Center)
                        .padding(horizontal = 24.dp),
                ) {
                    Text(
                        text = strings.searchUnavailable,
                        style = MaterialTheme.typography.bodyLarge.copy(letterSpacing = 0.sp),
                    )
                    Button(
                        onClick = { retryKey += 1 },
                        modifier = Modifier.padding(top = 16.dp),
                        shape = RoundedCornerShape(8.dp),
                    ) {
                        Text(strings.retry)
                    }
                }
                is SearchIndexState.Ready -> SearchBody(
                    modifier = Modifier.align(Alignment.TopCenter),
                    query = query,
                    state = searchState,
                    content = content,
                    strings = strings,
                    onChooseKeyword = { query = it },
                    onOpenResult = {
                        keyboardController?.hide()
                        onOpenResult(it)
                    },
                )
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun SearchBody(
    modifier: Modifier = Modifier,
    query: String,
    state: SearchResultsState,
    content: ScriptureContent,
    strings: AppStrings,
    onChooseKeyword: (String) -> Unit,
    onOpenResult: (ScriptureSearchResult) -> Unit,
) {
    val complete = state as? SearchResultsState.Complete
    LazyColumn(
        modifier = modifier
            .widthIn(max = 760.dp)
            .fillMaxWidth()
            .fillMaxHeight(),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        if (query.trim().isEmpty()) {
            item {
                Text(
                    text = strings.commonKeywords,
                    modifier = Modifier.padding(bottom = 2.dp),
                    color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.62f),
                    style = MaterialTheme.typography.labelLarge.copy(letterSpacing = 0.sp),
                )
            }
            item {
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    strings.searchKeywords.forEach { keyword ->
                        OutlinedButton(
                            onClick = { onChooseKeyword(keyword) },
                            shape = RoundedCornerShape(8.dp),
                            contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp),
                        ) {
                            Text(
                                text = keyword,
                                style = MaterialTheme.typography.bodyMedium.copy(letterSpacing = 0.sp),
                            )
                        }
                    }
                }
            }
        } else if (state == SearchResultsState.Searching) {
            item {
                Row(
                    horizontalArrangement = Arrangement.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 28.dp),
                ) {
                    CircularProgressIndicator(strokeWidth = 2.dp)
                }
            }
        } else if (complete != null && complete.results.isEmpty()) {
            item {
                Text(
                    text = strings.noSearchResults(query.trim()),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 36.dp),
                    color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.68f),
                    style = MaterialTheme.typography.bodyLarge.copy(letterSpacing = 0.sp),
                )
            }
        } else if (complete != null) {
            if (complete.hasMore) {
                item {
                    Text(
                        text = strings.searchResultLimit,
                        color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.58f),
                        style = MaterialTheme.typography.labelMedium.copy(letterSpacing = 0.sp),
                    )
                }
            }
            items(
                items = complete.results,
                key = ScriptureSearchResult::documentID,
            ) { result ->
                SearchResultRow(
                    result = result,
                    content = content,
                    strings = strings,
                    onClick = { onOpenResult(result) },
                )
            }
        }
    }
}

@Composable
private fun SearchResultRow(
    result: ScriptureSearchResult,
    content: ScriptureContent,
    strings: AppStrings,
    onClick: () -> Unit,
) {
    val target = remember(content, result) {
        ScriptureSearchNavigationPolicy.target(content, result)
    }
    val volumeTitle = target?.volumeID?.let(content::volume)?.title
    val sectionTitle = content.section(result.sectionID)?.title
    val source = listOfNotNull(volumeTitle, sectionTitle)
        .distinct()
        .joinToString(" · ")
    val resultText = if (result.kind == SearchDocumentKind.SECTION) {
        result.displayText
    } else {
        result.snippet
    }
    val markerColor = if (result.kind == SearchDocumentKind.SECTION) {
        MaterialTheme.colorScheme.secondary
    } else {
        MaterialTheme.colorScheme.primary
    }

    Surface(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 76.dp),
        shape = RoundedCornerShape(8.dp),
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 1.dp,
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Box(
                modifier = Modifier
                    .width(3.dp)
                    .height(48.dp)
                    .background(markerColor.copy(alpha = 0.72f)),
            )
            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(horizontal = 14.dp, vertical = 12.dp),
            ) {
                Text(
                    text = if (result.kind == SearchDocumentKind.SECTION) {
                        strings.outlineResult
                    } else {
                        strings.scriptureResult
                    },
                    color = markerColor,
                    style = MaterialTheme.typography.labelSmall.copy(letterSpacing = 0.sp),
                )
                Text(
                    text = highlightedText(
                        text = resultText,
                        result = result,
                        highlightColor = markerColor.copy(alpha = 0.22f),
                    ),
                    modifier = Modifier.padding(top = 4.dp),
                    maxLines = 3,
                    overflow = TextOverflow.Ellipsis,
                    style = MaterialTheme.typography.bodyLarge.copy(
                        lineHeight = 27.sp,
                        letterSpacing = 0.sp,
                    ),
                )
                if (source.isNotEmpty()) {
                    Text(
                        text = source,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 5.dp),
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.56f),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        style = MaterialTheme.typography.labelSmall.copy(letterSpacing = 0.sp),
                    )
                }
            }
        }
    }
}

private fun highlightedText(
    text: String,
    result: ScriptureSearchResult,
    highlightColor: Color,
) = buildAnnotatedString {
    append(text)
    val fullMatchStart = result.displayText.offsetByCodePoints(0, result.matchCharacterOffset)
    val fullMatchEnd = result.displayText.offsetByCodePoints(
        fullMatchStart,
        result.matchCharacterCount,
    )
    val matchedText = result.displayText.substring(fullMatchStart, fullMatchEnd)
    val start = text.indexOf(matchedText).takeIf { it >= 0 } ?: return@buildAnnotatedString
    val end = start + matchedText.length
    addStyle(
        style = SpanStyle(background = highlightColor),
        start = start,
        end = end,
    )
}

private sealed interface SearchIndexState {
    data object Loading : SearchIndexState
    data object Failed : SearchIndexState
    data class Ready(val index: ScriptureSearchIndex) : SearchIndexState
}

private sealed interface SearchResultsState {
    data object Idle : SearchResultsState
    data object Searching : SearchResultsState
    data class Complete(
        val results: List<ScriptureSearchResult>,
        val hasMore: Boolean,
    ) : SearchResultsState
}
