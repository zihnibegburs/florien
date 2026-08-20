import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const currentOnboardingVersion = '1';

class OnboardingAnswer {
  const OnboardingAnswer({
    required this.questionId,
    required this.answerId,
    required this.answeredAt,
  });

  final String questionId;
  final String answerId;
  final DateTime answeredAt;

  Map<String, dynamic> toJson() => {
    'questionId': questionId,
    'answerId': answerId,
    'answeredAt': answeredAt.toIso8601String(),
  };

  factory OnboardingAnswer.fromJson(
    String questionId,
    Map<String, dynamic> json,
  ) => OnboardingAnswer(
    questionId: questionId,
    answerId: json['answerId'] as String,
    answeredAt: DateTime.parse(json['answeredAt'] as String),
  );
}

class OnboardingPreferences {
  const OnboardingPreferences({
    this.completed = false,
    this.onboardingVersion = currentOnboardingVersion,
    this.answers = const {},
  });

  final bool completed;
  final String onboardingVersion;
  final Map<String, OnboardingAnswer> answers;

  bool get hasProgress => completed || answers.isNotEmpty;

  String? answerIdFor(String questionId) => answers[questionId]?.answerId;

  OnboardingPreferences copyWith({
    bool? completed,
    String? onboardingVersion,
    Map<String, OnboardingAnswer>? answers,
  }) => OnboardingPreferences(
    completed: completed ?? this.completed,
    onboardingVersion: onboardingVersion ?? this.onboardingVersion,
    answers: answers ?? this.answers,
  );

  Map<String, dynamic> toJson() => {
    'completed': completed,
    'onboardingVersion': onboardingVersion,
    'answers': answers.map(
      (questionId, answer) => MapEntry(questionId, answer.toJson()),
    ),
  };

  factory OnboardingPreferences.fromJson(Map<String, dynamic> json) {
    final completed = json['completed'] as bool? ?? false;
    final savedVersion = json['onboardingVersion'] as String?;
    if (savedVersion != currentOnboardingVersion) {
      return OnboardingPreferences(completed: completed);
    }

    final answers = <String, OnboardingAnswer>{};
    final encodedAnswers = json['answers'];
    if (encodedAnswers is Map) {
      for (final entry in encodedAnswers.entries) {
        if (entry.key is! String || entry.value is! Map) continue;
        try {
          final questionId = entry.key as String;
          answers[questionId] = OnboardingAnswer.fromJson(
            questionId,
            Map<String, dynamic>.from(entry.value as Map),
          );
        } catch (_) {}
      }
    }

    return OnboardingPreferences(
      completed: completed,
      onboardingVersion: currentOnboardingVersion,
      answers: answers,
    );
  }
}

class OnboardingStorage {
  static const _keyPrefix = 'onboarding_preferences_';

  Future<OnboardingPreferences> load(String ownerId) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString('$_keyPrefix$ownerId');
    if (encoded == null) return const OnboardingPreferences();
    try {
      return OnboardingPreferences.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
    } catch (_) {
      return const OnboardingPreferences();
    }
  }

  Future<void> save(String ownerId, OnboardingPreferences preferences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_keyPrefix$ownerId',
      jsonEncode(preferences.toJson()),
    );
  }

  Future<void> clear(String ownerId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_keyPrefix$ownerId');
  }
}

abstract interface class OnboardingRemoteStorage {
  Future<OnboardingPreferences> load(String userId);

  Future<void> save(String userId, OnboardingPreferences preferences);
}

class OnboardingPreferencesRepository {
  OnboardingPreferencesRepository({
    required OnboardingStorage local,
    required OnboardingRemoteStorage remote,
  }) : _local = local,
       _remote = remote;

  final OnboardingStorage _local;
  final OnboardingRemoteStorage _remote;

  Future<OnboardingPreferences> loadAuthenticated(String userId) async {
    final guestPreferences = await _local.load('guest');
    if (guestPreferences.hasProgress) {
      await _remote.save(userId, guestPreferences);
      await _local.clear('guest');
      return guestPreferences;
    }
    return _remote.load(userId);
  }

  Future<void> saveAuthenticated(
    String userId,
    OnboardingPreferences preferences,
  ) => _remote.save(userId, preferences);
}
