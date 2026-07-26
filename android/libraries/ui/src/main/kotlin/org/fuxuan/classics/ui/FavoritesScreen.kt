package org.fuxuan.classics.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
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
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.fuxuan.classics.core.behavior.FavoriteNavigationPolicy
import org.fuxuan.classics.core.behavior.FavoriteNavigationTarget
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
) {
    val rows = remember(content, favorites) {
        favorites.map { favorite -> favorite.toRow(content) }
    }
    Scaffold(
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
                            onOpen = { row.target?.let(onOpenFavorite) },
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
    onOpen: () -> Unit,
    onRemove: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 88.dp)
            .testTag("favorite.row.${row.favorite.favoriteID}")
            .then(
                if (row.target == null) Modifier else Modifier.clickable(onClick = onOpen),
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
