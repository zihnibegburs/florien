import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:florien/core/firebase/firebase_providers.dart';
import 'package:florien/core/repositories/repositories.dart';
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
  if (mode == TaskStorageMode.cloud) {
    return _completeTaskInFirestore(
      taskId: taskId,
      userId: userId,
      profileId: profileId,
    );
  }
  await initLocalTaskStore();
  final local = await LocalTaskCollection.open(
    uid: userId,
    profileId: profileId,
  );
  final repository = TaskRepository(local);
  final task = await repository.getTaskById(taskId);
  if (task == null || task.isCompleted) return false;
  await repository.completeTask(taskId);
  return true;
}

Future<bool> _completeTaskInFirestore({
  required String taskId,
  required String userId,
  required String profileId,
}) async {
  final taskRef = tasksCol(
    FirebaseFirestore.instance,
    userId,
    profileId,
  ).doc(taskId);
  final task = await taskRef.get();
  if (!task.exists || task.data()?['status'] == 'COMPLETED') return false;

  await taskRef.update({
    'status': 'COMPLETED',
    'completedAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
  final parentTaskId = task.data()?['parentTaskId'] as String?;
  if (parentTaskId != null) {
    final siblings = await tasksCol(
      FirebaseFirestore.instance,
      userId,
      profileId,
    ).where('parentTaskId', isEqualTo: parentTaskId).get();
    final allCompleted = siblings.docs.every(
      (sibling) =>
          sibling.id == taskId || sibling.data()['status'] == 'COMPLETED',
    );
    if (allCompleted) {
      await tasksCol(
        FirebaseFirestore.instance,
        userId,
        profileId,
      ).doc(parentTaskId).update({
        'status': 'COMPLETED',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
  return true;
}
