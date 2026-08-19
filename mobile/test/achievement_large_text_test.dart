import 'package:florien/core/models/achievement.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/todo/achievement_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('collection remains stable with large text', (tester) async {
    final catalog = await AchievementCatalog.load();
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: FlorienTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(430, 900),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: AchievementCollection(
                progress: AchievementProgress(
                  catalog: catalog,
                  completedTaskCount: 50,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Başarılar'), findsOneWidget);
    expect(find.text('25 kaldı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
