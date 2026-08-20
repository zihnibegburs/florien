import 'package:florien/core/services/task_alarm_service.dart';
import 'package:florien/core/storage/settings_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/onboarding/notification_permission_screen.dart';
import 'package:florien/features/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PermissionTaskAlarmService extends TaskAlarmService {
  _PermissionTaskAlarmService(this.storage) : super(storage);

  final SettingsStorage storage;
  bool requested = false;

  @override
  Future<bool> setTaskRemindersEnabled(bool enabled) async {
    requested = enabled;
    await storage.setTaskRemindersEnabled(enabled);
    return enabled;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('allows notification permission from the entry screen', (
    tester,
  ) async {
    final storage = SettingsStorage();
    final alarms = _PermissionTaskAlarmService(storage);
    var completed = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsStorageProvider.overrideWithValue(storage),
          taskAlarmServiceProvider.overrideWithValue(alarms),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: NotificationPermissionScreen(
            onComplete: () => completed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('reminder-permission-illustration')),
      findsOneWidget,
    );
    expect(find.text('Bildirimlere izin ver'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('allow-notifications')),
    );
    await tester.tap(find.byKey(const ValueKey('allow-notifications')));
    await tester.pumpAndSettle();

    expect(alarms.requested, isTrue);
    expect(completed, isTrue);
    expect(await storage.isNotificationPermissionIntroCompleted(), isTrue);
  });

  testWidgets('can postpone notification permission without blocking entry', (
    tester,
  ) async {
    final storage = SettingsStorage();
    var completed = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsStorageProvider.overrideWithValue(storage)],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: NotificationPermissionScreen(
            onComplete: () => completed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('skip-notifications')),
    );
    await tester.tap(find.byKey(const ValueKey('skip-notifications')));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(await storage.isNotificationPermissionIntroCompleted(), isTrue);
    expect(
      (await storage.getNotificationPreferences()).taskRemindersEnabled,
      isFalse,
    );
  });
}
