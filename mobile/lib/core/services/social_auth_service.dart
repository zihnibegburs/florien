import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mimio/core/config/google_config.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class SocialAuthCredential {
  const SocialAuthCredential({
    required this.credential,
    this.displayName,
  });

  final AuthCredential credential;
  final String? displayName;
}

class GoogleAuthService {
  GoogleAuthService()
      : _googleSignIn = GoogleSignIn(
          clientId: GoogleConfig.iosClientId,
          serverClientId: GoogleConfig.webClientId,
          scopes: const ['email', 'profile'],
        );

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
}

class AppleAuthService {
  Future<bool> get isAvailable async {
    if (kIsWeb) return false;
    return SignInWithApple.isAvailable();
  }

  Future<SocialAuthCredential?> signIn() async {
    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final idToken = appleCredential.identityToken;
    if (idToken == null) {
      throw StateError('Apple sign-in failed: missing identity token');
    }

    final given = appleCredential.givenName;
    final family = appleCredential.familyName;
    final parts = [given, family].whereType<String>().where((s) => s.isNotEmpty);
    final displayName = parts.isEmpty ? null : parts.join(' ');

    return SocialAuthCredential(
      credential: OAuthProvider('apple.com').credential(
        idToken: idToken,
        rawNonce: rawNonce,
      ),
      displayName: displayName,
    );
  }

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
