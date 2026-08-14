import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/firebase/firebase_providers.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/adhd_models.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/repositories/repositories.dart';
import 'package:florien/core/services/planner_ai_service.dart';
import 'package:florien/core/services/social_auth_service.dart';
import 'package:florien/core/services/task_alarm_service.dart';
import 'package:florien/core/storage/todo_list_storage.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/utils/task_icons.dart';

final googleAuthServiceProvider = Provider<GoogleAuthService>(
  (ref) => GoogleAuthService(),
);

final appleAuthServiceProvider = Provider<AppleAuthService>(
  (ref) => AppleAuthService(),
);

final taskAlarmServiceProvider = Provider<TaskAlarmService>(
  (ref) => TaskAlarmService(),
);

final plannerAiGatewayProvider = Provider<PlannerAiGateway>(
  (ref) => FirebasePlannerAiGateway(ref.watch(cloudFunctionsProvider)),
);

final authStateProvider = AsyncNotifierProvider<AuthNotifier, AuthResponse?>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<AuthResponse?> {
  @override
  Future<AuthResponse?> build() => ref.read(authRepositoryProvider).getMe();

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .login(email: email, password: password),
    );
    _refreshPreferences();
  }

  Future<void> loginWithGoogle() async {
    final social = await ref.read(googleAuthServiceProvider).signIn();
    if (social == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signInWithCredential(
            social.credential,
            displayName: social.displayName,
          ),
    );
    _refreshPreferences();
  }

  Future<void> loginWithApple() async {
    if (!await ref.read(appleAuthServiceProvider).isAvailable) {
      state = AsyncError(
        StateError('Apple ile giriş bu cihazda kullanılamıyor.'),
        StackTrace.current,
      );
      return;
    }
    final social = await ref.read(appleAuthServiceProvider).signIn();
    if (social == null) return;
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signInWithCredential(
            social.credential,
            displayName: social.displayName,
          ),
    );
    _refreshPreferences();
  }

  Future<void> register(
    String email,
    String password,
    String displayName,
  ) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .register(email: email, password: password, displayName: displayName),
    );
    _refreshPreferences();
  }

  Future<void> logout() async {
    await ref.read(googleAuthServiceProvider).signOut();
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }

  void _refreshPreferences() {
    if (state.valueOrNull == null) return;
    ref.invalidate(appLanguageProvider);
    ref.invalidate(appThemeModeProvider);
  }
}

final todoListStorageProvider = Provider<TodoListStorage>(
  (ref) => TodoListStorage(),
);

final todoListsProvider =
    AsyncNotifierProvider<TodoListsNotifier, List<TodoListDefinition>>(
      TodoListsNotifier.new,
    );

class TodoListsNotifier extends AsyncNotifier<List<TodoListDefinition>> {
  @override
  Future<List<TodoListDefinition>> build() =>
      ref.read(todoListStorageProvider).load();

  Future<void> save(List<TodoListDefinition> lists) async {
    state = AsyncData(lists);
    await ref.read(todoListStorageProvider).save(lists);
  }
}

final inboxProvider = AsyncNotifierProvider<InboxNotifier, List<TaskModel>>(
  InboxNotifier.new,
);

final dailyTimelineProvider = FutureProvider.autoDispose
    .family<TimelineModel, DateTime>((ref, date) async {
      try {
        return await ref.read(taskRepositoryProvider).getTimeline(date);
      } catch (_) {
        return TimelineModel(date: date, tasks: const []);
      }
    });

final dailyDeleteTaskProvider = Provider<Future<void> Function(String)>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  return (id) => repository.deleteTask(id);
});

final dailyMoveToTodoProvider =
    Provider<Future<void> Function(String, String?)>((ref) {
      final repository = ref.watch(taskRepositoryProvider);
      return (id, todoListId) async {
        await repository.moveToInbox(id, todoListId: todoListId);
        if (ref.read(activeFocusTaskProvider)?.taskId == id) {
          ref.read(activeFocusTaskProvider.notifier).state = null;
          ref.read(focusTaskLaunchProvider.notifier).state = null;
          ref.read(focusTimerResetSignalProvider.notifier).state++;
        }
        ref.invalidate(inboxProvider);
        ref.invalidate(dailyTimelineProvider);
      };
    });

