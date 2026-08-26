import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:florien/core/firebase/firebase_providers.dart';
import 'package:florien/core/repositories/repositories.dart';
import 'package:florien/core/storage/firestore_task_collection.dart';
import 'package:florien/core/storage/local_task_collection.dart';
import 'package:florien/core/storage/task_storage_mode.dart';

/// Completes a task from a background isolate (home-screen widget).
Future<bool> completeTaskFromBackground({
  required String taskId,
  required String userId,
  required String profileId,
}) async {
  final mode = await TaskStorageModeStore().load(
    uid: userId,
    profileId: profileId,
  );
  final TaskRepository repository;
  if (mode == TaskStorageMode.cloud) {
    repository = TaskRepository(
      FirestoreTaskCollection(
        tasksCol(FirebaseFirestore.instance, userId, profileId),
      ),
    );
  } else {
    await initLocalTaskStore();
    repository = TaskRepository(
      await LocalTaskCollection.open(uid: userId, profileId: profileId),
    );
  }
  final task = await repository.getTaskById(taskId);
  if (task == null || task.isCompleted) return false;
  await repository.completeTask(taskId);
  return true;
}
