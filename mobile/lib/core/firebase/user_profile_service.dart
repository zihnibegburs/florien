import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/firebase/firebase_providers.dart';

class UserProfileService {
  UserProfileService(this._db);

  final FirebaseFirestore _db;

  Future<void> ensureUserDocument({
    required User user,
    String? displayName,
    String? avatarColor,
  }) async {
    final ref = userDoc(_db, user.uid);
    if ((await ref.get()).exists) return;
    await ref.set({
      'email': user.email ?? '',
      'displayName': displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : (user.displayName ?? user.email?.split('@').first ?? 'User'),
      'avatarColor': avatarColor ?? '#4F52B2',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'settings': <String, dynamic>{},
    });
  }

  Future<Map<String, dynamic>?> loadProfile(String uid) async =>
      (await userDoc(_db, uid).get()).data();

  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? avatarColor,
  }) => userDoc(_db, uid).set({
    'updatedAt': FieldValue.serverTimestamp(),
    if (displayName != null) 'displayName': displayName.trim(),
    if (avatarColor != null) 'avatarColor': avatarColor,
  }, SetOptions(merge: true));

  Future<void> patchSettings(String uid, Map<String, dynamic> settingsPatch) =>
      userDoc(_db, uid).update({
        for (final entry in settingsPatch.entries)
          'settings.${entry.key}': entry.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
}

final userProfileServiceProvider = Provider<UserProfileService>((ref) {
  return UserProfileService(ref.watch(firestoreProvider));
});
