import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const achievementCatalogAsset = 'assets/achievements/achievements.json';
const _achievementAssetRoot = 'assets/achievements/';

@immutable
class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.threshold,
    required this.name,
    required this.asset,
  });

  final String id;
  final int threshold;
  final String name;
  final String asset;

  String get assetPath => '$_achievementAssetRoot$asset';

  factory AchievementDefinition.fromJson(Map<String, dynamic> json) {
    return AchievementDefinition(
      id: json['id'] as String,
      threshold: json['threshold'] as int,
      name: json['name'] as String,
      asset: json['asset'] as String,
    );
  }
}

@immutable
class AchievementCatalog {
  const AchievementCatalog({required this.version, required this.items});

  final int version;
  final List<AchievementDefinition> items;

  factory AchievementCatalog.fromJson(Map<String, dynamic> json) {
    final items = (json['achievements'] as List<dynamic>)
        .map(
          (item) =>
              AchievementDefinition.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
    if (items.isEmpty) {
      throw const FormatException('Achievement catalog cannot be empty.');
    }
    for (var index = 1; index < items.length; index++) {
      if (items[index].threshold <= items[index - 1].threshold) {
        throw const FormatException(
          'Achievement thresholds must follow JSON order.',
        );
      }
    }
    return AchievementCatalog(version: json['version'] as int, items: items);
  }

  static Future<AchievementCatalog> load({AssetBundle? bundle}) async {
    final source = await (bundle ?? rootBundle).loadString(
      achievementCatalogAsset,
    );
    return AchievementCatalog.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );
  }

  AchievementDefinition? nextAfter(int completedTaskCount) {
    for (final item in items) {
      if (item.threshold > completedTaskCount) return item;
    }
    return null;
  }

  AchievementDefinition? highestUnlocked(int completedTaskCount) {
    AchievementDefinition? result;
    for (final item in items) {
      if (item.threshold > completedTaskCount) break;
      result = item;
    }
    return result;
  }
}

@immutable
class AchievementProgress {
  const AchievementProgress({
    required this.catalog,
    required this.completedTaskCount,
  });

  final AchievementCatalog catalog;
  final int completedTaskCount;

  AchievementDefinition? get next => catalog.nextAfter(completedTaskCount);

  AchievementDefinition? get highestUnlocked =>
      catalog.highestUnlocked(completedTaskCount);

  bool isUnlocked(AchievementDefinition achievement) =>
      completedTaskCount >= achievement.threshold;

  int get remainingForNext =>
      next == null ? 0 : next!.threshold - completedTaskCount;

  double get nextProgress {
    final target = next;
    if (target == null) return 1;
    final previous = highestUnlocked?.threshold ?? 0;
    final span = target.threshold - previous;
    if (span <= 0) return 1;
    return ((completedTaskCount - previous) / span).clamp(0.0, 1.0).toDouble();
  }
}
