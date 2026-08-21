import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/services/notification_copy.dart';
import 'package:florien/core/services/notification_payload.dart';
import 'package:florien/core/storage/settings_storage.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

enum TaskAlarmReadiness {
  ready,
  past,
  remindersDisabled,
  permissionDenied,
  unsupported,
}

typedef NotificationResponseHandler =
    Future<void> Function(FlorienNotificationPayload payload);

typedef NotificationActionHandler =
    Future<void> Function(
      FlorienNotificationPayload payload,
      String actionId,
    );

class TaskAlarmService {
  TaskAlarmService(this._settingsStorage);

  static const _focusTimerAlarmId = 'focus_timer_alarm';
  static const _taskCategoryId = 'florien_task_reminder';
  static const _completeActionId = 'complete';

  /// iOS pending notification soft limit (~64). Keep headroom for general kinds.
  static const _maxPendingNotifications = 60;
  static const _generalReservation = 24;
  static const _scheduleWindowDays = 14;

  final SettingsStorage _settingsStorage;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  NotificationResponseHandler? onNotificationOpened;
  NotificationActionHandler? onNotificationAction;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    tz_data.initializeTimeZones();
    await _configureLocalTimezone();

    final darwinCategories = <DarwinNotificationCategory>[
      DarwinNotificationCategory(
        _taskCategoryId,
        actions: <DarwinNotificationAction>[
          DarwinNotificationAction.plain(
            _completeActionId,
            'Tamamlandı',
            options: <DarwinNotificationActionOption>{
              DarwinNotificationActionOption.foreground,
            },
          ),
        ],
      ),
    ];

