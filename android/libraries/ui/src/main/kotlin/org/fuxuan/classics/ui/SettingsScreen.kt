package org.fuxuan.classics.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.selection.selectable
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import org.fuxuan.classics.core.persistence.ProductPreferences
import org.fuxuan.classics.core.persistence.ThemePreference
import kotlin.math.roundToInt

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun SettingsScreen(
    preferences: ProductPreferences,
    supportedLocales: List<String>,
    strings: AppStrings,
    onSelectTheme: (ThemePreference) -> Unit,
    onSelectLocale: (String) -> Unit,
    onSelectFontSize: (Int) -> Unit,
) {
    Scaffold(
        modifier = Modifier.testTag("settings.screen"),
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = strings.settings,
                        style = MaterialTheme.typography.titleLarge.copy(letterSpacing = 0.sp),
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                ),
            )
        },
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
            contentPadding = PaddingValues(horizontal = 24.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            item {
                Column(
                    modifier = Modifier
                        .widthIn(max = 720.dp)
                        .fillMaxWidth(),
                ) {
                    SettingsHeading(strings.appearance)
                    ThemePreference.entries.forEach { theme ->
                        SettingsChoiceRow(
                            text = strings.themeName(theme),
                            selected = preferences.theme == theme,
                            testTag = "settings.theme.${theme.name.lowercase()}",
                            onClick = { onSelectTheme(theme) },
                        )
                    }

                    SettingsHeading(
                        text = strings.language,
                        modifier = Modifier.padding(top = 28.dp),
                    )
                    supportedLocales.forEach { locale ->
                        SettingsChoiceRow(
                            text = strings.localeName(locale),
                            selected = preferences.locale == locale,
                            testTag = "settings.locale.$locale",
                            onClick = { onSelectLocale(locale) },
                        )
                    }

                    SettingsHeading(
                        text = strings.fontSize,
                        modifier = Modifier.padding(top = 28.dp),
                    )
                    FontSizeSetting(
                        level = preferences.fontSizeLevel,
                        strings = strings,
                        onSelectFontSize = onSelectFontSize,
                    )
                }
            }
        }
    }
}

@Composable
private fun SettingsHeading(
    text: String,
    modifier: Modifier = Modifier,
) {
    Text(
        text = text,
        modifier = modifier.padding(bottom = 6.dp),
        color = MaterialTheme.colorScheme.primary,
        style = MaterialTheme.typography.titleMedium.copy(letterSpacing = 0.sp),
    )
}

@Composable
private fun SettingsChoiceRow(
    text: String,
    selected: Boolean,
    testTag: String,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 56.dp)
            .testTag(testTag)
            .selectable(
                selected = selected,
                onClick = onClick,
                role = Role.RadioButton,
            )
            .padding(horizontal = 4.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        RadioButton(
            selected = selected,
            onClick = null,
        )
        Text(
            text = text,
            modifier = Modifier.padding(start = 12.dp),
            style = MaterialTheme.typography.bodyLarge.copy(letterSpacing = 0.sp),
        )
    }
}

@Composable
private fun FontSizeSetting(
    level: Int,
    strings: AppStrings,
    onSelectFontSize: (Int) -> Unit,
) {
    var sliderValue by remember { mutableStateOf(level.toFloat()) }
    LaunchedEffect(level) { sliderValue = level.toFloat() }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("settings.font-size"),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        ReaderText(
            text = strings.fontPreview,
            fontSizeLevel = sliderValue.roundToInt(),
            modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp),
        )
        Slider(
            value = sliderValue,
            onValueChange = { sliderValue = it },
            onValueChangeFinished = { onSelectFontSize(sliderValue.roundToInt()) },
            valueRange = 0f..4f,
            steps = 3,
        )
    }
}
