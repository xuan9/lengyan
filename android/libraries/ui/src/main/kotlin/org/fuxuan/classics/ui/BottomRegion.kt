package org.fuxuan.classics.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp

@Composable
internal fun BottomRegion(
    selected: TopLevelDestination,
    strings: AppStrings,
    onSelect: (TopLevelDestination) -> Unit,
    miniPlayer: (@Composable () -> Unit)? = null,
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        miniPlayer?.invoke()
        NavigationBar(
            modifier = Modifier.testTag("bottom.navigation"),
            tonalElevation = 0.dp,
        ) {
            NavigationBarItem(
                selected = selected == TopLevelDestination.READING,
                onClick = { onSelect(TopLevelDestination.READING) },
                icon = {
                    Icon(
                        imageVector = Icons.Default.Home,
                        contentDescription = null,
                    )
                },
                label = { Text(strings.reading) },
                modifier = Modifier.testTag("bottom.reading"),
            )
            NavigationBarItem(
                selected = selected == TopLevelDestination.FAVORITES,
                onClick = { onSelect(TopLevelDestination.FAVORITES) },
                icon = {
                    Icon(
                        imageVector = Icons.Default.Favorite,
                        contentDescription = null,
                    )
                },
                label = { Text(strings.favorites) },
                modifier = Modifier.testTag("bottom.favorites"),
            )
            NavigationBarItem(
                selected = selected == TopLevelDestination.SETTINGS,
                onClick = { onSelect(TopLevelDestination.SETTINGS) },
                icon = {
                    Icon(
                        imageVector = Icons.Default.Settings,
                        contentDescription = null,
                    )
                },
                label = { Text(strings.settings) },
                modifier = Modifier.testTag("bottom.settings"),
            )
        }
    }
}

internal enum class TopLevelDestination {
    READING,
    FAVORITES,
    SETTINGS,
}
