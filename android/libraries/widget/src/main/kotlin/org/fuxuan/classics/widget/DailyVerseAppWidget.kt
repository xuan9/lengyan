package org.fuxuan.classics.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalSize
import androidx.glance.action.Action
import androidx.glance.action.ActionParameters
import androidx.glance.action.actionStartActivity
import androidx.glance.action.actionParametersOf
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.background
import androidx.glance.color.ColorProvider as DayNightColorProvider
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.semantics.contentDescription
import androidx.glance.semantics.semantics
import androidx.glance.semantics.testTag
import androidx.glance.text.FontFamily
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.fuxuan.classics.core.persistence.ThemePreference
import java.util.Locale

class DailyVerseAppWidget : GlanceAppWidget(
    errorUiLayout = R.layout.daily_verse_widget_error,
) {
    override val sizeMode: SizeMode = SizeMode.Responsive(
        setOf(
            DpSize(180.dp, 110.dp),
            DpSize(180.dp, 220.dp),
            DpSize(320.dp, 160.dp),
            DpSize(320.dp, 320.dp),
        ),
    )

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val host = context.applicationContext as? DailyVerseWidgetHost
        val content = host?.let { loadContent(context, it) } ?: unavailableContent(context)
        val launchAction = host?.let { widgetHost ->
            val parameters = content.paragraphID?.let { paragraphID ->
                actionParametersOf(PARAGRAPH_ID_ACTION_KEY to paragraphID)
            } ?: actionParametersOf()
            actionStartActivity(
                widgetHost.dailyVerseWidgetLaunchComponent,
                parameters,
            )
        }

        provideContent {
            val size = LocalSize.current
            DailyVerseWidgetView(
                content = content,
                layout = DailyVerseWidgetLayout.forSize(
                    widthDp = size.width.value,
                    heightDp = size.height.value,
                ),
                launchAction = launchAction,
            )
        }
    }

    private suspend fun loadContent(
        context: Context,
        host: DailyVerseWidgetHost,
    ): DailyVerseWidgetContent = withContext(Dispatchers.IO) {
        val stateStore = DailyVerseWidgetStateStore(context)
        try {
            DailyVerseWidgetDataLoader().load(
                container = host.dailyVerseWidgetContainer,
                stateStore = stateStore,
            )
        } catch (exception: CancellationException) {
            throw exception
        } catch (_: Exception) {
            try {
                stateStore.lastSnapshot()
            } catch (exception: CancellationException) {
                throw exception
            } catch (_: Exception) {
                null
            } ?: unavailableContent(context)
        }
    }

    private fun unavailableContent(context: Context): DailyVerseWidgetContent {
        val locale = context.resources.configuration.locales[0] ?: Locale.getDefault()
        val simplified = locale.script.equals("Hans", ignoreCase = true) ||
            locale.country in setOf("CN", "SG")
        return DailyVerseWidgetContent(
            productTitle = if (simplified) "经典阅读" else "經典閱讀",
            header = if (simplified) "今日读经" else "今日讀經",
            text = if (simplified) "打开 App 后即可显示今日经文。" else "開啟 App 後即可顯示今日經文。",
            source = "",
            paragraphID = null,
            theme = ThemePreference.SYSTEM,
            tapHint = "",
        )
    }
}

object DailyVerseWidgetUpdater {
    suspend fun updateAll(context: Context) {
        DailyVerseAppWidget().updateAll(context.applicationContext)
    }
}

