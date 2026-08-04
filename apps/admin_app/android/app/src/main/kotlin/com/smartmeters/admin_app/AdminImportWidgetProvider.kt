package com.smartmeters.admin_app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class AdminImportWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_secondary).apply {
                setTextViewText(R.id.widget_label, "الاستيراد")
                setTextViewText(
                    R.id.widget_title,
                    widgetData.getString("import_status", "idle") ?: "idle",
                )
                setTextViewText(
                    R.id.widget_subtitle,
                    widgetData.getString("import_hint", "لا دفعات حديثة")
                        ?: "لا دفعات حديثة",
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
