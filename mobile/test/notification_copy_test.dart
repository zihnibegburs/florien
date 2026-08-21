import 'package:florien/core/services/notification_copy.dart';
import 'package:florien/core/services/notification_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification copy picks are date-stable', () {
    final day = DateTime(2026, 8, 21);
    final first = NotificationCopy.pick(NotificationCopy.morningBodies, day);
    final second = NotificationCopy.pick(NotificationCopy.morningBodies, day);
    expect(first, second);
    expect(NotificationCopy.morningBodies, contains(first));
  });

  test('task body formats at-start and lead reminders', () {
    expect(
      NotificationCopy.taskBody(taskTitle: 'Yoga', leadMinutes: 0),
      'Yoga şimdi başlıyor.',
    );
    expect(
      NotificationCopy.taskBody(taskTitle: 'Yoga', leadMinutes: 10),
      'Yoga · 10 dk kaldı.',
    );
  });

  test('batch body lists count and preview titles', () {
    expect(
      NotificationCopy.batchBody(const ['A', 'B', 'C']),
      '3 görev: A, B, C',
    );
    expect(
      NotificationCopy.batchBody(const ['A', 'B', 'C', 'D']),
      '4 görev: A, B, C ve 1 tane daha',
    );
  });

  test('payload round-trips kind, account, task and target', () {
    const payload = FlorienNotificationPayload(
      kind: FlorienNotificationKind.taskReminder,
      accountId: 'uid-1',
      target: NotificationTargetScreen.taskFocus,
      taskId: 'task-1',
      occurrenceKey: 'task-1',
    );
    final parsed = FlorienNotificationPayload.tryParse(payload.encode());
    expect(parsed?.kind, FlorienNotificationKind.taskReminder);
    expect(parsed?.accountId, 'uid-1');
    expect(parsed?.taskId, 'task-1');
    expect(parsed?.target, NotificationTargetScreen.taskFocus);
  });

  test('legacy bare task id payload opens task focus', () {
    final parsed = FlorienNotificationPayload.tryParse('legacy-task');
    expect(parsed?.kind, FlorienNotificationKind.taskReminder);
    expect(parsed?.taskId, 'legacy-task');
    expect(parsed?.target, NotificationTargetScreen.taskFocus);
  });
}
