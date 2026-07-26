package org.fuxuan.classics.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.VerticalDivider
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.fuxuan.classics.core.behavior.FavoriteNavigationPolicy
import org.fuxuan.classics.core.behavior.FavoriteNavigationTarget
import org.fuxuan.classics.core.behavior.ParagraphTextAnchor
import org.fuxuan.classics.core.content.ScriptureContent
import org.fuxuan.classics.core.persistence.Favorite

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun FavoritesScreen(
    content: ScriptureContent,
    favorites: List<Favorite>,
    strings: AppStrings,
    onOpenFavorite: (FavoriteNavigationTarget) -> Unit,
    onRemoveFavorite: (Favorite) -> Unit,
    detailContent: (@Composable (FavoriteNavigationTarget) -> Unit)? = null,
) {
    val rows = remember(content, favorites) {
        favorites.map { favorite -> favorite.toRow(content) }
    }
    var selectedFavoriteID by rememberSaveable { mutableStateOf<String?>(null) }
    var selectedParagraphID by rememberSaveable { mutableStateOf<String?>(null) }
    val selectedTarget = remember(content, selectedParagraphID) {
        selectedParagraphID
            ?.let(content::paragraph)
            ?.let { paragraph ->
                paragraph.volumeID?.let { volumeID ->
                    FavoriteNavigationTarget(
                        volumeID = volumeID,
                        anchor = ParagraphTextAnchor(paragraph.paragraphID, 0),
                    )
                }
            }
    }

    BoxWithConstraints(modifier = Modifier.fillMaxSize()) {
        val usesSplitDetail = detailContent != null && maxWidth >= SPLIT_DETAIL_MIN_WIDTH
        LaunchedEffect(usesSplitDetail, rows, selectedTarget) {
            if (usesSplitDetail && selectedTarget == null) {
                rows.firstOrNull { it.target != null }?.let { row ->
                    selectedFavoriteID = row.favorite.favoriteID
                    selectedParagraphID = row.target?.anchor?.paragraphID
                }
            }
        }

        if (usesSplitDetail) {
            Row(
                modifier = Modifier
                    .fillMaxSize()
                    .testTag("favorites.split"),
            ) {
                FavoritesListPane(
                    rows = rows,
                    strings = strings,
                    selectedFavoriteID = selectedFavoriteID,
                    exposesSelection = true,
                    onOpen = { row ->
                        row.target?.let { target ->
                            selectedFavoriteID = row.favorite.favoriteID
                            selectedParagraphID = target.anchor.paragraphID
                        }
                    },
                    onRemoveFavorite = onRemoveFavorite,
                    modifier = Modifier
                        .width(SPLIT_LIST_WIDTH)
                        .fillMaxHeight()
                        .testTag("favorites.list-pane"),
                )
                VerticalDivider(modifier = Modifier.fillMaxHeight())
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight()
                        .testTag("favorites.detail"),
                ) {
                    if (selectedTarget == null) {
                        FavoritesEmptyState(
                            strings = strings,
                            modifier = Modifier.align(Alignment.Center),
                        )
                    } else {
                        detailContent(selectedTarget)
                    }
                }
            }
        } else {
            FavoritesListPane(
                rows = rows,
                strings = strings,
                selectedFavoriteID = null,
                exposesSelection = false,
                onOpen = { row -> row.target?.let(onOpenFavorite) },
                onRemoveFavorite = onRemoveFavorite,
                modifier = Modifier.fillMaxSize(),
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FavoritesListPane(
    rows: List<FavoriteRowModel>,
    strings: AppStrings,
    selectedFavoriteID: String?,
    exposesSelection: Boolean,
    onOpen: (FavoriteRowModel) -> Unit,
    onRemoveFavorite: (Favorite) -> Unit,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier,
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = strings.favorites,
                        style = MaterialTheme.typography.titleLarge.copy(letterSpacing = 0.sp),
                    )
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
            if (rows.isEmpty()) {
                FavoritesEmptyState(
                    strings = strings,
                    modifier = Modifier.align(Alignment.Center),
                )
            } else {
                LazyColumn(
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .widthIn(max = 760.dp)
                        .fillMaxWidth()
                        .fillMaxHeight()
                        .testTag("favorites.list"),
                    contentPadding = PaddingValues(horizontal = 20.dp, vertical = 12.dp),
                ) {
                    items(
                        items = rows,
                        key = { row -> row.favorite.favoriteID },
                    ) { row ->
                        FavoriteRow(
                            row = row,
                            strings = strings,
                            selected = selectedFavoriteID == row.favorite.favoriteID,
                            exposesSelection = exposesSelection,
                            onOpen = { onOpen(row) },
                            onRemove = { onRemoveFavorite(row.favorite) },
                        )
                        HorizontalDivider()
                    }
                }
            }
        }
    }
}

