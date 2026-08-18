import 'dart:convert';

import 'package:florien/core/storage/onboarding_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('stores answer identifiers and timestamps locally', () async {
    final answeredAt = DateTime(2026, 8, 18, 15, 30);
    final storage = OnboardingStorage();
    final preferences = OnboardingPreferences(
      answers: {
        'ONB-Q1': OnboardingAnswer(
          questionId: 'ONB-Q1',
          answerId: 'mind_overload',
          answeredAt: answeredAt,
        ),
      },
    );

    await storage.save('user-1', preferences);
    final restored = await storage.load('user-1');

    expect(restored.onboardingVersion, currentOnboardingVersion);
    expect(restored.answerIdFor('ONB-Q1'), 'mind_overload');
    expect(restored.answers['ONB-Q1']?.answeredAt, answeredAt);
  });

  test(
    'does not map incomplete answers from another question version',
    () async {
      SharedPreferences.setMockInitialValues({
        'onboarding_preferences_user-1': jsonEncode({
          'completed': false,
          'onboardingVersion': '0',
          'answers': {
            'OLD-Q1': {
              'questionId': 'OLD-Q1',
              'answerId': 'old-answer',
              'answeredAt': '2026-08-18T15:30:00.000',
            },
          },
        }),
      });

      final restored = await OnboardingStorage().load('user-1');

      expect(restored.completed, isFalse);
      expect(restored.onboardingVersion, currentOnboardingVersion);
      expect(restored.answers, isEmpty);
    },
  );
}
