import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:florien/features/onboarding/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('onboarding advances through questions and optional paywall', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Florien güncellemelerini almak ister misin?'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('onboarding-updates-next')),
      240,
    );
    await tester.tap(find.byKey(const ValueKey('onboarding-updates-next')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Görevlerimi hatırla'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('onboarding-choice-next')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ben nöroçeşitliyim'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('onboarding-choice-next')));
    await tester.pumpAndSettle();

    expect(find.text('Profesyonel gibi planla'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onboarding-continue-free')));
    await tester.pumpAndSettle();

    expect(find.text('Harika, hazırız!'), findsOneWidget);
    expect(find.text('Hadi başlayalım'), findsOneWidget);
  });
}
