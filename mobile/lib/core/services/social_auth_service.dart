import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:florien/core/l10n/app_strings.dart';

class SocialAuthCredential {
  const SocialAuthCredential({required this.credential, this.displayName});

  final AuthCredential credential;
  final String? displayName;
}

class GoogleAuthService {
  GoogleAuthService()
    : _googleSignIn = GoogleSignIn(scopes: const ['email', 'profile']);

  final GoogleSignIn _googleSignIn;

  Future<SocialAuthCredential?> signIn() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;

    final auth = await account.authentication;
    if (auth.idToken == null) {
      throw StateError('Google sign-in failed: missing id token');
    }

    return SocialAuthCredential(
      credential: GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      ),
      displayName: account.displayName,
    );
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      // There may be no active Google account to revoke, but the local
      // account selection still needs to be cleared.
      await signOut();
    }
  }
}

class AppleAuthService {
  Future<bool> get isAvailable async {
    if (kIsWeb) return false;
    return SignInWithApple.isAvailable();
  }

  Future<SocialAuthCredential?> signIn() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final AuthorizationCredentialAppleID appleCredential;
    try {
      appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) return null;
      throw StateError(_appleSignInMessage(error.code.name));
    }

    final idToken = appleCredential.identityToken;
    final authorizationCode = appleCredential.authorizationCode;
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        ActiveLanguage.s('Apple ile giriş başarısız oldu. Tekrar dene.'),
      );
    }

    final given = appleCredential.givenName;
    final family = appleCredential.familyName;
    final parts = [
      given,
      family,
    ].whereType<String>().where((s) => s.isNotEmpty);
    final displayName = parts.isEmpty ? null : parts.join(' ');

    return SocialAuthCredential(
      credential: OAuthProvider('apple.com').credential(
        idToken: idToken,
        rawNonce: rawNonce,
        // firebase_auth 5.2+ rejects Apple credentials without this.
        accessToken: authorizationCode,
      ),
      displayName: displayName,
    );
  }

  String _appleSignInMessage(String code) => switch (code) {
    'failed' || 'invalidResponse' || 'notHandled' || 'notInteractive' =>
      ActiveLanguage.s('Apple ile giriş tamamlanamadı. Tekrar dene.'),
    'unknown' => ActiveLanguage.s('Apple ile giriş şu anda kullanılamıyor.'),
    _ => ActiveLanguage.s('Apple ile giriş başarısız oldu. Tekrar dene.'),
  };

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

Object friendlySocialAuthError(Object error) {
  if (error is FirebaseAuthException) {
    return StateError(switch (error.code) {
      'invalid-credential' || 'invalid-verification-code' => ActiveLanguage.s(
        'Apple ile giriş doğrulanamadı. Tekrar dene.',
      ),
      'account-exists-with-different-credential' => ActiveLanguage.s(
        'Bu e-posta başka bir giriş yöntemiyle kayıtlı.',
      ),
      'user-disabled' => ActiveLanguage.s('Bu hesap devre dışı bırakılmış.'),
      'network-request-failed' => ActiveLanguage.s(
        'Bağlantı kurulamadı. İnternetini kontrol et.',
      ),
      'operation-not-allowed' => ActiveLanguage.s(
        'Apple ile giriş şu anda kapalı. Daha sonra dene.',
      ),
      _ => ActiveLanguage.s('Giriş başarısız oldu. Tekrar dene.'),
    });
  }
  return error;
}
