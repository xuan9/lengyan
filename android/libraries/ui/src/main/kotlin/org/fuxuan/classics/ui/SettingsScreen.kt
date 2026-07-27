package org.fuxuan.classics.ui

import android.Manifest
import android.app.TimePickerDialog
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.selection.toggleable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Slider
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import kotlinx.coroutines.launch
import org.fuxuan.classics.core.persistence.ProductPreferences
import org.fuxuan.classics.core.persistence.ReminderPreferences
import org.fuxuan.classics.core.persistence.ThemePreference
import java.util.Locale
import kotlin.math.roundToInt

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun SettingsScreen(
    preferences: ProductPreferences,
    supportedLocales: List<String>,
    productTitle: String,
    strings: AppStrings,
    dailyVerseWidgetInstalled: Boolean = false,
    dailyVerseWidgetPinSupported: Boolean = false,
    onRequestDailyVerseWidgetPin: (() -> Boolean)? = null,
    onSelectTheme: (ThemePreference) -> Unit,
    onSelectLocale: (String) -> Unit,
    onSelectFontSize: (Int) -> Unit,
    onSetReminder: (ReminderPreferences) -> Unit,
) {
    val context = LocalContext.current
    val snackbarHostState = remember { SnackbarHostState() }
    val coroutineScope = rememberCoroutineScope()
    var showWidgetGuide by rememberSaveable { mutableStateOf(false) }
    val notificationPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) {
            onSetReminder(preferences.reminder.copy(enabled = true))
        } else {
            coroutineScope.launch {
                snackbarHostState.showSnackbar(strings.notificationPermissionDenied)
            }
        }
    }

    fun setReminderEnabled(enabled: Boolean) {
        if (!enabled) {
            onSetReminder(preferences.reminder.copy(enabled = false))
            return
        }
        val permissionGranted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        if (permissionGranted) {
            onSetReminder(preferences.reminder.copy(enabled = true))
        } else {
            notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    if (showWidgetGuide) {
        WidgetInstallationGuideDialog(
            productTitle = productTitle,
            strings = strings,
            onDismiss = { showWidgetGuide = false },
        )
    }

    Scaffold(
        modifier = Modifier.testTag("settings.screen"),
        containerColor = MaterialTheme.colorScheme.background,
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = strings.settings,
                        modifier = Modifier.semantics { heading() },
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

                    if (onRequestDailyVerseWidgetPin != null) {
                        DailyVerseWidgetSettingsSection(
                            installed = dailyVerseWidgetInstalled,
                            pinRequestSupported = dailyVerseWidgetPinSupported,
                            strings = strings,
                            onRequestPin = onRequestDailyVerseWidgetPin,
                            onShowGuide = { showWidgetGuide = true },
                            modifier = Modifier.padding(top = 28.dp),
                        )
                    }

                    SettingsHeading(
                        text = strings.dailyPractice,
                        modifier = Modifier.padding(top = 28.dp),
                    )
                    DailyReminderSetting(
                        reminder = preferences.reminder,
                        strings = strings,
                        onSetReminder = onSetReminder,
                        onSetEnabled = ::setReminderEnabled,
                    )
                }
            }
        }
    }
}

@Composable
internal fun DailyVerseWidgetSettingsSection(
    installed: Boolean,
    pinRequestSupported: Boolean,
    strings: AppStrings,
    onRequestPin: () -> Boolean,
    onShowGuide: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier) {
        SettingsHeading(text = strings.desktopWidget)
        DailyVerseWidgetSetting(
            installed = installed,
            pinRequestSupported = pinRequestSupported,
            strings = strings,
            onRequestPin = onRequestPin,
            onShowGuide = onShowGuide,
        )
    }
}

