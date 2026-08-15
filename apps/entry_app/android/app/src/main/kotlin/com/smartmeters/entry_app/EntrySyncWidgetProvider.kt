package com.smartmeters.entry_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class EntrySyncWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_secondary).apply {
                setTextViewText(R.id.widget_label, "المزامنة")
                val pending = widgetData.getString("offline_pending", "0") ?: "0"
                setTextViewText(R.id.widget_title, "طابور Offline: $pending")
                setTextViewText(
                    R.id.widget_subtitle,
                    widgetData.getString("last_sync", "لم تتم مزامنة بعد")
                        ?: "لم تتم مزامنة بعد",
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
