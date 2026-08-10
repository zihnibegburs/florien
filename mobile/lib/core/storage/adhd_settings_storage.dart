import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/firebase/user_profile_service.dart';
import 'package:florien/core/models/adhd_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdhdSettingsStorage {
  static const _prefsKey = 'adhd_preferences';
  static const _legacyUnlockedAchievementsKey = 'unlocked_achievement_ids';

  static String _unlockedAchievementsKey(String userId) => 'unlocked_achievement_ids_$userId';

  Future<AdhdPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return const AdhdPreferences();
    try {
      return AdhdPreferences.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AdhdPreferences();
    }
  }

  Future<void> save(AdhdPreferences prefs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_prefsKey, jsonEncode(prefs.toJson()));
  }

  Future<Set<String>> loadUnlockedAchievementIds(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyUnlockedAchievementsKey);
    return prefs.getStringList(_unlockedAchievementsKey(userId))?.toSet() ?? {};
  }

  Future<void> saveUnlockedAchievementIds(String userId, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_unlockedAchievementsKey(userId), ids.toList());
  }

  Future<void> clearUnlockedAchievementIds(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_unlockedAchievementsKey(userId));
  }
}

final adhdSettingsStorageProvider = Provider<AdhdSettingsStorage>((ref) => AdhdSettingsStorage());

final adhdPreferencesProvider =
    AsyncNotifierProvider<AdhdPreferencesNotifier, AdhdPreferences>(AdhdPreferencesNotifier.new);

class AdhdPreferencesNotifier extends AsyncNotifier<AdhdPreferences> {
  @override
  Future<AdhdPreferences> build() async {
    return ref.read(adhdSettingsStorageProvider).load();
  }

  Future<void> patch(AdhdPreferences Function(AdhdPreferences) fn) async {
    final current = state.valueOrNull ?? await ref.read(adhdSettingsStorageProvider).load();
    final updated = fn(current);
    await ref.read(adhdSettingsStorageProvider).save(updated);
    state = AsyncData(updated);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await ref.read(userProfileServiceProvider).patchSettings(uid, {
          'adhdPreferences': updated.toJson(),
        });
      } catch (_) {}
    }
  }
}
