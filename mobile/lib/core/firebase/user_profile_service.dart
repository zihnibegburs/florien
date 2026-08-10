import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/firebase/firebase_providers.dart';
import 'package:florien/core/models/achievement.dart';
import 'package:florien/core/models/adhd_models.dart';
import 'package:florien/core/storage/achievement_storage.dart';
import 'package:florien/core/storage/adhd_settings_storage.dart';
import 'package:florien/core/storage/settings_storage.dart';

/// Syncs language, theme, ADHD prefs, and achievements to `users/{uid}.settings`.
class UserProfileService {
  UserProfileService(this._db);

  final FirebaseFirestore _db;

  Future<void> ensureUserDocument({
    required User user,
    String? displayName,
    String? avatarColor,
  }) async {
    final ref = userDoc(_db, user.uid);
    final snap = await ref.get();
    if (snap.exists) return;

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

  Future<Map<String, dynamic>?> loadProfile(String uid) async {
    final snap = await userDoc(_db, uid).get();
    return snap.data();
  }

  Future<void> updateProfile({
    required String uid,
    String? displayName,
    String? avatarColor,
  }) async {
    await userDoc(_db, uid).set({
      'updatedAt': FieldValue.serverTimestamp(),
      if (displayName != null) 'displayName': displayName.trim(),
      if (avatarColor != null) 'avatarColor': avatarColor,
    }, SetOptions(merge: true));
  }

  Future<void> syncSettingsFromCloud({
    required String uid,
    required SettingsStorage settings,
    required AdhdSettingsStorage adhd,
    required AchievementStorage achievements,
  }) async {
    final data = await loadProfile(uid);
    final cloudSettings = data?['settings'] as Map<String, dynamic>?;
    if (cloudSettings == null || cloudSettings.isEmpty) {
      await pushLocalSettingsToCloud(
        uid: uid,
        settings: settings,
        adhd: adhd,
        achievements: achievements,
      );
      return;
    }

    final language = cloudSettings['language'] as String?;
    if (language != null && language.isNotEmpty) {
      await settings.setLanguage(language);
    }

    final theme = cloudSettings['themeMode'] as String?;
    if (theme != null) {
      await settings.setThemeMode(switch (theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      });
    }

    final adhdJson = cloudSettings['adhdPreferences'] as Map<String, dynamic>?;
    if (adhdJson != null) {
      await adhd.save(AdhdPreferences.fromJson(adhdJson));
    }

    final statsJson = cloudSettings['achievements'] as Map<String, dynamic>?;
    if (statsJson != null) {
      await achievements.save(uid, AchievementStats.fromJson(statsJson));
    }

    final unlocked = (cloudSettings['unlockedAchievementIds'] as List?)
        ?.map((e) => e.toString())
        .toSet();
    if (unlocked != null) {
      await adhd.saveUnlockedAchievementIds(uid, unlocked);
    }

    final imported = (cloudSettings['importedCalendarEventIds'] as List?)?.map(
      (e) => e.toString(),
    );
    if (imported != null) {
      await settings.markCalendarEventsImported(imported);
    }
  }

  Future<void> pushLocalSettingsToCloud({
    required String uid,
    required SettingsStorage settings,
    required AdhdSettingsStorage adhd,
    required AchievementStorage achievements,
  }) async {
    final language = await settings.getLanguage();
    final themeMode = await settings.getThemeMode();
    final theme = switch (themeMode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    final adhdPrefs = await adhd.load();
    final stats = await achievements.load(uid);
    final unlocked = await adhd.loadUnlockedAchievementIds(uid);
    final imported = await settings.getImportedCalendarEventIds();

    await userDoc(_db, uid).set({
      'settings': {
        'language': language,
        'themeMode': theme,
        'adhdPreferences': adhdPrefs.toJson(),
        'achievements': stats.toJson(),
        'unlockedAchievementIds': unlocked.toList(),
        'importedCalendarEventIds': imported.toList(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> patchSettings(
    String uid,
    Map<String, dynamic> settingsPatch,
  ) async {
    final updates = <String, dynamic>{
      for (final e in settingsPatch.entries) 'settings.${e.key}': e.value,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await userDoc(_db, uid).update(updates);
  }
}

final userProfileServiceProvider = Provider<UserProfileService>((ref) {
  return UserProfileService(ref.watch(firestoreProvider));
});
