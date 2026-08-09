import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mimio/core/firebase/firebase_providers.dart';
import 'package:mimio/core/firebase/user_profile_service.dart';
import 'package:mimio/core/models/adhd_models.dart';
import 'package:mimio/core/models/models.dart';
import 'package:mimio/core/models/recurrence.dart';
import 'package:mimio/core/platform/siri_sync_service.dart';
import 'package:mimio/core/storage/achievement_storage.dart';
import 'package:mimio/core/storage/adhd_settings_storage.dart';
import 'package:mimio/core/storage/settings_storage.dart';
import 'package:mimio/core/utils/recurrence_generator.dart';
import 'package:mimio/firebase_options.dart';

class AuthRepository {
  AuthRepository({
    required FirebaseAuth auth,
    required UserProfileService profiles,
    required SettingsStorage settings,
    required AdhdSettingsStorage adhd,
    required AchievementStorage achievements,
  }) : _auth = auth,
       _profiles = profiles,
       _settings = settings,
       _adhd = adhd,
       _achievements = achievements;

  final FirebaseAuth _auth;
  final UserProfileService _profiles;
  final SettingsStorage _settings;
  final AdhdSettingsStorage _adhd;
  final AchievementStorage _achievements;

  void _ensureConfigured() {
    if (!DefaultFirebaseOptions.isConfigured) {
      throw StateError(
        'Firebase henüz yapılandırılmadı. mobile/lib/firebase_options.dart '
        'dosyasını flutterfire configure ile doldur.',
      );
    }
  }

  Future<AuthResponse> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _ensureConfigured();
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;
    await user.updateDisplayName(displayName.trim());
    await _profiles.ensureUserDocument(user: user, displayName: displayName);
    await _syncAfterSignIn(user);
    return authResponseFromUser(user, displayNameOverride: displayName.trim());
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    _ensureConfigured();
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;
    await _profiles.ensureUserDocument(user: user);
    await _syncAfterSignIn(user);
    return authResponseFromUser(user);
  }

  Future<AuthResponse> signInWithCredential(
    AuthCredential credential, {
    String? displayName,
  }) async {
    _ensureConfigured();
    final cred = await _auth.signInWithCredential(credential);
    final user = cred.user!;
    if (displayName != null &&
        displayName.trim().isNotEmpty &&
        (user.displayName == null || user.displayName!.trim().isEmpty)) {
      await user.updateDisplayName(displayName.trim());
    }
    await _profiles.ensureUserDocument(user: user, displayName: displayName);
    await _syncAfterSignIn(user);
    return authResponseFromUser(user, displayNameOverride: displayName);
  }

  Future<AuthResponse?> getMe() async {
    if (!DefaultFirebaseOptions.isConfigured) return null;
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      await user.getIdToken();
      await _profiles.ensureUserDocument(user: user);
      await _syncAfterSignIn(user);
      return authResponseFromUser(user);
    } catch (_) {
      await _auth.signOut();
      await SiriSyncService.syncCredentials();
      return null;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    await SiriSyncService.syncCredentials();
  }

  Future<AuthResponse> updateProfile({
    String? displayName,
    String? avatarColor,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Not signed in');

    if (displayName != null) {
      await user.updateDisplayName(displayName.trim());
    }
    await _profiles.updateProfile(
      uid: user.uid,
      displayName: displayName,
      avatarColor: avatarColor,
    );
    return authResponseFromUser(user, displayNameOverride: displayName);
  }

  Future<AuthResponse> authResponseFromUser(
    User user, {
    String? displayNameOverride,
  }) async {
    final profile = await _profiles.loadProfile(user.uid);
    final token = await user.getIdToken() ?? '';
    await SiriSyncService.syncCredentials(token: token);

    return AuthResponse(
      token: token,
      userId: user.uid,
      email: user.email ?? profile?['email'] as String? ?? '',
      displayName: displayNameOverride?.trim().isNotEmpty == true
          ? displayNameOverride!.trim()
          : (profile?['displayName'] as String? ??
                user.displayName ??
                user.email?.split('@').first ??
                'User'),
      avatarColor: profile?['avatarColor'] as String? ?? '#4F52B2',
    );
  }

  Future<void> _syncAfterSignIn(User user) async {
    await _profiles.syncSettingsFromCloud(
      uid: user.uid,
      settings: _settings,
      adhd: _adhd,
      achievements: _achievements,
    );
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    profiles: ref.watch(userProfileServiceProvider),
    settings: ref.watch(settingsStorageProvider),
    adhd: ref.watch(adhdSettingsStorageProvider),
    achievements: ref.watch(achievementStorageProvider),
  );
});

