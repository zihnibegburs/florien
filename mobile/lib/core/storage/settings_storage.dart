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

class SettingsStorage {
  static const _languageKey = 'app_language';
  static const _themeModeKey = 'app_theme_mode';
  static const _taskRemindersEnabledKey = 'task_reminders_enabled';
  static const _notificationSoundEnabledKey = 'notification_sound_enabled';
  static const _notificationVibrationEnabledKey =
      'notification_vibration_enabled';

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

  static const _importedCalendarEventsKey = 'imported_calendar_event_ids';
  static const _calendarConnectionPrefix = 'calendar_connection_';

  Future<Set<String>> getImportedCalendarEventIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_importedCalendarEventsKey)?.toSet() ?? {};
  }

  Future<void> markCalendarEventsImported(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current =
        prefs.getStringList(_importedCalendarEventsKey)?.toSet() ?? {};
    current.addAll(ids);
    await prefs.setStringList(_importedCalendarEventsKey, current.toList());
  }

  Future<String?> getCalendarConnectionDetail(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_calendarConnectionPrefix$provider');
  }

  Future<void> setCalendarConnectionDetail(
    String provider,
    String detail,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_calendarConnectionPrefix$provider', detail);
  }

  Future<void> clearCalendarConnection(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_calendarConnectionPrefix$provider');
  }
}

final settingsStorageProvider = Provider<SettingsStorage>(
  (ref) => SettingsStorage(),
);
