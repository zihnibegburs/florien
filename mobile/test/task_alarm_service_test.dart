import 'package:florien/core/models/models.dart';
import 'package:florien/core/services/notification_copy.dart';
import 'package:florien/core/services/task_alarm_service.dart';
import 'package:florien/core/storage/settings_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects a plan alarm whose time is in the past', () async {
    final alarms = TaskAlarmService(SettingsStorage());

    final readiness = await alarms.prepareTaskAlarm(
      DateTime.now().subtract(const Duration(minutes: 1)),
    );

    expect(readiness, TaskAlarmReadiness.past);
  });

  test('quiet hours shift overnight windows to quiet-hours end', () {
    const prefs = NotificationPreferences(
      quietHoursEnabled: true,
      quietHoursStartMinutes: 22 * 60,
      quietHoursEndMinutes: 8 * 60,
    );
    final evening = DateTime(2026, 8, 21, 22, 30);
    final shifted = TaskAlarmService.applyQuietHoursShift(evening, prefs);
    expect(shifted, DateTime(2026, 8, 22, 8, 0));

    final earlyMorning = DateTime(2026, 8, 22, 2, 0);
    final shiftedMorning = TaskAlarmService.applyQuietHoursShift(
      earlyMorning,
      prefs,
    );
    expect(shiftedMorning, DateTime(2026, 8, 22, 8, 0));
  });

  test('quiet hours leave times outside the window unchanged', () {
    const prefs = NotificationPreferences(
      quietHoursEnabled: true,
      quietHoursStartMinutes: 22 * 60,
      quietHoursEndMinutes: 8 * 60,
    );
    final afternoon = DateTime(2026, 8, 21, 14, 0);
    expect(
      TaskAlarmService.applyQuietHoursShift(afternoon, prefs),
      afternoon,
    );
  });

  test('disabled quiet hours never shift', () {
    const prefs = NotificationPreferences(
      quietHoursEnabled: false,
      quietHoursStartMinutes: 22 * 60,
      quietHoursEndMinutes: 8 * 60,
    );
    final evening = DateTime(2026, 8, 21, 23, 0);
    expect(TaskAlarmService.applyQuietHoursShift(evening, prefs), evening);
  });

  test('settings reminder uses preference lead for timed tasks', () {
    final alarms = TaskAlarmService(SettingsStorage());
    final start = DateTime.now().add(const Duration(hours: 2));
    final task = TaskModel(
      id: 't-reminder',
      title: 'Saatli görev',
      color: '#000',
      icon: 'task',
      durationMinutes: 30,
      scheduledAt: start,
      status: TaskStatus.pending,
      sortOrder: 0,
      isInbox: false,
      isTimed: true,
    );
    final fireAt = alarms.computeTaskReminderFireTime(
      task: task,
      preferences: const NotificationPreferences(taskReminderLeadMinutes: 10),
    );
    expect(fireAt, start.subtract(const Duration(minutes: 10)));
  });

  test('settings reminder skips when task reminders are off', () {
    final alarms = TaskAlarmService(SettingsStorage());
    final start = DateTime.now().add(const Duration(hours: 2));
    final task = TaskModel(
      id: 't-reminder-off',
      title: 'Saatli görev',
      color: '#000',
      icon: 'task',
      durationMinutes: 30,
      scheduledAt: start,
      status: TaskStatus.pending,
      sortOrder: 0,
      isInbox: false,
      isTimed: true,
    );
    expect(
      alarms.computeTaskReminderFireTime(
        task: task,
        preferences: const NotificationPreferences(taskRemindersEnabled: false),
      ),
      isNull,
    );
  });

  test('settings reminder skips when lead window already passed', () {
    final alarms = TaskAlarmService(SettingsStorage());
    final now = DateTime.now();
    final task = TaskModel(
      id: 't1',
      title: 'Yakın görev',
      color: '#000',
      icon: 'task',
      durationMinutes: 30,
      scheduledAt: now.add(const Duration(minutes: 4)),
      status: TaskStatus.pending,
      sortOrder: 0,
      isInbox: false,
      isTimed: true,
    );
    final fireAt = alarms.computeTaskReminderFireTime(
      task: task,
      preferences: const NotificationPreferences(taskReminderLeadMinutes: 10),
    );
    expect(fireAt, isNull);
  });

  test('untimed tasks do not get settings reminders', () {
    final alarms = TaskAlarmService(SettingsStorage());
    final task = TaskModel(
      id: 't3',
      title: 'Saatsiz',
      color: '#000',
      icon: 'task',
      durationMinutes: 30,
      scheduledAt: DateTime.now().add(const Duration(hours: 3)),
      status: TaskStatus.pending,
      sortOrder: 0,
      isInbox: false,
      isTimed: false,
    );
    expect(
      alarms.computeTaskReminderFireTime(
        task: task,
        preferences: const NotificationPreferences(),
      ),
      isNull,
    );
  });

  test('plan alarm fires at absolute alarmAt', () {
    final alarms = TaskAlarmService(SettingsStorage());
    final alarmAt = DateTime.now().add(const Duration(hours: 2));
    final task = TaskModel(
      id: 't3b',
      title: 'Sabah planı',
      color: '#000',
      icon: 'task',
      durationMinutes: 30,
      scheduledAt: DateTime.now().add(const Duration(hours: 3)),
      alarmAt: alarmAt,
      status: TaskStatus.pending,
      sortOrder: 0,
      isInbox: false,
      isTimed: false,
      dayPeriod: DayPeriod.morning,
    );
    expect(alarms.computePlanAlarmFireTime(task), alarmAt);
  });

  test('plan alarm fires even when task reminders preference is off', () {
    final alarms = TaskAlarmService(SettingsStorage());
    final alarmAt = DateTime.now().add(const Duration(hours: 1));
    final task = TaskModel(
      id: 't3c',
      title: 'Bağımsız alarm',
      color: '#000',
      icon: 'task',
      durationMinutes: 15,
      scheduledAt: DateTime.now().add(const Duration(hours: 3)),
      alarmAt: alarmAt,
      status: TaskStatus.pending,
      sortOrder: 0,
      isInbox: false,
      isTimed: false,
    );
    expect(alarms.computePlanAlarmFireTime(task), alarmAt);
    expect(
      alarms.computeTaskFireTime(
        task: task,
        preferences: const NotificationPreferences(taskRemindersEnabled: false),
      ),
      alarmAt,
    );
  });

  test('notification titles match product copy', () {
    expect(NotificationCopy.morningTitle, 'Bugünün planı');
    expect(NotificationCopy.motivationTitle, 'Küçük bir hatırlatma');
    expect(NotificationCopy.dailyReviewTitle, 'Günü değerlendirelim');
    expect(NotificationCopy.weeklyReviewTitle, 'Haftayı planlayalım');
    expect(NotificationCopy.taskTitle, 'Sıradaki görevin');
    expect(NotificationCopy.batchTitle, 'Sıradaki görevlerin');
    expect(NotificationCopy.planAlarmTitle, 'Alarm');
  });
}