class TaskRepository {
  TaskRepository(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _tasks => tasksCol(_db, _uid);

  Future<List<TaskModel>> getInbox() async {
    final snap = await _tasks
        .where('isInbox', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .map((d) => TaskModel.fromFirestore(d.id, d.data()))
        .toList();
  }

  Future<TaskModel> scheduleFromInbox(String id, DateTime scheduledAt) async {
    final ref = _tasks.doc(id);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('Task not found');
    final data = snap.data()!;
    if (data['isInbox'] != true) throw StateError('Task is not in inbox');

    await ref.update({
      'isInbox': false,
      'scheduledAt': Timestamp.fromDate(scheduledAt.toUtc()),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final updated = await ref.get();
    return TaskModel.fromFirestore(id, updated.data()!);
  }

  Future<TimelineModel> getTimeline(DateTime date) async {
    final dayStart = DateTime.utc(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final snap = await _tasks
        .where(
          'scheduledAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart),
        )
        .where('scheduledAt', isLessThan: Timestamp.fromDate(dayEnd))
        .orderBy('scheduledAt')
        .get();

    final all = snap.docs
        .map((d) => TaskModel.fromFirestore(d.id, d.data()))
        .where((t) => t.parentTaskId == null && !t.isInbox)
        .toList();

    final parentIds = all.map((t) => t.id).toList();
    final subtasksByParent = <String, List<TaskModel>>{};
    if (parentIds.isNotEmpty) {
      // Firestore whereIn is limited to 30; chunk if needed.
      for (var i = 0; i < parentIds.length; i += 30) {
        final chunk = parentIds.sublist(
          i,
          i + 30 > parentIds.length ? parentIds.length : i + 30,
        );
        final subSnap = await _tasks
            .where('parentTaskId', whereIn: chunk)
            .get();
        for (final d in subSnap.docs) {
          final task = TaskModel.fromFirestore(d.id, d.data());
          final parentId = task.parentTaskId!;
          subtasksByParent.putIfAbsent(parentId, () => []).add(task);
        }
      }
      for (final list in subtasksByParent.values) {
        list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      }
    }

    final tasks = all
        .map((t) => t.copyWith(subtasks: subtasksByParent[t.id] ?? const []))
        .toList();

    TaskModel? activeTask;
    final activeSnap = await _tasks
        .where('status', whereIn: ['IN_PROGRESS', 'PAUSED'])
        .limit(5)
        .get();
    if (activeSnap.docs.isNotEmpty) {
      final inProgress = activeSnap.docs.where(
        (d) => d.data()['status'] == 'IN_PROGRESS',
      );
      final doc = inProgress.isNotEmpty
          ? inProgress.first
          : activeSnap.docs.first;
      activeTask = TaskModel.fromFirestore(doc.id, doc.data());
    }

    return TimelineModel(date: date, tasks: tasks, activeTask: activeTask);
  }

  Future<TaskModel> createTask({
    required String title,
    String? description,
    String color = '#4F52B2',
    String icon = 'task',
    int durationMinutes = 30,
    DateTime? scheduledAt,
    bool isInbox = false,
    RecurrenceSelection recurrence = const RecurrenceSelection(),
    String? reward,
    EnergyLevel? energyLevel,
    String? motivation,
    int transitionBufferMinutes = 0,
  }) async {
    final ref = _tasks.doc();
    final now = FieldValue.serverTimestamp();
    final data = <String, dynamic>{
      'title': title.trim(),
      'description': description,
      'color': color,
      'icon': icon,
      'durationMinutes': durationMinutes,
      'scheduledAt': scheduledAt != null
          ? Timestamp.fromDate(scheduledAt.toUtc())
          : null,
      'status': 'PENDING',
      'sortOrder': 0,
      'isInbox': isInbox,
      'startedAt': null,
      'completedAt': null,
      'parentTaskId': null,
      'reward': _normalizeText(reward),
      'energyLevel': energyLevel?.apiValue,
      'motivation': _normalizeText(motivation),
      'transitionBufferMinutes': transitionBufferMinutes,
      'recurrenceType': recurrence.apiType(),
      'recurrenceInterval': recurrence.interval,
      'recurrenceUnit': recurrence.apiUnit(),
      'recurrenceSeriesId': null,
      'createdAt': now,
      'updatedAt': now,
    };

    await ref.set(data);

    if (recurrence.hasRecurrence && scheduledAt != null) {
      await ref.update({'recurrenceSeriesId': ref.id});
      await _createRecurringInstances(
        templateId: ref.id,
        title: title.trim(),
        description: description,
        color: color,
        icon: icon,
        durationMinutes: durationMinutes,
        start: scheduledAt,
        recurrence: recurrence,
        reward: _normalizeText(reward),
        energyLevel: energyLevel?.apiValue,
        motivation: _normalizeText(motivation),
        transitionBufferMinutes: transitionBufferMinutes,
      );
    }

    final snap = await ref.get();
    return TaskModel.fromFirestore(ref.id, snap.data()!);
  }

  Future<void> _createRecurringInstances({
    required String templateId,
    required String title,
    String? description,
    required String color,
    required String icon,
    required int durationMinutes,
    required DateTime start,
    required RecurrenceSelection recurrence,
    String? reward,
    String? energyLevel,
    String? motivation,
    required int transitionBufferMinutes,
  }) async {
    final occurrences = RecurrenceGenerator.generateOccurrences(
      start: start.toUtc(),
      type: recurrence.type,
      interval: recurrence.interval,
      unit: recurrence.type == RecurrenceType.custom ? recurrence.unit : null,
    );

    var batch = _db.batch();
    var ops = 0;
    for (final occurrence in occurrences) {
      final ref = _tasks.doc();
      batch.set(ref, {
        'title': title,
        'description': description,
        'color': color,
        'icon': icon,
        'durationMinutes': durationMinutes,
        'scheduledAt': Timestamp.fromDate(occurrence),
        'status': 'PENDING',
        'sortOrder': 0,
        'isInbox': false,
        'startedAt': null,
        'completedAt': null,
        'parentTaskId': null,
        'reward': reward,
        'energyLevel': energyLevel,
        'motivation': motivation,
        'transitionBufferMinutes': transitionBufferMinutes,
        'recurrenceType': 'NONE',
        'recurrenceInterval': 1,
        'recurrenceUnit': null,
        'recurrenceSeriesId': templateId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ops++;
      if (ops >= 400) {
        await batch.commit();
        batch = _db.batch();
        ops = 0;
      }
    }
    if (ops > 0) await batch.commit();
  }

  Future<TaskModel> createTaskWithSubtasks({
    required String title,
    required DateTime scheduledAt,
    String color = '#4F52B2',
    String icon = 'task',
    required List<({String title, int durationMinutes, String color})> subtasks,
  }) async {
    final totalDuration = subtasks.fold<int>(
      0,
      (sum, s) => sum + s.durationMinutes,
    );
    final parentRef = _tasks.doc();
    await parentRef.set({
      'title': title.trim(),
      'description': null,
      'color': color,
      'icon': icon,
      'durationMinutes': totalDuration,
      'scheduledAt': Timestamp.fromDate(scheduledAt.toUtc()),
      'status': 'PENDING',
      'sortOrder': 0,
      'isInbox': false,
      'startedAt': null,
      'completedAt': null,
      'parentTaskId': null,
      'reward': null,
      'energyLevel': null,
      'motivation': null,
      'transitionBufferMinutes': 0,
      'recurrenceType': 'NONE',
      'recurrenceInterval': 1,
      'recurrenceUnit': null,
      'recurrenceSeriesId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    var current = scheduledAt.toUtc();
    final createdSubs = <TaskModel>[];
    var order = 0;
    for (final sub in subtasks) {
      final childRef = _tasks.doc();
      final data = {
        'title': sub.title.trim(),
        'description': null,
        'color': sub.color,
        'icon': icon,
        'durationMinutes': sub.durationMinutes,
        'scheduledAt': Timestamp.fromDate(current),
        'status': 'PENDING',
        'sortOrder': order++,
        'isInbox': false,
        'startedAt': null,
        'completedAt': null,
        'parentTaskId': parentRef.id,
        'reward': null,
        'energyLevel': null,
        'motivation': null,
        'transitionBufferMinutes': 0,
        'recurrenceType': 'NONE',
        'recurrenceInterval': 1,
        'recurrenceUnit': null,
        'recurrenceSeriesId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await childRef.set(data);
      createdSubs.add(TaskModel.fromFirestore(childRef.id, data));
      current = current.add(Duration(minutes: sub.durationMinutes));
    }

    final parentSnap = await parentRef.get();
    return TaskModel.fromFirestore(
      parentRef.id,
      parentSnap.data()!,
      subtasks: createdSubs,
    );
  }

  Future<TaskModel> updateTask({
    required String id,
    String? title,
    String? description,
    String? color,
    int? durationMinutes,
    DateTime? scheduledAt,
    String? reward,
    EnergyLevel? energyLevel,
    String? motivation,
    int? transitionBufferMinutes,
    bool? isInbox,
  }) async {
    final patch = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      if (title != null) 'title': title.trim(),
      if (description != null) 'description': description,
      if (color != null) 'color': color,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      if (scheduledAt != null)
        'scheduledAt': Timestamp.fromDate(scheduledAt.toUtc()),
      if (reward != null) 'reward': _normalizeText(reward) ?? '',
      if (energyLevel != null) 'energyLevel': energyLevel.apiValue,
      if (motivation != null) 'motivation': _normalizeText(motivation) ?? '',
      if (transitionBufferMinutes != null)
        'transitionBufferMinutes': transitionBufferMinutes,
      if (isInbox != null) 'isInbox': isInbox,
    };
    await _tasks.doc(id).update(patch);
    final snap = await _tasks.doc(id).get();
    if (!snap.exists) throw StateError('Task not found');
    return TaskModel.fromFirestore(id, snap.data()!);
  }

  Future<TaskModel> addSubtasksToTask({
    required String parentId,
    required List<({String title, int durationMinutes, String color})> subtasks,
  }) async {
    final parentRef = _tasks.doc(parentId);
    final parentSnap = await parentRef.get();
    if (!parentSnap.exists) throw StateError('Task not found');
    final parent = TaskModel.fromFirestore(parentId, parentSnap.data()!);
    if (parent.parentTaskId != null) {
      throw StateError('Cannot add subtasks to a subtask');
    }

    final existing = await _tasks
        .where('parentTaskId', isEqualTo: parentId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      throw StateError('Task already has subtasks');
    }

    final totalDuration = subtasks.fold<int>(
      0,
      (sum, s) => sum + s.durationMinutes,
    );
    await parentRef.update({
      'durationMinutes': totalDuration,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    var current = parent.scheduledAt?.toUtc();
    final createdSubs = <TaskModel>[];
    var order = 0;
    for (final sub in subtasks) {
      final childRef = _tasks.doc();
      final data = {
        'title': sub.title.trim(),
        'description': null,
        'color': sub.color,
        'icon': parent.icon,
        'durationMinutes': sub.durationMinutes,
        'scheduledAt': current != null ? Timestamp.fromDate(current) : null,
        'status': 'PENDING',
        'sortOrder': order++,
        'isInbox': false,
        'startedAt': null,
        'completedAt': null,
        'parentTaskId': parentId,
        'reward': null,
        'energyLevel': null,
        'motivation': null,
        'transitionBufferMinutes': 0,
        'recurrenceType': 'NONE',
        'recurrenceInterval': 1,
        'recurrenceUnit': null,
        'recurrenceSeriesId': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await childRef.set(data);
      createdSubs.add(
        TaskModel.fromFirestore(childRef.id, {...data, 'scheduledAt': current}),
      );
      if (current != null) {
        current = current.add(Duration(minutes: sub.durationMinutes));
      }
    }

    final refreshed = await parentRef.get();
    return TaskModel.fromFirestore(
      parentId,
      refreshed.data()!,
      subtasks: createdSubs,
    );
  }

  Future<TaskModel> startTask(String id) async {
    final ref = _tasks.doc(id);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('Task not found');
    final task = TaskModel.fromFirestore(id, snap.data()!);
    if (task.status == TaskStatus.completed) {
      throw StateError('Cannot start a completed task');
    }

    final active = await _tasks.where('status', isEqualTo: 'IN_PROGRESS').get();
    final batch = _db.batch();
    for (final doc in active.docs) {
      if (doc.id == id) continue;
      batch.update(doc.reference, {
        'status': 'PAUSED',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    batch.update(ref, {
      'status': 'IN_PROGRESS',
      if (task.status != TaskStatus.paused)
        'startedAt': Timestamp.fromDate(DateTime.now().toUtc()),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    final updated = await ref.get();
    return TaskModel.fromFirestore(id, updated.data()!);
  }

  Future<TaskModel> pauseTask(String id) async {
    await _tasks.doc(id).update({
      'status': 'PAUSED',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final snap = await _tasks.doc(id).get();
    return TaskModel.fromFirestore(id, snap.data()!);
  }

  Future<TaskModel> completeTask(String id) async {
    final ref = _tasks.doc(id);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('Task not found');
    final task = TaskModel.fromFirestore(id, snap.data()!);

    await ref.update({
      'status': 'COMPLETED',
      'completedAt': Timestamp.fromDate(DateTime.now().toUtc()),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (task.parentTaskId != null) {
      final siblings = await _tasks
          .where('parentTaskId', isEqualTo: task.parentTaskId)
          .get();
      final allDone = siblings.docs.every((d) {
        if (d.id == id) return true;
        return d.data()['status'] == 'COMPLETED';
      });
      if (allDone) {
        await _tasks.doc(task.parentTaskId!).update({
          'status': 'COMPLETED',
          'completedAt': Timestamp.fromDate(DateTime.now().toUtc()),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    final updated = await ref.get();
    return TaskModel.fromFirestore(id, updated.data()!);
  }

  Future<TaskModel> uncompleteTask(String id) async {
    final ref = _tasks.doc(id);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('Task not found');
    final task = TaskModel.fromFirestore(id, snap.data()!);
    if (task.status != TaskStatus.completed) {
      throw StateError('Task is not completed');
    }

    await ref.update({
      'status': 'PENDING',
      'completedAt': null,
      'startedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (task.parentTaskId != null) {
      final parentRef = _tasks.doc(task.parentTaskId!);
      final parentSnap = await parentRef.get();
      if (parentSnap.exists && parentSnap.data()?['status'] == 'COMPLETED') {
        await parentRef.update({
          'status': 'PENDING',
          'completedAt': null,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    final updated = await ref.get();
    return TaskModel.fromFirestore(id, updated.data()!);
  }

  Future<void> deleteTask(
    String id, {
    DeleteRecurrenceScope scope = DeleteRecurrenceScope.thisOccurrence,
  }) async {
    final snap = await _tasks.doc(id).get();
    if (!snap.exists) return;
    final task = TaskModel.fromFirestore(id, snap.data()!);
    final seriesId = task.recurrenceSeriesId;

    if (scope == DeleteRecurrenceScope.thisOccurrence || seriesId == null) {
      await _deleteSingle(id);
      return;
    }

    QuerySnapshot<Map<String, dynamic>> toDelete;
    if (scope == DeleteRecurrenceScope.all) {
      toDelete = await _tasks
          .where('recurrenceSeriesId', isEqualTo: seriesId)
          .get();
    } else {
      final cutoff = task.scheduledAt?.toUtc();
      if (cutoff == null) {
        await _deleteSingle(id);
        return;
      }
      toDelete = await _tasks
          .where('recurrenceSeriesId', isEqualTo: seriesId)
          .where(
            'scheduledAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(cutoff),
          )
          .get();
    }

    var batch = _db.batch();
    var ops = 0;
    Future<void> flush() async {
      if (ops == 0) return;
      await batch.commit();
      batch = _db.batch();
      ops = 0;
    }

    for (final doc in toDelete.docs) {
      final children = await _tasks
          .where('parentTaskId', isEqualTo: doc.id)
          .get();
      for (final child in children.docs) {
        batch.delete(child.reference);
        ops++;
        if (ops >= 400) await flush();
      }
      batch.delete(doc.reference);
      ops++;
      if (ops >= 400) await flush();
    }
    await flush();
  }

  Future<void> _deleteSingle(String id) async {
    final children = await _tasks.where('parentTaskId', isEqualTo: id).get();
    final batch = _db.batch();
    for (final child in children.docs) {
      batch.delete(child.reference);
    }
    batch.delete(_tasks.doc(id));
    await batch.commit();
  }

  Future<FocusSessionModel?> getFocusSession() async => null;

  static String? _normalizeText(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});
