package org.fuxuan.classics.ui

import android.content.res.AssetManager
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
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
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import org.fuxuan.classics.core.behavior.ExternalUriPolicy

@Serializable
internal data class ThirdPartyNoticeDocument(
    val schemaVersion: Int,
    val inventorySHA256: String,
    val components: List<ThirdPartyNoticeComponent>,
    val licenses: List<ThirdPartyLicense>,
    val platform: String,
) {
    val moduleCount: Int
        get() = components.sumOf(ThirdPartyNoticeComponent::moduleCount)
}

@Serializable
internal data class ThirdPartyNoticeComponent(
    val componentID: String,
    val displayName: String,
    val versions: List<String>,
    val moduleCount: Int,
    val licenseID: String,
    val homepage: String,
    val notice: String,
)

@Serializable
internal data class ThirdPartyLicense(
    val licenseID: String,
    val name: String,
    val canonicalURL: String,
    val text: String,
)

internal object ThirdPartyNoticeCatalog {
    private const val ASSET_NAME = "third-party-notices.json"
    private val json = Json { ignoreUnknownKeys = false }

    fun load(assetManager: AssetManager): ThirdPartyNoticeDocument =
        assetManager.open(ASSET_NAME).bufferedReader().use { reader ->
            decode(reader.readText())
        }

