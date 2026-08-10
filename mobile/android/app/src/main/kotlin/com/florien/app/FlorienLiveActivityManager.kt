package com.florien.app

import android.app.Notification
import android.appwidget.AppWidgetManager
import android.content.Context
import android.widget.RemoteViews
import com.example.live_activities.LiveActivityManager

class FlorienLiveActivityManager(context: Context) : LiveActivityManager(context) {
    override suspend fun buildNotification(
        notification: Notification.Builder,
        event: String,
        data: Map<String, Any>,
    ): Notification {
        val remoteViews = RemoteViews(context.packageName, R.layout.live_activity).apply {
            setTextViewText(
                R.id.live_activity_title,
                data["taskTitle"]?.toString() ?: "Florien",
            )
            setTextViewText(
                R.id.live_activity_remaining,
                data["remaining"]?.toString() ?: "--:--",
            )
        }

        return notification
            .setCustomContentView(remoteViews)
            .setCustomBigContentView(remoteViews)
            .setStyle(Notification.DecoratedCustomViewStyle())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }
}
