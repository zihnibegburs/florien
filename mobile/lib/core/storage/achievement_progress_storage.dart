import 'package:shared_preferences/shared_preferences.dart';

class AchievementProgressStorage {
  static const _completedPrefix = 'achievement_completed_high_water_v1_';
  static const _celebratedPrefix = 'achievement_celebrated_threshold_v1_';

  Future<int> preserveCompletedTaskCount({
    required String profileScope,
    required int currentCount,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final key = '$_completedPrefix$profileScope';
    final previous = preferences.getInt(key) ?? 0;
    final highest = currentCount > previous ? currentCount : previous;
    if (highest != previous) await preferences.setInt(key, highest);
    return highest;
  }

  Future<int> loadCelebratedThreshold(String profileScope) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt('$_celebratedPrefix$profileScope') ?? 0;
  }

  Future<void> markCelebrated({
    required String profileScope,
    required int threshold,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final key = '$_celebratedPrefix$profileScope';
    final previous = preferences.getInt(key) ?? 0;
    if (threshold > previous) await preferences.setInt(key, threshold);
  }
}