@Composable
internal fun DailyVerseWidgetSetting(
    installed: Boolean,
    pinRequestSupported: Boolean,
    strings: AppStrings,
    onRequestPin: () -> Boolean,
    onShowGuide: () -> Unit,
) {
    val status = when {
        installed -> strings.widgetAdded
        pinRequestSupported -> strings.widgetAdd
        else -> strings.widgetOpenGuide
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 56.dp)
            .testTag("settings.widget")
            .clickable(
                role = Role.Button,
                onClick = {
                    val requested = pinRequestSupported && onRequestPin()
                    if (!requested) onShowGuide()
                },
            )
            .padding(horizontal = 4.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(end = 16.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Text(
                text = strings.todayReadingWidget,
                style = MaterialTheme.typography.bodyLarge.copy(letterSpacing = 0.sp),
            )
            Text(
                text = status,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                style = MaterialTheme.typography.bodyMedium.copy(letterSpacing = 0.sp),
            )
        }
        Icon(
            imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
internal fun WidgetInstallationGuideDialog(
    productTitle: String,
    strings: AppStrings,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        modifier = Modifier.testTag("settings.widget.guide"),
        title = {
            Text(
                text = strings.widgetGuideTitle(strings.todayReadingWidget),
                style = MaterialTheme.typography.titleLarge.copy(letterSpacing = 0.sp),
            )
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                strings.widgetGuideSteps(productTitle).forEachIndexed { index, step ->
                    Text(
                        text = "${index + 1}. $step",
                        style = MaterialTheme.typography.bodyLarge.copy(letterSpacing = 0.sp),
                    )
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text(strings.widgetGuideDone)
            }
        },
    )
}

@Composable
private fun DailyReminderSetting(
    reminder: ReminderPreferences,
    strings: AppStrings,
    onSetReminder: (ReminderPreferences) -> Unit,
    onSetEnabled: (Boolean) -> Unit,
) {
    val context = LocalContext.current
    val time = remember(reminder.hour, reminder.minute) {
        String.format(Locale.ROOT, "%02d:%02d", reminder.hour, reminder.minute)
    }

    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 56.dp)
                .testTag("settings.reminder.enabled")
                .toggleable(
                    value = reminder.enabled,
                    role = Role.Switch,
                    onValueChange = onSetEnabled,
                )
                .semantics {
                    stateDescription = if (reminder.enabled) {
                        strings.enabledState
                    } else {
                        strings.disabledState
                    }
                }
                .padding(horizontal = 4.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(end = 16.dp),
                verticalArrangement = Arrangement.spacedBy(2.dp),
            ) {
                Text(
                    text = strings.dailyReminder,
                    style = MaterialTheme.typography.bodyLarge.copy(letterSpacing = 0.sp),
                )
                Text(
                    text = strings.reminderSchedule(time),
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    style = MaterialTheme.typography.bodyMedium.copy(letterSpacing = 0.sp),
                )
            }
            Switch(
                checked = reminder.enabled,
                onCheckedChange = null,
            )
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 56.dp)
                .testTag("settings.reminder.time")
                .clickable(
                    role = Role.Button,
                    onClick = {
                        TimePickerDialog(
                            context,
                            { _, hour, minute ->
                                onSetReminder(
                                    reminder.copy(hour = hour, minute = minute),
                                )
                            },
                            reminder.hour,
                            reminder.minute,
                            true,
                        ).show()
                    },
                )
                .padding(horizontal = 4.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = strings.reminderTime,
                modifier = Modifier.weight(1f),
                style = MaterialTheme.typography.bodyLarge.copy(letterSpacing = 0.sp),
            )
            Text(
                text = time,
                color = MaterialTheme.colorScheme.primary,
                style = MaterialTheme.typography.bodyLarge.copy(letterSpacing = 0.sp),
            )
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
        modifier = modifier
            .semantics { heading() }
            .padding(bottom = 6.dp),
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
            modifier = Modifier
                .testTag("settings.font-size.slider")
                .semantics {
                    contentDescription = strings.fontSize
                    stateDescription = strings.fontSizeState(sliderValue.roundToInt())
                },
            valueRange = 0f..4f,
            steps = 3,
        )
    }
}
