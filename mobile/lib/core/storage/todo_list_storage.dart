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
  static const _key = 'todo_list_definitions_v1';

  Future<List<TodoListDefinition>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
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

  Future<void> save(List<TodoListDefinition> lists) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(lists.map((list) => list.toJson()).toList()),
    );
  }
}
