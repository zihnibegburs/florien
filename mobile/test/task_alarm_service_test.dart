import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/services/task_alarm_service.dart';
import 'package:florien/core/storage/settings_storage.dart';

void main() {
  test('rejects a plan alarm whose time is in the past', () async {
    final alarms = TaskAlarmService(SettingsStorage());

    final readiness = await alarms.prepareTaskAlarm(
      DateTime.now().subtract(const Duration(minutes: 1)),
    );

    expect(readiness, TaskAlarmReadiness.past);
  });
}
