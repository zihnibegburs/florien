import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/models/achievement.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AchievementStorage {
  static const _legacyStatsKey = 'achievement_stats';

  static String _statsKey(String userId) => 'achievement_stats_$userId';

  Future<AchievementStats> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyStatsKey);
    final raw = prefs.getString(_statsKey(userId));
    if (raw == null) return const AchievementStats();
    try {
      final stats = AchievementStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return _normalizeWeek(stats, DateTime.now());
    } catch (_) {
      return const AchievementStats();
    }
  }

  Future<void> save(String userId, AchievementStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statsKey(userId), jsonEncode(stats.toJson()));
  }

  Future<void> clear(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_statsKey(userId));
  }

  AchievementStats _normalizeWeek(AchievementStats stats, DateTime now) {
    final currentWeek = weekKeyFor(now);
    if (stats.weekKey == currentWeek) return stats;
    return stats.copyWith(tasksCompletedThisWeek: 0, weekKey: currentWeek);
  }

  AchievementStats recordTaskCompleted(
    AchievementStats current, {
    required DateTime completedAt,
  }) {
    final normalized = _normalizeWeek(current, completedAt);
    return normalized.copyWith(
      tasksCompleted: normalized.tasksCompleted + 1,
      tasksCompletedThisWeek: normalized.tasksCompletedThisWeek + 1,
      weekKey: weekKeyFor(completedAt),
    );
  }
}

final achievementStorageProvider = Provider<AchievementStorage>((ref) => AchievementStorage());
