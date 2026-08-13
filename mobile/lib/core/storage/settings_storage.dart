import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsStorage {
  static const _languageKey = 'app_language';
  static const _themeModeKey = 'app_theme_mode';

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

  static const _importedCalendarEventsKey = 'imported_calendar_event_ids';

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
}

final settingsStorageProvider = Provider<SettingsStorage>(
  (ref) => SettingsStorage(),
);
