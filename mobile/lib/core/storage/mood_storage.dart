import 'dart:convert';

import 'package:florien/core/models/mood_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MoodStorage {
  static const _entriesPrefix = 'mood_entries_v1_';
  static const _healthSyncPrefix = 'mood_health_sync_v1_';

  Future<List<MoodEntry>> load(String profileScope) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_entriesPrefix$profileScope');
    if (raw == null) return const [];
    try {
      final entries = (jsonDecode(raw) as List<dynamic>)
          .map((item) => MoodEntry.fromJson(item as Map<String, dynamic>))
          .toList();
      entries.sort((first, second) => first.date.compareTo(second.date));
      return entries;
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(String profileScope, List<MoodEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final sorted = [...entries]
      ..sort((first, second) => first.date.compareTo(second.date));
    await prefs.setString(
      '$_entriesPrefix$profileScope',
      jsonEncode(sorted.map((entry) => entry.toJson()).toList()),
    );
  }

  Future<bool> isHealthSyncEnabled(String profileScope) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_healthSyncPrefix$profileScope') ?? false;
  }

  Future<void> setHealthSyncEnabled(String profileScope, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_healthSyncPrefix$profileScope', enabled);
  }
}
