import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/firebase/firebase_providers.dart';
import 'package:florien/core/firebase/user_profile_service.dart';
import 'package:florien/core/models/adhd_models.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/models/recurrence.dart';
import 'package:florien/core/models/task_usage_summary.dart';
import 'package:florien/core/utils/recurrence_generator.dart';
import 'package:florien/firebase_options.dart';

class AuthRepository {
  AuthRepository({
    required FirebaseAuth auth,
    required FirebaseFunctions functions,
    required UserProfileService profiles,
  }) : _auth = auth,
       _functions = functions,
       _profiles = profiles;

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final UserProfileService _profiles;

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
    return authResponseFromUser(user, displayNameOverride: displayName);
  }

  Future<AuthResponse?> getMe() async {
    if (!DefaultFirebaseOptions.isConfigured) return null;
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      await user.getIdToken();
      await _profiles.ensureUserDocument(user: user);
      return authResponseFromUser(user);
    } catch (_) {
      await _auth.signOut();
      return null;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> deleteAccount() async {
    _ensureConfigured();
    if (_auth.currentUser == null) throw StateError('Oturum bulunamadı.');
    await _functions.httpsCallable('deleteAccount').call();
    await _auth.signOut();
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
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    functions: ref.watch(cloudFunctionsProvider),
    profiles: ref.watch(userProfileServiceProvider),
  );
});

class TaskRepository {
  TaskRepository(this._db, this._auth, {required this.profileId});

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final String profileId;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> get _tasks =>
      tasksCol(_db, _uid, profileId);

  Future<List<TaskUsageSummary>> getFrequentlyUsedTasks({
    int limit = 10,
  }) async {
    final snapshot = await _tasks.get();
    final tasksById = <String, TaskModel>{};
    final dataById = <String, Map<String, dynamic>>{};
    final subtasksByParent = <String, List<TaskModel>>{};

    for (final document in snapshot.docs) {
      final task = TaskModel.fromFirestore(document.id, document.data());
      tasksById[document.id] = task;
      dataById[document.id] = document.data();
      final parentId = task.parentTaskId;
      if (parentId != null) {
        subtasksByParent.putIfAbsent(parentId, () => []).add(task);
      }
    }
    for (final subtasks in subtasksByParent.values) {
      subtasks.sort(
        (first, second) => first.sortOrder.compareTo(second.sortOrder),
      );
    }

    final candidates = <TaskUsageCandidate>[];
    for (final entry in tasksById.entries) {
      final task = entry.value;
      if (task.parentTaskId != null) continue;
      final data = dataById[entry.key]!;
      candidates.add(
        TaskUsageCandidate(
          task: task.copyWith(subtasks: subtasksByParent[task.id] ?? const []),
          createdAt: _taskCreatedAt(data, fallback: task.scheduledAt),
        ),
      );
    }
    return rankFrequentlyUsedTasks(candidates, limit: limit);
  }

