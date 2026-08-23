package com.florien.app

import android.content.Intent
import android.os.Build
import android.provider.Settings
import com.example.live_activities.LiveActivityManagerHolder
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        LiveActivityManagerHolder.instance = FlorienLiveActivityManager(this)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "florien/notification_settings",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "authorizationStatus" -> result.success(
                    if (areNotificationsEnabled()) "authorized" else "denied",
                )
                "openNotificationSettings" -> {
                    startActivity(notificationSettingsIntent())
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun areNotificationsEnabled(): Boolean {
        val manager = getSystemService(NOTIFICATION_SERVICE) as android.app.NotificationManager
        return manager.areNotificationsEnabled()
    }

    private fun notificationSettingsIntent(): Intent {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = android.net.Uri.fromParts("package", packageName, null)
            }
        }
    }
}
