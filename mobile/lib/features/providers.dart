import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mimio/core/l10n/app_strings.dart';
import 'package:mimio/core/models/adhd_models.dart';
import 'package:mimio/core/models/models.dart';
import 'package:mimio/core/models/recurrence.dart';
import 'package:mimio/core/platform/live_activity_service.dart';
import 'package:mimio/core/platform/notification_service.dart';
import 'package:mimio/core/platform/widget_sync_service.dart';
import 'package:mimio/core/repositories/repositories.dart';
import 'package:mimio/core/services/calendar_import_service.dart';
import 'package:mimio/features/achievements/achievements_screen.dart';
import 'package:mimio/core/utils/task_icons.dart';
import 'package:mimio/core/firebase/user_profile_service.dart';
import 'package:mimio/core/services/social_auth_service.dart';
import 'package:mimio/core/storage/adhd_settings_storage.dart';
import 'package:mimio/core/storage/achievement_storage.dart';
import 'package:mimio/core/storage/local_focus_storage.dart';
import 'package:mimio/core/storage/settings_storage.dart';
import 'package:mimio/core/theme/mimio_theme.dart';

final localFocusStorageProvider = Provider<LocalFocusStorage>(
  (ref) => LocalFocusStorage(),
);

final googleAuthServiceProvider = Provider<GoogleAuthService>(
  (ref) => GoogleAuthService(),
);
final appleAuthServiceProvider = Provider<AppleAuthService>(
  (ref) => AppleAuthService(),
);

final liveActivityServiceProvider = Provider<LiveActivityService>(
  (ref) => LiveActivityService.instance,
);

final authStateProvider = AsyncNotifierProvider<AuthNotifier, AuthResponse?>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<AuthResponse?> {
  @override
  Future<AuthResponse?> build() async {
    return ref.read(authRepositoryProvider).getMe();
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
    });
    if (state.hasValue && state.value != null) {
      _invalidateSyncedPrefs();
    }
  }

  Future<void> loginWithGoogle() async {
    final social = await ref.read(googleAuthServiceProvider).signIn();
    if (social == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref
          .read(authRepositoryProvider)
          .signInWithCredential(
            social.credential,
            displayName: social.displayName,
          );
    });
    if (state.hasValue && state.value != null) {
      _invalidateSyncedPrefs();
    }
  }

  Future<void> loginWithApple() async {
    final available = await ref.read(appleAuthServiceProvider).isAvailable;
    if (!available) {
      state = AsyncError(
        Exception('Apple Sign-In is not available on this device'),
        StackTrace.current,
      );
      return;
    }

    final social = await ref.read(appleAuthServiceProvider).signIn();
    if (social == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref
          .read(authRepositoryProvider)
          .signInWithCredential(
            social.credential,
            displayName: social.displayName,
          );
    });
    if (state.hasValue && state.value != null) {
      _invalidateSyncedPrefs();
    }
  }

  Future<void> register(
    String email,
    String password,
    String displayName,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return ref
          .read(authRepositoryProvider)
          .register(email: email, password: password, displayName: displayName);
    });
    if (state.hasValue && state.value != null) {
      _invalidateSyncedPrefs();
    }
  }

  void _invalidateSyncedPrefs() {
    ref.invalidate(appLanguageProvider);
    ref.invalidate(appThemeModeProvider);
    ref.invalidate(adhdPreferencesProvider);
    ref.invalidate(achievementStatsProvider);
  }

  Future<void> logout() async {
    final userId = state.valueOrNull?.userId;
    await ref.read(focusSessionProvider.notifier).clearSession();
    await ref.read(googleAuthServiceProvider).signOut();
    await ref.read(authRepositoryProvider).logout();
    if (userId != null) {
      await ref.read(achievementStorageProvider).clear(userId);
      await ref
          .read(adhdSettingsStorageProvider)
          .clearUnlockedAchievementIds(userId);
    }
    state = const AsyncData(null);
  }

  Future<void> updateProfile({String? displayName, String? avatarColor}) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final updated = await ref
        .read(authRepositoryProvider)
        .updateProfile(displayName: displayName, avatarColor: avatarColor);
    state = AsyncData(updated);
  }

  Future<void> pushSettingsToCloud() async {
    final userId = state.valueOrNull?.userId;
    if (userId == null) return;
    await ref
        .read(userProfileServiceProvider)
        .pushLocalSettingsToCloud(
          uid: userId,
          settings: ref.read(settingsStorageProvider),
          adhd: ref.read(adhdSettingsStorageProvider),
          achievements: ref.read(achievementStorageProvider),
        );
  }
}

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

