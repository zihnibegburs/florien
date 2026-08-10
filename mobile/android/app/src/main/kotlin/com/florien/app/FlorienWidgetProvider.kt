package com.florien.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class FlorienWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.florien_widget).apply {
                val activeTitle = widgetData.getString("active_task_title", null)
                val nextTitle = widgetData.getString("next_task_title", null)
                val title = activeTitle ?: nextTitle ?: "Bugün plan yok"
                val subtitle = widgetData.getString("widget_subtitle", "Günlük planlayıcın")
                val taskCount = widgetData.getInt("task_count", 0)
                val dateLabel = widgetData.getString("date_label", "")

                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_subtitle, subtitle)
                setTextViewText(R.id.widget_meta, "$taskCount görev · $dateLabel")

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
