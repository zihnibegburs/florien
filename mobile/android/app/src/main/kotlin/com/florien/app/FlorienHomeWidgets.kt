package com.florien.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

internal fun widgetChrome(
    widgetData: SharedPreferences,
    key: String,
    fallback: String,
): String {
    val value = widgetData.getString(key, null)
    return if (value.isNullOrEmpty()) fallback else value
}

internal fun widgetChromeCount(
    widgetData: SharedPreferences,
    key: String,
    fallback: String,
    count: Int,
): String = widgetChrome(widgetData, key, fallback).replace("{count}", count.toString())

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
                setTextViewText(
                    R.id.focus_15_brand,
                    widgetChrome(widgetData, "chrome_focus_brand", context.getString(R.string.widget_focus_brand)),
                )
                setTextViewText(
                    R.id.focus_15_ready,
                    widgetChrome(widgetData, "chrome_focus_ready", context.getString(R.string.widget_focus_ready)),
                )
                setTextViewText(
                    R.id.focus_15_start,
                    widgetChrome(widgetData, "chrome_start", context.getString(R.string.widget_start)),
                )
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
                setTextViewText(
                    R.id.focus_presets_title,
                    widgetChrome(widgetData, "chrome_focus_how_long", context.getString(R.string.widget_focus_how_long)),
                )
                setTextViewText(R.id.focus_5, widgetChrome(widgetData, "chrome_min_5", context.getString(R.string.widget_min_5)))
                setTextViewText(R.id.focus_10, widgetChrome(widgetData, "chrome_min_10", context.getString(R.string.widget_min_10)))
                setTextViewText(R.id.focus_15, widgetChrome(widgetData, "chrome_min_15", context.getString(R.string.widget_min_15)))
                setTextViewText(R.id.focus_30, widgetChrome(widgetData, "chrome_min_30", context.getString(R.string.widget_min_30)))
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
                setTextViewText(
                    R.id.quick_add_prompt,
                    widgetChrome(widgetData, "chrome_quick_prompt", context.getString(R.string.widget_quick_prompt)),
                )
                setTextViewText(
                    R.id.quick_add_action,
                    widgetChrome(widgetData, "chrome_quick_cta", context.getString(R.string.widget_quick_cta)),
                )
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
                setTextViewText(
                    R.id.widget_ai_action,
                    widgetChrome(widgetData, "chrome_ai_prompt_star", context.getString(R.string.widget_ai_prompt)),
                )
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