enum TimelineViewMode { list, grid }

final timelineViewModeProvider = StateProvider<TimelineViewMode>(
  (ref) => TimelineViewMode.list,
);

class CelebrationEvent {
  const CelebrationEvent({required this.taskTitle, this.reward});

  final String taskTitle;
  final String? reward;

  bool get hasReward => reward != null && reward!.isNotEmpty;
}

TaskModel? findTaskInTimeline(TimelineModel timeline, String id) {
  for (final task in timeline.tasks) {
    if (task.id == id) return task;
    for (final sub in task.subtasks) {
      if (sub.id == id) return sub;
    }
  }
  return null;
}

Set<String> _taskIdsAffectedByDelete(
  TimelineModel timeline,
  TaskModel task,
  DeleteRecurrenceScope scope,
) {
  final ids = <String>{task.id};
  if (scope == DeleteRecurrenceScope.thisOccurrence ||
      task.recurrenceSeriesId == null) {
    return ids;
  }

  final seriesId = task.recurrenceSeriesId!;
  final cutoff = task.scheduledAt;

  void collect(List<TaskModel> tasks) {
    for (final candidate in tasks) {
      final inSeries = candidate.recurrenceSeriesId == seriesId;
      final matchesScope =
          scope == DeleteRecurrenceScope.all ||
          (cutoff != null &&
              candidate.scheduledAt != null &&
              !candidate.scheduledAt!.isBefore(cutoff));
      if (inSeries && matchesScope) {
        ids.add(candidate.id);
      }
      collect(candidate.subtasks);
    }
  }

  collect(timeline.tasks);
  return ids;
}

final focusSessionProvider =
    AsyncNotifierProvider<FocusSessionNotifier, FocusSessionModel?>(
      FocusSessionNotifier.new,
    );

class FocusSessionNotifier extends AsyncNotifier<FocusSessionModel?> {
  Timer? _tickTimer;
  LocalFocusSessionData? _session;

  @override
  Future<FocusSessionModel?> build() async {
    ref.onDispose(() => _tickTimer?.cancel());

    _session = await ref.read(localFocusStorageProvider).load();
    _syncTickTimer();
    if (_session != null) {
      final lang = ref.read(appLanguageProvider).valueOrNull ?? 'tr';
      await ref
          .read(liveActivityServiceProvider)
          .syncSession(_session!, language: lang);
    }
    return _session?.toFocusSessionModel();
  }

  Future<void> startWithTask(TaskModel task) async {
    _session = LocalFocusSessionData.fromTask(task);
    await _persistAndSync();
    _syncTickTimer();
  }

  Future<void> startStandalone({
    required String title,
    int durationMinutes = 25,
    String color = '#4F52B2',
  }) async {
    _session = LocalFocusSessionData.standalone(
      title: title,
      durationMinutes: durationMinutes,
      color: color,
    );
    await _persistAndSync();
    _syncTickTimer();
  }

  Future<void> pause() async {
    final session = _session;
    if (session == null || session.isPaused) return;
    _session = session.copyWith(pausedAt: DateTime.now());
    await _persistAndSync();
    _tickTimer?.cancel();
  }

  Future<void> resume() async {
    final session = _session;
    if (session == null || !session.isPaused || session.pausedAt == null)
      return;
    final pauseMs = DateTime.now().difference(session.pausedAt!).inMilliseconds;
    _session = session.copyWith(
      accumulatedPauseMs: session.accumulatedPauseMs + pauseMs,
      clearPausedAt: true,
    );
    await _persistAndSync();
    _syncTickTimer();
  }

  Future<void> seekBySeconds(int seconds) async {
    final session = _session;
    if (session == null) return;
    final total = session.durationMinutes * 60;
    final targetElapsed =
        session.toFocusSessionModel().elapsedSeconds + seconds;
    _applyElapsedSeconds(targetElapsed.clamp(0, total));
    await _persistAndSync();
  }

  void seekToProgress(double progress, {bool persist = true}) {
    final session = _session;
    if (session == null) return;
    final total = session.durationMinutes * 60;
    final targetElapsed = (progress.clamp(0.0, 1.0) * total).round();
    _applyElapsedSeconds(targetElapsed);
    if (persist) {
      _persistAndSync();
    }
  }

