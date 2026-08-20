import 'package:florien/core/models/achievement.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/todo/achievement_collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AchievementCatalog catalog;

  setUpAll(() async => catalog = await AchievementCatalog.load());

  testWidgets('collection exposes unlocked and locked states to VoiceOver', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: FlorienTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AchievementCollection(
              progress: AchievementProgress(
                catalog: catalog,
                completedTaskCount: 10,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.bySemanticsLabel('İlk adım, 1 görev, açıldı'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('achievement-list')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Akış, 15 görev, kilitli'), findsOneWidget);
    expect(find.text('5 kaldı'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('opening achievements does not show a delayed popup', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          achievementProgressProvider.overrideWith(
            (ref) =>
                AchievementProgress(catalog: catalog, completedTaskCount: 10),
          ),
        ],
        child: MaterialApp(
          theme: FlorienTheme.light,
          home: const Scaffold(
            body: SingleChildScrollView(child: AchievementSection()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('achievement-celebration')), findsNothing);
    expect(find.byKey(const ValueKey('achievement-list')), findsOneWidget);
  });
}
