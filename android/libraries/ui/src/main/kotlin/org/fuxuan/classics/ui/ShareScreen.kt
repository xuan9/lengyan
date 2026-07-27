package org.fuxuan.classics.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.OutputStreamWriter

internal sealed interface ShareImageGenerationState {
    data object Idle : ShareImageGenerationState

    data class Generating(
        val completedPageCount: Int,
        val pageCount: Int?,
    ) : ShareImageGenerationState
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun ShareScreen(
    document: ShareDocument,
    strings: AppStrings,
    onBack: () -> Unit,
    imageExporterOverride: ShareImageExporter? = null,
    onImagesReadyOverride: ((ShareImageExport) -> Unit)? = null,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val exporter = imageExporterOverride ?: remember(context.applicationContext) {
        AndroidShareImageExporter(context.applicationContext)
    }
    var generationState by remember(document) {
        mutableStateOf<ShareImageGenerationState>(ShareImageGenerationState.Idle)
    }
    var generationJob by remember(document) { mutableStateOf<Job?>(null) }
    var statusMessage by remember(document) { mutableStateOf<String?>(null) }

    val saveTextLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("text/plain"),
    ) { uri ->
        if (uri != null) {
            scope.launch {
                val saved = try {
                    withContext(Dispatchers.IO) {
                        writeUtf8Text(context, uri, document.completeText)
                    }
                    true
                } catch (cancellation: CancellationException) {
                    throw cancellation
                } catch (_: Exception) {
                    false
                }
                statusMessage = if (saved) strings.textSaved else strings.textSaveFailed
            }
        }
    }

    fun startImageExport() {
        if (generationJob?.isActive == true) return
        statusMessage = null
        generationState = ShareImageGenerationState.Generating(
            completedPageCount = 0,
            pageCount = null,
        )
        generationJob = scope.launch {
            val result = try {
                exporter.export(document) { progress ->
                    withContext(Dispatchers.Main.immediate) {
                        generationState = ShareImageGenerationState.Generating(
                            completedPageCount = progress.completedPageCount,
                            pageCount = progress.pageCount,
                        )
                    }
                }
            } catch (_: CancellationException) {
                generationState = ShareImageGenerationState.Idle
                return@launch
            } catch (_: Exception) {
                generationState = ShareImageGenerationState.Idle
                statusMessage = strings.imageExportFailed
                return@launch
            }

            generationState = ShareImageGenerationState.Idle
            try {
                if (onImagesReadyOverride != null) {
                    onImagesReadyOverride(result)
                } else {
                    shareImages(context, document.volumeTitle, result.files)
                }
            } catch (_: Exception) {
                statusMessage = strings.shareFailed
            }
        }
    }

    ShareScreenContent(
        document = document,
        strings = strings,
        generationState = generationState,
        statusMessage = statusMessage,
        onBack = onBack,
        onShareImage = ::startImageExport,
        onShareText = {
            statusMessage = null
            try {
                sharePlainText(context, document.volumeTitle, document.completeText)
            } catch (_: Exception) {
                statusMessage = strings.shareFailed
            }
        },
        onSaveText = {
            statusMessage = null
            saveTextLauncher.launch(document.textFileName)
        },
        onCopyText = {
            try {
                copyText(context, document.volumeTitle, document.completeText)
                statusMessage = strings.textCopied
            } catch (_: Exception) {
                statusMessage = strings.textCopyFailed
            }
        },
        onCancelImageExport = {
            generationJob?.cancel()
            generationState = ShareImageGenerationState.Idle
        },
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun ShareScreenContent(
    document: ShareDocument,
    strings: AppStrings,
    generationState: ShareImageGenerationState,
    statusMessage: String?,
    onBack: () -> Unit,
    onShareImage: () -> Unit,
    onShareText: () -> Unit,
    onSaveText: () -> Unit,
    onCopyText: () -> Unit,
    onCancelImageExport: () -> Unit,
) {
    Scaffold(
        modifier = Modifier
            .fillMaxSize()
            .testTag("share.screen"),
        containerColor = MaterialTheme.colorScheme.background,
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = strings.sharePreview,
                        modifier = Modifier.semantics { heading() },
                        style = MaterialTheme.typography.titleMedium.copy(letterSpacing = 0.sp),
                    )
                },
                navigationIcon = { BackButton(strings.back, onBack) },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                ),
            )
        },
        bottomBar = {
            ShareActionRegion(
                strings = strings,
                generationState = generationState,
                onShareImage = onShareImage,
                onShareText = onShareText,
                onSaveText = onSaveText,
                onCopyText = onCopyText,
                onCancelImageExport = onCancelImageExport,
            )
        },
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
        ) {
            Column(
                verticalArrangement = Arrangement.spacedBy(16.dp),
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .widthIn(max = 680.dp)
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp, vertical = 16.dp),
            ) {
                ShareTextPreview(document)
                Text(
                    text = strings.shareCharacterCount(document.characterCount),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.bodySmall.copy(letterSpacing = 0.sp),
                )
                if (statusMessage != null) {
                    Text(
                        text = statusMessage,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier
                            .testTag("share.status")
                            .semantics { liveRegion = LiveRegionMode.Polite },
                        style = MaterialTheme.typography.bodyMedium.copy(letterSpacing = 0.sp),
                    )
                }
            }
        }
    }
}

