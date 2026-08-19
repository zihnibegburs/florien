import 'package:florien/core/models/achievement.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('catalog loads 28 ordered achievements and every PNG asset', () async {
    final catalog = await AchievementCatalog.load();

    expect(catalog.items, hasLength(28));
    expect(catalog.items.first.threshold, 1);
    expect(catalog.items.last.threshold, 1000);
    expect(
      catalog.items.map((achievement) => achievement.threshold),
      orderedEquals([
        1,
        3,
        5,
        7,
        10,
        15,
        20,
        25,
        30,
        40,
        50,
        75,
        100,
        125,
        150,
        175,
        200,
        250,
        300,
        350,
        400,
        450,
        500,
        600,
        700,
        800,
        900,
        1000,
      ]),
    );

    for (final achievement in catalog.items) {
      final asset = await rootBundle.load(achievement.assetPath);
      expect(
        asset.lengthInBytes,
        greaterThan(0),
        reason: achievement.assetPath,
      );
    }
  });

  test('unlock boundaries include 1, 10, 50 and 1000 tasks', () async {
    final catalog = await AchievementCatalog.load();

    for (final threshold in [1, 10, 50, 1000]) {
      final progress = AchievementProgress(
        catalog: catalog,
        completedTaskCount: threshold,
      );
      final achievement = catalog.items.firstWhere(
        (item) => item.threshold == threshold,
      );
      expect(progress.isUnlocked(achievement), isTrue);
      expect(
        AchievementProgress(
          catalog: catalog,
          completedTaskCount: threshold - 1,
        ).isUnlocked(achievement),
        isFalse,
      );
    }
  });
}
