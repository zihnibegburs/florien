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

  testWidgets('ratings up to three can submit issue and suggestion feedback', (
    tester,
  ) async {
    int? submittedRating;
    String? submittedIssue;
    String? submittedSuggestion;
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: FlorienTheme.light,
        home: Scaffold(
          body: StatisticsReviewCard(
            submitFeedback: (rating, issue, suggestion) async {
              submittedRating = rating;
              submittedIssue = issue;
              submittedSuggestion = suggestion;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('statistics-rating-2')));
    await tester.pumpAndSettle();

    expect(find.text('Yaşadığın sorun nedir?'), findsOneWidget);
    expect(find.text('Önerin nedir?'), findsOneWidget);
    final submit = find.byKey(
      const ValueKey('statistics-rating-submit-feedback'),
    );
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('statistics-rating-issue')),
      'Takvim bağlantısını bulamadım',
    );
    await tester.enterText(
      find.byKey(const ValueKey('statistics-rating-suggestion')),
      'Ayarlar ekranında daha görünür olabilir',
    );
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(submittedRating, 2);
    expect(submittedIssue, 'Takvim bağlantısını bulamadım');
    expect(submittedSuggestion, 'Ayarlar ekranında daha görünür olabilir');
    expect(
      find.text('Geri bildirimin bize ulaştı. Teşekkür ederiz!'),
      findsOneWidget,
    );
  });
}
