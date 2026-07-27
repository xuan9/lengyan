package org.fuxuan.classics.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.fuxuan.classics.core.behavior.ExternalUriPolicy
import org.fuxuan.classics.core.content.DocumentedSource
import org.fuxuan.classics.core.content.SourceManifest
import org.fuxuan.classics.core.content.SourceReleaseEligibility

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun SourceInfoScreen(
    manifest: SourceManifest,
    productTitle: String,
    locale: String,
    strings: AppStrings,
    onBack: () -> Unit,
    onOpenExternalUri: ((String) -> Unit)?,
) {
    Scaffold(
        modifier = Modifier.testTag("source.screen"),
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = strings.sourceInformation,
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
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .testTag("source.list"),
            contentPadding = PaddingValues(horizontal = 24.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            item {
                Column(
                    modifier = Modifier
                        .widthIn(max = 720.dp)
                        .fillMaxWidth(),
                ) {
                    SourceReviewSummary(
                        manifest = manifest,
                        productTitle = productTitle,
                        strings = strings,
                    )
                    SourceApprovalSummary(manifest = manifest, strings = strings)
                    Text(
                        text = strings.sourceRecords,
                        modifier = Modifier
                            .padding(top = 32.dp, bottom = 8.dp)
                            .semantics { heading() },
                        color = MaterialTheme.colorScheme.primary,
                        style = MaterialTheme.typography.titleMedium.copy(letterSpacing = 0.sp),
                    )
                }
            }
            items(
                items = manifest.sources,
                key = DocumentedSource::sourceID,
            ) { source ->
                DocumentedSourceItem(
                    source = source,
                    productTitle = productTitle,
                    locale = locale,
                    strings = strings,
                    onOpenExternalUri = onOpenExternalUri,
                    modifier = Modifier
                        .widthIn(max = 720.dp)
                        .fillMaxWidth(),
                )
            }
        }
    }
}

@Composable
private fun SourceReviewSummary(
    manifest: SourceManifest,
    productTitle: String,
    strings: AppStrings,
) {
    val approved = manifest.releaseEligibility == SourceReleaseEligibility.ELIGIBLE
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("source.status"),
        color = if (approved) {
            MaterialTheme.colorScheme.primaryContainer
        } else {
            MaterialTheme.colorScheme.surfaceVariant
        },
        contentColor = if (approved) {
            MaterialTheme.colorScheme.onPrimaryContainer
        } else {
            MaterialTheme.colorScheme.onSurfaceVariant
        },
        shape = RoundedCornerShape(4.dp),
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 14.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(
                text = strings.sourceReviewTitle(manifest.reviewStatus),
                modifier = Modifier.semantics { heading() },
                style = MaterialTheme.typography.titleMedium.copy(letterSpacing = 0.sp),
            )
            Text(
                text = strings.sourceReviewBody(
                    manifest.reviewStatus,
                    manifest.releaseEligibility,
                    productTitle,
                ),
                style = MaterialTheme.typography.bodyLarge.copy(letterSpacing = 0.sp),
            )
        }
    }
}

@Composable
private fun SourceApprovalSummary(
    manifest: SourceManifest,
    strings: AppStrings,
) {
    Column(
        modifier = Modifier.padding(top = 24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        SourceApprovalItem(
            label = strings.textAccuracy,
            value = strings.sourceApproval(manifest.approvals.textAccuracy.status),
        )
        SourceApprovalItem(
            label = strings.distributionRights,
            value = strings.sourceApproval(manifest.approvals.rights.status),
        )
    }
}

@Composable
private fun SourceApprovalItem(label: String, value: String) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(
            text = label,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            style = MaterialTheme.typography.labelLarge.copy(letterSpacing = 0.sp),
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyLarge.copy(letterSpacing = 0.sp),
        )
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun DocumentedSourceItem(
    source: DocumentedSource,
    productTitle: String,
    locale: String,
    strings: AppStrings,
    onOpenExternalUri: ((String) -> Unit)?,
    modifier: Modifier = Modifier,
) {
    val sourceUri = ExternalUriPolicy.normalizedHttps(source.sourceURI)
    val rightsUri = ExternalUriPolicy.normalizedHttps(source.rights.statementURI)
    Column(
        modifier = modifier
            .testTag("source.record.${source.sourceID}")
            .padding(vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Text(
            text = strings.documentedSourceRole(source.role),
            color = MaterialTheme.colorScheme.primary,
            style = MaterialTheme.typography.labelLarge.copy(letterSpacing = 0.sp),
        )
        Text(
            text = strings.documentedSourceTitle(source, productTitle),
            modifier = Modifier.semantics { heading() },
            style = MaterialTheme.typography.titleMedium.copy(letterSpacing = 0.sp),
        )
        strings.documentedSourceRoleNote(source.role)?.let { note ->
            Text(
                text = note,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodyMedium.copy(letterSpacing = 0.sp),
            )
        }
        Text(
            text = strings.sourceRights(source.rights.status),
            style = MaterialTheme.typography.bodyLarge.copy(letterSpacing = 0.sp),
        )
        source.institution?.let { value ->
            SourceMetadata(strings.sourceMetadata(strings.sourceInstitutionLabel, value))
        }
        source.canonicalIdentifier?.let { value ->
            SourceMetadata(strings.sourceMetadata(strings.sourceIdentifierLabel, value))
        }
        source.attribution(locale)?.let { value ->
            SourceMetadata(strings.sourceMetadata(strings.sourceAttributionLabel, value))
        }
        SourceMetadata(
            strings.sourceMetadata(
                strings.sourceRetrievedLabel,
                strings.sourceRetrievedDate(source.retrievedOn),
            ),
        )

        if (onOpenExternalUri != null && (sourceUri != null || rightsUri != null)) {
            FlowRow(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                sourceUri?.let { uri ->
                    SourceLinkButton(
                        label = strings.openSourcePage,
                        onClick = { onOpenExternalUri(uri) },
                    )
                }
                rightsUri?.let { uri ->
                    SourceLinkButton(
                        label = strings.openRightsPage,
                        onClick = { onOpenExternalUri(uri) },
                    )
                }
            }
        }
        HorizontalDivider(modifier = Modifier.padding(top = 8.dp))
    }
}

@Composable
private fun SourceMetadata(text: String) {
    Text(
        text = text,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        style = MaterialTheme.typography.bodyMedium.copy(letterSpacing = 0.sp),
    )
}

@Composable
private fun SourceLinkButton(label: String, onClick: () -> Unit) {
    TextButton(onClick = onClick) {
        Icon(
            imageVector = Icons.AutoMirrored.Filled.ArrowForward,
            contentDescription = null,
            modifier = Modifier.size(18.dp),
        )
        Text(
            text = label,
            modifier = Modifier.padding(start = 8.dp),
            style = MaterialTheme.typography.labelLarge.copy(letterSpacing = 0.sp),
        )
    }
}
