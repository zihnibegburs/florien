import 'package:flutter/material.dart';
import 'package:florien/core/theme/florien_theme.dart';

enum AchievementScope { weekly, allTime }

const allTimeAchievementCount = 400;

class AchievementDefinition {
  const AchievementDefinition({
    required this.key,
    required this.scope,
    required this.icon,
    required this.color,
    required this.target,
    required this.progressOf,
  });

  final String key;
  final AchievementScope scope;
  final IconData icon;
  final Color color;
  final int target;
  final int Function(AchievementStats stats) progressOf;

  bool isUnlocked(AchievementStats stats) => progressOf(stats) >= target;
  double progress(AchievementStats stats) =>
      (progressOf(stats) / target).clamp(0.0, 1.0);

  String unlockKey(AchievementStats stats) =>
      scope == AchievementScope.weekly ? '${key}_${stats.weekKey}' : key;
}

class AchievementStats {
  const AchievementStats({
    this.tasksCompleted = 0,
    this.tasksCompletedThisWeek = 0,
    this.weekKey,
  });

  final int tasksCompleted;
  final int tasksCompletedThisWeek;
  final String? weekKey;

  AchievementStats copyWith({
    int? tasksCompleted,
    int? tasksCompletedThisWeek,
    String? weekKey,
  }) {
    return AchievementStats(
      tasksCompleted: tasksCompleted ?? this.tasksCompleted,
      tasksCompletedThisWeek:
          tasksCompletedThisWeek ?? this.tasksCompletedThisWeek,
      weekKey: weekKey ?? this.weekKey,
    );
  }

  Map<String, dynamic> toJson() => {
    'tasksCompleted': tasksCompleted,
    'tasksCompletedThisWeek': tasksCompletedThisWeek,
    'weekKey': weekKey,
  };

  factory AchievementStats.fromJson(Map<String, dynamic> json) =>
      AchievementStats(
        tasksCompleted: json['tasksCompleted'] as int? ?? 0,
        tasksCompletedThisWeek: json['tasksCompletedThisWeek'] as int? ?? 0,
        weekKey: json['weekKey'] as String?,
      );
}

String weekKeyFor(DateTime date) {
  final monday = date.subtract(Duration(days: date.weekday - 1));
  return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
}

const _achievementIcons = [
  Icons.flag_rounded,
  Icons.bolt_rounded,
  Icons.auto_awesome_rounded,
  Icons.emoji_events_rounded,
  Icons.star_rounded,
  Icons.local_fire_department_rounded,
  Icons.rocket_launch_rounded,
  Icons.diamond_rounded,
  Icons.workspace_premium_rounded,
  Icons.military_tech_rounded,
  Icons.celebration_rounded,
  Icons.thumb_up_rounded,
];

final _achievementColors = FlorienColors.taskColors
    .map(FlorienColors.fromHex)
    .toList();

const weeklyAchievementDefinitions = [
  AchievementDefinition(
    key: 'weekly_1',
    scope: AchievementScope.weekly,
    icon: Icons.wb_sunny_rounded,
    color: Color(0xFF4F52B2),
    target: 1,
    progressOf: _weeklyTasksCompleted,
  ),
  AchievementDefinition(
    key: 'weekly_5',
    scope: AchievementScope.weekly,
    icon: Icons.bolt_rounded,
    color: Color(0xFF4ECDC4),
    target: 5,
    progressOf: _weeklyTasksCompleted,
  ),
  AchievementDefinition(
    key: 'weekly_10',
    scope: AchievementScope.weekly,
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFFFF6B9D),
    target: 10,
    progressOf: _weeklyTasksCompleted,
  ),
  AchievementDefinition(
    key: 'weekly_20',
    scope: AchievementScope.weekly,
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFFFE66D),
    target: 20,
    progressOf: _weeklyTasksCompleted,
  ),
];

final allTimeAchievementDefinitions = List<AchievementDefinition>.generate(
  allTimeAchievementCount,
  (index) {
    final target = index + 1;
    return AchievementDefinition(
      key: 'allTime_$target',
      scope: AchievementScope.allTime,
      icon: _achievementIcons[index % _achievementIcons.length],
      color: _achievementColors[index % _achievementColors.length],
      target: target,
      progressOf: _tasksCompleted,
    );
  },
);

final achievementDefinitions = [
  ...weeklyAchievementDefinitions,
  ...allTimeAchievementDefinitions,
];

int _tasksCompleted(AchievementStats stats) => stats.tasksCompleted;
int _weeklyTasksCompleted(AchievementStats stats) =>
    stats.tasksCompletedThisWeek;
