import 'dart:convert';

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
  static const _legacyKey = 'todo_list_definitions_v1';
  static const _keyPrefix = 'todo_list_definitions_v2_';

  Future<List<TodoListDefinition>> load({required String profileScope}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getString(_keyFor(profileScope)) ??
        (profileScope.endsWith(':primary')
            ? prefs.getString(_legacyKey)
            : null);
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

  Future<void> save(
    List<TodoListDefinition> lists, {
    required String profileScope,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyFor(profileScope),
      jsonEncode(lists.map((list) => list.toJson()).toList()),
    );
  }

  String _keyFor(String profileScope) => '$_keyPrefix$profileScope';
}