class FocusTaskLaunch {
  const FocusTaskLaunch({
    required this.taskId,
    required this.title,
    required this.durationMinutes,
    required this.icon,
    required this.color,
    this.startedAt,
    this.endsAt,
    this.automatic = false,
  });

  final String taskId;
  final String title;
  final int durationMinutes;
  final String icon;
  final String color;
  final DateTime? startedAt;
  final DateTime? endsAt;
  final bool automatic;
}

final focusTaskLaunchProvider = StateProvider<FocusTaskLaunch?>((ref) => null);

class ActiveFocusTask {
  const ActiveFocusTask({
    required this.taskId,
    required this.totalSeconds,
    required this.remainingSeconds,
    required this.isRunning,
  });

  final String taskId;
  final int totalSeconds;
  final int remainingSeconds;
  final bool isRunning;

  double get progress {
    if (totalSeconds <= 0) return 0;
    return (1 - remainingSeconds / totalSeconds).clamp(0, 1);
  }
}

final activeFocusTaskProvider = StateProvider<ActiveFocusTask?>((ref) => null);

final focusTimerResetSignalProvider = StateProvider<int>((ref) => 0);

final createStandaloneFocusTaskProvider =
    Provider<Future<FocusTaskLaunch> Function(int)>((ref) {
      final repository = ref.watch(taskRepositoryProvider);
      return (durationMinutes) async {
        final duration = durationMinutes.clamp(1, 24 * 60);
        final scheduledAt = DateTime.now();
        final created = await repository.createTask(
          title: 'Odaklan',
          color: '#6C5CE7',
          icon: 'timer',
          durationMinutes: duration,
          scheduledAt: scheduledAt,
          isTimed: true,
          isInbox: false,
          dayPeriod: dayPeriodForLocalTime(scheduledAt),
        );
        final started = await repository.startTask(created.id);
        final startedAt = started.startedAt ?? scheduledAt;

        ref.invalidate(inboxProvider);
        ref.invalidate(dailyTimelineProvider);
        return FocusTaskLaunch(
          taskId: started.id,
          title: started.title,
          durationMinutes: started.durationMinutes,
          icon: started.icon,
          color: started.color,
          startedAt: startedAt,
          endsAt: startedAt.add(Duration(minutes: duration)),
        );
      };
    });

final completionCountsProvider = FutureProvider.autoDispose<CompletionCounts>((
  ref,
) async {
  try {
    return await ref
        .read(taskRepositoryProvider)
        .getCompletionCounts(DateTime.now());
  } catch (_) {
    // The task that opened this page has just completed, so one is the safe
    // minimum while an offline count cannot be loaded.
    return const CompletionCounts(today: 1, thisWeek: 1);
  }
});

final manualCompletionSummaryProvider =
    Provider<Future<CompletionCounts> Function(String)>((ref) {
      return (taskId) async {
        if (ref.read(activeFocusTaskProvider)?.taskId == taskId) {
          ref.read(activeFocusTaskProvider.notifier).state = null;
          ref.read(focusTaskLaunchProvider.notifier).state = null;
          ref.read(focusTimerResetSignalProvider.notifier).state++;
        }
        ref.invalidate(completionCountsProvider);
        return ref.read(completionCountsProvider.future);
      };
    });

DayPeriod dayPeriodForLocalTime(DateTime localTime) {
  final hour = localTime.toLocal().hour;
  if (hour < 12) return DayPeriod.morning;
  if (hour < 18) return DayPeriod.daytime;
  return DayPeriod.evening;
}

final startTaskFocusProvider = Provider<Future<void> Function(TaskModel)>((
  ref,
) {
  final repository = ref.watch(taskRepositoryProvider);
  return (task) async {
    final now = DateTime.now();
    if (task.isInbox) {
      await repository.scheduleFromInbox(
        task.id,
        now,
        dayPeriod: dayPeriodForLocalTime(now),
      );
    } else if (task.isCompleted) {
      await repository.uncompleteTask(task.id);
    }
    await repository.startTask(task.id);
    ref.invalidate(inboxProvider);
    ref.invalidate(dailyTimelineProvider);
  };
});

