import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class TaskReminderSettings {
  const TaskReminderSettings({
    this.remind10Min = false,
    this.remind5Min = false,
    this.remind1Min = false,
    this.transitionEnd = false,
  });

  final bool remind10Min;
  final bool remind5Min;
  final bool remind1Min;
  final bool transitionEnd;

  bool get hasAny => remind10Min || remind5Min || remind1Min || transitionEnd;
}

class NotificationService {
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static int _id10(String taskId) => '${taskId}_10'.hashCode.abs() % 100000;
  static int _id5(String taskId) => '${taskId}_5'.hashCode.abs() % 100000;
  static int _id1(String taskId) => '${taskId}_1'.hashCode.abs() % 100000;
  static int _idEnd(String taskId) => '${taskId}_end'.hashCode.abs() % 100000;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await initialize();
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    return true;
  }

  Future<void> scheduleTaskReminders(
    TaskModel task, {
    required TaskReminderSettings settings,
    required String titlePrefix,
    required String body10,
    required String body5,
    required String body1,
    required String bodyTransition,
    required String bodyEnd,
    bool scheduleTransition = true,
  }) async {
    if (kIsWeb || task.scheduledAt == null) return;
    await initialize();
    await cancelTaskReminders(task.id);

    final scheduled = task.scheduledAt!.toLocal();
    final now = DateTime.now();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'task_reminders',
        titlePrefix,
        channelDescription: titlePrefix,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    Future<void> scheduleAt(int id, String body, DateTime at) async {
      if (at.isAfter(now)) {
        await _plugin.zonedSchedule(
          id,
          titlePrefix,
          body.replaceAll('{title}', task.title),
          tz.TZDateTime.from(at, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }

    if (settings.remind10Min) {
      await scheduleAt(_id10(task.id), body10, scheduled.subtract(const Duration(minutes: 10)));
    }
    if (settings.remind5Min) {
      await scheduleAt(_id5(task.id), body5, scheduled.subtract(const Duration(minutes: 5)));
    }
    if (settings.remind1Min) {
      await scheduleAt(_id1(task.id), body1, scheduled.subtract(const Duration(minutes: 1)));
    }
    if (scheduleTransition && settings.transitionEnd) {
      final end = task.taskEndTime.toLocal();
      await scheduleAt(_idEnd(task.id), bodyEnd, end);
    }

    await _saveReminderSettings(task.id, settings);
  }

  Future<void> cancelTaskReminders(String taskId) async {
    if (kIsWeb) return;
    await initialize();
    await _plugin.cancel(_id10(taskId));
    await _plugin.cancel(_id5(taskId));
    await _plugin.cancel(_id1(taskId));
    await _plugin.cancel(_idEnd(taskId));
    await _clearReminderSettings(taskId);
  }

  Future<TaskReminderSettings> loadReminderSettings(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('task_reminder_$taskId');
    if (raw == null) return const TaskReminderSettings();
    final parts = raw.split(',');
    return TaskReminderSettings(
      remind10Min: parts.isNotEmpty && parts[0] == '1',
      remind5Min: parts.length > 2 && parts[2] == '1',
      remind1Min: parts.length > 1 && parts[1] == '1',
      transitionEnd: parts.length > 3 && parts[3] == '1',
    );
  }

  Future<void> _saveReminderSettings(String taskId, TaskReminderSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'task_reminder_$taskId',
      '${settings.remind10Min ? 1 : 0},${settings.remind1Min ? 1 : 0},${settings.remind5Min ? 1 : 0},${settings.transitionEnd ? 1 : 0}',
    );
  }

  Future<void> _clearReminderSettings(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('task_reminder_$taskId');
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(FlutterLocalNotificationsPlugin());
});
