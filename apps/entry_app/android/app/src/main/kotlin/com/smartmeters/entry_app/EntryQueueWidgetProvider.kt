package com.smartmeters.entry_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class EntryQueueWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_primary).apply {
                setTextViewText(R.id.widget_label, "معلّق اليوم")
                setTextViewText(
                    R.id.widget_value,
                    widgetData.getString("pending_meters", "0") ?: "0",
                )
                setTextViewText(
                    R.id.widget_title,
                    widgetData.getString("queue_hint", "افتح التطبيق للتحديث")
                        ?: "افتح التطبيق للتحديث",
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
