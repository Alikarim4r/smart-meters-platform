package com.smartmeters.dashboard_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class DashboardSiteWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_secondary).apply {
                setTextViewText(R.id.widget_label, "الموقع")
                setTextViewText(
                    R.id.widget_title,
                    widgetData.getString("site_name", "—") ?: "—",
                )
                setTextViewText(
                    R.id.widget_subtitle,
                    widgetData.getString("site_summary", "—") ?: "—",
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
