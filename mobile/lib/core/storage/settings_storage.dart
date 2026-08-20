import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:florien/core/firebase/firebase_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  const NotificationPreferences({
    this.taskRemindersEnabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
  });

  final bool taskRemindersEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
}

class LiveActivityPreferences {
  const LiveActivityPreferences({this.focusTimerEnabled = true});

  final bool focusTimerEnabled;

  LiveActivityPreferences copyWith({bool? focusTimerEnabled}) =>
      LiveActivityPreferences(
        focusTimerEnabled: focusTimerEnabled ?? this.focusTimerEnabled,
      );
}

class SettingsStorage {
  SettingsStorage({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore,
      _auth = auth;

  static const _languageKey = 'app_language';
  static const _themeModeKey = 'app_theme_mode';
  static const _taskRemindersEnabledKey = 'task_reminders_enabled';
  static const _notificationSoundEnabledKey = 'notification_sound_enabled';
  static const _notificationVibrationEnabledKey =
      'notification_vibration_enabled';
  static const _notificationPermissionIntroKey =
      'notification_permission_intro_completed';
  static const _updatesConsentIntroKey = 'updates_consent_intro_completed';
  static const _marketingUpdatesEnabledKey = 'marketing_updates_enabled';
  static const _liveFocusKey = 'live_activity_focus_enabled';

  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;

  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? 'tr';
  }

  Future<void> setLanguage(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, code);
  }

