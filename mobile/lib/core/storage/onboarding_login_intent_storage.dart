import 'package:shared_preferences/shared_preferences.dart';

enum OnboardingLoginIntent { firstTimeSetup, existingAccount }

class OnboardingLoginIntentStorage {
  static const _key = 'onboarding_login_intent';

  Future<void> setFirstTimeSetup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, 'first_time');
  }

  Future<void> setExistingAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, 'existing');
  }

  Future<OnboardingLoginIntent?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_key)) {
      'first_time' => OnboardingLoginIntent.firstTimeSetup,
      'existing' => OnboardingLoginIntent.existingAccount,
      _ => null,
    };
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