@Composable
private fun ShareTextPreview(document: ShareDocument) {
    Surface(
        color = MaterialTheme.colorScheme.surface,
        contentColor = MaterialTheme.colorScheme.onSurface,
        shape = MaterialTheme.shapes.small,
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant),
        modifier = Modifier
            .fillMaxWidth()
            .testTag("share.preview"),
    ) {
        Column(
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier.padding(horizontal = 22.dp, vertical = 20.dp),
        ) {
            Text(
                text = document.productTitle,
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.primary,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.fillMaxWidth(),
                style = MaterialTheme.typography.titleMedium.copy(letterSpacing = 0.sp),
            )
            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
            SelectionContainer {
                ReaderText(
                    text = document.preview(),
                    fontSizeLevel = document.fontSizeLevel,
                    modifier = Modifier.testTag("share.preview.body"),
                )
            }
            Text(
                text = document.volumeTitle,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Start,
                style = MaterialTheme.typography.bodySmall.copy(letterSpacing = 0.sp),
            )
        }
    }
}

@Composable
private fun ShareActionRegion(
    strings: AppStrings,
    generationState: ShareImageGenerationState,
    onShareImage: () -> Unit,
    onShareText: () -> Unit,
    onSaveText: () -> Unit,
    onCopyText: () -> Unit,
    onCancelImageExport: () -> Unit,
) {
    Surface(
        color = MaterialTheme.colorScheme.surface,
        tonalElevation = 2.dp,
    ) {
        Column(
            verticalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 10.dp),
        ) {
            if (generationState is ShareImageGenerationState.Generating) {
                val total = generationState.pageCount
                Text(
                    text = strings.imageExportProgress(
                        generationState.completedPageCount,
                        total,
                    ),
                    style = MaterialTheme.typography.labelLarge.copy(letterSpacing = 0.sp),
                )
                if (total != null) {
                    LinearProgressIndicator(
                        progress = {
                            generationState.completedPageCount.toFloat() / total.toFloat()
                        },
                        modifier = Modifier.fillMaxWidth(),
                    )
                } else {
                    LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
                }
                Button(
                    onClick = onCancelImageExport,
                    shape = MaterialTheme.shapes.small,
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 48.dp)
                        .testTag("share.action.cancel"),
                ) {
                    Text(
                        text = strings.cancel,
                        style = MaterialTheme.typography.labelLarge.copy(letterSpacing = 0.sp),
                    )
                }
            } else {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    ShareActionButton(
                        label = strings.shareImage,
                        icon = Icons.Default.Share,
                        primary = true,
                        onClick = onShareImage,
                        modifier = Modifier
                            .weight(1f)
                            .testTag("share.action.image"),
                    )
                    ShareActionButton(
                        label = strings.shareText,
                        icon = Icons.AutoMirrored.Filled.Send,
                        onClick = onShareText,
                        modifier = Modifier
                            .weight(1f)
                            .testTag("share.action.text"),
                    )
                }
                Row(
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    ShareActionButton(
                        label = strings.saveTextFile,
                        icon = null,
                        onClick = onSaveText,
                        modifier = Modifier
                            .weight(1f)
                            .testTag("share.action.save"),
                    )
                    ShareActionButton(
                        label = strings.copyText,
                        icon = null,
                        onClick = onCopyText,
                        modifier = Modifier
                            .weight(1f)
                            .testTag("share.action.copy"),
                    )
                }
            }
        }
    }
}

@Composable
private fun ShareActionButton(
    label: String,
    icon: ImageVector?,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    primary: Boolean = false,
) {
    val content: @Composable () -> Unit = {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            if (icon != null) {
                Icon(imageVector = icon, contentDescription = null)
            }
            Text(
                text = label,
                maxLines = 2,
                textAlign = TextAlign.Center,
                style = MaterialTheme.typography.labelLarge.copy(letterSpacing = 0.sp),
            )
        }
    }
    val contentPadding = PaddingValues(horizontal = 8.dp, vertical = 10.dp)
    if (primary) {
        Button(
            onClick = onClick,
            modifier = modifier.heightIn(min = 76.dp),
            shape = MaterialTheme.shapes.small,
            contentPadding = contentPadding,
            content = { content() },
        )
    } else {
        OutlinedButton(
            onClick = onClick,
            modifier = modifier.heightIn(min = 76.dp),
            shape = MaterialTheme.shapes.small,
            contentPadding = contentPadding,
            content = { content() },
        )
    }
}

private fun shareImages(context: Context, title: String, files: List<File>) {
    val authority = "${context.packageName}.share-files"
    val uris = files.map { file -> FileProvider.getUriForFile(context, authority, file) }
    val intent = if (uris.size == 1) {
        Intent(Intent.ACTION_SEND).apply {
            type = "image/jpeg"
            putExtra(Intent.EXTRA_STREAM, uris.single())
        }
    } else {
        Intent(Intent.ACTION_SEND_MULTIPLE).apply {
            type = "image/jpeg"
            putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(uris))
        }
    }
    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
    intent.clipData = ClipData.newUri(context.contentResolver, title, uris.first()).apply {
        uris.drop(1).forEach { uri -> addItem(ClipData.Item(uri)) }
    }
    context.startActivity(Intent.createChooser(intent, title))
}

private fun sharePlainText(context: Context, title: String, text: String) {
    val intent = Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TITLE, title)
        putExtra(Intent.EXTRA_TEXT, text)
    }
    context.startActivity(Intent.createChooser(intent, title))
}

private fun copyText(context: Context, title: String, text: String) {
    val clipboard = context.getSystemService(ClipboardManager::class.java)
    clipboard.setPrimaryClip(ClipData.newPlainText(title, text))
}

private fun writeUtf8Text(context: Context, uri: Uri, text: String) {
    val output = requireNotNull(context.contentResolver.openOutputStream(uri, "wt")) {
        "document provider did not return an output stream"
    }
    OutputStreamWriter(output, Charsets.UTF_8).use { writer -> writer.write(text) }
}