@Composable
private fun FavoritesEmptyState(
    strings: AppStrings,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .testTag("favorites.empty")
            .padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            imageVector = Icons.Default.FavoriteBorder,
            contentDescription = null,
            modifier = Modifier.size(32.dp),
            tint = MaterialTheme.colorScheme.primary,
        )
        Text(
            text = strings.noFavorites,
            modifier = Modifier.padding(top = 14.dp),
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.72f),
            style = MaterialTheme.typography.bodyLarge.copy(letterSpacing = 0.sp),
        )
    }
}

@Composable
private fun FavoriteRow(
    row: FavoriteRowModel,
    strings: AppStrings,
    selected: Boolean,
    exposesSelection: Boolean,
    onOpen: () -> Unit,
    onRemove: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 88.dp)
            .background(
                if (exposesSelection && selected) {
                    MaterialTheme.colorScheme.primary.copy(alpha = 0.10f)
                } else {
                    MaterialTheme.colorScheme.background
                },
            )
            .testTag("favorite.row.${row.favorite.favoriteID}")
            .semantics {
                if (exposesSelection) this.selected = selected
            }
            .then(
                if (row.target == null) {
                    Modifier
                } else {
                    Modifier.clickable(role = Role.Button, onClick = onOpen)
                },
            )
            .padding(start = 4.dp, top = 14.dp, end = 0.dp, bottom = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = row.text ?: strings.favoriteUnavailable,
                color = if (row.target == null) {
                    MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f)
                } else {
                    MaterialTheme.colorScheme.onSurface
                },
                maxLines = 3,
                overflow = TextOverflow.Ellipsis,
                style = MaterialTheme.typography.bodyLarge.copy(
                    lineHeight = 27.sp,
                    letterSpacing = 0.sp,
                ),
            )
            row.location?.let { location ->
                Text(
                    text = location,
                    modifier = Modifier.padding(top = 6.dp),
                    color = MaterialTheme.colorScheme.primary,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    style = MaterialTheme.typography.labelMedium.copy(letterSpacing = 0.sp),
                )
            }
        }
        IconButton(
            onClick = onRemove,
            modifier = Modifier.testTag("favorite.remove.${row.favorite.favoriteID}"),
        ) {
            Icon(
                imageVector = Icons.Default.Favorite,
                contentDescription = strings.removeFavorite,
                tint = MaterialTheme.colorScheme.primary,
            )
        }
    }
}

private fun Favorite.toRow(content: ScriptureContent): FavoriteRowModel {
    val target = FavoriteNavigationPolicy.target(content, this)
    val paragraph = target?.anchor?.paragraphID?.let(content::paragraph)
    val volume = paragraph?.volumeID?.let(content::volume)
    val section = paragraph?.sectionID?.let(content::section)
    return FavoriteRowModel(
        favorite = this,
        target = target,
        text = paragraph?.text?.trim(),
        location = listOfNotNull(volume?.title, section?.title)
            .distinct()
            .joinToString(" · ")
            .ifBlank { null },
    )
}

private data class FavoriteRowModel(
    val favorite: Favorite,
    val target: FavoriteNavigationTarget?,
    val text: String?,
    val location: String?,
)

private val SPLIT_DETAIL_MIN_WIDTH = 720.dp
private val SPLIT_LIST_WIDTH = 340.dp