  Future<void> persistSession() => _persistAndSync();

  void _applyElapsedSeconds(int targetElapsed) {
    final session = _session;
    if (session == null) return;
    final total = session.durationMinutes * 60;
    final clamped = targetElapsed.clamp(0, total);
    final currentElapsed = session.toFocusSessionModel().elapsedSeconds;
    if (clamped == currentElapsed) return;

    final now = DateTime.now();
    var pauseMs = session.accumulatedPauseMs;
    if (session.pausedAt != null) {
      pauseMs += now.difference(session.pausedAt!).inMilliseconds;
    }
    final newStartedAt = now.subtract(
      Duration(milliseconds: pauseMs + clamped * 1000),
    );
    _session = session.copyWith(startedAt: newStartedAt);
    state = AsyncData(_session!.toFocusSessionModel());
  }

  Future<void> clearSession() async {
    _tickTimer?.cancel();
    _session = null;
    state = const AsyncData(null);
    await ref.read(localFocusStorageProvider).clear();
    try {
      await ref.read(liveActivityServiceProvider).endActivity();
    } catch (e) {
      debugPrint('Live activity end skipped: $e');
    }
  }

  Future<void> _persistAndSync() async {
    final session = _session;
    if (session == null) return;
    await ref.read(localFocusStorageProvider).save(session);
    state = AsyncData(session.toFocusSessionModel());
    final lang = ref.read(appLanguageProvider).valueOrNull ?? 'tr';
    await ref
        .read(liveActivityServiceProvider)
        .syncSession(session, language: lang);
    ref.invalidate(timelineProvider);
  }

  void _syncTickTimer() {
    _tickTimer?.cancel();
    final session = _session;
    if (session == null || session.isPaused) return;
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = _session;
      if (current == null) return;
      state = AsyncData(current.toFocusSessionModel());
    });
  }
}

final timelineProvider = AsyncNotifierProvider<TimelineNotifier, TimelineModel>(
  TimelineNotifier.new,
);

class TimelineNotifier extends AsyncNotifier<TimelineModel> {
  @override
  Future<TimelineModel> build() async {
    final date = ref.watch(selectedDateProvider);
    final timeline = await ref.read(taskRepositoryProvider).getTimeline(date);
    await _syncPlatform(timeline);
    return timeline;
  }

  Future<void> refresh({bool showLoading = true}) async {
    if (showLoading) state = const AsyncLoading();
    final date = ref.read(selectedDateProvider);
    state = await AsyncValue.guard(() async {
      return ref.read(taskRepositoryProvider).getTimeline(date);
    });
    final timeline = state.valueOrNull;
    if (timeline != null) await _syncPlatform(timeline);
  }

  Future<void> _refreshAfterAction() async {
    final date = ref.read(selectedDateProvider);
    final previous = state.valueOrNull;
    try {
      final timeline = await ref.read(taskRepositoryProvider).getTimeline(date);
      state = AsyncData(timeline);
      await _syncPlatform(timeline);
    } catch (e, st) {
      debugPrint('Refresh after task action failed: $e\n$st');
      if (previous != null) state = AsyncData(previous);
      rethrow;
    }
  }

  Future<void> _syncPlatform(TimelineModel timeline) async {
    try {
      final session = ref.read(focusSessionProvider).valueOrNull;
      final lang = ref.read(appLanguageProvider).valueOrNull ?? 'tr';
      await WidgetSyncService.syncTimeline(
        timeline,
        session: session,
        language: lang,
      );
    } catch (e) {
      debugPrint('Platform sync skipped: $e');
    }
  }

  Future<void> createTask({
    required String title,
    String? description,
    String? icon,
    int durationMinutes = 30,
    String color = '#4F52B2',
    DateTime? scheduledAt,
    RecurrenceSelection recurrence = const RecurrenceSelection(),
    String? reward,
    bool autoStart = false,
    bool isInbox = false,
    TaskReminderSettings reminders = const TaskReminderSettings(),
    EnergyLevel? energyLevel,
    String? motivation,
    int transitionBufferMinutes = 0,
  }) async {
    final taskIcon = icon ?? TaskIcons.inferName(title);
    final task = await ref
        .read(taskRepositoryProvider)
        .createTask(
          title: title,
          description: description,
          durationMinutes: durationMinutes,
          color: color,
          icon: taskIcon,
          scheduledAt: scheduledAt,
          isInbox: isInbox,
          recurrence: recurrence,
          reward: reward,
          energyLevel: energyLevel,
          motivation: motivation,
          transitionBufferMinutes: transitionBufferMinutes,
        );
    if (autoStart) {
      await ref.read(focusSessionProvider.notifier).startWithTask(task);
    }
    await refresh(showLoading: false);
    if (!isInbox) {
      await _scheduleReminders(task, reminders);
    } else {
      ref.invalidate(inboxProvider);
    }
  }

