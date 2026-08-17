import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:florien/core/storage/settings_storage.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class TaskAlarmService {
  TaskAlarmService(this._settingsStorage);

  static const _focusTimerAlarmId = 'focus_timer_alarm';

  final SettingsStorage _settingsStorage;
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
    final preferences = await getPreferences();
    if (!preferences.taskRemindersEnabled) return false;
    await initialize();
    if (kIsWeb) return false;
    final permitted = await _requestPermission();
    if (!permitted) return false;

    final scheduled = tz.TZDateTime.from(alarmAt.toUtc(), tz.UTC);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'task_alarms',
        'Görev alarmları',
        channelDescription: 'Planlanan görev saatleri için hatırlatmalar',
        importance: Importance.high,
        priority: Priority.high,
        playSound: preferences.soundEnabled,
        enableVibration: preferences.vibrationEnabled,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentSound: preferences.soundEnabled,
      ),
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

  Future<bool> scheduleFocusTimerAlarm({
    required String title,
    required DateTime alarmAt,
  }) async {
    if (alarmAt.toUtc().isBefore(DateTime.now().toUtc())) return false;
    await initialize();
    if (kIsWeb || !await _requestPermission()) return false;

    final preferences = await getPreferences();
    final details = _focusTimerNotificationDetails(preferences);
    final scheduled = tz.TZDateTime.from(alarmAt.toUtc(), tz.UTC);
    try {
      await _notifications.zonedSchedule(
        _notificationId(_focusTimerAlarmId),
        title,
        'Odak turun tamamlandı.',
        scheduled,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: _focusTimerAlarmId,
      );
    } catch (_) {
      await _notifications.zonedSchedule(
        _notificationId(_focusTimerAlarmId),
        title,
        'Odak turun tamamlandı.',
        scheduled,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: _focusTimerAlarmId,
      );
    }
    return true;
  }

  Future<void> completeFocusTimerAlarm({required String title}) async {
    await initialize();
    if (kIsWeb) return;

    final preferences = await getPreferences();
    await _notifications.cancel(_notificationId(_focusTimerAlarmId));
    await _notifications.show(
      _notificationId(_focusTimerAlarmId),
      title,
      'Odak turun tamamlandı.',
      _focusTimerNotificationDetails(preferences),
      payload: _focusTimerAlarmId,
    );
  }

  Future<void> cancelFocusTimerAlarm() => cancel(_focusTimerAlarmId);

  Future<NotificationPreferences> getPreferences() =>
      _settingsStorage.getNotificationPreferences();

  Future<bool> setTaskRemindersEnabled(bool enabled) async {
    if (!enabled) {
      await _settingsStorage.setTaskRemindersEnabled(false);
      await cancelAll();
      return false;
    }

    await initialize();
    if (kIsWeb || !await _requestPermission()) return false;
    await _settingsStorage.setTaskRemindersEnabled(true);
    return true;
  }

  Future<void> setSoundEnabled(bool enabled) =>
      _settingsStorage.setNotificationSoundEnabled(enabled);

  Future<void> setVibrationEnabled(bool enabled) =>
      _settingsStorage.setNotificationVibrationEnabled(enabled);

  Future<void> cancelAll() async {
    await initialize();
    if (kIsWeb) return;
    await _notifications.cancelAll();
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

  NotificationDetails _focusTimerNotificationDetails(
    NotificationPreferences preferences,
  ) => NotificationDetails(
    android: AndroidNotificationDetails(
      'focus_timer_alarm',
      'Odak zamanlayıcısı',
      channelDescription: 'Odak süresi tamamlandığında çalan alarm',
      importance: Importance.max,
      priority: Priority.max,
      playSound: preferences.soundEnabled,
      enableVibration: preferences.vibrationEnabled,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentSound: preferences.soundEnabled,
    ),
  );

  int _notificationId(String taskId) {
    var hash = 17;
    for (final codeUnit in taskId.codeUnits) {
      hash = 37 * hash + codeUnit;
    }
    return hash & 0x7fffffff;
  }
}
