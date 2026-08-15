import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/storage/settings_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('persists task notification preferences', () async {
    final storage = SettingsStorage();

    expect(
      (await storage.getNotificationPreferences()).taskRemindersEnabled,
      isTrue,
    );

    await storage.setTaskRemindersEnabled(false);
    await storage.setNotificationSoundEnabled(false);
    await storage.setNotificationVibrationEnabled(false);

    final preferences = await storage.getNotificationPreferences();
    expect(preferences.taskRemindersEnabled, isFalse);
    expect(preferences.soundEnabled, isFalse);
    expect(preferences.vibrationEnabled, isFalse);
  });
}
