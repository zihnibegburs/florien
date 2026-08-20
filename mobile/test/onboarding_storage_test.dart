import 'dart:convert';

import 'package:florien/core/storage/onboarding_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryOnboardingRemoteStorage implements OnboardingRemoteStorage {
  final Map<String, OnboardingPreferences> values = {};

  @override
  Future<OnboardingPreferences> load(String userId) async =>
      values[userId] ?? const OnboardingPreferences();

  @override
  Future<void> save(String userId, OnboardingPreferences preferences) async {
    values[userId] = preferences;
  }
}

class _FailingOnboardingRemoteStorage implements OnboardingRemoteStorage {
  @override
  Future<OnboardingPreferences> load(String userId) async =>
      const OnboardingPreferences();

  @override
  Future<void> save(String userId, OnboardingPreferences preferences) =>
      Future<void>.error(StateError('offline'));
}

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

  test(
    'moves guest survey answers to the authenticated remote store',
    () async {
      final local = OnboardingStorage();
      final remote = _MemoryOnboardingRemoteStorage();
      final preferences = OnboardingPreferences(
        completed: true,
        answers: {
          'ONB-Q1': OnboardingAnswer(
            questionId: 'ONB-Q1',
            answerId: 'mind_overload',
            answeredAt: DateTime(2026, 8, 18, 15, 30),
          ),
        },
      );
      await local.save('guest', preferences);
      final repository = OnboardingPreferencesRepository(
        local: local,
        remote: remote,
      );

      final restored = await repository.loadAuthenticated('user-1');

      expect(restored.completed, isTrue);
      expect(restored.answerIdFor('ONB-Q1'), 'mind_overload');
      expect(remote.values['user-1']?.answerIdFor('ONB-Q1'), 'mind_overload');
      expect((await local.load('guest')).hasProgress, isFalse);
    },
  );

  test('keeps the guest survey when Firestore migration fails', () async {
    final local = OnboardingStorage();
    final preferences = OnboardingPreferences(
      answers: {
        'ONB-Q1': OnboardingAnswer(
          questionId: 'ONB-Q1',
          answerId: 'mind_overload',
          answeredAt: DateTime(2026, 8, 18, 15, 30),
        ),
      },
    );
    await local.save('guest', preferences);
    final repository = OnboardingPreferencesRepository(
      local: local,
      remote: _FailingOnboardingRemoteStorage(),
    );

    await expectLater(repository.loadAuthenticated('user-1'), throwsStateError);

    expect((await local.load('guest')).answerIdFor('ONB-Q1'), 'mind_overload');
  });
}
