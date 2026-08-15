import 'dart:convert';

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
  static const _profilesPrefix = 'app_profiles_v1_';
  static const _activeProfilePrefix = 'active_app_profile_v1_';

  Future<AppProfilesState> load({
    required String ownerId,
    required String fallbackName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final profilesKey = '$_profilesPrefix$ownerId';
    final activeKey = '$_activeProfilePrefix$ownerId';
    final profiles = _readProfiles(prefs.getString(profilesKey));

    if (profiles.isEmpty) {
      final initial = AppProfile(
        id: 'primary',
        name: _normaliseName(fallbackName),
      );
      await _save(prefs, profilesKey, activeKey, [initial], initial.id);
      return AppProfilesState(profiles: [initial], activeProfileId: initial.id);
    }

    final activeId = prefs.getString(activeKey);
    final selectedId = profiles.any((profile) => profile.id == activeId)
        ? activeId!
        : profiles.first.id;
    if (selectedId != activeId) {
      await prefs.setString(activeKey, selectedId);
    }
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
}
