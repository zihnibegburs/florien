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
import 'package:florien/core/storage/task_collection.dart';
import 'package:florien/core/utils/recurrence_generator.dart';
import 'package:florien/core/utils/recurrence_merge.dart';
import 'package:florien/core/utils/task_icons.dart';
import 'package:florien/firebase_options.dart';
import 'package:florien/core/l10n/app_strings.dart';

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

  Future<({AuthResponse response, bool isNewUser})> signInWithCredentialResult(
    AuthCredential credential, {
    String? displayName,
  }) async {
    _ensureConfigured();
    final cred = await _auth.signInWithCredential(credential);
    final isNewUser = cred.additionalUserInfo?.isNewUser ?? false;
    final user = cred.user!;
    if (displayName != null &&
        displayName.trim().isNotEmpty &&
        (user.displayName == null || user.displayName!.trim().isEmpty)) {
      await user.updateDisplayName(displayName.trim());
    }
    await _profiles.ensureUserDocument(user: user, displayName: displayName);
    final response = await authResponseFromUser(
      user,
      displayNameOverride: displayName,
    );
    return (response: response, isNewUser: isNewUser);
  }

  Future<AuthResponse?> getMe() async {
    if (!DefaultFirebaseOptions.isConfigured) return null;
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      // iOS Keychain keeps Firebase Auth after app uninstall. Reload + force
      // token refresh so a Console-deleted account is rejected immediately.
      await user.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null) return null;
      await refreshedUser.getIdToken(true);

      // Do not recreate users/{uid} here — that undoes Console deletions and
      // makes a Keychain-restored session look like a fresh login.
      final profile = await _profiles.loadProfile(refreshedUser.uid);
      if (profile == null) {
        await _auth.signOut();
        return null;
      }
      return authResponseFromUser(refreshedUser);
    } on FirebaseAuthException catch (error) {
      const invalidUserCodes = {
        'user-not-found',
        'user-disabled',
        'invalid-user-token',
        'user-token-expired',
        'invalid-credential',
      };
      if (!invalidUserCodes.contains(error.code)) rethrow;
      await _auth.signOut();
      return null;
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied' &&
          error.code != 'unauthenticated') {
        rethrow;
      }
      await _auth.signOut();
      return null;
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> deleteAccount() async {
    _ensureConfigured();
    if (_auth.currentUser == null)
      throw StateError(ActiveLanguage.s('Oturum bulunamadı.'));
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
  TaskRepository(this._tasks);

  final TaskCollection _tasks;

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
      if (task.recurrenceException != RecurrenceExceptionKind.none) continue;
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
    final streakStart = today.subtract(const Duration(days: 90));
    final recentSnapshotFuture = _tasks
        .where(
          'completedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(streakStart.toUtc()),
        )
        .get();
    final totalSnapshotFuture = _tasks
        .where('status', isEqualTo: 'COMPLETED')
        .where('parentTaskId', isNull: true)
        .count()
        .get();
    final recentSnapshot = await recentSnapshotFuture;
    final totalSnapshot = await totalSnapshotFuture;

    var todayCount = 0;
    var weekCount = 0;
    final completionDays = <DateTime>{};
    for (final document in recentSnapshot.docs) {
      final data = document.data();
      if (data['parentTaskId'] != null || data['status'] != 'COMPLETED') {
        continue;
      }
      final value = data['completedAt'];
      final completedAt = switch (value) {
        Timestamp timestamp => timestamp.toDate().toLocal(),
        DateTime date => date.toLocal(),
        String text => DateTime.tryParse(text)?.toLocal(),
        _ => null,
      };
      if (completedAt == null) continue;
      final day = DateTime(
        completedAt.year,
        completedAt.month,
        completedAt.day,
      );
      completionDays.add(day);
      if (!day.isBefore(weekStart)) weekCount++;
      if (!completedAt.isBefore(today)) todayCount++;
    }
    return CompletionCounts(
      today: todayCount,
      thisWeek: weekCount,
      total: totalSnapshot.count ?? 0,
      streak: florienCompletionStreak(completionDays, today),
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

    final leavesToday = florienRescheduleLeavesToday(
      scheduledAt,
      DateTime.now(),
    );
    await ref.update({
      'isInbox': false,
      'scheduledAt': Timestamp.fromDate(scheduledAt.toUtc()),
      'dayPeriod': _dayPeriodValue(dayPeriod),
      if (leavesToday) 'status': 'PENDING',
      if (leavesToday) 'startedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final updated = await ref.get();
    return TaskModel.fromFirestore(id, updated.data()!);
  }

  Future<TaskModel> moveToInbox(String id, {String? todoListId}) async {
    id = (await _ensureMaterialized(id)).id;
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
    final day = RecurrenceOccurrence.dateOnly(date);
    final dayStart = DateTime(day.year, day.month, day.day).toUtc();
    final dayEnd = dayStart.add(const Duration(days: 1));
    final dateKey = RecurrenceOccurrence.dateKey(day);

    final snap = await _tasks
        .where(
          'scheduledAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart),
        )
        .where('scheduledAt', isLessThan: Timestamp.fromDate(dayEnd))
        .orderBy('scheduledAt')
        .get();
    final exceptionSnap = await _tasks
        .where('occurrenceDate', isEqualTo: dateKey)
        .get();
    final seriesSnap = await _tasks
        .where(
          'recurrenceType',
          whereIn: const ['DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY', 'CUSTOM'],
        )
        .get();

    final byId = <String, TaskModel>{};
    for (final doc in [...snap.docs, ...exceptionSnap.docs]) {
      byId[doc.id] = TaskModel.fromFirestore(doc.id, doc.data());
    }

    final seriesById = <String, TaskModel>{};
    for (final doc in seriesSnap.docs) {
      final task = TaskModel.fromFirestore(doc.id, doc.data());
      if (task.isSeriesMaster) seriesById[doc.id] = task;
    }

    final visible = <TaskModel>[];
    for (final task in byId.values) {
      if (task.parentTaskId != null || task.isInbox || task.isSeriesMaster) {
        continue;
      }
      if (task.recurrenceException == RecurrenceExceptionKind.skip) {
        continue;
      }
      final scheduledDay = task.scheduledAt == null
          ? null
          : RecurrenceOccurrence.dateOnly(task.scheduledAt!);
      if (scheduledDay != null && scheduledDay != day) continue;
      final master = seriesById[task.recurrenceSeriesId];
      if (master != null &&
          task.recurrenceException == RecurrenceExceptionKind.override) {
        visible.add(
          mergeRecurrenceException(
            template: _virtualOccurrence(master, day),
            exception: task,
          ),
        );
        continue;
      }
      visible.add(
        master == null
            ? task
            : task.copyWith(recurrenceType: master.recurrenceType),
      );
    }

    for (final master in seriesById.values) {
      if (master.isInbox || master.parentTaskId != null) continue;
      if (!_seriesOccursOn(master, day)) continue;
      if (_seriesOccupiedOnDay(master.id, day, byId.values)) continue;
      visible.add(_virtualOccurrence(master, day));
    }

    final all = visible.toList()
      ..sort((a, b) {
        final left = a.scheduledAt ?? day;
        final right = b.scheduledAt ?? day;
        return left.compareTo(right);
      });

    final parentIds = <String>{
      for (final task in all) task.id,
      ...seriesById.keys,
    }.toList();
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

    final tasks = all.map((task) {
      final own = subtasksByParent[task.id];
      if (own != null && own.isNotEmpty) {
        return task.copyWith(subtasks: own);
      }
      final seriesId = task.recurrenceSeriesId;
      if (seriesId != null &&
          (task.isVirtualOccurrence ||
              task.recurrenceException == RecurrenceExceptionKind.override)) {
        return task.copyWith(subtasks: subtasksByParent[seriesId] ?? const []);
      }
      return task.copyWith(subtasks: own ?? const []);
    }).toList();

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
    int? reminderLeadMinutes,
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
      'reminderLeadMinutes': reminderLeadMinutes,
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
      'recurrenceSeriesId': recurrence.hasRecurrence ? ref.id : null,
      'recurrenceRootId': recurrence.hasRecurrence ? ref.id : null,
      'recurrenceUntil': null,
      'occurrenceDate': null,
      'recurrenceException': null,
      'priority': _priorityValue(priority),
      'dayPeriod': _dayPeriodValue(dayPeriod),
      'todoListId': todoListId,
      'createdAt': now,
      'updatedAt': now,
    };

    await ref.set(data);
    final snap = await ref.get();
    return TaskModel.fromFirestore(ref.id, snap.data()!);
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
        'icon': TaskIcons.nameForTitle(sub.title, fallback: icon),
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
    int? reminderLeadMinutes,
    bool clearReminderLeadMinutes = false,
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
    TaskStatus? status,
    bool clearStartedAt = false,
  }) async {
    final current = await _ensureMaterialized(id);
    id = current.id;
    final applyRecurrence =
        recurrence != null &&
        current.occurrenceDate == null &&
        current.recurrenceException == RecurrenceExceptionKind.none;
    final proposedOwned = <String>[
      if (title != null) RecurrencePatch.title,
      if (description != null || clearDescription) RecurrencePatch.description,
      if (color != null) RecurrencePatch.color,
      if (icon != null) RecurrencePatch.icon,
      if (durationMinutes != null) RecurrencePatch.durationMinutes,
      if (scheduledAt != null) RecurrencePatch.scheduledAt,
      if (alarmAt != null || clearAlarmAt) RecurrencePatch.alarmAt,
      if (reminderLeadMinutes != null || clearReminderLeadMinutes)
        RecurrencePatch.reminderLeadMinutes,
      if (isTimed != null) RecurrencePatch.isTimed,
      if (dayPeriod != null) RecurrencePatch.dayPeriod,
      if (isInbox != null) RecurrencePatch.isInbox,
    ];
    final sparseOverride =
        current.recurrenceException == RecurrenceExceptionKind.override &&
        current.recurrenceOwnedFields != null;
    List<String>? nextOwned;
    if (sparseOverride && proposedOwned.isNotEmpty) {
      nextOwned = await _reconcileSparseOwnedFields(
        current: current,
        proposed: proposedOwned,
        title: title,
        description: description,
        clearDescription: clearDescription,
        color: color,
        icon: icon,
        durationMinutes: durationMinutes,
        scheduledAt: scheduledAt,
        alarmAt: alarmAt,
        clearAlarmAt: clearAlarmAt,
        reminderLeadMinutes: reminderLeadMinutes,
        clearReminderLeadMinutes: clearReminderLeadMinutes,
        isTimed: isTimed,
        dayPeriod: dayPeriod,
        isInbox: isInbox,
      );
    }
    String? nextOccurrenceDate;
    if (scheduledAt != null &&
        current.recurrenceException == RecurrenceExceptionKind.override) {
      nextOccurrenceDate = RecurrenceOccurrence.dateKey(scheduledAt);
    }
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
      if (reminderLeadMinutes != null)
        'reminderLeadMinutes': reminderLeadMinutes,
      if (clearReminderLeadMinutes) 'reminderLeadMinutes': null,
      if (isTimed != null) 'isTimed': isTimed,
      if (applyRecurrence) ...recurrence!.toApiJson(),
      if (applyRecurrence && recurrence!.hasRecurrence) ...{
        'recurrenceSeriesId': current.recurrenceSeriesId ?? id,
        'recurrenceRootId': current.recurrenceRootId ?? id,
      },
      if (applyRecurrence && !recurrence!.hasRecurrence) ...{
        'recurrenceSeriesId': null,
        'recurrenceRootId': null,
        'recurrenceUntil': null,
      },
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
      if (status != null) 'status': _statusValue(status),
      if (clearStartedAt) 'startedAt': null,
      if (nextOccurrenceDate != null) 'occurrenceDate': nextOccurrenceDate,
      if (nextOwned != null) 'recurrenceOwnedFields': nextOwned,
    };
    await _tasks.doc(id).update(patch);
    final snap = await _tasks.doc(id).get();
    if (!snap.exists) throw StateError('Task not found');
    return TaskModel.fromFirestore(id, snap.data()!);
  }

  String _statusValue(TaskStatus status) => switch (status) {
    TaskStatus.pending => 'PENDING',
    TaskStatus.inProgress => 'IN_PROGRESS',
    TaskStatus.paused => 'PAUSED',
    TaskStatus.completed => 'COMPLETED',
    TaskStatus.skipped => 'SKIPPED',
  };

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
        'icon': TaskIcons.nameForTitle(sub.title, fallback: parent.icon),
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
    parentId = (await _ensureMaterialized(parentId)).id;
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
    final batch = _tasks.newBatch();
    var scheduledAt = parent.scheduledAt?.toUtc();

    for (var index = 0; index < cappedTitles.length; index++) {
      final title = cappedTitles[index];
      if (index < existing.length) {
        final document = existing[index];
        batch.update(document.reference, {
          'title': title,
          'icon': TaskIcons.nameForTitle(title, fallback: parent.icon),
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
          'icon': TaskIcons.nameForTitle(title, fallback: parent.icon),
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

  /// Writes the same subtask titles onto a one-off parent, or onto every
  /// series master and OVERRIDE exception when [id] belongs to a series.
  Future<void> replaceSubtasksForSeries({
    required String id,
    required List<String> titles,
  }) async {
    final resolved = await _resolveTask(id, materialize: false);
    if (resolved == null) throw StateError('Task not found');
    if (!resolved.isRecurring) {
      final target = resolved.isVirtualOccurrence
          ? await _ensureMaterialized(id)
          : resolved;
      await replaceSubtasks(parentId: target.id, titles: titles);
      return;
    }

    final masters = await _mastersForRoot(_rootId(resolved));
    final targets = <String>{};
    for (final master in masters) {
      targets.add(master.id);
      for (final exception in await _overrideExceptionsForSeries(master.id)) {
        final children = await _tasks
            .where('parentTaskId', isEqualTo: exception.id)
            .get();
        if (children.docs.isEmpty && exception.recurrenceOwnedFields != null) {
          continue;
        }
        targets.add(exception.id);
      }
    }
    for (final targetId in targets) {
      await replaceSubtasks(parentId: targetId, titles: titles);
    }
  }

  Future<TaskModel> startTask(String id) async {
    id = (await _ensureMaterialized(id)).id;
    final ref = _tasks.doc(id);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('Task not found');
    final task = TaskModel.fromFirestore(id, snap.data()!);
    if (task.status == TaskStatus.completed) {
      throw StateError('Cannot start a completed task');
    }

    final active = await _tasks.where('status', isEqualTo: 'IN_PROGRESS').get();
    final batch = _tasks.newBatch();
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
    id = (await _ensureMaterialized(id)).id;
    await _tasks.doc(id).update({
      'status': 'PAUSED',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final snap = await _tasks.doc(id).get();
    return TaskModel.fromFirestore(id, snap.data()!);
  }

  Future<TaskModel> completeTask(String id) async {
    id = (await _ensureMaterialized(id)).id;
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
        final parentSnap = await _tasks.doc(task.parentTaskId!).get();
        if (parentSnap.exists) {
          final parent = TaskModel.fromFirestore(
            parentSnap.id,
            parentSnap.data()!,
          );
          if (!parent.isSeriesMaster) {
            await _tasks.doc(task.parentTaskId!).update({
              'status': 'COMPLETED',
              'completedAt': Timestamp.fromDate(DateTime.now().toUtc()),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
    }

    final updated = await ref.get();
    return TaskModel.fromFirestore(id, updated.data()!);
  }

  Future<TaskModel> uncompleteTask(String id) async {
    id = (await _ensureMaterialized(id)).id;
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

  Future<void> toggleSubtask({
    required String parentId,
    required String subtaskId,
  }) async {
    final parent = await _resolveTask(parentId, materialize: false);
    if (parent == null) throw StateError('Task not found');
    final subSnap = await _tasks.doc(subtaskId).get();
    if (!subSnap.exists) throw StateError('Task not found');
    final subtask = TaskModel.fromFirestore(subtaskId, subSnap.data()!);
    var targetId = subtaskId;
    final inheritsTemplate =
        parent.isVirtualOccurrence ||
        (parent.recurrenceException == RecurrenceExceptionKind.override &&
            subtask.parentTaskId != parent.id);
    if (inheritsTemplate) {
      final materialized = await _ensureMaterialized(parentId);
      await _copyTemplateSubtasksTo(
        fromParentId: parent.recurrenceSeriesId ?? materialized.id,
        toParentId: materialized.id,
      );
      final copies = await _tasks
          .where('parentTaskId', isEqualTo: materialized.id)
          .get();
      final match = copies.docs.where((doc) {
        return (doc.data()['title'] as String? ?? '') == subtask.title;
      });
      if (match.isNotEmpty) {
        targetId = match.first.id;
      } else {
        return;
      }
    }
    final targetSnap = await _tasks.doc(targetId).get();
    if (!targetSnap.exists) throw StateError('Task not found');
    final target = TaskModel.fromFirestore(targetId, targetSnap.data()!);
    if (target.isCompleted) {
      await uncompleteTask(targetId);
    } else {
      await completeTask(targetId);
    }
  }

  Future<void> deleteTask(
    String id, {
    RecurrenceScope scope = RecurrenceScope.thisOccurrence,
  }) async {
    final resolved = await _resolveTask(id, materialize: false);
    if (resolved == null) return;
    final seriesId = resolved.recurrenceSeriesId;
    if (seriesId == null || !resolved.isRecurring) {
      if (resolved.isVirtualOccurrence) return;
      await _deleteSingle(resolved.id);
      return;
    }

    final occurrenceDay = _occurrenceDay(resolved);
    switch (scope) {
      case RecurrenceScope.thisOccurrence:
        await _skipOccurrence(resolved, occurrenceDay);
      case RecurrenceScope.future:
        await _endSeriesFrom(resolved, occurrenceDay);
      case RecurrenceScope.all:
        await _deleteSeriesTree(resolved);
    }
  }

  Future<void> _deleteSingle(String id) async {
    final children = await _tasks.where('parentTaskId', isEqualTo: id).get();
    final batch = _tasks.newBatch();
    for (final child in children.docs) {
      batch.delete(child.reference);
    }
    batch.delete(_tasks.doc(id));
    await batch.commit();
  }

  /// Incomplete timed tasks that may need a reminder in [from, to].
  Future<List<TaskModel>> getUpcomingTimedTasks({
    required DateTime from,
    required DateTime to,
  }) async {
    final fromTs = Timestamp.fromDate(from.toUtc());
    final toTs = Timestamp.fromDate(to.toUtc());
    final scheduledSnap = await _tasks
        .where('scheduledAt', isGreaterThanOrEqualTo: fromTs)
        .where('scheduledAt', isLessThan: toTs)
        .get();
    final seriesSnap = await _tasks
        .where(
          'recurrenceType',
          whereIn: const ['DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY', 'CUSTOM'],
        )
        .get();

    final seriesById = <String, TaskModel>{};
    for (final doc in seriesSnap.docs) {
      final task = TaskModel.fromFirestore(doc.id, doc.data());
      if (task.isSeriesMaster) seriesById[task.id] = task;
    }

    final byId = <String, TaskModel>{};
    for (final doc in scheduledSnap.docs) {
      var task = TaskModel.fromFirestore(doc.id, doc.data());
      if (task.isSeriesMaster) continue;
      if (task.recurrenceException == RecurrenceExceptionKind.skip) continue;
      final master = seriesById[task.recurrenceSeriesId];
      if (master != null &&
          task.recurrenceException == RecurrenceExceptionKind.override) {
        task = mergeRecurrenceException(
          template: _virtualOccurrence(master, _occurrenceDay(task)),
          exception: task,
        );
      }
      byId.putIfAbsent(task.id, () => task);
    }

    var cursor = RecurrenceOccurrence.dateOnly(from);
    final last = RecurrenceOccurrence.dateOnly(to);
    while (cursor.isBefore(last)) {
      for (final doc in seriesSnap.docs) {
        final master = TaskModel.fromFirestore(doc.id, doc.data());
        if (!master.isSeriesMaster || !master.isTimed || master.isInbox) {
          continue;
        }
        if (!_seriesOccursOn(master, cursor)) continue;
        if (_seriesOccupiedOnDay(master.id, cursor, byId.values)) continue;
        final virtual = _virtualOccurrence(master, cursor);
        byId.putIfAbsent(virtual.id, () => virtual);
      }
      cursor = cursor.add(const Duration(days: 1));
    }

    return byId.values
        .where(
          (task) =>
              !task.isCompleted &&
              task.status != TaskStatus.skipped &&
              task.isTimed &&
              task.recurrenceException != RecurrenceExceptionKind.skip,
        )
        .toList();
  }

  Future<TaskModel?> getTaskById(String id) async {
    return _resolveTask(id, materialize: false);
  }

  Future<List<String>> updateTaskAndFollowing({
    required String id,
    RecurrenceScope scope = RecurrenceScope.future,
    String? title,
    String? description,
    bool clearDescription = false,
    String? color,
    String? icon,
    int? durationMinutes,
    DateTime? scheduledAt,
    DateTime? alarmAt,
    bool clearAlarmAt = false,
    int? reminderLeadMinutes,
    bool clearReminderLeadMinutes = false,
    bool? isTimed,
    RecurrenceSelection? recurrence,
    DayPeriod? dayPeriod,
    bool? isInbox,
  }) async {
    final updated = await updateRecurringTask(
      id: id,
      scope: scope,
      title: title,
      description: description,
      clearDescription: clearDescription,
      color: color,
      icon: icon,
      durationMinutes: durationMinutes,
      scheduledAt: scheduledAt,
      alarmAt: alarmAt,
      clearAlarmAt: clearAlarmAt,
      reminderLeadMinutes: reminderLeadMinutes,
      clearReminderLeadMinutes: clearReminderLeadMinutes,
      isTimed: isTimed,
      recurrence: recurrence,
      dayPeriod: dayPeriod,
      isInbox: isInbox,
    );
    return [updated.id];
  }

  Future<TaskModel> updateRecurringTask({
    required String id,
    RecurrenceScope scope = RecurrenceScope.thisOccurrence,
    String? title,
    String? description,
    bool clearDescription = false,
    String? color,
    String? icon,
    int? durationMinutes,
    DateTime? scheduledAt,
    DateTime? alarmAt,
    bool clearAlarmAt = false,
    int? reminderLeadMinutes,
    bool clearReminderLeadMinutes = false,
    bool? isTimed,
    RecurrenceSelection? recurrence,
    DayPeriod? dayPeriod,
    bool? isInbox,
  }) async {
    final resolved = await _resolveTask(id, materialize: false);
    if (resolved == null) throw StateError('Task not found');
    if (scope == RecurrenceScope.thisOccurrence && resolved.isRecurring) {
      final target = await _materializeThisOccurrence(resolved, id);
      return updateTask(
        id: target.id,
        title: title,
        description: description,
        clearDescription: clearDescription,
        color: color,
        icon: icon,
        durationMinutes: durationMinutes,
        scheduledAt: scheduledAt,
        alarmAt: alarmAt,
        clearAlarmAt: clearAlarmAt,
        reminderLeadMinutes: reminderLeadMinutes,
        clearReminderLeadMinutes: clearReminderLeadMinutes,
        isTimed: isTimed,
        dayPeriod: dayPeriod,
        isInbox: isInbox,
      );
    }
    if (!resolved.isRecurring) {
      return updateTask(
        id: resolved.id,
        title: title,
        description: description,
        clearDescription: clearDescription,
        color: color,
        icon: icon,
        durationMinutes: durationMinutes,
        scheduledAt: scheduledAt,
        alarmAt: alarmAt,
        clearAlarmAt: clearAlarmAt,
        reminderLeadMinutes: reminderLeadMinutes,
        clearReminderLeadMinutes: clearReminderLeadMinutes,
        isTimed: isTimed,
        recurrence: recurrence,
        dayPeriod: dayPeriod,
        isInbox: isInbox,
      );
    }

    final occurrenceDay = _occurrenceDay(resolved);
    if (scope == RecurrenceScope.future) {
      final target = await _splitSeriesFrom(resolved, occurrenceDay);
      return updateTask(
        id: target.id,
        title: title,
        description: description,
        clearDescription: clearDescription,
        color: color,
        icon: icon,
        durationMinutes: durationMinutes,
        scheduledAt:
            scheduledAt ??
            RecurrenceGenerator.scheduledAtFor(
              start: target.scheduledAt ?? occurrenceDay,
              date: occurrenceDay,
            ),
        alarmAt: alarmAt,
        clearAlarmAt: clearAlarmAt,
        reminderLeadMinutes: reminderLeadMinutes,
        clearReminderLeadMinutes: clearReminderLeadMinutes,
        isTimed: isTimed,
        recurrence: recurrence,
        dayPeriod: dayPeriod,
        isInbox: isInbox,
      );
    }

    final masters = await _mastersForRoot(_rootId(resolved));
    TaskModel? latest;
    for (final master in masters) {
      latest = await updateTask(
        id: master.id,
        title: title,
        description: description,
        clearDescription: clearDescription,
        color: color,
        icon: icon,
        durationMinutes: durationMinutes,
        scheduledAt: scheduledAt == null || master.scheduledAt == null
            ? scheduledAt
            : RecurrenceGenerator.scheduledAtFor(
                start: scheduledAt,
                date: master.scheduledAt!,
              ),
        alarmAt: alarmAt,
        clearAlarmAt: clearAlarmAt,
        reminderLeadMinutes: reminderLeadMinutes,
        clearReminderLeadMinutes: clearReminderLeadMinutes,
        isTimed: isTimed,
        recurrence: recurrence,
        dayPeriod: dayPeriod,
        isInbox: isInbox,
      );
      for (final exception in await _overrideExceptionsForSeries(master.id)) {
        if (exception.recurrenceOwnedFields != null) {
          if (dayPeriod != null || scheduledAt != null || isTimed != null) {
            await _releaseOwnedPlacementFields(exception);
          }
          continue;
        }
        await updateTask(
          id: exception.id,
          title: title,
          description: description,
          clearDescription: clearDescription,
          color: color,
          icon: icon,
          durationMinutes: durationMinutes,
          scheduledAt: scheduledAt == null
              ? null
              : RecurrenceGenerator.scheduledAtFor(
                  start: scheduledAt,
                  date: _occurrenceDay(exception),
                ),
          alarmAt: alarmAt,
          clearAlarmAt: clearAlarmAt,
          reminderLeadMinutes: reminderLeadMinutes,
          clearReminderLeadMinutes: clearReminderLeadMinutes,
          isTimed: isTimed,
          dayPeriod: dayPeriod,
          isInbox: isInbox,
        );
      }
    }
    return latest ?? resolved;
  }

  Future<List<TaskModel>> _overrideExceptionsForSeries(String seriesId) async {
    final related = await _tasks
        .where('recurrenceSeriesId', isEqualTo: seriesId)
        .get();
    return [
      for (final doc in related.docs)
        TaskModel.fromFirestore(doc.id, doc.data()),
    ].where((task) {
      if (task.isSeriesMaster || task.parentTaskId != null) return false;
      return task.recurrenceException == RecurrenceExceptionKind.override;
    }).toList();
  }

  Future<TaskModel> _materializeThisOccurrence(
    TaskModel resolved,
    String id,
  ) async {
    if (resolved.isVirtualOccurrence) {
      return _ensureMaterialized(id);
    }
    if (resolved.isSeriesMaster) {
      return _materializeOccurrence(resolved, _occurrenceDay(resolved));
    }
    return resolved;
  }

  Future<TaskModel> _ensureMaterialized(String id) async {
    if (!RecurrenceOccurrence.isVirtualId(id)) {
      final snap = await _tasks.doc(id).get();
      if (!snap.exists) throw StateError('Task not found');
      return TaskModel.fromFirestore(id, snap.data()!);
    }
    final resolved = await _resolveTask(id, materialize: true);
    if (resolved == null) throw StateError('Task not found');
    return resolved;
  }

  Future<TaskModel?> _resolveTask(String id, {bool materialize = false}) async {
    final virtual = RecurrenceOccurrence.parse(id);
    if (virtual == null) {
      final snap = await _tasks.doc(id).get();
      if (!snap.exists) return null;
      final task = TaskModel.fromFirestore(id, snap.data()!);
      if (materialize && task.isSeriesMaster) {
        final day = task.scheduledAt == null
            ? RecurrenceOccurrence.dateOnly(DateTime.now())
            : RecurrenceOccurrence.dateOnly(task.scheduledAt!);
        return _materializeOccurrence(task, day);
      }
      return task;
    }

    final masterSnap = await _tasks.doc(virtual.seriesId).get();
    if (!masterSnap.exists) return null;
    final master = TaskModel.fromFirestore(
      virtual.seriesId,
      masterSnap.data()!,
    );
    final day =
        RecurrenceOccurrence.parseDateKey(virtual.dateKey) ??
        RecurrenceOccurrence.dateOnly(DateTime.now());
    final existing = await _exceptionFor(virtual.seriesId, virtual.dateKey);
    if (existing != null) {
      if (existing.recurrenceException == RecurrenceExceptionKind.skip) {
        return existing;
      }
      return mergeRecurrenceException(
        template: _virtualOccurrence(master, day),
        exception: existing,
      );
    }
    if (!materialize) return _virtualOccurrence(master, day);
    return _materializeOccurrence(master, day);
  }

  Future<TaskModel> _materializeOccurrence(
    TaskModel master,
    DateTime day,
  ) async {
    final dateKey = RecurrenceOccurrence.dateKey(day);
    final existing = await _exceptionFor(master.id, dateKey);
    if (existing != null &&
        existing.recurrenceException != RecurrenceExceptionKind.skip) {
      return mergeRecurrenceException(
        template: _virtualOccurrence(master, day),
        exception: existing,
      );
    }

    final scheduledAt = RecurrenceGenerator.scheduledAtFor(
      start: master.scheduledAt ?? day,
      date: day,
    );
    final alarmAt = RecurrenceGenerator.alarmAtFor(
      alarmAt: master.alarmAt,
      occurrence: scheduledAt,
    );
    final ref = _tasks.doc();
    await ref.set({
      'title': master.title,
      'description': master.description,
      'color': master.color,
      'icon': master.icon,
      'durationMinutes': master.durationMinutes,
      'scheduledAt': Timestamp.fromDate(scheduledAt.toUtc()),
      'alarmAt': alarmAt == null ? null : Timestamp.fromDate(alarmAt.toUtc()),
      'status': 'PENDING',
      'sortOrder': master.sortOrder,
      'isInbox': false,
      'startedAt': null,
      'completedAt': null,
      'parentTaskId': null,
      'isTimed': master.isTimed,
      'recurrenceType': 'NONE',
      'recurrenceInterval': 1,
      'recurrenceUnit': null,
      'recurrenceSeriesId': master.id,
      'recurrenceRootId': _rootId(master),
      'recurrenceUntil': null,
      'occurrenceDate': dateKey,
      'recurrenceException': 'OVERRIDE',
      'recurrenceOwnedFields': <String>[],
      'priority': master.priorityApiValue,
      'dayPeriod': master.dayPeriodApiValue,
      'todoListId': master.todoListId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final snap = await ref.get();
    return mergeRecurrenceException(
      template: _virtualOccurrence(master, day),
      exception: TaskModel.fromFirestore(ref.id, snap.data()!),
    );
  }

  Future<TaskModel?> _exceptionFor(String seriesId, String dateKey) async {
    final snap = await _tasks
        .where('recurrenceSeriesId', isEqualTo: seriesId)
        .where('occurrenceDate', isEqualTo: dateKey)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return TaskModel.fromFirestore(doc.id, doc.data());
  }

  Future<void> _skipOccurrence(TaskModel task, DateTime day) async {
    final dateKey = RecurrenceOccurrence.dateKey(day);
    final seriesId = task.recurrenceSeriesId ?? task.id;
    final existing = await _exceptionFor(seriesId, dateKey);
    if (existing != null) {
      if (!existing.isVirtualOccurrence) {
        await _tasks.doc(existing.id).update({
          'recurrenceException': 'SKIP',
          'status': 'SKIPPED',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      return;
    }
    final master = task.isSeriesMaster ? task : await _requireMaster(seriesId);
    final scheduledAt = RecurrenceGenerator.scheduledAtFor(
      start: master.scheduledAt ?? day,
      date: day,
    );
    await _tasks.doc().set({
      ...master.toFirestoreMap(),
      'scheduledAt': Timestamp.fromDate(scheduledAt.toUtc()),
      'status': 'SKIPPED',
      'startedAt': null,
      'completedAt': null,
      'parentTaskId': null,
      'isInbox': false,
      'recurrenceType': 'NONE',
      'recurrenceSeriesId': seriesId,
      'recurrenceRootId': _rootId(master),
      'occurrenceDate': dateKey,
      'recurrenceException': 'SKIP',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _endSeriesFrom(TaskModel task, DateTime day) async {
    final master = await _requireMaster(task.recurrenceSeriesId ?? task.id);
    final untilKey = RecurrenceOccurrence.dateKey(day);
    final startKey = master.scheduledAt == null
        ? untilKey
        : RecurrenceOccurrence.dateKey(master.scheduledAt!);
    if (untilKey == startKey) {
      await _deleteSeriesTree(master);
      return;
    }
    await _tasks.doc(master.id).update({
      'recurrenceUntil': untilKey,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final related = await _tasks
        .where('recurrenceSeriesId', isEqualTo: master.id)
        .get();
    for (final doc in related.docs) {
      final exception = TaskModel.fromFirestore(doc.id, doc.data());
      if (exception.isSeriesMaster || exception.parentTaskId != null) continue;
      final key = exception.occurrenceDate;
      if (key != null && key.compareTo(untilKey) >= 0) {
        await _deleteSingle(exception.id);
      }
    }
    final later = await _mastersForRoot(_rootId(master));
    for (final other in later) {
      if (other.id == master.id || other.scheduledAt == null) continue;
      if (!RecurrenceOccurrence.dateOnly(
        other.scheduledAt!,
      ).isBefore(RecurrenceOccurrence.dateOnly(day))) {
        await _deleteSingle(other.id);
      }
    }
  }

  Future<void> _deleteSeriesTree(TaskModel task) async {
    final rootId = _rootId(task);
    final masters = await _mastersForRoot(rootId);
    final seriesIds = {
      for (final master in masters) master.id,
      if (task.recurrenceSeriesId != null) task.recurrenceSeriesId!,
    };
    for (final seriesId in seriesIds) {
      final related = await _tasks
          .where('recurrenceSeriesId', isEqualTo: seriesId)
          .get();
      for (final doc in related.docs) {
        await _deleteSingle(doc.id);
      }
      await _deleteSingle(seriesId);
    }
  }

  Future<TaskModel> _splitSeriesFrom(TaskModel task, DateTime day) async {
    final master = await _requireMaster(task.recurrenceSeriesId ?? task.id);
    final startKey = master.scheduledAt == null
        ? RecurrenceOccurrence.dateKey(day)
        : RecurrenceOccurrence.dateKey(master.scheduledAt!);
    final dayKey = RecurrenceOccurrence.dateKey(day);
    if (startKey == dayKey) return master;

    await _tasks.doc(master.id).update({
      'recurrenceUntil': dayKey,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final ref = _tasks.doc();
    final scheduledAt = RecurrenceGenerator.scheduledAtFor(
      start: master.scheduledAt ?? day,
      date: day,
    );
    await ref.set({
      ...master.toFirestoreMap(),
      'scheduledAt': Timestamp.fromDate(scheduledAt.toUtc()),
      'status': 'PENDING',
      'startedAt': null,
      'completedAt': null,
      'isInbox': false,
      'recurrenceType': _recurrenceTypeApi(master.recurrenceType),
      'recurrenceInterval': master.recurrenceInterval,
      'recurrenceUnit': master.recurrenceUnit == null
          ? null
          : switch (master.recurrenceUnit!) {
              RecurrenceUnit.days => 'DAYS',
              RecurrenceUnit.weeks => 'WEEKS',
              RecurrenceUnit.months => 'MONTHS',
            },
      'recurrenceSeriesId': ref.id,
      'recurrenceRootId': _rootId(master),
      'recurrenceUntil': master.recurrenceUntil,
      'occurrenceDate': null,
      'recurrenceException': null,
      'recurrenceOwnedFields': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _copyTemplateSubtasksTo(fromParentId: master.id, toParentId: ref.id);
    await _reassignExceptions(
      fromSeriesId: master.id,
      toSeriesId: ref.id,
      fromDateKey: dayKey,
    );
    final snap = await ref.get();
    return TaskModel.fromFirestore(ref.id, snap.data()!);
  }

  Future<void> _copyTemplateSubtasksTo({
    required String fromParentId,
    required String toParentId,
  }) async {
    if (fromParentId == toParentId) return;
    final existing = await _tasks
        .where('parentTaskId', isEqualTo: toParentId)
        .get();
    if (existing.docs.isNotEmpty) return;
    final templateSubs = await _tasks
        .where('parentTaskId', isEqualTo: fromParentId)
        .get();
    if (templateSubs.docs.isEmpty) return;
    final titles = [...templateSubs.docs]
      ..sort(
        (a, b) => ((a.data()['sortOrder'] as num?)?.toInt() ?? 0).compareTo(
          (b.data()['sortOrder'] as num?)?.toInt() ?? 0,
        ),
      );
    await addSubtasksToTask(
      parentId: toParentId,
      subtasks: titles
          .map(
            (doc) => (
              title: (doc.data()['title'] as String?) ?? '',
              durationMinutes:
                  (doc.data()['durationMinutes'] as num?)?.toInt() ?? 5,
              color: (doc.data()['color'] as String?) ?? '#4F52B2',
            ),
          )
          .toList(),
    );
  }

  Future<void> _reassignExceptions({
    required String fromSeriesId,
    required String toSeriesId,
    required String fromDateKey,
  }) async {
    final related = await _tasks
        .where('recurrenceSeriesId', isEqualTo: fromSeriesId)
        .get();
    for (final doc in related.docs) {
      final exception = TaskModel.fromFirestore(doc.id, doc.data());
      if (exception.isSeriesMaster || exception.parentTaskId != null) continue;
      final key = exception.occurrenceDate;
      if (key == null || key.compareTo(fromDateKey) < 0) continue;
      await _tasks.doc(exception.id).update({
        'recurrenceSeriesId': toSeriesId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<List<TaskModel>> _mastersForRoot(String rootId) async {
    final snap = await _tasks
        .where('recurrenceRootId', isEqualTo: rootId)
        .get();
    final masters = snap.docs
        .map((doc) => TaskModel.fromFirestore(doc.id, doc.data()))
        .where((task) => task.isSeriesMaster)
        .toList();
    if (masters.isNotEmpty) return masters;
    final fallback = await _tasks.doc(rootId).get();
    if (!fallback.exists) return const [];
    return [TaskModel.fromFirestore(rootId, fallback.data()!)];
  }

  Future<TaskModel> _requireMaster(String seriesId) async {
    final snap = await _tasks.doc(seriesId).get();
    if (!snap.exists) throw StateError('Task not found');
    return TaskModel.fromFirestore(seriesId, snap.data()!);
  }

  static const _placementOwnedFields = {
    RecurrencePatch.dayPeriod,
    RecurrencePatch.scheduledAt,
    RecurrencePatch.isTimed,
  };

  Future<void> _releaseOwnedPlacementFields(TaskModel exception) async {
    final owned = exception.recurrenceOwnedFields;
    if (owned == null) return;
    final next = [
      for (final field in owned)
        if (!_placementOwnedFields.contains(field)) field,
    ];
    if (next.length == owned.length) return;
    await _tasks.doc(exception.id).update({
      'recurrenceOwnedFields': next,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<String>> _reconcileSparseOwnedFields({
    required TaskModel current,
    required List<String> proposed,
    String? title,
    String? description,
    bool clearDescription = false,
    String? color,
    String? icon,
    int? durationMinutes,
    DateTime? scheduledAt,
    DateTime? alarmAt,
    bool clearAlarmAt = false,
    int? reminderLeadMinutes,
    bool clearReminderLeadMinutes = false,
    bool? isTimed,
    DayPeriod? dayPeriod,
    bool? isInbox,
  }) async {
    final owned = {...current.recurrenceOwnedFields!};
    final seriesId = current.recurrenceSeriesId;
    TaskModel? template;
    if (seriesId != null) {
      try {
        final master = await _requireMaster(seriesId);
        template = _virtualOccurrence(master, _occurrenceDay(current));
      } catch (_) {
        template = null;
      }
    }
    if (template == null) {
      owned.addAll(proposed);
      return owned.toList();
    }

    void apply(String field, bool matchesTemplate) {
      if (!proposed.contains(field)) return;
      if (matchesTemplate) {
        owned.remove(field);
      } else {
        owned.add(field);
      }
    }

    apply(
      RecurrencePatch.title,
      title == null || title.trim() == template.title,
    );
    final nextDescription = clearDescription ? null : description;
    apply(
      RecurrencePatch.description,
      proposed.contains(RecurrencePatch.description) &&
          _sameOptionalText(nextDescription, template.description),
    );
    apply(RecurrencePatch.color, color == null || color == template.color);
    apply(RecurrencePatch.icon, icon == null || icon == template.icon);
    apply(
      RecurrencePatch.durationMinutes,
      durationMinutes == null || durationMinutes == template.durationMinutes,
    );
    apply(
      RecurrencePatch.scheduledAt,
      scheduledAt == null ||
          _sameOccurrenceClock(scheduledAt, template.scheduledAt),
    );
    final nextAlarm = clearAlarmAt ? null : alarmAt;
    apply(
      RecurrencePatch.alarmAt,
      !proposed.contains(RecurrencePatch.alarmAt) ||
          _sameOccurrenceClock(nextAlarm, template.alarmAt),
    );
    final nextReminder = clearReminderLeadMinutes ? null : reminderLeadMinutes;
    apply(
      RecurrencePatch.reminderLeadMinutes,
      !proposed.contains(RecurrencePatch.reminderLeadMinutes) ||
          nextReminder == template.reminderLeadMinutes,
    );
    apply(
      RecurrencePatch.isTimed,
      isTimed == null || isTimed == template.isTimed,
    );
    apply(
      RecurrencePatch.dayPeriod,
      dayPeriod == null || dayPeriod == template.dayPeriod,
    );
    apply(
      RecurrencePatch.isInbox,
      isInbox == null || isInbox == template.isInbox,
    );
    return owned.toList();
  }

  bool _sameOptionalText(String? a, String? b) {
    final left = a?.trim() ?? '';
    final right = b?.trim() ?? '';
    return left == right;
  }

  bool _sameOccurrenceClock(DateTime? a, DateTime? b) {
    if (a == null || b == null) return a == b;
    final left = a.toLocal();
    final right = b.toLocal();
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day &&
        left.hour == right.hour &&
        left.minute == right.minute;
  }

  String _rootId(TaskModel task) =>
      task.recurrenceRootId ?? task.recurrenceSeriesId ?? task.id;

  DateTime _occurrenceDay(TaskModel task) {
    final fromKey = RecurrenceOccurrence.parseDateKey(task.occurrenceDate);
    if (fromKey != null) return fromKey;
    final virtual = RecurrenceOccurrence.parse(task.id);
    if (virtual != null) {
      return RecurrenceOccurrence.parseDateKey(virtual.dateKey) ??
          RecurrenceOccurrence.dateOnly(DateTime.now());
    }
    if (task.scheduledAt != null) {
      return RecurrenceOccurrence.dateOnly(task.scheduledAt!);
    }
    return RecurrenceOccurrence.dateOnly(DateTime.now());
  }

  bool _seriesOccursOn(TaskModel master, DateTime day) {
    if (master.scheduledAt == null) return false;
    return RecurrenceGenerator.occursOn(
      date: day,
      start: master.scheduledAt!,
      type: master.recurrenceType,
      interval: master.recurrenceInterval,
      unit: master.recurrenceUnit,
      until: RecurrenceOccurrence.parseDateKey(master.recurrenceUntil),
    );
  }

  bool _seriesOccupiedOnDay(
    String seriesId,
    DateTime day,
    Iterable<TaskModel> tasks,
  ) {
    final dateKey = RecurrenceOccurrence.dateKey(day);
    for (final task in tasks) {
      if (task.recurrenceSeriesId != seriesId && task.id != seriesId) continue;
      if (task.isSeriesMaster) continue;
      if (task.occurrenceDate == dateKey) return true;
      if (task.occurrenceDate == null &&
          task.scheduledAt != null &&
          RecurrenceOccurrence.dateKey(task.scheduledAt!) == dateKey) {
        return true;
      }
    }
    return false;
  }

  TaskModel _virtualOccurrence(TaskModel master, DateTime day) {
    final scheduledAt = RecurrenceGenerator.scheduledAtFor(
      start: master.scheduledAt ?? day,
      date: day,
    );
    return master.copyWith(
      id: RecurrenceOccurrence.id(master.id, day),
      scheduledAt: scheduledAt,
      alarmAt: RecurrenceGenerator.alarmAtFor(
        alarmAt: master.alarmAt,
        occurrence: scheduledAt,
      ),
      clearAlarmAt: master.alarmAt == null,
      status: TaskStatus.pending,
      startedAt: null,
      completedAt: null,
      clearStartedAt: true,
      clearCompletedAt: true,
      isInbox: false,
      recurrenceSeriesId: master.id,
      recurrenceRootId: _rootId(master),
      occurrenceDate: RecurrenceOccurrence.dateKey(day),
      subtasks: const [],
    );
  }

  String _recurrenceTypeApi(RecurrenceType type) => switch (type) {
    RecurrenceType.none => 'NONE',
    RecurrenceType.daily => 'DAILY',
    RecurrenceType.weekly => 'WEEKLY',
    RecurrenceType.monthly => 'MONTHLY',
    RecurrenceType.yearly => 'YEARLY',
    RecurrenceType.custom => 'CUSTOM',
  };

  Future<FocusSessionModel?> getFocusSession() async => null;

  static String? _normalizeText(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
