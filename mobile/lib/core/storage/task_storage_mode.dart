import 'package:shared_preferences/shared_preferences.dart';

enum TaskStorageMode { local, cloud }

class TaskStorageModeStore {
  static const _keyPrefix = 'task_storage_mode_v1_';

  Future<TaskStorageMode?> load({
    required String uid,
    required String profileId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return parseTaskStorageMode(prefs.getString(_key(uid, profileId)));
  }

  Future<void> save({
    required String uid,
    required String profileId,
    required TaskStorageMode mode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(uid, profileId), mode.name);
  }

  String _key(String uid, String profileId) => '$_keyPrefix${uid}_$profileId';
}

TaskStorageMode? parseTaskStorageMode(String? raw) => switch (raw) {
  'local' => TaskStorageMode.local,
  'cloud' => TaskStorageMode.cloud,
  _ => null,
};
