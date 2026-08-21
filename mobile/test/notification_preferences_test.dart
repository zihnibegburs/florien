import 'package:flutter_test/flutter_test.dart';
import 'package:florien/core/storage/settings_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('persists expanded notification preferences', () async {
    final storage = SettingsStorage();

    final initial = await storage.getNotificationPreferences();
    expect(initial.taskRemindersEnabled, isTrue);
    expect(initial.taskReminderLeadMinutes, 10);
    expect(initial.morningSummaryEnabled, isTrue);
    expect(initial.morningSummaryMinutes, 9 * 60);
    expect(initial.motivationEnabled, isTrue);
    expect(initial.motivationMinutes, 14 * 60);
    expect(initial.dailyReviewEnabled, isTrue);
    expect(initial.dailyReviewMinutes, 21 * 60);
    expect(initial.weeklyReviewEnabled, isTrue);
    expect(initial.weeklyReviewMinutes, 19 * 60);
    expect(initial.quietHoursEnabled, isTrue);
    expect(initial.quietHoursStartMinutes, 22 * 60);
    expect(initial.quietHoursEndMinutes, 8 * 60);

    await storage.saveNotificationPreferences(
      initial.copyWith(
        taskRemindersEnabled: false,
        taskReminderLeadMinutes: 15,
        morningSummaryEnabled: false,
        morningSummaryMinutes: 8 * 60,
        quietHoursEnabled: false,
        soundEnabled: false,
      ),
    );

    final preferences = await storage.getNotificationPreferences();
    expect(preferences.taskRemindersEnabled, isFalse);
    expect(preferences.taskReminderLeadMinutes, 15);
    expect(preferences.morningSummaryEnabled, isFalse);
    expect(preferences.morningSummaryMinutes, 8 * 60);
    expect(preferences.quietHoursEnabled, isFalse);
    expect(preferences.soundEnabled, isFalse);
  });

  test('enableDefaultNotificationPlan restores defaults', () async {
    final storage = SettingsStorage();
    await storage.setTaskRemindersEnabled(false);
    final restored = await storage.enableDefaultNotificationPlan();
    expect(restored.taskRemindersEnabled, isTrue);
    expect(restored.morningSummaryEnabled, isTrue);
    expect(restored.motivationEnabled, isTrue);
    expect(restored.dailyReviewEnabled, isTrue);
    expect(restored.weeklyReviewEnabled, isTrue);
    expect(restored.quietHoursEnabled, isTrue);
  });
}
