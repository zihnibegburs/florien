package com.florien.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

private fun widgetLaunchIntent(
    context: Context,
    path: String,
    minutes: Int? = null,
) = HomeWidgetLaunchIntent.getActivity(
    context,
    MainActivity::class.java,
    Uri.Builder()
        .scheme("florien")
        .authority("widget")
        .path(path)
        .appendQueryParameter("homeWidget", "1")
        .apply { minutes?.let { appendQueryParameter("minutes", it.toString()) } }
        .build(),
)

class Focus15WidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.florien_focus_15_widget).apply {
                setOnClickPendingIntent(
                    R.id.focus_15_start,
                    widgetLaunchIntent(context, "focus", 15),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class FocusPresetsWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.florien_focus_presets_widget).apply {
                setOnClickPendingIntent(R.id.focus_5, widgetLaunchIntent(context, "focus", 5))
                setOnClickPendingIntent(R.id.focus_10, widgetLaunchIntent(context, "focus", 10))
                setOnClickPendingIntent(R.id.focus_15, widgetLaunchIntent(context, "focus", 15))
                setOnClickPendingIntent(R.id.focus_30, widgetLaunchIntent(context, "focus", 30))
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class QuickAddWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.florien_quick_add_widget).apply {
                setOnClickPendingIntent(
                    R.id.quick_add_action,
                    widgetLaunchIntent(context, "todo/add"),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class QuickActionsWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.florien_quick_actions_widget).apply {
                setOnClickPendingIntent(R.id.widget_ai_action, widgetLaunchIntent(context, "ai"))
                setOnClickPendingIntent(R.id.widget_daily_action, widgetLaunchIntent(context, "today"))
                setOnClickPendingIntent(R.id.widget_todo_add_action, widgetLaunchIntent(context, "todo/add"))
                setOnClickPendingIntent(R.id.widget_daily_add_action, widgetLaunchIntent(context, "daily/add"))
                setOnClickPendingIntent(R.id.widget_focus_action, widgetLaunchIntent(context, "focus/screen"))
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
