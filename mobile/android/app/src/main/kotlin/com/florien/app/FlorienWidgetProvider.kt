package com.florien.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
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
                val taskCount = widgetData.getInt("daily_pending_count", 0)
                val dateLabel = widgetData.getString("date_label", "")
                val showCompletionControls = appWidgetManager
                    .getAppWidgetOptions(widgetId)
                    .getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0) > 150

                setTextViewText(
                    R.id.widget_header,
                    widgetChrome(widgetData, "chrome_daily_title", context.getString(R.string.widget_daily_plan)),
                )
                val openShort = widgetChromeCount(
                    widgetData,
                    "chrome_open_short",
                    context.getString(R.string.widget_open_short),
                    taskCount,
                )
                setTextViewText(
                    R.id.widget_meta,
                    if (dateLabel.isNullOrEmpty()) openShort else "$openShort · $dateLabel",
                )
                bindTask(this, context, widgetData, "daily_task", "daily", 1, R.id.widget_task_one, R.id.widget_complete_one, showCompletionControls)
                bindTask(this, context, widgetData, "daily_task", "daily", 2, R.id.widget_task_two, R.id.widget_complete_two, showCompletionControls)
                bindTask(this, context, widgetData, "daily_task", "daily", 3, R.id.widget_task_three, R.id.widget_complete_three, showCompletionControls)

                val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("florien://widget/today?homeWidget=1"),
                )
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
                setOnClickPendingIntent(
                    R.id.widget_add_daily,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("florien://widget/daily/add?homeWidget=1"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun bindTask(
        views: RemoteViews,
        context: Context,
        widgetData: SharedPreferences,
        prefix: String,
        source: String,
        index: Int,
        viewId: Int,
        completeViewId: Int,
        showCompletionControls: Boolean,
    ) {
        val title = widgetData.getString("${prefix}_$index", "").orEmpty()
        val icon = widgetData.getString("${prefix}_${index}_icon", "task").orEmpty()
        val taskId = widgetData.getString("${prefix}_${index}_id", "").orEmpty()
        views.setTextViewText(viewId, if (title.isEmpty()) "" else "${taskIcon(icon)}  $title")
        views.setViewVisibility(viewId, if (title.isEmpty()) View.GONE else View.VISIBLE)
        views.setViewVisibility(
            completeViewId,
            if (title.isEmpty() || !showCompletionControls) View.GONE else View.VISIBLE,
        )
        if (taskId.isNotEmpty()) {
            views.setOnClickPendingIntent(completeViewId, taskCompletionIntent(context, taskId, source))
        }
    }
}

class TodoWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.florien_todo_widget).apply {
                val taskCount = widgetData.getInt("todo_pending_count", 0)
                val showCompletionControls = appWidgetManager
                    .getAppWidgetOptions(widgetId)
                    .getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0) > 150
                setTextViewText(
                    R.id.widget_header,
                    widgetChrome(widgetData, "chrome_todo_title", "To-do"),
                )
                setTextViewText(
                    R.id.widget_meta,
                    widgetChromeCount(
                        widgetData,
                        "chrome_open_tasks",
                        context.getString(R.string.widget_open_tasks_count),
                        taskCount,
                    ),
                )
                bindTask(this, context, widgetData, "todo_task", "todo", 1, R.id.widget_task_one, R.id.widget_complete_one, showCompletionControls)
                bindTask(this, context, widgetData, "todo_task", "todo", 2, R.id.widget_task_two, R.id.widget_complete_two, showCompletionControls)
                bindTask(this, context, widgetData, "todo_task", "todo", 3, R.id.widget_task_three, R.id.widget_complete_three, showCompletionControls)
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("florien://widget/todo?homeWidget=1"),
                    ),
                )
                setOnClickPendingIntent(
                    R.id.widget_add_todo,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("florien://widget/todo/add?homeWidget=1"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun bindTask(
        views: RemoteViews,
        context: Context,
        widgetData: SharedPreferences,
        prefix: String,
        source: String,
        index: Int,
        viewId: Int,
        completeViewId: Int,
        showCompletionControls: Boolean,
    ) {
        val title = widgetData.getString("${prefix}_$index", "").orEmpty()
        val icon = widgetData.getString("${prefix}_${index}_icon", "task").orEmpty()
        val taskId = widgetData.getString("${prefix}_${index}_id", "").orEmpty()
        views.setTextViewText(viewId, if (title.isEmpty()) "" else "${taskIcon(icon)}  $title")
        views.setViewVisibility(viewId, if (title.isEmpty()) View.GONE else View.VISIBLE)
        views.setViewVisibility(
            completeViewId,
            if (title.isEmpty() || !showCompletionControls) View.GONE else View.VISIBLE,
        )
        if (taskId.isNotEmpty()) {
            views.setOnClickPendingIntent(completeViewId, taskCompletionIntent(context, taskId, source))
        }
    }
}

private fun taskCompletionIntent(context: Context, taskId: String, source: String) =
    HomeWidgetBackgroundIntent.getBroadcast(
        context,
        Uri.Builder()
            .scheme("florien")
            .authority("widget")
            .path("task/complete")
            .appendQueryParameter("taskId", taskId)
            .appendQueryParameter("source", source)
            .appendQueryParameter("homeWidget", "1")
            .build(),
    )

private fun taskIcon(icon: String): String = when (icon) {
    "meeting", "groups" -> "👥"
    "email" -> "✉"
    "phone_call" -> "☎"
    "study", "school", "menu_book", "reading" -> "📖"
    "shopping", "groceries", "shopping_bag" -> "🛍"
    "breakfast", "lunch", "dinner", "restaurant", "cooking" -> "🍽"
    "running", "directions_run" -> "🏃"
    "walking", "directions_walk" -> "🚶"
    "gym", "fitness", "workout" -> "🏋"
    "cleaning" -> "✨"
    "meditation", "self_improvement" -> "🧘"
    "work", "project", "presentation" -> "💼"
    "appointment", "doctor", "health" -> "✚"
    "timer" -> "⏱"
    else -> "✓"
}
