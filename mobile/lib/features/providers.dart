import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/firebase/firebase_providers.dart';
import 'package:florien/core/firebase/onboarding_firestore_storage.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/adhd_models.dart';
import 'package:florien/core/models/achievement.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/models/mood_entry.dart';
import 'package:florien/core/repositories/repositories.dart';
import 'package:florien/core/services/apple_health_mood_service.dart';
import 'package:florien/core/services/qwen_on_device_ai.dart';
import 'package:florien/core/services/planner_ai_service.dart';
import 'package:florien/core/services/calendar_connection_service.dart';
import 'package:florien/core/services/home_screen_widget_service.dart';
import 'package:florien/core/services/live_activity_service.dart';
import 'package:florien/core/services/social_auth_service.dart';
import 'package:florien/core/services/task_alarm_service.dart';
import 'package:florien/core/services/notification_payload.dart';
import 'package:florien/core/storage/settings_storage.dart';
import 'package:florien/core/storage/achievement_progress_storage.dart';
import 'package:florien/core/storage/onboarding_login_intent_storage.dart';
import 'package:florien/core/storage/onboarding_storage.dart';
import 'package:florien/core/storage/mood_storage.dart';
import 'package:florien/core/storage/profile_storage.dart';
import 'package:florien/core/storage/todo_list_storage.dart';
import 'package:florien/core/storage/firestore_task_collection.dart';
import 'package:florien/core/storage/local_task_collection.dart';
import 'package:florien/core/storage/task_storage_mode.dart';
import 'package:florien/core/storage/task_storage_router.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/utils/task_icons.dart';
import 'package:florien/features/premium/premium_membership.dart';
import 'package:florien/firebase_options.dart';

final googleAuthServiceProvider = Provider<GoogleAuthService>(
  (ref) => GoogleAuthService(),
);

final appleAuthServiceProvider = Provider<AppleAuthService>(
  (ref) => AppleAuthService(),
);

final onboardingStorageProvider = Provider<OnboardingStorage>(
  (ref) => OnboardingStorage(),
);

final onboardingLoginIntentStorageProvider =
    Provider<OnboardingLoginIntentStorage>(
      (ref) => OnboardingLoginIntentStorage(),
    );

final recentAuthIsNewUserProvider = StateProvider<bool?>((ref) => null);

final onboardingRemoteStorageProvider = Provider<OnboardingRemoteStorage>(
  (ref) => OnboardingFirestoreStorage(ref.watch(firestoreProvider)),
);

final onboardingPreferencesRepositoryProvider =
    Provider<OnboardingPreferencesRepository>(
      (ref) => OnboardingPreferencesRepository(
        local: ref.watch(onboardingStorageProvider),
        remote: ref.watch(onboardingRemoteStorageProvider),
      ),
    );

final onboardingPreferencesProvider =
    AsyncNotifierProvider<OnboardingPreferencesNotifier, OnboardingPreferences>(
      OnboardingPreferencesNotifier.new,
    );

