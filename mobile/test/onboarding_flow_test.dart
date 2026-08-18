import 'dart:convert';

import 'package:florien/features/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('test mode restarts a previously completed onboarding', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_preferences_guest': jsonEncode({
        'completed': true,
        'onboardingVersion': '1',
        'answers': {
          'ONB-Q1': {
            'questionId': 'ONB-Q1',
            'answerId': 'mind_overload',
            'answeredAt': '2026-08-18T15:30:00.000',
          },
        },
      }),
    });
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Bazen plan yapmak bile yorucu gelebilir.'),
      findsOneWidget,
    );
    expect(find.text('0/7'), findsOneWidget);
  });

  testWidgets('onboarding saves seven answers and advances automatically', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OnboardingScreen())),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Bazen plan yapmak bile yorucu gelebilir.'),
      findsOneWidget,
    );
    expect(find.text('0/7'), findsOneWidget);
    expect(find.text('Profesyonel gibi planla'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('onboarding-start')));
    await tester.pumpAndSettle();
    expect(
      find.text('Gün içinde en sık hangisini yaşıyorsun?'),
      findsOneWidget,
    );

    await tester.tap(find.text('Yapacaklarım kafamda birbirine giriyor'));
    await tester.pumpAndSettle();
    expect(find.text('1/7'), findsOneWidget);
    expect(
      find.text('Bir işe başlaman gerektiğinde genelde ne yapıyorsun?'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('onboarding-back')));
    await tester.pumpAndSettle();
    final selectedAnswer = find.byKey(
      const ValueKey('onboarding-answer-mind_overload'),
    );
    expect(
      find.descendant(
        of: selectedAnswer,
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Yapacaklarım kafamda birbirine giriyor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gözümde büyütüyorum'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DEHB tanısı aldım'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Birkaç gün iyi gidiyor, sonra bırakıyorum'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bir işin ne kadar süreceğini kestiremiyorum'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kendime yükleniyorum'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nereden başlayacağımı bilmek'));
    await tester.pumpAndSettle();

    expect(find.text('Yalnız değilsin.'), findsOneWidget);
    expect(find.text('Devam et'), findsOneWidget);
    expect(find.text('7/7'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final preferences = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(preferences.getString('onboarding_preferences_guest')!)
            as Map<String, dynamic>;
    final answers = stored['answers'] as Map<String, dynamic>;
    expect(stored['onboardingVersion'], '1');
    expect(answers, hasLength(7));
    expect(
      (answers['ONB-Q3'] as Map<String, dynamic>)['answerId'],
      'diagnosed',
    );
  });
}
