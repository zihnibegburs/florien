import 'package:florien/core/models/models.dart';
import 'package:florien/core/services/live_activity_service.dart';
import 'package:florien/core/services/task_alarm_service.dart';
import 'package:florien/core/storage/settings_storage.dart';
import 'package:florien/features/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SilentAlarms extends TaskAlarmService {
  _SilentAlarms() : super(SettingsStorage());

  bool focusAlarmCancelled = false;

  @override
  Future<void> cancelFocusTimerAlarm() async {
    focusAlarmCancelled = true;
  }
}

class _SilentLiveActivity extends FlorienLiveActivityService {
  bool focusEnded = false;

  @override
  Future<void> endFocus() async {
    focusEnded = true;
  }
}

void main() {
  final now = DateTime(2026, 8, 23, 14, 30);

  test('planning for tomorrow leaves today', () {
    expect(
      florienRescheduleLeavesToday(DateTime(2026, 8, 24), now),
      isTrue,
    );
  });

  test('same-day reschedule stays on today', () {
    expect(
      florienRescheduleLeavesToday(DateTime(2026, 8, 23, 18), now),
      isFalse,
    );
  });

  test('abandoning a focused task closes the session', () {
    final alarms = _SilentAlarms();
    final live = _SilentLiveActivity();
    final container = ProviderContainer(
      overrides: [
        taskAlarmServiceProvider.overrideWithValue(alarms),
        liveActivityServiceProvider.overrideWithValue(live),
      ],
    );
    addTearDown(container.dispose);

    container.read(activeFocusTaskProvider.notifier).state = const ActiveFocusTask(
      taskId: 'focus-1',
      title: 'Odaklan',
      icon: 'timer',
      usesDefaultFocusIcon: true,
      totalSeconds: 900,
      remainingSeconds: 400,
      isRunning: true,
    );
    container.read(focusTaskLaunchProvider.notifier).state = const FocusTaskLaunch(
      taskId: 'focus-1',
      title: 'Odaklan',
      durationMinutes: 15,
      icon: 'timer',
      color: '#6C5CE7',
    );

    final ref = container.read(Provider<Ref>((ref) => ref));
    abandonFocusForTask(ref, 'focus-1');

    expect(container.read(activeFocusTaskProvider), isNull);
    expect(container.read(focusTaskLaunchProvider), isNull);
    expect(container.read(focusTimerResetSignalProvider), 1);
    expect(alarms.focusAlarmCancelled, isTrue);
    expect(live.focusEnded, isTrue);
  });

  test('abandoning another task leaves the current focus running', () {
    final container = ProviderContainer(
      overrides: [
        taskAlarmServiceProvider.overrideWithValue(_SilentAlarms()),
        liveActivityServiceProvider.overrideWithValue(_SilentLiveActivity()),
      ],
    );
    addTearDown(container.dispose);

    container.read(activeFocusTaskProvider.notifier).state = const ActiveFocusTask(
      taskId: 'focus-1',
      title: 'Odaklan',
      icon: 'timer',
      usesDefaultFocusIcon: true,
      totalSeconds: 900,
      remainingSeconds: 400,
      isRunning: true,
    );

    final ref = container.read(Provider<Ref>((ref) => ref));
    abandonFocusForTask(ref, 'other-task');

    expect(container.read(activeFocusTaskProvider)?.taskId, 'focus-1');
    expect(container.read(focusTimerResetSignalProvider), 0);
  });
}
