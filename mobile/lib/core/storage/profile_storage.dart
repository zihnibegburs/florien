import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppProfile {
  const AppProfile({required this.id, required this.name});

  final String id;
  final String name;

  AppProfile copyWith({String? name}) =>
      AppProfile(id: id, name: name ?? this.name);

  Map<String, String> toJson() => {'id': id, 'name': name};

  factory AppProfile.fromJson(Map<String, dynamic> json) =>
      AppProfile(id: json['id'] as String, name: json['name'] as String);
}

class AppProfilesState {
  const AppProfilesState({
    required this.profiles,
    required this.activeProfileId,
  });

  final List<AppProfile> profiles;
  final String activeProfileId;

  AppProfile get activeProfile =>
      profiles.firstWhere((profile) => profile.id == activeProfileId);
}

class ProfileStorage {
  ProfileStorage({FirebaseFirestore? firestore}) : _firestore = firestore;

  static const _profilesPrefix = 'app_profiles_v1_';
  static const _activeProfilePrefix = 'active_app_profile_v1_';

  final FirebaseFirestore? _firestore;

  Future<AppProfilesState> load({
    required String ownerId,
    required String fallbackName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final profilesKey = '$_profilesPrefix$ownerId';
    final activeKey = '$_activeProfilePrefix$ownerId';
    final profiles = _readProfiles(prefs.getString(profilesKey));

    final remote = await _loadRemote(ownerId);
    if (remote != null) {
      await _save(
        prefs,
        profilesKey,
        activeKey,
        remote.profiles,
        remote.activeProfileId,
      );
      return remote;
    }

    if (profiles.isEmpty) {
      final initial = AppProfile(
        id: 'primary',
        name: _normaliseName(fallbackName),
      );
      await _save(prefs, profilesKey, activeKey, [initial], initial.id);
      await _saveRemote(ownerId, [initial], initial.id);
      return AppProfilesState(profiles: [initial], activeProfileId: initial.id);
    }

    final activeId = prefs.getString(activeKey);
    final selectedId = profiles.any((profile) => profile.id == activeId)
        ? activeId!
        : profiles.first.id;
    if (selectedId != activeId) {
      await prefs.setString(activeKey, selectedId);
    }
    await _saveRemote(ownerId, profiles, selectedId);
    return AppProfilesState(profiles: profiles, activeProfileId: selectedId);
  }

  Future<AppProfilesState> create({
    required String ownerId,
    required String fallbackName,
    required String name,
  }) async {
    final current = await load(ownerId: ownerId, fallbackName: fallbackName);
    final profile = AppProfile(
      id: 'profile_${DateTime.now().microsecondsSinceEpoch}',
      name: _normaliseName(name),
    );
    final profiles = [...current.profiles, profile];
    return _persist(ownerId, profiles, current.activeProfileId);
  }

  Future<AppProfilesState> rename({
    required String ownerId,
    required String fallbackName,
    required String profileId,
    required String name,
  }) async {
    final current = await load(ownerId: ownerId, fallbackName: fallbackName);
    final profiles = current.profiles
        .map(
          (profile) => profile.id == profileId
              ? profile.copyWith(name: _normaliseName(name))
              : profile,
        )
        .toList();
    return _persist(ownerId, profiles, current.activeProfileId);
  }

  Future<AppProfilesState> select({
    required String ownerId,
    required String fallbackName,
    required String profileId,
  }) async {
    final current = await load(ownerId: ownerId, fallbackName: fallbackName);
    if (!current.profiles.any((profile) => profile.id == profileId)) {
      throw StateError('Profil bulunamadı.');
    }
    return _persist(ownerId, current.profiles, profileId);
  }

  Future<AppProfilesState> delete({
    required String ownerId,
    required String fallbackName,
    required String profileId,
  }) async {
    final current = await load(ownerId: ownerId, fallbackName: fallbackName);
    if (current.profiles.length <= 1) {
      throw StateError('En az bir profil kalmalıdır.');
    }
    final profiles = current.profiles
        .where((profile) => profile.id != profileId)
        .toList();
    final activeId = current.activeProfileId == profileId
        ? profiles.first.id
        : current.activeProfileId;
    return _persist(ownerId, profiles, activeId);
  }

  List<AppProfile> _readProfiles(String? raw) {
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((item) => AppProfile.fromJson(item as Map<String, dynamic>))
          .where((profile) => profile.name.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<AppProfilesState> _persist(
    String ownerId,
    List<AppProfile> profiles,
    String activeProfileId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await _save(
      prefs,
      '$_profilesPrefix$ownerId',
      '$_activeProfilePrefix$ownerId',
      profiles,
      activeProfileId,
    );
    await _saveRemote(ownerId, profiles, activeProfileId);
    return AppProfilesState(
      profiles: profiles,
      activeProfileId: activeProfileId,
    );
  }

  Future<void> _save(
    SharedPreferences prefs,
    String profilesKey,
    String activeKey,
    List<AppProfile> profiles,
    String activeProfileId,
  ) async {
    await prefs.setString(
      profilesKey,
      jsonEncode(profiles.map((profile) => profile.toJson()).toList()),
    );
    await prefs.setString(activeKey, activeProfileId);
  }

  String _normaliseName(String value) {
    final name = value.trim();
    return name.isEmpty ? 'Profilim' : name;
  }

  DocumentReference<Map<String, dynamic>>? _remoteRef(String ownerId) {
    final firestore = _firestore;
    if (firestore == null || ownerId == 'guest') return null;
    return firestore
        .collection('users')
        .doc(ownerId)
        .collection('app_data')
        .doc('profiles');
  }

  Future<AppProfilesState?> _loadRemote(String ownerId) async {
    final ref = _remoteRef(ownerId);
    if (ref == null) return null;
    try {
      final data = (await ref.get()).data();
      final rawProfiles = data?['profiles'];
      if (rawProfiles is! List) return null;
      final profiles = rawProfiles
          .whereType<Map>()
          .map(
            (item) => AppProfile.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .where((profile) => profile.name.trim().isNotEmpty)
          .toList();
      if (profiles.isEmpty) return null;
      final storedActiveId = data?['activeProfileId']?.toString();
      final activeId = profiles.any((profile) => profile.id == storedActiveId)
          ? storedActiveId!
          : profiles.first.id;
      return AppProfilesState(profiles: profiles, activeProfileId: activeId);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveRemote(
    String ownerId,
    List<AppProfile> profiles,
    String activeProfileId,
  ) async {
    final ref = _remoteRef(ownerId);
    if (ref == null) return;
    try {
      await ref.set({
        'profiles': profiles.map((profile) => profile.toJson()).toList(),
        'activeProfileId': activeProfileId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
