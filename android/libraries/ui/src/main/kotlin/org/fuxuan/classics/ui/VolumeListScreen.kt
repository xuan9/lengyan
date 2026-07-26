package org.fuxuan.classics.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
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
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.PrimaryTabRow
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Tab
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.fuxuan.classics.core.behavior.OutlineDisclosurePolicy
import org.fuxuan.classics.core.behavior.OutlineDisclosureRow
import org.fuxuan.classics.core.content.ScriptureContent
import org.fuxuan.classics.core.content.ScriptureParagraph
import org.fuxuan.classics.core.content.ScriptureVolume
import kotlin.math.min

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun ContentBrowserScreen(
    content: ScriptureContent,
    strings: AppStrings,
    resumeRoute: VolumeReaderRoute?,
    expandedSectionIDs: Set<String>,
    onExpandedSectionIDsChanged: (Set<String>) -> Unit,
    onBack: () -> Unit,
    onOpenVolume: (String) -> Unit,
    onOpenParagraph: (ScriptureParagraph) -> Unit,
) {
    var selectedTab by rememberSaveable { mutableStateOf(ContentBrowserTab.OUTLINE) }
    val resumeSectionID = resumeRoute?.paragraphID
        ?.let(content::paragraph)
        ?.sectionID

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = strings.scriptureDirectory,
                        modifier = Modifier.semantics { heading() },
                        style = MaterialTheme.typography.titleLarge.copy(letterSpacing = 0.sp),
                    )
                },
                navigationIcon = { BackButton(strings.back, onBack) },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                ),
            )
        },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(
                modifier = Modifier
                    .widthIn(max = 760.dp)
                    .fillMaxWidth()
                    .fillMaxHeight(),
            ) {
                PrimaryTabRow(
                    selectedTabIndex = selectedTab.ordinal,
                    modifier = Modifier.testTag("directory.tabs"),
                ) {
                    ContentBrowserTab.entries.forEach { tab ->
                        Tab(
                            selected = selectedTab == tab,
                            onClick = { selectedTab = tab },
                            text = {
                                Text(
                                    text = when (tab) {
                                        ContentBrowserTab.OUTLINE -> strings.outline
                                        ContentBrowserTab.VOLUMES -> strings.volumes
                                    },
                                    style = MaterialTheme.typography.labelLarge.copy(
                                        letterSpacing = 0.sp,
                                    ),
                                )
                            },
                            modifier = Modifier.testTag("directory.tab.${tab.name.lowercase()}"),
                        )
                    }
                }
                when (selectedTab) {
                    ContentBrowserTab.OUTLINE -> OutlineList(
                        content = content,
                        strings = strings,
                        expandedSectionIDs = expandedSectionIDs,
                        resumeSectionID = resumeSectionID,
                        onExpandedSectionIDsChanged = onExpandedSectionIDsChanged,
                        onOpenParagraph = onOpenParagraph,
                        modifier = Modifier.weight(1f),
                    )
                    ContentBrowserTab.VOLUMES -> VolumeList(
                        content = content,
                        strings = strings,
                        resumeRoute = resumeRoute,
                        onOpenVolume = onOpenVolume,
                        modifier = Modifier.weight(1f),
                    )
                }
            }
        }
    }
}

@Composable
private fun OutlineList(
    content: ScriptureContent,
    strings: AppStrings,
    expandedSectionIDs: Set<String>,
    resumeSectionID: String?,
    onExpandedSectionIDsChanged: (Set<String>) -> Unit,
    onOpenParagraph: (ScriptureParagraph) -> Unit,
    modifier: Modifier = Modifier,
) {
    val rows = remember(content, expandedSectionIDs) {
        OutlineDisclosurePolicy.visibleRows(content, expandedSectionIDs)
    }
    LazyColumn(
        modifier = modifier
            .fillMaxWidth()
            .testTag("outline.list"),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
    ) {
        items(
            items = rows,
            key = { row -> row.section.sectionID },
        ) { row ->
            OutlineRow(
                row = row,
                strings = strings,
                isCurrent = !row.hasChildren && row.section.sectionID == resumeSectionID,
                onClick = {
                    if (row.hasChildren) {
                        val next = expandedSectionIDs.toMutableSet()
                        if (row.isExpanded) next.remove(row.section.sectionID)
                        else next.add(row.section.sectionID)
                        onExpandedSectionIDsChanged(next)
                    } else {
                        content.firstParagraphInSubtree(row.section.sectionID)
                            ?.let(onOpenParagraph)
                    }
                },
            )
            HorizontalDivider()
        }
    }
}

