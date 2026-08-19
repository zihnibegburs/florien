import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/todo/statistics_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('every rating shows thanks and high ratings open store', (
    tester,
  ) async {
    var storeOpenCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: FlorienTheme.light,
        home: Scaffold(
          body: StatisticsReviewCard(
            openStore: () async {
              storeOpenCount++;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('statistics-rating-3')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('statistics-rating-thanks-dialog')),
      findsOneWidget,
    );
    expect(find.text('Teşekkürler!'), findsOneWidget);
    expect(storeOpenCount, 0);
    await tester.tap(find.byKey(const ValueKey('statistics-rating-dismiss')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('statistics-rating-4')));
    await tester.pumpAndSettle();
    expect(storeOpenCount, 0);
    await tester.tap(
      find.byKey(const ValueKey('statistics-rating-open-store')),
    );
    await tester.pumpAndSettle();
    expect(storeOpenCount, 1);

    await tester.tap(find.byKey(const ValueKey('statistics-rating-5')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('statistics-rating-open-store')),
    );
    await tester.pumpAndSettle();
    expect(storeOpenCount, 2);
  });

  testWidgets('stars use high contrast outlined and selected states', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: FlorienTheme.light,
        home: const Scaffold(body: StatisticsReviewCard()),
      ),
    );

    final thirdStar = find.byKey(const ValueKey('statistics-rating-3'));
    expect(
      find.descendant(
        of: thirdStar,
        matching: find.byIcon(Icons.star_outline_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(thirdStar);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: thirdStar, matching: find.byIcon(Icons.star_rounded)),
      findsOneWidget,
    );
  });
}
