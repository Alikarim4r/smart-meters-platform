package com.smartmeters.dashboard_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class DashboardAlertsWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_primary).apply {
                setTextViewText(R.id.widget_label, "تنبيهات")
                setTextViewText(
                    R.id.widget_value,
                    widgetData.getString("unread_count", "0") ?: "0",
                )
                setTextViewText(
                    R.id.widget_title,
                    widgetData.getString("top_title", "لا تنبيهات") ?: "لا تنبيهات",
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
