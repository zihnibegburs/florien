import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class TaskAlarmService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    tz_data.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _notifications.initialize(settings);
    _initialized = true;
  }

  Future<bool> schedule({
    required String taskId,
    required String title,
    required DateTime alarmAt,
  }) async {
    if (alarmAt.toUtc().isBefore(DateTime.now().toUtc())) return false;
    await initialize();
    if (kIsWeb) return false;
    final permitted = await _requestPermission();
    if (!permitted) return false;

    final scheduled = tz.TZDateTime.from(alarmAt.toUtc(), tz.UTC);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'task_alarms',
        'Görev alarmları',
        channelDescription: 'Planlanan görev saatleri için hatırlatmalar',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );
    try {
      await _notifications.zonedSchedule(
        _notificationId(taskId),
        title,
        'Görev saatiniz geldi.',
        scheduled,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: taskId,
      );
    } catch (_) {
      await _notifications.zonedSchedule(
        _notificationId(taskId),
        title,
        'Görev saatiniz geldi.',
        scheduled,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: taskId,
      );
    }
    return true;
  }

  Future<void> cancel(String taskId) async {
    await initialize();
    if (kIsWeb) return;
    await _notifications.cancel(_notificationId(taskId));
  }

  Future<bool> _requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return await _notifications
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final notificationsAllowed =
          await android?.requestNotificationsPermission() ?? true;
      if (!notificationsAllowed) return false;
      await android?.requestExactAlarmsPermission();
    }
    return true;
  }

  int _notificationId(String taskId) {
    var hash = 17;
    for (final codeUnit in taskId.codeUnits) {
      hash = 37 * hash + codeUnit;
    }
    return hash & 0x7fffffff;
  }
}
