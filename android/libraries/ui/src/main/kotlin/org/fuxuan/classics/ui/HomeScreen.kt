package org.fuxuan.classics.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
internal fun HomeScreen(
    loaded: LoadedContent,
    strings: AppStrings,
    resumeRoute: VolumeReaderRoute?,
    onRead: () -> Unit,
    onBrowseVolumes: () -> Unit,
) {
    val resumeVolume = resumeRoute?.let { loaded.content.volume(it.volumeID) }
        ?: loaded.content.volumesInReadingOrder().first()

    Box(modifier = Modifier.fillMaxSize()) {
        LazyColumn(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .widthIn(max = 720.dp)
                .fillMaxWidth()
                .fillMaxHeight()
                .windowInsetsPadding(WindowInsets.safeDrawing),
            contentPadding = PaddingValues(horizontal = 24.dp, vertical = 40.dp),
        ) {
            item {
                Text(
                    text = loaded.product.title(loaded.content.locale),
                    color = MaterialTheme.colorScheme.primary,
                    style = MaterialTheme.typography.displaySmall.copy(letterSpacing = 0.sp),
                )
                Text(
                    text = loaded.book.title(loaded.content.locale),
                    modifier = Modifier.padding(top = 12.dp),
                    color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.72f),
                    style = MaterialTheme.typography.bodyLarge.copy(
                        lineHeight = 27.sp,
                        letterSpacing = 0.sp,
                    ),
                )
                Text(
                    text = strings.volumeCount(loaded.content.volumes.size),
                    modifier = Modifier.padding(top = 18.dp),
                    color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.58f),
                    style = MaterialTheme.typography.labelLarge.copy(letterSpacing = 0.sp),
                )
            }
            item { Spacer(modifier = Modifier.height(38.dp)) }
            item {
                Button(
                    onClick = onRead,
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 68.dp),
                    shape = RoundedCornerShape(8.dp),
                    contentPadding = PaddingValues(horizontal = 20.dp, vertical = 12.dp),
                ) {
                    Column(
                        modifier = Modifier.weight(1f),
                        horizontalAlignment = Alignment.Start,
                    ) {
                        Text(
                            text = if (resumeRoute == null) strings.startReading else strings.continueReading,
                            style = MaterialTheme.typography.titleMedium.copy(letterSpacing = 0.sp),
                        )
                        Text(
                            text = resumeVolume.title,
                            modifier = Modifier.padding(top = 2.dp),
                            color = LocalContentColor.current.copy(alpha = 0.78f),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            style = MaterialTheme.typography.bodySmall.copy(letterSpacing = 0.sp),
                        )
                    }
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                        contentDescription = null,
                    )
                }
            }
            item { Spacer(modifier = Modifier.height(14.dp)) }
            item {
                OutlinedButton(
                    onClick = onBrowseVolumes,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(56.dp),
                    shape = RoundedCornerShape(8.dp),
                    contentPadding = ButtonDefaults.ContentPadding,
                ) {
                    Text(
                        text = strings.chooseVolume,
                        style = MaterialTheme.typography.labelLarge.copy(letterSpacing = 0.sp),
                    )
                }
            }
        }
    }
}