  DateTime _taskCreatedAt(Map<String, dynamic> data, {DateTime? fallback}) {
    final value = data['createdAt'];
    if (value is Timestamp) return value.toDate().toLocal();
    if (value is DateTime) return value.toLocal();
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal() ??
          fallback ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }
    return fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<List<TaskModel>> getInbox() async {
    final snap = await _tasks
        .where('isInbox', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();
    final parents = snap.docs
        .map((d) => TaskModel.fromFirestore(d.id, d.data()))
        .toList();
    if (parents.isEmpty) return const [];

    final subtasksByParent = <String, List<TaskModel>>{};
    final parentIds = parents.map((task) => task.id).toList();
    for (var index = 0; index < parentIds.length; index += 30) {
      final end = index + 30 > parentIds.length ? parentIds.length : index + 30;
      final subtaskSnapshot = await _tasks
          .where('parentTaskId', whereIn: parentIds.sublist(index, end))
          .get();
      for (final document in subtaskSnapshot.docs) {
        final subtask = TaskModel.fromFirestore(document.id, document.data());
        final parentId = subtask.parentTaskId;
        if (parentId == null) continue;
        subtasksByParent.putIfAbsent(parentId, () => []).add(subtask);
      }
    }
    for (final subtasks in subtasksByParent.values) {
      subtasks.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    return parents
        .map(
          (task) =>
              task.copyWith(subtasks: subtasksByParent[task.id] ?? const []),
        )
        .toList();
  }

  Future<CompletionCounts> getCompletionCounts(DateTime now) async {
    final localNow = now.toLocal();
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final weeklySnapshotFuture = _tasks
        .where(
          'completedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart.toUtc()),
        )
        .get();
    final totalSnapshotFuture = _tasks
        .where('status', isEqualTo: 'COMPLETED')
        .where('parentTaskId', isNull: true)
        .count()
        .get();
    final weeklySnapshot = await weeklySnapshotFuture;
    final totalSnapshot = await totalSnapshotFuture;

    var todayCount = 0;
    var weekCount = 0;
    for (final document in weeklySnapshot.docs) {
      final data = document.data();
      if (data['parentTaskId'] != null || data['status'] != 'COMPLETED') {
        continue;
      }
      final value = data['completedAt'];
      final completedAt = switch (value) {
        Timestamp timestamp => timestamp.toDate().toLocal(),
        DateTime date => date.toLocal(),
        _ => null,
      };
      if (completedAt == null) continue;
      weekCount++;
      if (!completedAt.isBefore(today)) todayCount++;
    }
    return CompletionCounts(
      today: todayCount,
      thisWeek: weekCount,
      total: totalSnapshot.count ?? 0,
    );
  }

  Future<TaskModel> scheduleFromInbox(
    String id,
    DateTime scheduledAt, {
    DayPeriod dayPeriod = DayPeriod.anytime,
  }) async {
    final ref = _tasks.doc(id);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('Task not found');
    final data = snap.data()!;
    if (data['isInbox'] != true) throw StateError('Task is not in inbox');

    await ref.update({
      'isInbox': false,
      'scheduledAt': Timestamp.fromDate(scheduledAt.toUtc()),
      'dayPeriod': _dayPeriodValue(dayPeriod),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final updated = await ref.get();
    return TaskModel.fromFirestore(id, updated.data()!);
  }

  Future<TaskModel> moveToInbox(String id, {String? todoListId}) async {
    final ref = _tasks.doc(id);
    final snapshot = await ref.get();
    if (!snapshot.exists) throw StateError('Task not found');
    await ref.update({
      'isInbox': true,
      'scheduledAt': null,
      'dayPeriod': 'ANYTIME',
      'priority': 'NONE',
      'todoListId': todoListId,
      'status': 'PENDING',
      'startedAt': null,
      'completedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final updated = await ref.get();
    return TaskModel.fromFirestore(id, updated.data()!);
  }

  Future<TimelineModel> getTimeline(DateTime date) async {
    final dayStart = DateTime(date.year, date.month, date.day).toUtc();
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
    DateTime? alarmAt,
    bool isTimed = false,
    bool isInbox = false,
    RecurrenceSelection recurrence = const RecurrenceSelection(),
    String? reward,
    EnergyLevel? energyLevel,
    String? motivation,
    int transitionBufferMinutes = 0,
    TaskPriority priority = TaskPriority.none,
    DayPeriod dayPeriod = DayPeriod.anytime,
    String? todoListId,
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
      'alarmAt': alarmAt != null ? Timestamp.fromDate(alarmAt.toUtc()) : null,
      'isTimed': isTimed,
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
      'priority': _priorityValue(priority),
      'dayPeriod': _dayPeriodValue(dayPeriod),
      'todoListId': todoListId,
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
        alarmAt: alarmAt,
        isTimed: isTimed,
        recurrence: recurrence,
        reward: _normalizeText(reward),
        energyLevel: energyLevel?.apiValue,
        motivation: _normalizeText(motivation),
        transitionBufferMinutes: transitionBufferMinutes,
        priority: priority,
        dayPeriod: dayPeriod,
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
    DateTime? alarmAt,
    required bool isTimed,
    required RecurrenceSelection recurrence,
    String? reward,
    String? energyLevel,
    String? motivation,
    required int transitionBufferMinutes,
    required TaskPriority priority,
    required DayPeriod dayPeriod,
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
        'alarmAt': alarmAt == null
            ? null
            : Timestamp.fromDate(
                _alarmForOccurrence(alarmAt, occurrence).toUtc(),
              ),
        'isTimed': isTimed,
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
        'priority': _priorityValue(priority),
        'dayPeriod': _dayPeriodValue(dayPeriod),
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
      (total, step) => total + step.durationMinutes,
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
    bool clearDescription = false,
    String? color,
    String? icon,
    int? durationMinutes,
    DateTime? scheduledAt,
    DateTime? alarmAt,
    bool clearAlarmAt = false,
    bool? isTimed,
    RecurrenceSelection? recurrence,
    String? reward,
    EnergyLevel? energyLevel,
    String? motivation,
    int? transitionBufferMinutes,
    bool? isInbox,
    TaskPriority? priority,
    DayPeriod? dayPeriod,
    String? todoListId,
    bool clearTodoListId = false,
  }) async {
    final patch = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
      if (title != null) 'title': title.trim(),
      if (description != null) 'description': description,
      if (clearDescription) 'description': null,
      if (color != null) 'color': color,
      if (icon != null) 'icon': icon,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      if (scheduledAt != null)
        'scheduledAt': Timestamp.fromDate(scheduledAt.toUtc()),
      if (alarmAt != null) 'alarmAt': Timestamp.fromDate(alarmAt.toUtc()),
      if (clearAlarmAt) 'alarmAt': null,
      if (isTimed != null) 'isTimed': isTimed,
      if (recurrence != null) ...recurrence.toApiJson(),
      if (reward != null) 'reward': _normalizeText(reward) ?? '',
      if (energyLevel != null) 'energyLevel': energyLevel.apiValue,
      if (motivation != null) 'motivation': _normalizeText(motivation) ?? '',
      if (transitionBufferMinutes != null)
        'transitionBufferMinutes': transitionBufferMinutes,
      if (isInbox != null) 'isInbox': isInbox,
      if (priority != null) 'priority': _priorityValue(priority),
      if (dayPeriod != null) 'dayPeriod': _dayPeriodValue(dayPeriod),
      if (todoListId != null) 'todoListId': todoListId,
      if (clearTodoListId) 'todoListId': null,
    };
    await _tasks.doc(id).update(patch);
    final snap = await _tasks.doc(id).get();
    if (!snap.exists) throw StateError('Task not found');
    return TaskModel.fromFirestore(id, snap.data()!);
  }

  DateTime _alarmForOccurrence(DateTime alarmAt, DateTime occurrence) {
    final localAlarm = alarmAt.toLocal();
    final localOccurrence = occurrence.toLocal();
    return DateTime(
      localOccurrence.year,
      localOccurrence.month,
      localOccurrence.day,
      localAlarm.hour,
      localAlarm.minute,
    );
  }

  String _priorityValue(TaskPriority priority) => switch (priority) {
    TaskPriority.high => 'HIGH',
    TaskPriority.medium => 'MEDIUM',
    TaskPriority.low => 'LOW',
    TaskPriority.none => 'NONE',
  };

  String _dayPeriodValue(DayPeriod period) => switch (period) {
    DayPeriod.anytime => 'ANYTIME',
    DayPeriod.morning => 'MORNING',
    DayPeriod.daytime => 'DAYTIME',
    DayPeriod.evening => 'EVENING',
  };

  Future<TaskModel> addSubtasksToTask({
    required String parentId,
    required List<({String title, int durationMinutes, String color})> subtasks,
  }) async {
    final capped = subtasks
        .take(TaskModel.userSubtaskLimit)
        .toList(growable: false);
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

    final totalDuration = capped.fold<int>(
      0,
      (total, step) => total + step.durationMinutes,
    );
    await parentRef.update({
      'durationMinutes': totalDuration,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    var current = parent.scheduledAt?.toUtc();
    final createdSubs = <TaskModel>[];
    var order = 0;
    for (final sub in capped) {
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

  Future<void> replaceSubtasks({
    required String parentId,
    required List<String> titles,
  }) async {
    final cappedTitles = titles
        .map((title) => title.trim())
        .where((title) => title.isNotEmpty)
        .take(TaskModel.userSubtaskLimit)
        .toList(growable: false);
    final parentRef = _tasks.doc(parentId);
    final parentSnapshot = await parentRef.get();
    if (!parentSnapshot.exists) throw StateError('Task not found');
    final parent = TaskModel.fromFirestore(parentId, parentSnapshot.data()!);
    if (parent.parentTaskId != null) {
      throw StateError('Cannot edit subtasks of a subtask');
    }

    final existingSnapshot = await _tasks
        .where('parentTaskId', isEqualTo: parentId)
        .get();
    final existing = [...existingSnapshot.docs]
      ..sort(
        (a, b) => ((a.data()['sortOrder'] as num?)?.toInt() ?? 0).compareTo(
          (b.data()['sortOrder'] as num?)?.toInt() ?? 0,
        ),
      );
    final batch = _db.batch();
    var scheduledAt = parent.scheduledAt?.toUtc();

    for (var index = 0; index < cappedTitles.length; index++) {
      final title = cappedTitles[index];
      if (index < existing.length) {
        final document = existing[index];
        batch.update(document.reference, {
          'title': title,
          'sortOrder': index,
          if (scheduledAt != null)
            'scheduledAt': Timestamp.fromDate(scheduledAt),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        final duration =
            (document.data()['durationMinutes'] as num?)?.toInt() ?? 5;
        if (scheduledAt != null) {
          scheduledAt = scheduledAt.add(Duration(minutes: duration));
        }
      } else {
        final childRef = _tasks.doc();
        batch.set(childRef, {
          'title': title,
          'description': null,
          'color': parent.color,
          'icon': parent.icon,
          'durationMinutes': 5,
          'scheduledAt': scheduledAt == null
              ? null
              : Timestamp.fromDate(scheduledAt),
          'status': 'PENDING',
          'sortOrder': index,
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
        });
        if (scheduledAt != null) {
          scheduledAt = scheduledAt.add(const Duration(minutes: 5));
        }
      }
    }
    for (var index = cappedTitles.length; index < existing.length; index++) {
      batch.delete(existing[index].reference);
    }
    await batch.commit();
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
      'priority': 'NONE',
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