@Composable
fun DailyVerseWidgetView(
    content: DailyVerseWidgetContent,
    layout: DailyVerseWidgetLayout,
    launchAction: Action?,
) {
    val colors = DailyVerseWidgetColors.forTheme(content.theme)
    val displayText = DailyVerseWidgetTextPolicy.displayText(content.text, layout.textLimit)
    var rootModifier = GlanceModifier
        .fillMaxSize()
        .background(colors.background)
        .padding(horizontal = 16.dp, vertical = 13.dp)
        .semantics {
            testTag = "daily-verse.root"
            contentDescription = content.accessibilityDescription(displayText)
        }
    if (launchAction != null) {
        rootModifier = rootModifier.clickable(launchAction)
    }

    Column(modifier = rootModifier) {
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            verticalAlignment = Alignment.Vertical.CenterVertically,
        ) {
            Text(
                text = content.header,
                modifier = GlanceModifier.semantics { testTag = "daily-verse.header" },
                style = TextStyle(
                    color = colors.accent,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                ),
                maxLines = 1,
            )
            Spacer(modifier = GlanceModifier.defaultWeight())
            Text(
                text = content.productTitle,
                style = TextStyle(
                    color = colors.secondaryText,
                    fontSize = 11.sp,
                ),
                maxLines = 1,
            )
        }

        Spacer(modifier = GlanceModifier.height(if (layout == DailyVerseWidgetLayout.COMPACT) 7.dp else 10.dp))

        Text(
            text = displayText,
            modifier = GlanceModifier
                .defaultWeight()
                .fillMaxWidth()
                .semantics { testTag = "daily-verse.text" },
            style = TextStyle(
                color = colors.primaryText,
                fontSize = layout.bodyFontSize.sp,
                fontWeight = FontWeight.Normal,
                textAlign = TextAlign.Start,
                fontFamily = FontFamily.Serif,
            ),
            maxLines = layout.maxLines,
        )

        if (content.source.isNotBlank()) {
            Spacer(modifier = GlanceModifier.height(7.dp))
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.Vertical.CenterVertically,
            ) {
                Box(
                    modifier = GlanceModifier
                        .width(24.dp)
                        .height(1.dp)
                        .background(colors.divider),
                ) {}
                Spacer(modifier = GlanceModifier.width(8.dp))
                Text(
                    text = content.source,
                    modifier = GlanceModifier
                        .defaultWeight()
                        .semantics { testTag = "daily-verse.source" },
                    style = TextStyle(
                        color = colors.secondaryText,
                        fontSize = 11.sp,
                    ),
                    maxLines = 1,
                )
                if (layout == DailyVerseWidgetLayout.EXPANDED && content.tapHint.isNotBlank()) {
                    Spacer(modifier = GlanceModifier.width(8.dp))
                    Text(
                        text = content.tapHint,
                        style = TextStyle(
                            color = colors.accent,
                            fontSize = 11.sp,
                            fontWeight = FontWeight.Medium,
                        ),
                        maxLines = 1,
                    )
                }
            }
        }
    }
}

private data class DailyVerseWidgetColors(
    val background: ColorProvider,
    val primaryText: ColorProvider,
    val secondaryText: ColorProvider,
    val accent: ColorProvider,
    val divider: ColorProvider,
) {
    companion object {
        fun forTheme(theme: ThemePreference): DailyVerseWidgetColors = when (theme) {
            ThemePreference.LIGHT -> light()
            ThemePreference.DARK -> dark()
            ThemePreference.SYSTEM -> system()
        }

        private fun light() = DailyVerseWidgetColors(
            background = ColorProvider(LIGHT_BACKGROUND),
            primaryText = ColorProvider(LIGHT_TEXT),
            secondaryText = ColorProvider(LIGHT_SECONDARY_TEXT),
            accent = ColorProvider(LIGHT_ACCENT),
            divider = ColorProvider(LIGHT_DIVIDER),
        )

        private fun dark() = DailyVerseWidgetColors(
            background = ColorProvider(DARK_BACKGROUND),
            primaryText = ColorProvider(DARK_TEXT),
            secondaryText = ColorProvider(DARK_SECONDARY_TEXT),
            accent = ColorProvider(DARK_ACCENT),
            divider = ColorProvider(DARK_DIVIDER),
        )

        private fun system() = DailyVerseWidgetColors(
            background = DayNightColorProvider(LIGHT_BACKGROUND, DARK_BACKGROUND),
            primaryText = DayNightColorProvider(LIGHT_TEXT, DARK_TEXT),
            secondaryText = DayNightColorProvider(LIGHT_SECONDARY_TEXT, DARK_SECONDARY_TEXT),
            accent = DayNightColorProvider(LIGHT_ACCENT, DARK_ACCENT),
            divider = DayNightColorProvider(LIGHT_DIVIDER, DARK_DIVIDER),
        )

        private val LIGHT_BACKGROUND = Color(0xFFF4EFE3)
        private val LIGHT_TEXT = Color(0xFF292B27)
        private val LIGHT_SECONDARY_TEXT = Color(0xFF6C6B63)
        private val LIGHT_ACCENT = Color(0xFF4E7352)
        private val LIGHT_DIVIDER = Color(0xFFB2A98F)
        private val DARK_BACKGROUND = Color(0xFF1D201D)
        private val DARK_TEXT = Color(0xFFF1EDE3)
        private val DARK_SECONDARY_TEXT = Color(0xFFB7B6AD)
        private val DARK_ACCENT = Color(0xFF9BB58F)
        private val DARK_DIVIDER = Color(0xFF6F7468)
    }
}

private val PARAGRAPH_ID_ACTION_KEY =
    ActionParameters.Key<String>(DAILY_VERSE_PARAGRAPH_ID_EXTRA)
