import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/firebase/user_profile_service.dart';
import 'package:florien/core/storage/settings_storage.dart';

const supportedLanguageCodes = ['en', 'tr'];

final appLanguageProvider = AsyncNotifierProvider<AppLanguageNotifier, String>(
  AppLanguageNotifier.new,
);

class AppLanguageNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() => ref.read(settingsStorageProvider).getLanguage();

  Future<void> setLanguage(String code) async {
    await ref.read(settingsStorageProvider).setLanguage(code);
    state = AsyncData(code);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await ref.read(userProfileServiceProvider).patchSettings(uid, {
          'language': code,
        });
      } catch (_) {}
    }
  }
}

class S {
  const S(this.lang);
  final String lang;

  String _text(String en, String tr) => lang == 'tr' ? tr : en;

  String get loginTagline =>
      _text('A calm place for your tasks', 'Görevlerin için sade bir alan');
  String get email => _text('Email', 'E-posta');
  String get emailRequired => _text('Email is required', 'E-posta gerekli');
  String get password => _text('Password', 'Şifre');
  String get passwordMin6 => _text('At least 6 characters', 'En az 6 karakter');
  String get login => _text('Log in', 'Giriş Yap');
  String get orContinueWith =>
      _text('or continue with', 'veya şununla devam et');
  String get loginWithGoogle =>
      _text('Continue with Google', 'Google ile devam et');
  String get loginWithApple =>
      _text('Continue with Apple', 'Apple ile devam et');
  String get noAccountRegister => _text('Create an account', 'Hesap oluştur');
  String get createAccount => _text('Create account', 'Hesap oluştur');
  String get registerSubtitle => _text(
    'Start keeping your tasks together.',
    'Görevlerini tek yerde toplamaya başla.',
  );
  String get yourName => _text('Your name', 'Adın');
  String get nameMin2 =>
      _text('Enter at least 2 characters', 'En az 2 karakter gir');
  String get validEmail =>
      _text('Enter a valid email', 'Geçerli bir e-posta gir');
  String get register => _text('Register', 'Kayıt ol');
}

final stringsProvider = Provider<S>((ref) {
  return S(ref.watch(appLanguageProvider).valueOrNull ?? 'tr');
});
