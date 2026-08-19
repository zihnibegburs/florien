import 'package:florien/core/storage/achievement_progress_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'completed task high water never decreases and is profile scoped',
    () async {
      final storage = AchievementProgressStorage();

      expect(
        await storage.preserveCompletedTaskCount(
          profileScope: 'user:primary',
          currentCount: 50,
        ),
        50,
      );
      expect(
        await storage.preserveCompletedTaskCount(
          profileScope: 'user:primary',
          currentCount: 12,
        ),
        50,
      );
      expect(
        await storage.preserveCompletedTaskCount(
          profileScope: 'user:second',
          currentCount: 3,
        ),
        3,
      );
    },
  );

  test('celebrated threshold only moves forward', () async {
    final storage = AchievementProgressStorage();
    const scope = 'user:primary';

    await storage.markCelebrated(profileScope: scope, threshold: 10);
    await storage.markCelebrated(profileScope: scope, threshold: 5);

    expect(await storage.loadCelebratedThreshold(scope), 10);
  });
}