@Composable
private fun OutlineRow(
    row: OutlineDisclosureRow,
    strings: AppStrings,
    isCurrent: Boolean,
    onClick: () -> Unit,
) {
    val indentation = (min(row.depth, MAX_VISIBLE_INDENT_LEVEL) * INDENT_STEP_DP).dp
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 56.dp)
            .testTag("outline.row.${row.section.sectionID}")
            .semantics {
                if (row.depth == 0) heading()
                if (isCurrent) selected = true
                if (row.hasChildren) {
                    stateDescription = if (row.isExpanded) strings.expanded else strings.collapsed
                }
            }
            .clickable(role = Role.Button, onClick = onClick)
            .padding(
                start = 4.dp + indentation,
                top = 10.dp,
                end = 4.dp,
                bottom = 10.dp,
            ),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (row.hasChildren) {
            Icon(
                imageVector = if (row.isExpanded) {
                    Icons.Default.KeyboardArrowDown
                } else {
                    Icons.AutoMirrored.Filled.KeyboardArrowRight
                },
                contentDescription = null,
                modifier = Modifier.size(24.dp),
                tint = if (row.depth == 0) {
                    MaterialTheme.colorScheme.primary
                } else {
                    MaterialTheme.colorScheme.onSurface.copy(alpha = 0.58f)
                },
            )
        } else {
            Spacer(modifier = Modifier.size(24.dp))
        }
        Text(
            text = row.section.title,
            modifier = Modifier
                .weight(1f)
                .padding(start = 8.dp),
            color = when {
                isCurrent -> MaterialTheme.colorScheme.secondary
                row.depth == 0 -> MaterialTheme.colorScheme.primary
                !row.hasChildren -> MaterialTheme.colorScheme.onSurface
                else -> MaterialTheme.colorScheme.onSurface.copy(alpha = 0.78f)
            },
            fontWeight = when {
                isCurrent -> FontWeight.Medium
                row.depth == 0 -> FontWeight.SemiBold
                else -> FontWeight.Normal
            },
            style = if (row.depth == 0) {
                MaterialTheme.typography.titleMedium.copy(
                    lineHeight = 25.sp,
                    letterSpacing = 0.sp,
                )
            } else {
                MaterialTheme.typography.bodyLarge.copy(
                    lineHeight = 26.sp,
                    letterSpacing = 0.sp,
                )
            },
        )
        if (!row.hasChildren) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                contentDescription = null,
                modifier = Modifier
                    .padding(start = 8.dp)
                    .size(20.dp),
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.42f),
            )
        }
    }
}

@Composable
private fun VolumeList(
    content: ScriptureContent,
    strings: AppStrings,
    resumeRoute: VolumeReaderRoute?,
    onOpenVolume: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val volumes = content.volumesInReadingOrder()
    LazyColumn(
        modifier = modifier
            .fillMaxWidth()
            .testTag("volume.list"),
        contentPadding = PaddingValues(horizontal = 20.dp, vertical = 12.dp),
    ) {
        items(
            count = volumes.size,
            key = { index -> volumes[index].volumeID },
        ) { index ->
            val volume = volumes[index]
            VolumeRow(
                volume = volume,
                strings = strings,
                isResumeVolume = resumeRoute?.volumeID == volume.volumeID,
                onClick = { onOpenVolume(volume.volumeID) },
            )
            if (index < volumes.lastIndex) HorizontalDivider()
        }
    }
}

@Composable
private fun VolumeRow(
    volume: ScriptureVolume,
    strings: AppStrings,
    isResumeVolume: Boolean,
    onClick: () -> Unit,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 72.dp)
            .testTag("volume.row.${volume.volumeID}")
            .semantics {
                if (isResumeVolume) selected = true
            }
            .clickable(role = Role.Button, onClick = onClick)
            .padding(horizontal = 4.dp, vertical = 12.dp),
    ) {
        Text(
            text = volume.number.toString().padStart(2, '0'),
            modifier = Modifier.width(42.dp),
            color = MaterialTheme.colorScheme.primary,
            style = MaterialTheme.typography.labelLarge.copy(letterSpacing = 0.sp),
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = volume.title,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
                style = MaterialTheme.typography.titleMedium.copy(
                    lineHeight = 24.sp,
                    letterSpacing = 0.sp,
                ),
            )
            if (isResumeVolume) {
                Text(
                    text = strings.lastRead,
                    modifier = Modifier.padding(top = 3.dp),
                    color = MaterialTheme.colorScheme.secondary,
                    style = MaterialTheme.typography.labelMedium.copy(letterSpacing = 0.sp),
                )
            }
        }
        Icon(
            imageVector = Icons.AutoMirrored.Filled.ArrowForward,
            contentDescription = null,
            modifier = Modifier.size(20.dp),
            tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.48f),
        )
    }
}

@Composable
internal fun BackButton(contentDescription: String, onClick: () -> Unit) {
    IconButton(onClick = onClick) {
        Icon(
            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
            contentDescription = contentDescription,
        )
    }
}

private enum class ContentBrowserTab {
    OUTLINE,
    VOLUMES,
}

private const val MAX_VISIBLE_INDENT_LEVEL = 7
private const val INDENT_STEP_DP = 10
