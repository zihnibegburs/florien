import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:florien/core/models/mood_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MoodStorage {
  MoodStorage({FirebaseFirestore? firestore}) : _firestore = firestore;

  static const _entriesPrefix = 'mood_entries_v1_';
  static const _healthSyncPrefix = 'mood_health_sync_v1_';

  final FirebaseFirestore? _firestore;

  Future<List<MoodEntry>> load(String profileScope) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_entriesPrefix$profileScope');
    final local = _decode(raw);
    final remoteRef = _remoteRef(profileScope);
    if (remoteRef == null) return local;
    try {
      final remoteData = (await remoteRef.get()).data();
      if (remoteData?['entries'] case final List<dynamic> entries) {
        final remote = _decode(jsonEncode(entries));
        await _saveLocal(profileScope, remote);
        return remote;
      }
      if (local.isNotEmpty) await _saveRemote(profileScope, local);
    } catch (_) {
      return local;
    }
    return local;
  }

  Future<void> save(String profileScope, List<MoodEntry> entries) async {
    final sorted = [...entries]
      ..sort((first, second) => first.date.compareTo(second.date));
    await _saveLocal(profileScope, sorted);
    await _saveRemote(profileScope, sorted);
  }

  List<MoodEntry> _decode(String? raw) {
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

  Future<void> _saveLocal(String profileScope, List<MoodEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_entriesPrefix$profileScope',
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }

  DocumentReference<Map<String, dynamic>>? _remoteRef(String profileScope) {
    final firestore = _firestore;
    final separator = profileScope.indexOf(':');
    if (firestore == null || separator <= 0) return null;
    final userId = profileScope.substring(0, separator);
    final profileId = profileScope.substring(separator + 1);
    if (userId == 'guest' || profileId.isEmpty) return null;
    return firestore
        .collection('users')
        .doc(userId)
        .collection('profiles')
        .doc(profileId)
        .collection('app_data')
        .doc('mood_entries');
  }

  Future<void> _saveRemote(String profileScope, List<MoodEntry> entries) async {
    final ref = _remoteRef(profileScope);
    if (ref == null) return;
    try {
      await ref.set({
        'entries': entries.map((entry) => entry.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
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
