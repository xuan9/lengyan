package org.fuxuan.lengyan

import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import org.fuxuan.classics.widget.DailyVerseAppWidget

class LengyanDailyVerseWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = DailyVerseAppWidget()
}