class OnboardingPreferencesNotifier
    extends AsyncNotifier<OnboardingPreferences> {
  String? _userId;

  @override
  Future<OnboardingPreferences> build() async {
    _userId = ref.watch(authStateProvider).valueOrNull?.userId;
    final userId = _userId;
    if (userId == null) {
      return ref.read(onboardingStorageProvider).load('guest');
    }
    return ref
        .read(onboardingPreferencesRepositoryProvider)
        .loadAuthenticated(userId);
  }

  Future<void> recordOnboardingAnswer({
    required String questionId,
    required String answerId,
  }) {
    final current = state.valueOrNull ?? const OnboardingPreferences();
    return _save(
      current.copyWith(
        answers: {
          ...current.answers,
          questionId: OnboardingAnswer(
            questionId: questionId,
            answerId: answerId,
            answeredAt: DateTime.now(),
          ),
        },
      ),
    );
  }

  Future<void> completeOnboarding() {
    final current = state.valueOrNull ?? const OnboardingPreferences();
    return _save(current.copyWith(completed: true));
  }

  Future<void> restartOnboarding() => _save(const OnboardingPreferences());

  Future<void> _save(OnboardingPreferences preferences) async {
    final previous = state;
    state = AsyncData(preferences);
    try {
      final userId = _userId;
      if (userId == null) {
        await ref.read(onboardingStorageProvider).save('guest', preferences);
      } else {
        await ref
            .read(onboardingPreferencesRepositoryProvider)
            .saveAuthenticated(userId, preferences);
      }
    } catch (error, stackTrace) {
      state = previous;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}

final taskAlarmServiceProvider = Provider<TaskAlarmService>(
  (ref) => TaskAlarmService(ref.watch(settingsStorageProvider)),
);

final notificationPreferencesProvider = FutureProvider<NotificationPreferences>(
  (ref) => ref.watch(taskAlarmServiceProvider).getPreferences(),
);

class NotificationLaunchCommand {
  const NotificationLaunchCommand({
    required this.target,
    this.taskId,
    this.kind,
  });

  final NotificationTargetScreen target;
  final String? taskId;
  final FlorienNotificationKind? kind;
}

final notificationLaunchProvider = StateProvider<NotificationLaunchCommand?>(
  (ref) => null,
);

final dailyPlannerDateRequestProvider = StateProvider<DateTime?>((ref) => null);

final dailyReviewLaunchSignalProvider = StateProvider<int>((ref) => 0);

/// Reconciles OS local notifications with upcoming tasks.
final notificationReconcileProvider =
    Provider<Future<void> Function({int? previousDefaultLeadMinutes})>((ref) {
      return ({int? previousDefaultLeadMinutes}) async {
        final auth = ref.read(authStateProvider).valueOrNull;
        if (auth == null) return;
        final alarms = ref.read(taskAlarmServiceProvider);
        final repository = ref.read(taskRepositoryProvider);
        final now = DateTime.now();
        final tasks = await repository.getUpcomingTimedTasks(
          from: now,
          to: now.add(const Duration(days: 14)),
        );
        await alarms.reconcile(
          accountId: auth.userId,
          upcomingTasks: tasks,
          previousDefaultLeadMinutes: previousDefaultLeadMinutes,
        );
      };
    });

final liveActivityServiceProvider = Provider<FlorienLiveActivityService>(
  (ref) => FlorienLiveActivityService(),
);

final liveActivityPreferencesProvider = FutureProvider<LiveActivityPreferences>(
  (ref) => ref.watch(settingsStorageProvider).getLiveActivityPreferences(),
);

final calendarConnectionServiceProvider = Provider<CalendarConnectionService>(
  (ref) => CalendarConnectionService(ref.watch(settingsStorageProvider)),
);

final calendarConnectionsProvider = FutureProvider<List<CalendarConnection>>(
  (ref) => ref.watch(calendarConnectionServiceProvider).getConnections(),
);

final profileStorageProvider = Provider<ProfileStorage>(
  (ref) => ProfileStorage(firestore: ref.watch(optionalFirestoreProvider)),
);

final appProfilesProvider =
    AsyncNotifierProvider<AppProfilesNotifier, AppProfilesState>(
      AppProfilesNotifier.new,
    );

class AppProfilesNotifier extends AsyncNotifier<AppProfilesState> {
  late String _ownerId;
  late String _fallbackName;

  @override
  Future<AppProfilesState> build() async {
    final auth = ref.watch(authStateProvider).valueOrNull;
    _ownerId = auth?.userId ?? 'guest';
    _fallbackName = auth?.firstName.isNotEmpty == true
        ? auth!.firstName
        : ActiveLanguage.s('Profilim');
    final profiles = await ref
        .read(profileStorageProvider)
        .load(ownerId: _ownerId, fallbackName: _fallbackName);
    if (auth != null) await _migrateLocalData(profiles);
    return profiles;
  }

  Future<void> create(String name) => _save(
    () => ref
        .read(profileStorageProvider)
        .create(ownerId: _ownerId, fallbackName: _fallbackName, name: name),
  );

  Future<void> rename(String profileId, String name) => _save(
    () => ref
        .read(profileStorageProvider)
        .rename(
          ownerId: _ownerId,
          fallbackName: _fallbackName,
          profileId: profileId,
          name: name,
        ),
  );

  Future<void> select(String profileId) async {
    final currentId = state.valueOrNull?.activeProfileId;
    final next = await _save(
      () => ref
          .read(profileStorageProvider)
          .select(
            ownerId: _ownerId,
            fallbackName: _fallbackName,
            profileId: profileId,
          ),
    );
    if (next.activeProfileId != currentId) _resetProfileScopedState();
  }

  Future<void> delete(String profileId) async {
    final currentId = state.valueOrNull?.activeProfileId;
    final next = await _save(
      () => ref
          .read(profileStorageProvider)
          .delete(
            ownerId: _ownerId,
            fallbackName: _fallbackName,
            profileId: profileId,
          ),
    );
    if (next.activeProfileId != currentId) _resetProfileScopedState();
  }

  Future<AppProfilesState> _save(
    Future<AppProfilesState> Function() operation,
  ) async {
    try {
      final next = await operation();
      state = AsyncData(next);
      return next;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  void _resetProfileScopedState() {
    ref.read(activeFocusTaskProvider.notifier).state = null;
    ref.read(focusTaskLaunchProvider.notifier).state = null;
    ref.read(focusTimerResetSignalProvider.notifier).state++;
    ref.invalidate(inboxProvider);
    ref.invalidate(todoListsProvider);
    ref.invalidate(dailyTimelineProvider);
    ref.invalidate(completionCountsProvider);
    ref.invalidate(moodEntriesProvider);
    unawaited(ref.read(notificationReconcileProvider)());
  }

  Future<void> _migrateLocalData(AppProfilesState state) async {
    for (final profile in state.profiles) {
      final scope = '$_ownerId:${profile.id}';
      await _bestEffort(
        () => ref.read(todoListStorageProvider).load(profileScope: scope),
      );
      await _bestEffort(() => ref.read(moodStorageProvider).load(scope));
      await _bestEffort(
        () => ref
            .read(achievementProgressStorageProvider)
            .preserveCompletedTaskCount(profileScope: scope, currentCount: 0),
      );
      await _bestEffort(
        () => ref
            .read(achievementProgressStorageProvider)
            .loadCelebratedThreshold(scope),
      );
    }
    final settings = ref.read(settingsStorageProvider);
    await _bestEffort(settings.getImportedCalendarEventIds);
    for (final provider in CalendarProvider.values) {
      await _bestEffort(
        () => settings.getCalendarConnectionDetail(provider.name),
      );
    }
  }

  Future<void> _bestEffort(Future<Object?> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      // Local data remains intact and will be retried on the next app start.
    }
  }
}

final activeAppProfileProvider = Provider<AppProfile?>(
  (ref) => ref.watch(appProfilesProvider).valueOrNull?.activeProfile,
);

final activeProfileScopeProvider = Provider<String>((ref) {
  final ownerId = ref.watch(authStateProvider).valueOrNull?.userId ?? 'guest';
  final profileId = ref.watch(activeAppProfileProvider)?.id ?? 'primary';
  return '$ownerId:$profileId';
});

final moodStorageProvider = Provider<MoodStorage>(
  (ref) => MoodStorage(firestore: ref.watch(optionalFirestoreProvider)),
);

final appleHealthMoodServiceProvider = Provider<AppleHealthMoodService>(
  (ref) => AppleHealthMoodService(),
);

final moodEntriesProvider =
    AsyncNotifierProvider<MoodEntriesNotifier, List<MoodEntry>>(
      MoodEntriesNotifier.new,
    );

class MoodEntriesNotifier extends AsyncNotifier<List<MoodEntry>> {
  late String _profileScope;

  @override
  Future<List<MoodEntry>> build() async {
    _profileScope = ref.watch(activeProfileScopeProvider);
    return ref.read(moodStorageProvider).load(_profileScope);
  }

  Future<void> saveEntry(MoodEntry entry) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (entry.day.isAfter(today)) {
      throw ArgumentError.value(
        entry.date,
        'entry.date',
        ActiveLanguage.s(
          'Ruh hali ve günlük yansıma gelecekteki bir güne kaydedilemez.',
        ),
      );
    }
    final current = state.valueOrNull ?? const <MoodEntry>[];
    final updated = _upsert(current, entry.copyWith(healthSynced: false));
    await _persist(updated);
    if (await ref
        .read(moodStorageProvider)
        .isHealthSyncEnabled(_profileScope)) {
      await _syncUnsyncedEntries(updated);
    }
  }

  Future<bool> connectAppleHealth() async {
    final allowed = await ref
        .read(appleHealthMoodServiceProvider)
        .requestAuthorization();
    if (!allowed) return false;
    await ref
        .read(moodStorageProvider)
        .setHealthSyncEnabled(_profileScope, true);
    await syncCurrentWeek();
    return true;
  }

  Future<void> syncCurrentWeek() async {
    final current = state.valueOrNull ?? const <MoodEntry>[];
    var updated = await _syncUnsyncedEntries(current, persist: false);
    final weekStart = _startOfWeek(DateTime.now());
    final healthEntries = await ref
        .read(appleHealthMoodServiceProvider)
        .readWeek(weekStart);
    for (final healthEntry in healthEntries) {
      final alreadyStored = updated.any(
        (entry) => _isSameDay(entry.date, healthEntry.date),
      );
      if (!alreadyStored) {
        updated = _upsert(
          updated,
          MoodEntry(
            date: healthEntry.date,
            mood: healthEntry.mood,
            healthSynced: true,
          ),
        );
      }
    }
    await _persist(updated);
  }

  Future<List<MoodEntry>> _syncUnsyncedEntries(
    List<MoodEntry> entries, {
    bool persist = true,
  }) async {
    final service = ref.read(appleHealthMoodServiceProvider);
    var updated = [...entries];
    for (var index = 0; index < updated.length; index++) {
      final entry = updated[index];
      if (entry.healthSynced || !await service.save(entry)) continue;
      updated[index] = entry.copyWith(healthSynced: true);
    }
    if (persist) await _persist(updated);
    return updated;
  }

  Future<void> _persist(List<MoodEntry> entries) async {
    await ref.read(moodStorageProvider).save(_profileScope, entries);
    state = AsyncData(entries);
  }

  List<MoodEntry> _upsert(List<MoodEntry> entries, MoodEntry entry) {
    final result =
        entries
            .where((current) => !_isSameDay(current.date, entry.date))
            .toList()
          ..add(entry);
    result.sort((first, second) => first.date.compareTo(second.date));
    return result;
  }
}

DateTime _startOfWeek(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

bool _isSameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

final taskStorageModeStoreProvider = Provider<TaskStorageModeStore>(
  (ref) => TaskStorageModeStore(),
);

final taskStorageRouterProvider = Provider<TaskStorageRouter?>((ref) {
  final uid = ref.watch(firebaseUserProvider).valueOrNull?.uid;
  if (uid == null) return null;
  final profileId = ref.watch(activeAppProfileProvider)?.id ?? 'primary';
  final firestore = ref.watch(optionalFirestoreProvider);
  final router = TaskStorageRouter(
    uid: uid,
    profileId: profileId,
    openLocal: () => LocalTaskCollection.open(uid: uid, profileId: profileId),
    cloud: firestore == null
        ? null
        : FirestoreTaskCollection(tasksCol(firestore, uid, profileId)),
    isPremium: () {
      final membership = ref.read(premiumMembershipProvider);
      if (membership.isLoading && membership.valueOrNull == null) return null;
      return membership.valueOrNull?.hasActivePremium ?? false;
    },
    modeStore: ref.watch(taskStorageModeStoreProvider),
    confirmPremium: () async {
      if (!DefaultFirebaseOptions.isConfigured) return false;
      try {
        final entitlement = await ref
            .read(premiumPurchaseServiceProvider)
            .fetchEntitlement()
            .timeout(const Duration(seconds: 8));
        return entitlement.isPremium;
      } catch (_) {
        return false;
      }
    },
  );
  ref.listen(premiumMembershipProvider, (previous, next) {
    final wasPremium = previous?.valueOrNull?.hasActivePremium;
    final isPremium = next.valueOrNull?.hasActivePremium;
    if (wasPremium == isPremium) return;
    unawaited(router.resolve());
  });
  return router;
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  final router = ref.watch(taskStorageRouterProvider);
  if (router == null) {
    return TaskRepository(LocalTaskCollection.memory('signed-out'));
  }
  return TaskRepository(RoutedTaskCollection(router.resolve));
});

final qwenOnDeviceAiProvider = ChangeNotifierProvider<QwenOnDeviceAi>(
  (ref) => QwenOnDeviceAi(),
);

final plannerAiGatewayProvider = Provider<PlannerAiGateway>(
  (ref) => ref.watch(qwenOnDeviceAiProvider),
);

final taskBreakdownServiceProvider = Provider<TaskBreakdownService>(
  (ref) => ref.watch(qwenOnDeviceAiProvider),
);

final authStateProvider = AsyncNotifierProvider<AuthNotifier, AuthResponse?>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<AuthResponse?> {
  @override
  Future<AuthResponse?> build() async {
    final hadCachedFirebaseUser =
        ref.read(firebaseAuthProvider).currentUser != null;
    final current = await ref.read(authRepositoryProvider).getMe();
    if (hadCachedFirebaseUser && current == null) {
      await ref.read(googleAuthServiceProvider).disconnect();
    }
    return current;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .login(email: email, password: password),
    );
    ref.read(recentAuthIsNewUserProvider.notifier).state = false;
    _refreshPreferences();
  }

  Future<void> loginWithGoogle() async {
    final social = await ref.read(googleAuthServiceProvider).signIn();
    if (social == null) return;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signInWithCredentialResult(
            social.credential,
            displayName: social.displayName,
          ),
    );
    state = result.when(
      data: (value) => AsyncData(value.response),
      loading: () => const AsyncLoading(),
      error: AsyncError.new,
    );
    result.whenData(
      (value) => ref.read(recentAuthIsNewUserProvider.notifier).state =
          value.isNewUser,
    );
    _refreshPreferences();
  }

  Future<void> loginWithApple() async {
    if (!await ref.read(appleAuthServiceProvider).isAvailable) {
      state = AsyncError(
        StateError(
          ActiveLanguage.s('Apple ile giriş bu cihazda kullanılamıyor.'),
        ),
        StackTrace.current,
      );
      return;
    }
    final SocialAuthCredential? social;
    try {
      social = await ref.read(appleAuthServiceProvider).signIn();
    } catch (error, stackTrace) {
      state = AsyncError(friendlySocialAuthError(error), stackTrace);
      return;
    }
    if (social == null) return;
    final signedIn = social;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref
          .read(authRepositoryProvider)
          .signInWithCredentialResult(
            signedIn.credential,
            displayName: signedIn.displayName,
          ),
    );
    state = result.when(
      data: (value) => AsyncData(value.response),
      loading: () => const AsyncLoading(),
      error: (error, stackTrace) =>
          AsyncError(friendlySocialAuthError(error), stackTrace),
    );
    result.whenData(
      (value) => ref.read(recentAuthIsNewUserProvider.notifier).state =
          value.isNewUser,
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
    ref.read(recentAuthIsNewUserProvider.notifier).state = true;
    _refreshPreferences();
  }

  Future<void> logout() async {
    final userId = state.valueOrNull?.userId;
    if (userId != null) {
      await ref
          .read(taskAlarmServiceProvider)
          .cancelAccountNotifications(userId);
    }
    await ref.read(googleAuthServiceProvider).signOut();
    await ref.read(authRepositoryProvider).logout();
    ref.read(recentAuthIsNewUserProvider.notifier).state = null;
    state = const AsyncData(null);
  }

  Future<void> deleteAccount() async {
    final userId = state.valueOrNull?.userId;
    state = const AsyncLoading();
    try {
      if (userId != null) {
        await ref
            .read(taskAlarmServiceProvider)
            .cancelAccountNotifications(userId);
      }
      await ref.read(authRepositoryProvider).deleteAccount();
      await ref.read(googleAuthServiceProvider).disconnect();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  void _refreshPreferences() {
    final userId = state.valueOrNull?.userId;
    if (userId == null) return;
    ref.invalidate(onboardingPreferencesProvider);
    ref.invalidate(appProfilesProvider);
    ref.invalidate(appLanguageProvider);
    ref.invalidate(appThemeModeProvider);
    unawaited(_syncGuestOnboarding(userId));
    unawaited(_warmPersistentData());
  }

  Future<void> _syncGuestOnboarding(String userId) async {
    try {
      await ref
          .read(onboardingPreferencesRepositoryProvider)
          .loadAuthenticated(userId);
    } catch (_) {
      // The local guest copy remains available for the next sync attempt.
    }
  }

  Future<void> _warmPersistentData() async {
    try {
      await ref.read(appProfilesProvider.future);
    } catch (_) {
      // Storage providers retry migration when their screens are opened.
    }
  }
}

final todoListStorageProvider = Provider<TodoListStorage>(
  (ref) => TodoListStorage(firestore: ref.watch(optionalFirestoreProvider)),
);

final todoListsProvider =
    AsyncNotifierProvider<TodoListsNotifier, List<TodoListDefinition>>(
      TodoListsNotifier.new,
    );

class TodoListsNotifier extends AsyncNotifier<List<TodoListDefinition>> {
  @override
  Future<List<TodoListDefinition>> build() => ref
      .watch(todoListStorageProvider)
      .load(profileScope: ref.watch(activeProfileScopeProvider));

  Future<void> save(List<TodoListDefinition> lists) async {
    state = AsyncData(lists);
    await ref
        .read(todoListStorageProvider)
        .save(lists, profileScope: ref.read(activeProfileScopeProvider));
  }
}

final inboxProvider = AsyncNotifierProvider<InboxNotifier, List<TaskModel>>(
  InboxNotifier.new,
);

final dailyTimelineProvider = FutureProvider.autoDispose
    .family<TimelineModel, DateTime>((ref, date) async {
      ref.keepAlive();
      final repository = ref.watch(taskRepositoryProvider);
      try {
        return await repository.getTimeline(date);
      } catch (_) {
        return TimelineModel(date: date, tasks: const []);
      }
    });

final dailyDeleteTaskProvider = Provider<Future<void> Function(String)>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  return (id) async {
    await repository.deleteTask(id);
    await ref.read(taskAlarmServiceProvider).cancel(id);
    unawaited(ref.read(notificationReconcileProvider)());
  };
});

final dailyMoveToTodoProvider =
    Provider<Future<void> Function(String, String?)>((ref) {
      final repository = ref.watch(taskRepositoryProvider);
      return (id, todoListId) async {
        await repository.moveToInbox(id, todoListId: todoListId);
        await ref.read(taskAlarmServiceProvider).cancel(id);
        abandonFocusForTask(ref, id);
        ref.invalidate(inboxProvider);
        ref.invalidate(dailyTimelineProvider);
        unawaited(ref.read(notificationReconcileProvider)());
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

/// Requests the AI shell surface while the planner chat route is already open.
enum PlannerAiChatMode { chat, todo, daily, focus }

final plannerAiModeRequestProvider = StateProvider<PlannerAiChatMode?>(
  (ref) => null,
);

final scheduledFocusLaunchProvider = StateProvider<FocusTaskLaunch?>(
  (ref) => null,
);

final homeWidgetLaunchProvider = StateProvider<HomeWidgetLaunchCommand?>(
  (ref) => null,
);

final dailyPlannerQuickAddSignalProvider = StateProvider<int>((ref) => 0);

class ActiveFocusTask {
  const ActiveFocusTask({
    required this.taskId,
    required this.title,
    required this.icon,
    required this.usesDefaultFocusIcon,
    required this.totalSeconds,
    required this.remainingSeconds,
    required this.isRunning,
    this.startedAt,
    this.endsAt,
  });

  final String taskId;
  final String title;
  final String icon;
  final bool usesDefaultFocusIcon;
  final int totalSeconds;
  final int remainingSeconds;
  final bool isRunning;
  final DateTime? startedAt;
  final DateTime? endsAt;

  double get progress {
    if (totalSeconds <= 0) return 0;
    return (1 - remainingSeconds / totalSeconds).clamp(0, 1);
  }

  ActiveFocusTask copyWith({
    int? remainingSeconds,
    bool? isRunning,
    DateTime? startedAt,
    DateTime? endsAt,
  }) {
    return ActiveFocusTask(
      taskId: taskId,
      title: title,
      icon: icon,
      usesDefaultFocusIcon: usesDefaultFocusIcon,
      totalSeconds: totalSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRunning: isRunning ?? this.isRunning,
      startedAt: startedAt ?? this.startedAt,
      endsAt: endsAt ?? this.endsAt,
    );
  }
}

final activeFocusTaskProvider = StateProvider<ActiveFocusTask?>((ref) => null);

void abandonFocusForTask(Ref ref, String taskId) {
  final matchesActive = ref.read(activeFocusTaskProvider)?.taskId == taskId;
  final matchesLaunch = ref.read(focusTaskLaunchProvider)?.taskId == taskId;
  final matchesScheduled =
      ref.read(scheduledFocusLaunchProvider)?.taskId == taskId;
  if (!matchesActive && !matchesLaunch && !matchesScheduled) return;

  if (matchesActive) {
    ref.read(activeFocusTaskProvider.notifier).state = null;
  }
  if (matchesLaunch) {
    ref.read(focusTaskLaunchProvider.notifier).state = null;
  }
  if (matchesScheduled) {
    ref.read(scheduledFocusLaunchProvider.notifier).state = null;
  }
  if (matchesActive || matchesLaunch) {
    ref.read(focusTimerResetSignalProvider.notifier).state++;
    unawaited(ref.read(taskAlarmServiceProvider).cancelFocusTimerAlarm());
    unawaited(ref.read(liveActivityServiceProvider).endFocus());
  }
}

final focusTimerResetSignalProvider = StateProvider<int>((ref) => 0);
final focusTimerFinishSignalProvider = StateProvider<int>((ref) => 0);

final createStandaloneFocusTaskProvider =
    Provider<Future<FocusTaskLaunch> Function(int)>((ref) {
      final repository = ref.watch(taskRepositoryProvider);
      return (durationMinutes) async {
        final duration = durationMinutes.clamp(1, 24 * 60);
        final scheduledAt = DateTime.now();
        final created = await repository.createTask(
          title: ActiveLanguage.s('Odaklan'),
          color: '#6C5CE7',
          icon: 'timer',
          durationMinutes: duration,
          scheduledAt: scheduledAt,
          // A manually started focus is a daily activity, not a task pinned
          // to an exact clock time. Keeping this false also lets standard
          // users persist the task under the exact-time Premium rule.
          isTimed: false,
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
  final repository = ref.watch(taskRepositoryProvider);
  try {
    return await repository.getCompletionCounts(DateTime.now());
  } catch (_) {
    // The task that opened this page has just completed, so one is the safe
    // minimum while an offline count cannot be loaded.
    return const CompletionCounts(today: 1, thisWeek: 1);
  }
});

final achievementProgressStorageProvider = Provider<AchievementProgressStorage>(
  (ref) => AchievementProgressStorage(
    firestore: ref.watch(optionalFirestoreProvider),
  ),
);

final achievementCatalogProvider = FutureProvider<AchievementCatalog>(
  (ref) => AchievementCatalog.load(),
);

final achievementProgressProvider =
    FutureProvider.autoDispose<AchievementProgress>((ref) async {
      final catalog = await ref.watch(achievementCatalogProvider.future);
      final counts = await ref.watch(completionCountsProvider.future);
      final profileScope = ref.watch(activeProfileScopeProvider);
      final completedTaskCount = await ref
          .watch(achievementProgressStorageProvider)
          .preserveCompletedTaskCount(
            profileScope: profileScope,
            currentCount: counts.total,
          );
      return AchievementProgress(
        catalog: catalog,
        completedTaskCount: completedTaskCount,
      );
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
    ref.invalidate(completionCountsProvider);
  };
});

final completeFocusedTaskProvider = Provider<Future<void> Function(String)>((
  ref,
) {
  final repository = ref.watch(taskRepositoryProvider);
  return (taskId) async {
    await repository.completeTask(taskId);
    await ref.read(taskAlarmServiceProvider).cancel(taskId);
    if (ref.read(activeFocusTaskProvider)?.taskId == taskId) {
      ref.read(activeFocusTaskProvider.notifier).state = null;
    }
    if (ref.read(focusTaskLaunchProvider)?.taskId == taskId) {
      ref.read(focusTaskLaunchProvider.notifier).state = null;
    }
    ref.invalidate(inboxProvider);
    ref.invalidate(dailyTimelineProvider);
    ref.invalidate(completionCountsProvider);
    unawaited(ref.read(notificationReconcileProvider)());
  };
});

class InboxNotifier extends AsyncNotifier<List<TaskModel>> {
  @override
  Future<List<TaskModel>> build() async {
    final repository = ref.watch(taskRepositoryProvider);
    try {
      return await repository.getInbox();
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
    TaskPriority priority = TaskPriority.none,
    required String? todoListId,
    String? description,
    List<String> subtasks = const [],
  }) => addDetailedWithIcon(
    title: title,
    durationMinutes: durationMinutes,
    priority: priority,
    todoListId: todoListId,
    description: description,
    subtasks: subtasks,
  );

  Future<void> addDetailedWithIcon({
    required String title,
    required int durationMinutes,
    TaskPriority priority = TaskPriority.none,
    required String? todoListId,
    String? icon,
    String? description,
    List<String> subtasks = const [],
  }) async {
    final task = await addToInbox(
      title: title,
      description: description,
      durationMinutes: durationMinutes,
      priority: priority,
      todoListId: todoListId,
      icon: icon,
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
    TaskPriority priority = TaskPriority.none,
    required String? todoListId,
    String? description,
    List<String> subtasks = const [],
  }) => updateDetailedWithIcon(
    id: id,
    title: title,
    durationMinutes: durationMinutes,
    priority: priority,
    todoListId: todoListId,
    description: description,
    subtasks: subtasks,
  );

  Future<void> updateDetailedWithIcon({
    required String id,
    required String title,
    required int durationMinutes,
    TaskPriority priority = TaskPriority.none,
    required String? todoListId,
    String? icon,
    String? description,
    List<String> subtasks = const [],
  }) async {
    final repository = ref.read(taskRepositoryProvider);
    await repository.updateTask(
      id: id,
      title: title,
      description: description,
      clearDescription: description == null,
      icon: icon,
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
    await ref.read(taskAlarmServiceProvider).cancel(id);
    ref.invalidate(completionCountsProvider);
    await refresh();
    unawaited(ref.read(notificationReconcileProvider)());
  }

  Future<void> uncompleteTask(String id) async {
    await ref.read(taskRepositoryProvider).uncompleteTask(id);
    ref.invalidate(completionCountsProvider);
    await refresh();
    unawaited(ref.read(notificationReconcileProvider)());
  }

  Future<void> scheduleTask(String id, DateTime scheduledAt) async {
    await ref.read(taskRepositoryProvider).scheduleFromInbox(id, scheduledAt);
    if (florienRescheduleLeavesToday(scheduledAt, DateTime.now())) {
      abandonFocusForTask(ref, id);
    }
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
    await ref.read(taskAlarmServiceProvider).cancel(id);
    await refresh();
    unawaited(ref.read(notificationReconcileProvider)());
  }
}
