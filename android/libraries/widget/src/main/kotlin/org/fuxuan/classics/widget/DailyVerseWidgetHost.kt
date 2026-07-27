package org.fuxuan.classics.widget

import android.content.ComponentName
import org.fuxuan.classics.core.AppContainer

interface DailyVerseWidgetHost {
    val dailyVerseWidgetContainer: AppContainer
    val dailyVerseWidgetLaunchComponent: ComponentName
}

const val DAILY_VERSE_PARAGRAPH_ID_EXTRA =
    "org.fuxuan.classics.extra.DAILY_VERSE_PARAGRAPH_ID"
