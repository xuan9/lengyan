package org.fuxuan.classics.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun PrivacyInfoScreen(
    strings: AppStrings,
    privacyPolicyUri: String?,
    onBack: () -> Unit,
    onOpenExternalUri: ((String) -> Unit)?,
) {
    val externalPolicyUri = ExternalUriPolicy.normalizedHttps(privacyPolicyUri)
    Scaffold(
        modifier = Modifier.testTag("privacy.screen"),
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = strings.privacy,
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
                .testTag("privacy.list"),
            contentPadding = PaddingValues(horizontal = 24.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            item {
                Column(
                    modifier = Modifier
                        .widthIn(max = 720.dp)
                        .fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(28.dp),
                ) {
                    PrivacySection(strings.privacyLocalTitle, strings.privacyLocalBody)
                    PrivacySection(strings.privacyTrackingTitle, strings.privacyTrackingBody)
                    PrivacySection(strings.privacyNetworkTitle, strings.privacyNetworkBody)
                    PrivacySection(strings.privacyRemovalTitle, strings.privacyRemovalBody)
                    if (externalPolicyUri != null && onOpenExternalUri != null) {
                        Button(
                            onClick = { onOpenExternalUri(externalPolicyUri) },
                            modifier = Modifier.testTag("privacy.open-policy"),
                        ) {
                            Icon(
                                imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                                contentDescription = null,
                                modifier = Modifier.size(18.dp),
                            )
                            Text(
                                text = strings.openFullPrivacyPolicy,
                                modifier = Modifier.padding(start = 8.dp),
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PrivacySection(title: String, body: String) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = title,
            modifier = Modifier.semantics { heading() },
            color = MaterialTheme.colorScheme.primary,
            style = MaterialTheme.typography.titleMedium.copy(letterSpacing = 0.sp),
        )
        Text(
            text = body,
            style = MaterialTheme.typography.bodyLarge.copy(letterSpacing = 0.sp),
        )
    }
}