  Future<int> importCalendarEvents(List<CalendarImportEvent> events) async {
    if (events.isEmpty) return 0;

    final importedIds = <String>[];
    for (final event in events) {
      await ref
          .read(taskRepositoryProvider)
          .createTask(
            title: event.title,
            description: event.description,
            durationMinutes: event.durationMinutes,
            color: event.color,
            scheduledAt: event.scheduledAt,
          );
      importedIds.add(event.id);
    }

    await ref
        .read(settingsStorageProvider)
        .markCalendarEventsImported(importedIds);
    await refresh(showLoading: false);
    return importedIds.length;
  }

  Future<void> createTaskWithSubtasks({
    required String title,
    required DateTime scheduledAt,
    String color = '#4F52B2',
    required List<({String title, int durationMinutes, String color})> subtasks,
    bool autoStart = false,
  }) async {
    final task = await ref
        .read(taskRepositoryProvider)
        .createTaskWithSubtasks(
          title: title,
          scheduledAt: scheduledAt,
          color: color,
          icon: TaskIcons.inferName(title),
          subtasks: subtasks,
        );
    if (autoStart) {
      final firstSubtask = task.subtasks.isNotEmpty
          ? task.subtasks.first
          : task;
      await ref.read(focusSessionProvider.notifier).startWithTask(firstSubtask);
    }
    await refresh(showLoading: false);
  }

  Future<void> updateTask({
    required String id,
    String? title,
    String? description,
    String? color,
    int? durationMinutes,
    DateTime? scheduledAt,
    String? reward,
    TaskReminderSettings? reminders,
    EnergyLevel? energyLevel,
    String? motivation,
    int? transitionBufferMinutes,
    bool? isInbox,
  }) async {
    final task = await ref
        .read(taskRepositoryProvider)
        .updateTask(
          id: id,
          title: title,
          description: description,
          color: color,
          durationMinutes: durationMinutes,
          scheduledAt: scheduledAt,
          reward: reward,
          energyLevel: energyLevel,
          motivation: motivation,
          transitionBufferMinutes: transitionBufferMinutes,
          isInbox: isInbox,
        );
    await refresh(showLoading: false);
    ref.invalidate(inboxProvider);
    if (reminders != null) {
      await _scheduleReminders(task, reminders);
    } else if (scheduledAt != null) {
      final existing = await ref
          .read(notificationServiceProvider)
          .loadReminderSettings(id);
      if (existing.hasAny) {
        await _scheduleReminders(task, existing);
      }
    }
  }

  Future<void> addSubtasksToTask({
    required String parentId,
    required List<({String title, int durationMinutes, String color})> subtasks,
  }) async {
    await ref
        .read(taskRepositoryProvider)
        .addSubtasksToTask(parentId: parentId, subtasks: subtasks);
    await refresh(showLoading: false);
  }

  Future<void> startTask(String id) async {
    final timeline = state.valueOrNull;
    if (timeline == null) {
      await refresh(showLoading: false);
    }
    final current = state.valueOrNull;
    if (current == null) return;

    final task = findTaskInTimeline(current, id);
    if (task == null) {
      throw StateError('Task not found');
    }
    await ref.read(focusSessionProvider.notifier).startWithTask(task);
    await _syncPlatform(current);
  }

  Future<void> pauseTask(String id) async {
    final session = ref.read(focusSessionProvider).valueOrNull;
    if (session?.taskId != id) return;
    await ref.read(focusSessionProvider.notifier).pause();
    final timeline = state.valueOrNull;
    if (timeline != null) await _syncPlatform(timeline);
  }

  Future<void> resumeTask(String id) async {
    final session = ref.read(focusSessionProvider).valueOrNull;
    if (session?.taskId != id) return;
    await ref.read(focusSessionProvider.notifier).resume();
    final timeline = state.valueOrNull;
    if (timeline != null) await _syncPlatform(timeline);
  }

