import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TodoListDefinition {
  const TodoListDefinition({
    required this.id,
    required this.name,
    this.description = '',
  });

  final String id;
  final String name;
  final String description;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
  };

  factory TodoListDefinition.fromJson(Map<String, dynamic> json) =>
      TodoListDefinition(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
      );
}

class TodoListStorage {
  TodoListStorage({FirebaseFirestore? firestore}) : _firestore = firestore;

  static const _legacyKey = 'todo_list_definitions_v1';
  static const _keyPrefix = 'todo_list_definitions_v2_';

  final FirebaseFirestore? _firestore;

  Future<List<TodoListDefinition>> load({required String profileScope}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getString(_keyFor(profileScope)) ??
        (profileScope.endsWith(':primary')
            ? prefs.getString(_legacyKey)
            : null);
    final local = _decode(raw);
    final remoteRef = _remoteRef(profileScope);
    if (remoteRef == null) return local;
    try {
      final remoteData = (await remoteRef.get()).data();
      if (remoteData?['lists'] case final List<dynamic> lists) {
        final remote = _decode(jsonEncode(lists));
        await _saveLocal(remote, profileScope);
        return remote;
      }
      if (local.isNotEmpty) await _saveRemote(local, profileScope);
    } catch (_) {
      return local;
    }
    return local;
  }

  Future<void> save(
    List<TodoListDefinition> lists, {
    required String profileScope,
  }) async {
    await _saveLocal(lists, profileScope);
    await _saveRemote(lists, profileScope);
  }

  String _keyFor(String profileScope) => '$_keyPrefix$profileScope';

  List<TodoListDefinition> _decode(String? raw) {
    if (raw == null) return const [];
    try {
      final value = jsonDecode(raw) as List<dynamic>;
      return value
          .map(
            (item) => TodoListDefinition.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveLocal(
    List<TodoListDefinition> lists,
    String profileScope,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyFor(profileScope),
      jsonEncode(lists.map((list) => list.toJson()).toList()),
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
        .doc('todo_lists');
  }

  Future<void> _saveRemote(
    List<TodoListDefinition> lists,
    String profileScope,
  ) async {
    final ref = _remoteRef(profileScope);
    if (ref == null) return;
    try {
      await ref.set({
        'lists': lists.map((list) => list.toJson()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