  Future<bool> hasThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_themeModeKey);
  }

  Future<ThemeMode> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_themeModeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_themeModeKey, value);
  }

  Future<NotificationPreferences> getNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPreferences(
      taskRemindersEnabled: prefs.getBool(_taskRemindersEnabledKey) ?? true,
      soundEnabled: prefs.getBool(_notificationSoundEnabledKey) ?? true,
      vibrationEnabled: prefs.getBool(_notificationVibrationEnabledKey) ?? true,
    );
  }

  Future<void> setTaskRemindersEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_taskRemindersEnabledKey, enabled);
  }

  Future<void> setNotificationSoundEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationSoundEnabledKey, enabled);
  }

  Future<void> setNotificationVibrationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationVibrationEnabledKey, enabled);
  }

  Future<bool> isNotificationPermissionIntroCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scopedKey(_notificationPermissionIntroKey)) ?? false;
  }

  Future<void> markNotificationPermissionIntroCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey(_notificationPermissionIntroKey), true);
  }

  Future<bool> isUpdatesConsentIntroCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scopedKey(_updatesConsentIntroKey)) ?? false;
  }

  Future<bool> isMarketingUpdatesEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scopedKey(_marketingUpdatesEnabledKey)) ?? false;
  }

  Future<void> setMarketingUpdatesEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scopedKey(_marketingUpdatesEnabledKey), enabled);
    await prefs.setBool(_scopedKey(_updatesConsentIntroKey), true);

    final ref = _preferencesRemoteRef();
    if (ref == null) return;
    try {
      await ref.set({
        'marketingUpdatesEnabled': enabled,
        'marketingConsentUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // The device preference remains authoritative until the next update.
    }
  }

  Future<LiveActivityPreferences> getLiveActivityPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    return LiveActivityPreferences(
      focusTimerEnabled: prefs.getBool(_liveFocusKey) ?? true,
    );
  }

  Future<void> setLiveActivityPreferences(LiveActivityPreferences value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_liveFocusKey, value.focusTimerEnabled);
  }

  static const _importedCalendarEventsKey = 'imported_calendar_event_ids';
  static const _calendarConnectionPrefix = 'calendar_connection_';

  Future<Set<String>> getImportedCalendarEventIds() async {
    final prefs = await SharedPreferences.getInstance();
    final localKey = _scopedKey(_importedCalendarEventsKey);
    final legacy = prefs.getStringList(_importedCalendarEventsKey);
    final local = (prefs.getStringList(localKey) ?? legacy ?? const <String>[])
        .toSet();
    if (legacy != null) {
      await prefs.setStringList(localKey, local.toList());
      await prefs.remove(_importedCalendarEventsKey);
    }
    final ref = _calendarRemoteRef();
    if (ref == null) return local;
    try {
      final data = (await ref.get()).data();
      final remote =
          (data?['importedEventIds'] as List?)
              ?.map((value) => value.toString())
              .toSet() ??
          <String>{};
      final merged = {...local, ...remote};
      await prefs.setStringList(localKey, merged.toList());
      await prefs.remove(_importedCalendarEventsKey);
      if (merged.length != remote.length) await _saveImportedIds(merged);
      return merged;
    } catch (_) {
      return local;
    }
  }

  Future<void> markCalendarEventsImported(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    final current = await getImportedCalendarEventIds();
    current.addAll(ids);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _scopedKey(_importedCalendarEventsKey),
      current.toList(),
    );
    await _saveImportedIds(current);
  }

  Future<String?> getCalendarConnectionDetail(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    final legacyKey = '$_calendarConnectionPrefix$provider';
    final localKey = _scopedKey(legacyKey);
    final legacy = prefs.getString(legacyKey);
    final local = prefs.getString(localKey) ?? legacy;
    if (legacy != null && local != null) {
      await prefs.setString(localKey, local);
      await prefs.remove(legacyKey);
    }
    final ref = _calendarRemoteRef();
    if (ref == null) return local;
    try {
      final data = (await ref.get()).data();
      final connections = data?['connections'];
      final remote = connections is Map
          ? connections[provider]?.toString()
          : null;
      if (remote != null && remote.isNotEmpty) {
        await prefs.setString(localKey, remote);
        await prefs.remove(legacyKey);
        return remote;
      }
      if (local != null) await _saveConnection(provider, local);
      return local;
    } catch (_) {
      return local;
    }
  }

  Future<void> setCalendarConnectionDetail(
    String provider,
    String detail,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scopedKey('$_calendarConnectionPrefix$provider'),
      detail,
    );
    await _saveConnection(provider, detail);
  }

  Future<void> clearCalendarConnection(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    final legacyKey = '$_calendarConnectionPrefix$provider';
    await prefs.remove(legacyKey);
    await prefs.remove(_scopedKey(legacyKey));
    final ref = _calendarRemoteRef();
    if (ref == null) return;
    try {
      await ref.update({'connections.$provider': FieldValue.delete()});
    } catch (_) {}
  }

  String _scopedKey(String base) {
    final uid = _auth?.currentUser?.uid;
    return uid == null ? '${base}_guest' : '${base}_$uid';
  }

  DocumentReference<Map<String, dynamic>>? _calendarRemoteRef() {
    final firestore = _firestore;
    final uid = _auth?.currentUser?.uid;
    if (firestore == null || uid == null) return null;
    return firestore
        .collection('users')
        .doc(uid)
        .collection('app_data')
        .doc('calendar');
  }

  DocumentReference<Map<String, dynamic>>? _preferencesRemoteRef() {
    final firestore = _firestore;
    final uid = _auth?.currentUser?.uid;
    if (firestore == null || uid == null) return null;
    return firestore
        .collection('users')
        .doc(uid)
        .collection('app_data')
        .doc('preferences');
  }

  Future<void> _saveImportedIds(Set<String> ids) async {
    final ref = _calendarRemoteRef();
    if (ref == null) return;
    try {
      await ref.set({
        'importedEventIds': ids.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _saveConnection(String provider, String detail) async {
    final ref = _calendarRemoteRef();
    if (ref == null) return;
    try {
      await ref.set({
        'connections': {provider: detail},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}

final settingsStorageProvider = Provider<SettingsStorage>(
  (ref) => SettingsStorage(
    firestore: ref.watch(optionalFirestoreProvider),
    auth: ref.watch(optionalFirebaseAuthProvider),
  ),
);