  Future<TaskModel> completeTask(String id) async {
    final timeline = state.valueOrNull;
    final task = timeline != null ? findTaskInTimeline(timeline, id) : null;

    await ref.read(focusSessionProvider.notifier).clearSession();
    final completed = await ref.read(taskRepositoryProvider).completeTask(id);
    await _refreshAfterAction();

    if (task != null) {
      await ref
          .read(achievementStatsProvider.notifier)
          .recordTaskCompleted(completedAt: DateTime.now());
    }

    return completed;
  }

  Future<TaskModel> uncompleteTask(String id) async {
    final task = await ref.read(taskRepositoryProvider).uncompleteTask(id);
    await refresh(showLoading: false);
    return task;
  }

  Future<void> deleteTask(
    String id, {
    DeleteRecurrenceScope scope = DeleteRecurrenceScope.thisOccurrence,
  }) async {
    final timeline = state.valueOrNull;
    final task = timeline != null ? findTaskInTimeline(timeline, id) : null;
    final idsToCancel = task != null && timeline != null
        ? _taskIdsAffectedByDelete(timeline, task, scope)
        : {id};

    final session = ref.read(focusSessionProvider).valueOrNull;
    if (session != null && idsToCancel.contains(session.taskId)) {
      await ref.read(focusSessionProvider.notifier).clearSession();
    }
    for (final taskId in idsToCancel) {
      await ref.read(notificationServiceProvider).cancelTaskReminders(taskId);
    }
    await ref.read(taskRepositoryProvider).deleteTask(id, scope: scope);
    await refresh(showLoading: false);
  }

  Future<void> _scheduleReminders(
    TaskModel task,
    TaskReminderSettings reminders,
  ) async {
    if (!reminders.hasAny) {
      await ref.read(notificationServiceProvider).cancelTaskReminders(task.id);
      return;
    }
    final s = ref.read(stringsProvider);
    final prefs =
        ref.read(adhdPreferencesProvider).valueOrNull ??
        const AdhdPreferences();
    await ref.read(notificationServiceProvider).requestPermission();
    await ref
        .read(notificationServiceProvider)
        .scheduleTaskReminders(
          task,
          settings: reminders,
          titlePrefix: s.taskReminderTitle,
          body10: s.taskReminder10('{title}'),
          body5: s.taskReminder5('{title}'),
          body1: s.taskReminder1('{title}'),
          bodyTransition: s.taskReminderTransition('{title}', ''),
          bodyEnd: s.taskReminderEnd('{title}'),
          scheduleTransition: prefs.transitionAlerts,
        );
  }
}

final weeklyTimelineProvider = FutureProvider<List<TimelineModel>>((ref) async {
  final selected = ref.watch(selectedDateProvider);
  final monday = selected.subtract(Duration(days: selected.weekday - 1));
  final repo = ref.read(taskRepositoryProvider);
  final futures = List.generate(
    7,
    (i) => repo.getTimeline(monday.add(Duration(days: i))),
  );
  return Future.wait(futures);
});

final inboxProvider = AsyncNotifierProvider<InboxNotifier, List<TaskModel>>(
  InboxNotifier.new,
);

class InboxNotifier extends AsyncNotifier<List<TaskModel>> {
  @override
  Future<List<TaskModel>> build() async {
    try {
      return await ref.read(taskRepositoryProvider).getInbox();
    } catch (_) {
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(taskRepositoryProvider).getInbox(),
    );
  }

  Future<void> addToInbox({
    required String title,
    int durationMinutes = 30,
    String color = '#4F52B2',
    String? icon,
    EnergyLevel? energyLevel,
    String? motivation,
  }) async {
    await ref
        .read(taskRepositoryProvider)
        .createTask(
          title: title,
          durationMinutes: durationMinutes,
          color: color,
          icon: icon ?? TaskIcons.inferName(title),
          isInbox: true,
          energyLevel: energyLevel,
          motivation: motivation,
        );
    await refresh();
  }

  Future<void> scheduleTask(String id, DateTime scheduledAt) async {
    await ref.read(taskRepositoryProvider).scheduleFromInbox(id, scheduledAt);
    await refresh();
  }

  Future<void> deleteTask(
    String id, {
    DeleteRecurrenceScope scope = DeleteRecurrenceScope.thisOccurrence,
  }) async {
    await ref.read(taskRepositoryProvider).deleteTask(id, scope: scope);
    await refresh();
  }
}
