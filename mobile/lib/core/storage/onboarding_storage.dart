import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPreferences {
  const OnboardingPreferences({
    this.completed = false,
    this.productUpdatesEnabled = true,
    this.primaryNeed,
    this.neuroProfile,
    this.paywallSeen = false,
  });

  final bool completed;
  final bool productUpdatesEnabled;
  final String? primaryNeed;
  final String? neuroProfile;
  final bool paywallSeen;

  OnboardingPreferences copyWith({
    bool? completed,
    bool? productUpdatesEnabled,
    String? primaryNeed,
    String? neuroProfile,
    bool? paywallSeen,
  }) => OnboardingPreferences(
    completed: completed ?? this.completed,
    productUpdatesEnabled: productUpdatesEnabled ?? this.productUpdatesEnabled,
    primaryNeed: primaryNeed ?? this.primaryNeed,
    neuroProfile: neuroProfile ?? this.neuroProfile,
    paywallSeen: paywallSeen ?? this.paywallSeen,
  );

  Map<String, dynamic> toJson() => {
    'completed': completed,
    'productUpdatesEnabled': productUpdatesEnabled,
    'primaryNeed': primaryNeed,
    'neuroProfile': neuroProfile,
    'paywallSeen': paywallSeen,
  };

  factory OnboardingPreferences.fromJson(Map<String, dynamic> json) =>
      OnboardingPreferences(
        completed: json['completed'] as bool? ?? false,
        productUpdatesEnabled: json['productUpdatesEnabled'] as bool? ?? true,
        primaryNeed: json['primaryNeed'] as String?,
        neuroProfile: json['neuroProfile'] as String?,
        paywallSeen: json['paywallSeen'] as bool? ?? false,
      );
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
}