    final settings = InitializationSettings(
      android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        notificationCategories: darwinCategories,
      ),
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          florienNotificationBackgroundHandler,
    );
    _initialized = true;
  }

  Future<FlorienNotificationPayload?> consumeLaunchPayload() async {
    await initialize();
    if (kIsWeb) return null;
    final details = await _notifications.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return FlorienNotificationPayload.tryParse(
      details?.notificationResponse?.payload,
    );
  }

  Future<bool> hasOsPermission() async {
    await initialize();
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final options = await ios?.checkPermissions();
      return options?.isEnabled ?? false;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.areNotificationsEnabled() ?? true;
    }
    return false;
  }

  Future<bool> requestOsPermission() async {
    await initialize();
    if (kIsWeb) return false;
    return _requestPermission();
  }

  Future<void> openSystemNotificationSettings() async {
    if (kIsWeb) return;
    final uri = Uri.parse('app-settings:');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<NotificationPreferences> getPreferences() =>
      _settingsStorage.getNotificationPreferences();

  Future<void> savePreferences(NotificationPreferences preferences) async {
    await _settingsStorage.saveNotificationPreferences(preferences);
  }

  Future<bool> enableDefaultsAfterPermissionGrant() async {
    await initialize();
    if (kIsWeb || !await _requestPermission()) return false;
    await _settingsStorage.enableDefaultNotificationPlan();
    return true;
  }

  Future<bool> setTaskRemindersEnabled(bool enabled) async {
    final current = await getPreferences();
    if (!enabled) {
      await savePreferences(current.copyWith(taskRemindersEnabled: false));
      return false;
    }
    await initialize();
    if (kIsWeb || !await _requestPermission()) return false;
    await savePreferences(current.copyWith(taskRemindersEnabled: true));
    return true;
  }

  Future<void> setSoundEnabled(bool enabled) =>
      _settingsStorage.setNotificationSoundEnabled(enabled);

  Future<void> setVibrationEnabled(bool enabled) =>
      _settingsStorage.setNotificationVibrationEnabled(enabled);

  Future<TaskAlarmReadiness> prepareTaskAlarm(DateTime alarmAt) async {
    if (!alarmAt.toLocal().isAfter(DateTime.now())) {
      return TaskAlarmReadiness.past;
    }
    final preferences = await getPreferences();
    if (!preferences.taskRemindersEnabled) {
      return TaskAlarmReadiness.remindersDisabled;
    }
    await initialize();
    if (kIsWeb) return TaskAlarmReadiness.unsupported;
    return await hasOsPermission()
        ? TaskAlarmReadiness.ready
        : TaskAlarmReadiness.permissionDenied;
  }

  /// Legacy single-task schedule API used by older call sites.
  Future<bool> schedule({
    required String taskId,
    required String title,
    required DateTime alarmAt,
    String accountId = '',
    int leadMinutes = 0,
  }) async {
    final readiness = await prepareTaskAlarm(alarmAt);
    if (readiness != TaskAlarmReadiness.ready) return false;
    final preferences = await getPreferences();
    final payload = FlorienNotificationPayload(
      kind: FlorienNotificationKind.taskReminder,
      accountId: accountId,
      target: NotificationTargetScreen.taskFocus,
      taskId: taskId,
      occurrenceKey: taskId,
    );
    return _zonedSchedule(
      idKey: _taskIdKey(taskId),
      title: NotificationCopy.taskTitle,
      body: NotificationCopy.taskBody(taskTitle: title, leadMinutes: leadMinutes),
      when: alarmAt,
      preferences: preferences,
      payload: payload,
      categoryId: _taskCategoryId,
    );
  }

  Future<void> cancel(String taskId) async {
    await initialize();
    if (kIsWeb) return;
    await _notifications.cancel(_notificationId(_taskIdKey(taskId)));
  }

  Future<void> cancelAccountNotifications(String accountId) async {
    await initialize();
    if (kIsWeb || accountId.isEmpty) {
      await cancelAll();
      return;
    }
    final pending = await _notifications.pendingNotificationRequests();
    for (final request in pending) {
      final payload = FlorienNotificationPayload.tryParse(request.payload);
      if (payload == null) continue;
      if (payload.accountId == accountId ||
          payload.kind == FlorienNotificationKind.focusTimer) {
        await _notifications.cancel(request.id);
      }
    }
  }

  Future<void> cancelAll() async {
    await initialize();
    if (kIsWeb) return;
    await _notifications.cancelAll();
  }

  Future<bool> scheduleFocusTimerAlarm({
    required String title,
    required DateTime alarmAt,
  }) async {
    if (!alarmAt.toLocal().isAfter(DateTime.now())) return false;
    await initialize();
    if (kIsWeb || !await _requestPermission()) return false;

    final preferences = await getPreferences();
    final payload = FlorienNotificationPayload(
      kind: FlorienNotificationKind.focusTimer,
      accountId: '',
      target: NotificationTargetScreen.taskFocus,
    );
    return _zonedSchedule(
      idKey: _focusTimerAlarmId,
      title: title,
      body: 'Odak turun tamamlandı.',
      when: alarmAt,
      preferences: preferences,
      payload: payload,
      channelPrefix: 'focus_timer_alarm_v2',
      channelName: 'Odak zamanlayıcısı',
      channelDescription: 'Odak süresi tamamlandığında çalan alarm',
    );
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
      _notificationDetails(
        preferences,
        channelPrefix: 'focus_timer_alarm_v2',
        channelName: 'Odak zamanlayıcısı',
        channelDescription: 'Odak süresi tamamlandığında çalan alarm',
      ),
      payload: FlorienNotificationPayload(
        kind: FlorienNotificationKind.focusTimer,
        accountId: '',
        target: NotificationTargetScreen.taskFocus,
      ).encode(),
    );
  }

  Future<void> cancelFocusTimerAlarm() => cancel(_focusTimerAlarmId);

  /// Full reconcile of general + task notifications for the signed-in account.
  /// Local plan notifications are iOS-only (see product scope).
  Future<void> reconcile({
    required String accountId,
    required List<TaskModel> upcomingTasks,
    int? previousDefaultLeadMinutes,
  }) async {
    await initialize();
    if (kIsWeb || accountId.isEmpty) return;
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    final permitted = await hasOsPermission();
    if (!permitted) return;

    final preferences = await getPreferences();
    await _detectTimezoneChange();

    // Cancel Florien-managed pending notifications for this account (keep focus).
    final pending = await _notifications.pendingNotificationRequests();
    for (final request in pending) {
      final payload = FlorienNotificationPayload.tryParse(request.payload);
      if (payload == null) continue;
      if (payload.kind == FlorienNotificationKind.focusTimer) continue;
      if (payload.accountId.isNotEmpty && payload.accountId != accountId) {
        continue;
      }
      await _notifications.cancel(request.id);
    }

    final generalScheduled = await _scheduleGeneralNotifications(
      accountId: accountId,
      preferences: preferences,
    );

    if (preferences.taskRemindersEnabled) {
      final taskSlots =
          (_maxPendingNotifications - generalScheduled).clamp(0, _maxPendingNotifications);
      await _scheduleTaskNotifications(
        accountId: accountId,
        preferences: preferences,
        tasks: upcomingTasks,
        taskSlots: taskSlots,
      );
    }
  }

  DateTime? computeTaskFireTime({
    required TaskModel task,
    required NotificationPreferences preferences,
  }) {
    if (!preferences.taskRemindersEnabled) return null;
    if (!task.isTimed || task.scheduledAt == null) return null;
    if (task.isCompleted || task.status == TaskStatus.skipped) return null;
    // Opt-in per task: alarm toggle stores alarmAt and/or reminderLeadMinutes.
    if (task.alarmAt == null && task.reminderLeadMinutes == null) return null;

    final start = task.scheduledAt!.toLocal();
    final fireAt =
        task.alarmAt?.toLocal() ??
        start.subtract(Duration(minutes: task.reminderLeadMinutes ?? 0));
    final now = DateTime.now();
    // Too close: do not fire immediately or at start as a catch-up.
    if (!fireAt.isAfter(now)) return null;
    return fireAt;
  }

  Future<int> _scheduleGeneralNotifications({
    required String accountId,
    required NotificationPreferences preferences,
  }) async {
    final now = DateTime.now();
    final end = now.add(const Duration(days: _scheduleWindowDays));
    final entries = <_Schedulable>[];

    if (preferences.morningSummaryEnabled) {
      entries.addAll(
        _buildDailyKindEntries(
          accountId: accountId,
          preferences: preferences,
          kind: FlorienNotificationKind.morningSummary,
          target: NotificationTargetScreen.dailyPlan,
          title: NotificationCopy.morningTitle,
          bodies: NotificationCopy.morningBodies,
          minutes: preferences.morningSummaryMinutes,
          from: now,
          to: end,
          idPrefix: 'morning',
          applyQuietHours: true,
        ),
      );
    }

    if (preferences.motivationEnabled) {
      entries.addAll(
        _buildMotivationEntries(
          accountId: accountId,
          preferences: preferences,
          from: now,
          to: end,
        ),
      );
    }

    if (preferences.dailyReviewEnabled) {
      entries.addAll(
        _buildDailyKindEntries(
          accountId: accountId,
          preferences: preferences,
          kind: FlorienNotificationKind.dailyReview,
          target: NotificationTargetScreen.dailyReview,
          title: NotificationCopy.dailyReviewTitle,
          bodies: NotificationCopy.dailyReviewBodies,
          minutes: preferences.dailyReviewMinutes,
          from: now,
          to: end,
          idPrefix: 'daily_review',
          applyQuietHours: true,
        ),
      );
    }

    if (preferences.weeklyReviewEnabled) {
      entries.addAll(
        _buildWeeklyReviewEntries(
          accountId: accountId,
          preferences: preferences,
          from: now,
          to: end,
        ),
      );
    }

    entries.sort((a, b) => a.when.compareTo(b.when));
    final limited = entries.take(_generalReservation).toList();
    var scheduled = 0;
    for (final entry in limited) {
      final ok = await _zonedSchedule(
        idKey: entry.idKey,
        title: entry.title,
        body: entry.body,
        when: entry.when,
        preferences: preferences,
        payload: entry.payload,
        categoryId: entry.categoryId,
      );
      if (ok) scheduled++;
    }
    return scheduled;
  }

  List<_Schedulable> _buildDailyKindEntries({
    required String accountId,
    required NotificationPreferences preferences,
    required FlorienNotificationKind kind,
    required NotificationTargetScreen target,
    required String title,
    required List<String> bodies,
    required int minutes,
    required DateTime from,
    required DateTime to,
    required String idPrefix,
    required bool applyQuietHours,
  }) {
    final entries = <_Schedulable>[];
    var day = DateTime(from.year, from.month, from.day);
    final last = DateTime(to.year, to.month, to.day);
    while (!day.isAfter(last)) {
      var when = _localDateTime(day, minutes);
      if (applyQuietHours) {
        when = applyQuietHoursShift(when, preferences) ?? when;
      }
      if (when.isAfter(from) && !when.isAfter(to)) {
        entries.add(
          _Schedulable(
            idKey: '${idPrefix}_${accountId}_${_dayKey(day)}',
            when: when,
            title: title,
            body: NotificationCopy.pick(bodies, day),
            payload: FlorienNotificationPayload(
              kind: kind,
              accountId: accountId,
              target: target,
            ),
            categoryId: null,
          ),
        );
      }
      day = day.add(const Duration(days: 1));
    }
    return entries;
  }

  List<_Schedulable> _buildMotivationEntries({
    required String accountId,
    required NotificationPreferences preferences,
    required DateTime from,
    required DateTime to,
  }) {
    final entries = <_Schedulable>[];
    var day = DateTime(from.year, from.month, from.day);
    final last = DateTime(to.year, to.month, to.day);
    while (!day.isAfter(last)) {
      if (day.weekday == DateTime.tuesday ||
          day.weekday == DateTime.thursday) {
        var when = _localDateTime(day, preferences.motivationMinutes);
        when = applyQuietHoursShift(when, preferences) ?? when;
        if (when.isAfter(from) && !when.isAfter(to)) {
          entries.add(
            _Schedulable(
              idKey: 'motivation_${accountId}_${_dayKey(day)}',
              when: when,
              title: NotificationCopy.motivationTitle,
              body: NotificationCopy.pick(NotificationCopy.motivationBodies, day),
              payload: FlorienNotificationPayload(
                kind: FlorienNotificationKind.motivation,
                accountId: accountId,
                target: NotificationTargetScreen.dailyPlan,
              ),
              categoryId: null,
            ),
          );
        }
      }
      day = day.add(const Duration(days: 1));
    }
    return entries;
  }

  List<_Schedulable> _buildWeeklyReviewEntries({
    required String accountId,
    required NotificationPreferences preferences,
    required DateTime from,
    required DateTime to,
  }) {
    final entries = <_Schedulable>[];
    var day = DateTime(from.year, from.month, from.day);
    final last = DateTime(to.year, to.month, to.day);
    while (!day.isAfter(last)) {
      if (day.weekday == DateTime.sunday) {
        var when = _localDateTime(day, preferences.weeklyReviewMinutes);
        when = applyQuietHoursShift(when, preferences) ?? when;
        if (when.isAfter(from) && !when.isAfter(to)) {
          entries.add(
            _Schedulable(
              idKey: 'weekly_${accountId}_${_dayKey(day)}',
              when: when,
              title: NotificationCopy.weeklyReviewTitle,
              body: NotificationCopy.pick(
                NotificationCopy.weeklyReviewBodies,
                day,
              ),
              payload: FlorienNotificationPayload(
                kind: FlorienNotificationKind.weeklyReview,
                accountId: accountId,
                target: NotificationTargetScreen.weeklyPlanMonday,
              ),
              categoryId: null,
            ),
          );
        }
      }
      day = day.add(const Duration(days: 1));
    }
    return entries;
  }

  Future<void> _scheduleTaskNotifications({
    required String accountId,
    required NotificationPreferences preferences,
    required List<TaskModel> tasks,
    required int taskSlots,
  }) async {
    if (taskSlots <= 0) return;

    final candidates = <_TaskFireCandidate>[];
    for (final task in tasks) {
      // Custom lead stays on the task; null lead uses the account default.
      final fireAt = computeTaskFireTime(task: task, preferences: preferences);
      if (fireAt == null) continue;
      final lead = task.reminderLeadMinutes ?? 0;
      candidates.add(
        _TaskFireCandidate(task: task, fireAt: fireAt, leadMinutes: lead),
      );
    }

    candidates.sort((a, b) => a.fireAt.compareTo(b.fireAt));

    final groups = <String, List<_TaskFireCandidate>>{};
    for (final candidate in candidates) {
      final key = _minuteKey(candidate.fireAt);
      groups.putIfAbsent(key, () => []).add(candidate);
    }

    final scheduledEntries = <_Schedulable>[];
    final orderedKeys = groups.keys.toList()
      ..sort((a, b) => groups[a]!.first.fireAt.compareTo(groups[b]!.first.fireAt));
    for (final key in orderedKeys) {
      final group = groups[key]!;
      if (group.length >= 3) {
        final titles = group.map((c) => c.task.title).toList();
        scheduledEntries.add(
          _Schedulable(
            idKey: 'batch_${accountId}_${_minuteKey(group.first.fireAt)}',
            when: group.first.fireAt,
            title: NotificationCopy.batchTitle,
            body: NotificationCopy.batchBody(titles),
            payload: FlorienNotificationPayload(
              kind: FlorienNotificationKind.taskBatch,
              accountId: accountId,
              target: NotificationTargetScreen.dailyPlan,
              taskIds: group.map((c) => c.task.id).toList(),
            ),
            categoryId: null,
          ),
        );
      } else {
        for (final candidate in group) {
          scheduledEntries.add(
            _Schedulable(
              idKey: _taskIdKey(candidate.task.id),
              when: candidate.fireAt,
              title: NotificationCopy.taskTitle,
              body: NotificationCopy.taskBody(
                taskTitle: candidate.task.title,
                leadMinutes: candidate.leadMinutes,
              ),
              payload: FlorienNotificationPayload(
                kind: FlorienNotificationKind.taskReminder,
                accountId: accountId,
                target: NotificationTargetScreen.taskFocus,
                taskId: candidate.task.id,
                occurrenceKey: candidate.task.id,
              ),
              categoryId: _taskCategoryId,
            ),
          );
        }
      }
    }

    for (final entry in scheduledEntries.take(taskSlots)) {
      await _zonedSchedule(
        idKey: entry.idKey,
        title: entry.title,
        body: entry.body,
        when: entry.when,
        preferences: preferences,
        payload: entry.payload,
        categoryId: entry.categoryId,
      );
    }
  }

  /// Shifts general notifications out of quiet hours to quiet-hours end.
  @visibleForTesting
  static DateTime? applyQuietHoursShift(
    DateTime when,
    NotificationPreferences preferences,
  ) {
    if (!preferences.quietHoursEnabled) return when;
    if (!_isInQuietHours(when, preferences)) return when;

    final endMinutes = preferences.quietHoursEndMinutes;
    final startMinutes = preferences.quietHoursStartMinutes;
    final day = DateTime(when.year, when.month, when.day);
    // Overnight quiet hours (e.g. 22:00–08:00).
    if (startMinutes > endMinutes) {
      final minutesNow = when.hour * 60 + when.minute;
      if (minutesNow >= startMinutes) {
        return _localDateTime(day.add(const Duration(days: 1)), endMinutes);
      }
      return _localDateTime(day, endMinutes);
    }
    // Same-day quiet window.
    return _localDateTime(day, endMinutes);
  }

  static bool _isInQuietHours(
    DateTime when,
    NotificationPreferences preferences,
  ) {
    final minutes = when.hour * 60 + when.minute;
    final start = preferences.quietHoursStartMinutes;
    final end = preferences.quietHoursEndMinutes;
    if (start == end) return false;
    if (start < end) {
      return minutes >= start && minutes < end;
    }
    return minutes >= start || minutes < end;
  }

  Future<bool> _zonedSchedule({
    required String idKey,
    required String title,
    required String body,
    required DateTime when,
    required NotificationPreferences preferences,
    required FlorienNotificationPayload payload,
    String? categoryId,
    String channelPrefix = 'florien_local_v1',
    String channelName = 'Florien hatırlatmaları',
    String channelDescription = 'Yerel plan ve görev bildirimleri',
  }) async {
    if (!when.toLocal().isAfter(DateTime.now())) return false;
    await _configureLocalTimezone();
    final scheduled = tz.TZDateTime.from(when.toLocal(), tz.local);
    final details = _notificationDetails(
      preferences,
      channelPrefix: channelPrefix,
      channelName: channelName,
      channelDescription: channelDescription,
      categoryId: categoryId,
    );
    try {
      await _notifications.zonedSchedule(
        _notificationId(idKey),
        title,
        body,
        scheduled,
        details,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload.encode(),
      );
    } catch (error) {
      debugPrint('Exact notification failed: $error');
      try {
        await _notifications.zonedSchedule(
          _notificationId(idKey),
          title,
          body,
          scheduled,
          details,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload.encode(),
        );
      } catch (fallbackError) {
        debugPrint('Notification could not be scheduled: $fallbackError');
        return false;
      }
    }
    return true;
  }

  NotificationDetails _notificationDetails(
    NotificationPreferences preferences, {
    required String channelPrefix,
    required String channelName,
    required String channelDescription,
    String? categoryId,
  }) => NotificationDetails(
    android: AndroidNotificationDetails(
      _androidChannelId(channelPrefix, preferences),
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      playSound: preferences.soundEnabled,
      enableVibration: preferences.vibrationEnabled,
      actions: categoryId == _taskCategoryId
          ? <AndroidNotificationAction>[
              const AndroidNotificationAction(
                _completeActionId,
                'Tamamlandı',
                showsUserInterface: true,
              ),
            ]
          : null,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentSound: preferences.soundEnabled,
      presentBanner: true,
      presentList: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
      categoryIdentifier: categoryId,
    ),
  );

  String _androidChannelId(
    String prefix,
    NotificationPreferences preferences,
  ) =>
      '${prefix}_${preferences.soundEnabled ? 'sound' : 'silent'}_${preferences.vibrationEnabled ? 'vibrate' : 'steady'}';

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

  Future<void> _configureLocalTimezone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      final name = info.identifier;
      tz.setLocalLocation(tz.getLocation(name));
    } catch (error) {
      debugPrint('Local timezone setup failed: $error');
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
    }
  }

  Future<bool> _detectTimezoneChange() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      final current = info.identifier;
      final previous = await _settingsStorage.getLastKnownTimezone();
      await _settingsStorage.setLastKnownTimezone(current);
      return previous != null && previous != current;
    } catch (_) {
      return false;
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = FlorienNotificationPayload.tryParse(response.payload);
    if (payload == null) return;
    final actionId = response.actionId;
    if (actionId != null && actionId.isNotEmpty) {
      onNotificationAction?.call(payload, actionId);
      return;
    }
    onNotificationOpened?.call(payload);
  }

  static String _taskIdKey(String taskId) => 'task_$taskId';

  static String _dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}'
      '${day.month.toString().padLeft(2, '0')}'
      '${day.day.toString().padLeft(2, '0')}';

  static String _minuteKey(DateTime when) =>
      '${_dayKey(when)}_${when.hour.toString().padLeft(2, '0')}'
      '${when.minute.toString().padLeft(2, '0')}';

  static DateTime _localDateTime(DateTime day, int minutes) {
    final clamped = minutes.clamp(0, 24 * 60 - 1);
    return DateTime(
      day.year,
      day.month,
      day.day,
      clamped ~/ 60,
      clamped % 60,
    );
  }

  int _notificationId(String key) {
    var hash = 17;
    for (final codeUnit in key.codeUnits) {
      hash = 37 * hash + codeUnit;
    }
    return hash & 0x7fffffff;
  }
}

class _TaskFireCandidate {
  const _TaskFireCandidate({
    required this.task,
    required this.fireAt,
    required this.leadMinutes,
  });

  final TaskModel task;
  final DateTime fireAt;
  final int leadMinutes;
}

class _Schedulable {
  const _Schedulable({
    required this.idKey,
    required this.when,
    required this.title,
    required this.body,
    required this.payload,
    required this.categoryId,
  });

  final String idKey;
  final DateTime when;
  final String title;
  final String body;
  final FlorienNotificationPayload payload;
  final String? categoryId;
}

@pragma('vm:entry-point')
void florienNotificationBackgroundHandler(NotificationResponse response) {
  // Foreground completion is handled when the app opens via payload.
}