    fun decode(raw: String): ThirdPartyNoticeDocument {
        val document = json.decodeFromString<ThirdPartyNoticeDocument>(raw)
        require(document.schemaVersion == 1) { "Unsupported third-party notice schema" }
        require(document.platform == "android") { "Unexpected notice platform" }
        require(document.inventorySHA256.matches(Regex("[0-9a-f]{64}"))) {
            "Invalid third-party inventory hash"
        }
        require(document.components.isNotEmpty()) { "Third-party components are empty" }
        require(document.licenses.isNotEmpty()) { "Third-party licenses are empty" }

        val licenseIDs = document.licenses.map(ThirdPartyLicense::licenseID)
        require(licenseIDs.size == licenseIDs.toSet().size) { "Duplicate third-party license" }
        require(document.components.map(ThirdPartyNoticeComponent::componentID).let {
            it.size == it.toSet().size
        }) { "Duplicate third-party component" }
        document.components.forEach { component ->
            require(component.displayName.isNotBlank()) { "Third-party component name is empty" }
            require(component.versions.isNotEmpty() && component.versions.none(String::isBlank)) {
                "Third-party component versions are empty"
            }
            require(component.moduleCount > 0) { "Third-party module count must be positive" }
            require(component.licenseID in licenseIDs) { "Third-party component license is missing" }
            require(ExternalUriPolicy.normalizedHttps(component.homepage) == component.homepage) {
                "Third-party homepage must use canonical HTTPS"
            }
        }
        document.licenses.forEach { license ->
            require(license.name.isNotBlank() && license.text.isNotBlank()) {
                "Third-party license text is empty"
            }
            require(ExternalUriPolicy.normalizedHttps(license.canonicalURL) == license.canonicalURL) {
                "Third-party license URL must use canonical HTTPS"
            }
        }
        return document
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun OpenSourceLicensesScreen(
    document: ThirdPartyNoticeDocument?,
    strings: AppStrings,
    onBack: () -> Unit,
    onOpenExternalUri: ((String) -> Unit)?,
) {
    Scaffold(
        modifier = Modifier.testTag("licenses.screen"),
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = strings.openSourceSoftware,
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
                .testTag("licenses.list"),
            contentPadding = PaddingValues(horizontal = 24.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            item {
                Column(
                    modifier = Modifier
                        .widthIn(max = 720.dp)
                        .fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Text(
                        text = strings.openSourceSoftwareIntro,
                        style = MaterialTheme.typography.bodyLarge.copy(letterSpacing = 0.sp),
                    )
                    if (document != null) {
                        Text(
                            text = strings.openSourceSoftwareSummary(
                                componentCount = document.components.size,
                                moduleCount = document.moduleCount,
                            ),
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            style = MaterialTheme.typography.bodyMedium.copy(letterSpacing = 0.sp),
                        )
                    }
                }
            }

            if (document == null) {
                item {
                    Text(
                        text = strings.openSourceSoftwareUnavailable,
                        modifier = Modifier
                            .widthIn(max = 720.dp)
                            .fillMaxWidth()
                            .padding(top = 24.dp),
                        color = MaterialTheme.colorScheme.error,
                        style = MaterialTheme.typography.bodyLarge.copy(letterSpacing = 0.sp),
                    )
                }
            } else {
                items(
                    items = document.components,
                    key = ThirdPartyNoticeComponent::componentID,
                ) { component ->
                    OpenSourceComponent(
                        component = component,
                        strings = strings,
                        onOpenExternalUri = onOpenExternalUri,
                        modifier = Modifier
                            .widthIn(max = 720.dp)
                            .fillMaxWidth(),
                    )
                }

                item {
                    Text(
                        text = strings.licenseTerms,
                        modifier = Modifier
                            .widthIn(max = 720.dp)
                            .fillMaxWidth()
                            .padding(top = 32.dp, bottom = 8.dp)
                            .semantics { heading() },
                        color = MaterialTheme.colorScheme.primary,
                        style = MaterialTheme.typography.titleMedium.copy(letterSpacing = 0.sp),
                    )
                }
                items(
                    items = document.licenses,
                    key = ThirdPartyLicense::licenseID,
                ) { license ->
                    OpenSourceLicense(
                        license = license,
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
}

@Composable
private fun OpenSourceComponent(
    component: ThirdPartyNoticeComponent,
    strings: AppStrings,
    onOpenExternalUri: ((String) -> Unit)?,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .padding(top = 28.dp)
            .testTag("licenses.component.${component.componentID}"),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text(
            text = component.displayName,
            modifier = Modifier.semantics { heading() },
            style = MaterialTheme.typography.titleMedium.copy(letterSpacing = 0.sp),
        )
        LicenseMetadata(strings.openSourceVersions(component.versions))
        LicenseMetadata(strings.openSourceModuleCount(component.moduleCount))
        LicenseMetadata(strings.openSourceLicense(component.licenseID))
        if (component.notice.isNotBlank()) {
            Text(
                text = component.notice,
                style = MaterialTheme.typography.bodyMedium.copy(letterSpacing = 0.sp),
            )
        }
        if (onOpenExternalUri != null) {
            TextButton(onClick = { onOpenExternalUri(component.homepage) }) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp),
                )
                Text(
                    text = strings.openProjectHomepage,
                    modifier = Modifier.padding(start = 8.dp),
                    style = MaterialTheme.typography.labelLarge.copy(letterSpacing = 0.sp),
                )
            }
        }
        HorizontalDivider(modifier = Modifier.padding(top = 8.dp))
    }
}

@Composable
private fun OpenSourceLicense(
    license: ThirdPartyLicense,
    strings: AppStrings,
    onOpenExternalUri: ((String) -> Unit)?,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .padding(top = 20.dp)
            .testTag("licenses.license.${license.licenseID}"),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(
            text = license.name,
            modifier = Modifier.semantics { heading() },
            style = MaterialTheme.typography.titleMedium.copy(letterSpacing = 0.sp),
        )
        if (onOpenExternalUri != null) {
            TextButton(onClick = { onOpenExternalUri(license.canonicalURL) }) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp),
                )
                Text(
                    text = strings.openLicensePage,
                    modifier = Modifier.padding(start = 8.dp),
                    style = MaterialTheme.typography.labelLarge.copy(letterSpacing = 0.sp),
                )
            }
        }
        SelectionContainer {
            Text(
                text = license.text.trimEnd(),
                style = MaterialTheme.typography.bodySmall.copy(letterSpacing = 0.sp),
            )
        }
        HorizontalDivider(modifier = Modifier.padding(top = 8.dp))
    }
}

@Composable
private fun LicenseMetadata(text: String) {
    Text(
        text = text,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        style = MaterialTheme.typography.bodyMedium.copy(letterSpacing = 0.sp),
    )
}