final completeFocusedTaskProvider = Provider<Future<void> Function(String)>((
  ref,
) {
  final repository = ref.watch(taskRepositoryProvider);
  return (taskId) async {
    await repository.completeTask(taskId);
    if (ref.read(activeFocusTaskProvider)?.taskId == taskId) {
      ref.read(activeFocusTaskProvider.notifier).state = null;
    }
    if (ref.read(focusTaskLaunchProvider)?.taskId == taskId) {
      ref.read(focusTaskLaunchProvider.notifier).state = null;
    }
    ref.invalidate(inboxProvider);
    ref.invalidate(dailyTimelineProvider);
  };
});

class InboxNotifier extends AsyncNotifier<List<TaskModel>> {
  @override
  Future<List<TaskModel>> build() async {
    try {
      return await ref.read(taskRepositoryProvider).getInbox();
    } catch (_) {
      return const [];
    }
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(taskRepositoryProvider).getInbox(),
    );
  }

  Future<TaskModel> addToInbox({
    required String title,
    String? description,
    int durationMinutes = 30,
    String color = '#4F52B2',
    String? icon,
    EnergyLevel? energyLevel,
    String? motivation,
    TaskPriority priority = TaskPriority.none,
    String? todoListId,
  }) async {
    final task = await ref
        .read(taskRepositoryProvider)
        .createTask(
          title: title,
          description: description,
          durationMinutes: durationMinutes,
          color: color,
          icon: icon ?? TaskIcons.defaultName,
          isInbox: true,
          energyLevel: energyLevel,
          motivation: motivation,
          priority: priority,
          todoListId: todoListId,
        );
    await refresh();
    return task;
  }

  Future<void> addDetailed({
    required String title,
    required int durationMinutes,
    required TaskPriority priority,
    required String? todoListId,
    String? description,
    List<String> subtasks = const [],
  }) async {
    final task = await addToInbox(
      title: title,
      description: description,
      durationMinutes: durationMinutes,
      priority: priority,
      todoListId: todoListId,
    );
    if (subtasks.isNotEmpty) {
      await ref
          .read(taskRepositoryProvider)
          .addSubtasksToTask(
            parentId: task.id,
            subtasks: subtasks
                .map(
                  (title) =>
                      (title: title, durationMinutes: 5, color: task.color),
                )
                .toList(),
          );
      await refresh();
    }
  }

  Future<void> updateDetailed({
    required String id,
    required String title,
    required int durationMinutes,
    required TaskPriority priority,
    required String? todoListId,
    String? description,
    List<String> subtasks = const [],
  }) async {
    final repository = ref.read(taskRepositoryProvider);
    await repository.updateTask(
      id: id,
      title: title,
      description: description,
      clearDescription: description == null,
      durationMinutes: durationMinutes,
      priority: priority,
      todoListId: todoListId,
      clearTodoListId: todoListId == null,
    );
    await repository.replaceSubtasks(parentId: id, titles: subtasks);
    await refresh();
  }

  Future<void> completeTask(String id) async {
    await ref.read(taskRepositoryProvider).completeTask(id);
    await refresh();
  }

  Future<void> uncompleteTask(String id) async {
    await ref.read(taskRepositoryProvider).uncompleteTask(id);
    await refresh();
  }

  Future<void> scheduleTask(String id, DateTime scheduledAt) async {
    await ref.read(taskRepositoryProvider).scheduleFromInbox(id, scheduledAt);
    await refresh();
  }

  Future<void> updatePriority(String id, TaskPriority priority) async {
    await ref
        .read(taskRepositoryProvider)
        .updateTask(id: id, priority: priority);
    await refresh();
  }

  Future<void> moveTask(String id, String? todoListId) async {
    await ref
        .read(taskRepositoryProvider)
        .updateTask(
          id: id,
          todoListId: todoListId,
          clearTodoListId: todoListId == null,
        );
    await refresh();
  }

  Future<void> deleteTask(String id) async {
    await ref.read(taskRepositoryProvider).deleteTask(id);
    await refresh();
  }
}
