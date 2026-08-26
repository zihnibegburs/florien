import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/services/home_screen_widget_service.dart';
import 'package:florien/core/services/notification_payload.dart';
import 'package:florien/core/widgets/florien_bottom_nav.dart';
import 'package:florien/core/widgets/florien_logo.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/premium/premium_membership.dart';
import 'package:florien/features/premium/premium_membership_screen.dart';
import 'package:florien/features/premium/premium_upsell_button.dart';
import 'package:florien/features/premium/premium_gate.dart';
import 'package:florien/features/todo/daily_planner_tab.dart';
import 'package:florien/features/todo/planner_ai_chat_screen.dart';
import 'package:florien/features/todo/statistics_tab.dart';
import 'package:florien/features/todo/todo_list_tab.dart';

class TodoHomeScreen extends ConsumerStatefulWidget {
  const TodoHomeScreen({super.key});

  @override
  ConsumerState<TodoHomeScreen> createState() => _TodoHomeScreenState();
}

class _TodoHomeScreenState extends ConsumerState<TodoHomeScreen> {
  int _selectedIndex = 0;
  int _todoQuickAddSignal = 0;
  late final ProviderSubscription<FocusTaskLaunch?> _focusLaunchSubscription;
  late final ProviderSubscription<HomeWidgetLaunchCommand?>
  _homeWidgetLaunchSubscription;
  late final ProviderSubscription<NotificationLaunchCommand?>
  _notificationLaunchSubscription;
  late final ProviderSubscription<AsyncValue<TimelineModel>>
  _widgetTimelineSubscription;
  late final ProviderSubscription<AsyncValue<List<TaskModel>>>
  _widgetInboxSubscription;
  Timer? _scheduledFocusClock;
  bool _refreshingScheduledFocus = false;
  int _widgetLaunchRevision = 0;
  bool _plannerAiOpen = false;

  @override
  void initState() {
    super.initState();
    _focusLaunchSubscription = ref.listenManual(focusTaskLaunchProvider, (
      _,
      request,
    ) {
      if (request != null && mounted) {
        unawaited(
          _openPlannerAi(
            initialMode: PlannerAiChatMode.focus,
            gateAiPremium: false,
          ),
        );
      }
    });
    _homeWidgetLaunchSubscription = ref.listenManual(
      homeWidgetLaunchProvider,
      (_, command) => unawaited(_handleHomeWidgetLaunch(command)),
      fireImmediately: true,
    );
    _notificationLaunchSubscription = ref.listenManual(
      notificationLaunchProvider,
      (_, command) => unawaited(_handleNotificationLaunch(command)),
      fireImmediately: true,
    );
    final today = _today();
    _widgetTimelineSubscription = ref.listenManual(
      dailyTimelineProvider(today),
      (_, timeline) {
        final value = timeline.valueOrNull;
        if (value != null) {
          final profileId = ref.read(activeAppProfileProvider)?.id ?? 'primary';
          unawaited(
            HomeScreenWidgetService.syncDailyPlan(
              date: today,
              tasks: value.tasks,
              profileId: profileId,
            ),
          );
          unawaited(_syncDailyLiveActivities(today, value.tasks));
        }
      },
      fireImmediately: true,
    );
    _widgetInboxSubscription = ref.listenManual(inboxProvider, (_, inbox) {
      final tasks = inbox.valueOrNull;
      if (tasks != null) {
        unawaited(
          HomeScreenWidgetService.syncTodo(
            tasks: tasks,
            profileId: ref.read(activeAppProfileProvider)?.id ?? 'primary',
          ),
        );
      }
    }, fireImmediately: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshScheduledFocus());
    });
    _scheduledFocusClock = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_refreshScheduledFocus());
      _tickBackgroundFocus();
    });
  }

  @override
  void dispose() {
    _scheduledFocusClock?.cancel();
    _focusLaunchSubscription.close();
    _homeWidgetLaunchSubscription.close();
    _notificationLaunchSubscription.close();
    _widgetTimelineSubscription.close();
    _widgetInboxSubscription.close();
    super.dispose();
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _handleNotificationLaunch(
    NotificationLaunchCommand? command,
  ) async {
    if (command == null || !mounted) return;
    ref.read(notificationLaunchProvider.notifier).state = null;
    switch (command.target) {
      case NotificationTargetScreen.taskFocus:
        final taskId = command.taskId;
        if (taskId == null) {
          _selectTab(1);
          return;
        }
        try {
          final task = await ref
              .read(taskRepositoryProvider)
              .getTaskById(taskId);
          if (task == null || task.isCompleted) {
            _selectTab(1);
            return;
          }
          ref.read(focusTaskLaunchProvider.notifier).state = FocusTaskLaunch(
            taskId: task.id,
            title: task.title,
            durationMinutes: task.durationMinutes,
            icon: task.icon,
            color: task.color,
          );
        } catch (_) {
          _selectTab(1);
        }
      case NotificationTargetScreen.dailyPlan:
        _selectTab(1);
      case NotificationTargetScreen.dailyReview:
        _selectTab(1);
        ref.read(dailyReviewLaunchSignalProvider.notifier).state++;
      case NotificationTargetScreen.weeklyPlanMonday:
        final now = DateTime.now();
        var monday = DateTime(now.year, now.month, now.day);
        while (monday.weekday != DateTime.monday) {
          monday = monday.add(const Duration(days: 1));
        }
        ref.read(dailyPlannerDateRequestProvider.notifier).state = monday;
        _selectTab(1);
    }
  }

  Future<void> _handleHomeWidgetLaunch(HomeWidgetLaunchCommand? command) async {
    if (command == null || !mounted) return;
    final revision = ++_widgetLaunchRevision;
    ref.read(homeWidgetLaunchProvider.notifier).state = null;
    await _dismissWidgetOverlays();
    if (!mounted || revision != _widgetLaunchRevision) return;
    switch (command.action) {
      case HomeWidgetLaunchAction.focus:
      case HomeWidgetLaunchAction.focusScreen:
        unawaited(
          _openPlannerAi(
            initialMode: PlannerAiChatMode.focus,
            gateAiPremium: false,
            rootNavigator: true,
          ),
        );
      case HomeWidgetLaunchAction.focusStop:
        unawaited(
          _openPlannerAi(
            initialMode: PlannerAiChatMode.focus,
            gateAiPremium: false,
            rootNavigator: true,
          ),
        );
        await ref.read(liveActivityServiceProvider).endFocus();
        ref.read(focusTimerFinishSignalProvider.notifier).state++;
      case HomeWidgetLaunchAction.today:
        _selectTab(1);
      case HomeWidgetLaunchAction.todo:
        _selectTab(0);
      case HomeWidgetLaunchAction.todoAdd:
        _selectTab(0);
        unawaited(_openWidgetTodoQuickAdd(revision));
      case HomeWidgetLaunchAction.dailyAdd:
        _selectTab(1);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && revision == _widgetLaunchRevision) {
            ref.read(dailyPlannerQuickAddSignalProvider.notifier).state++;
          }
        });
      case HomeWidgetLaunchAction.ai:
        _selectTab(0);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || revision != _widgetLaunchRevision) return;
          FocusManager.instance.primaryFocus?.unfocus();
          unawaited(_openPlannerAi(rootNavigator: true));
        });
      case HomeWidgetLaunchAction.taskComplete:
        _selectTab(command.isDailyPlan ? 1 : 0);
        final taskId = command.taskId;
        if (taskId != null) unawaited(_completeWidgetTask(taskId));
    }
  }

  Future<void> _dismissWidgetOverlays() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).popUntil((route) => route.isFirst);
    await WidgetsBinding.instance.endOfFrame;
    _plannerAiOpen = false;
  }

  Future<void> _completeWidgetTask(String taskId) async {
    try {
      await ref.read(taskRepositoryProvider).completeTask(taskId);
      ref.invalidate(inboxProvider);
      ref.invalidate(dailyTimelineProvider);
      ref.invalidate(completionCountsProvider);
    } catch (error) {
      debugPrint('Home widget task could not be completed: $error');
    }
  }

  Future<void> _openWidgetTodoQuickAdd(int revision) async {
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted || revision != _widgetLaunchRevision) return;
    try {
      await showTodoQuickAdd(context: context, ref: ref, autofocus: false);
    } catch (error) {
      debugPrint('Home widget To-do sheet could not be opened: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n('To-do ekleme ekranı açılamadı.')),
          ),
        );
      }
    }
  }

  Future<void> _refreshScheduledFocus() async {
    if (_refreshingScheduledFocus) return;
    _refreshingScheduledFocus = true;
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final timeline = await ref.read(dailyTimelineProvider(today).future);
      if (!mounted) return;
      final task = activeScheduledTaskAt(
        tasks: timeline.tasks,
        selectedDate: today,
        now: now,
      );
      FocusTaskLaunch? next;
      if (task?.scheduledAt case final start?) {
        next = FocusTaskLaunch(
          taskId: task!.id,
          title: task.title,
          durationMinutes: task.durationMinutes,
          icon: task.icon,
          color: task.color,
          startedAt: start,
          endsAt: start.add(Duration(minutes: task.durationMinutes)),
          automatic: true,
        );
      }
      final current = ref.read(scheduledFocusLaunchProvider);
      if (_sameScheduledLaunch(current, next)) return;
      ref.read(scheduledFocusLaunchProvider.notifier).state = next;
    } catch (_) {
      if (ref.read(scheduledFocusLaunchProvider) != null) {
        ref.read(scheduledFocusLaunchProvider.notifier).state = null;
      }
    } finally {
      _refreshingScheduledFocus = false;
    }
  }

  bool _sameScheduledLaunch(FocusTaskLaunch? a, FocusTaskLaunch? b) =>
      a?.taskId == b?.taskId &&
      a?.startedAt == b?.startedAt &&
      a?.endsAt == b?.endsAt;

  void _tickBackgroundFocus() {
    if (_plannerAiOpen) return;
    final progress = ref.read(activeFocusTaskProvider);
    final end = progress?.endsAt;
    if (progress == null || !progress.isRunning || end == null) return;
    final remaining = end.difference(DateTime.now()).inSeconds;
    if (remaining <= 0) {
      unawaited(_expireBackgroundFocus(progress));
      return;
    }
    if (remaining == progress.remainingSeconds) return;
    final next = progress.copyWith(remainingSeconds: remaining);
    ref.read(activeFocusTaskProvider.notifier).state = next;
    unawaited(_syncFocusLiveActivity(next));
  }

  Future<void> _expireBackgroundFocus(ActiveFocusTask progress) async {
    ref.read(activeFocusTaskProvider.notifier).state = null;
    if (ref.read(focusTaskLaunchProvider)?.taskId == progress.taskId) {
      ref.read(focusTaskLaunchProvider.notifier).state = null;
    }
    await _completeFocusedTask(progress.taskId);
    if (!mounted) return;
    await ref.read(liveActivityServiceProvider).endFocus();
  }

  Future<void> _completeFocusedTask(String taskId) async {
    if (ref.read(scheduledFocusLaunchProvider)?.taskId == taskId) {
      ref.read(scheduledFocusLaunchProvider.notifier).state = null;
    }
    await ref.read(completeFocusedTaskProvider)(taskId);
    if (mounted) unawaited(_refreshScheduledFocus());
  }

  Future<void> _syncDailyLiveActivities(
    DateTime date,
    List<TaskModel> tasks,
  ) async {
    final preferences = await ref.read(liveActivityPreferencesProvider.future);
    await ref
        .read(liveActivityServiceProvider)
        .syncDailyPlan(date: date, tasks: tasks, preferences: preferences);
  }

  Future<void> _syncFocusLiveActivity(ActiveFocusTask? progress) async {
    final preferences = await ref.read(liveActivityPreferencesProvider.future);
    await ref
        .read(liveActivityServiceProvider)
        .syncFocus(
          title: progress?.title ?? 'Odaklanma',
          taskIcon: progress?.icon,
          usesDefaultFocusIcon: progress?.usesDefaultFocusIcon ?? true,
          remainingSeconds: progress?.remainingSeconds ?? 0,
          totalSeconds: progress?.totalSeconds ?? 0,
          isRunning: progress?.isRunning ?? false,
          preferences: preferences,
        );
  }

  void _onFocusTaskProgressChanged(ActiveFocusTask? progress) {
    ref.read(activeFocusTaskProvider.notifier).state = progress;
    unawaited(_syncFocusLiveActivity(progress));
  }

  void _selectTab(int index) {
    if (!mounted) return;
    setState(() => _selectedIndex = index);
  }

  Future<FocusTaskLaunch> _createStandaloneFocusTask(
    int durationMinutes,
  ) async {
    final launch = await ref.read(createStandaloneFocusTaskProvider)(
      durationMinutes,
    );
    ref.read(focusTaskLaunchProvider.notifier).state = launch;
    ref.invalidate(dailyTimelineProvider);
    return launch;
  }

  Future<void> _openPlannerAi({
    bool rootNavigator = false,
    PlannerAiChatMode initialMode = PlannerAiChatMode.chat,
    bool gateAiPremium = false,
  }) async {
    if (_plannerAiOpen) {
      ref.read(plannerAiModeRequestProvider.notifier).state = initialMode;
      return;
    }
    if (gateAiPremium) {
      final allowed = await requirePremiumAccess(
        context,
        ref,
        PremiumFeature.aiChat,
      );
      if (!allowed || !mounted) return;
    }
    _plannerAiOpen = true;
    try {
      await Navigator.of(context, rootNavigator: rootNavigator).push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 220),
          pageBuilder: (_, animation, _) => FadeTransition(
            opacity: animation,
            child: PlannerAiChatScreen(
              initialMode: initialMode,
              onStandaloneFocusStarted: _createStandaloneFocusTask,
              onTaskProgressChanged: _onFocusTaskProgressChanged,
              onTaskCompleted: _completeFocusedTask,
            ),
          ),
        ),
      );
    } finally {
      _plannerAiOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final premium = ref.watch(premiumMembershipProvider).valueOrNull;
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: _selectedIndex == 0
          ? AppBar(
              title: const Row(
                key: ValueKey('todo-home-scroll-chrome-header'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  FlorienLogo(key: ValueKey('todo-home-brand-icon'), size: 34),
                  SizedBox(width: 10),
                  Text('Florien'),
                ],
              ),
              actions: [
                if (premium != null && !premium.hasActivePremium)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: PremiumUpsellButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PremiumMembershipScreen(),
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          TodoListTab(quickAddSignal: _todoQuickAddSignal),
          DailyPlannerTab(
            quickAddSignal: ref.watch(dailyPlannerQuickAddSignalProvider),
            showPremiumUpsell: premium != null && !premium.hasActivePremium,
            onPremiumUpsellPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PremiumMembershipScreen(),
              ),
            ),
          ),
          const StatisticsTab(),
        ],
      ),
      bottomNavigationBar: FlorienBottomNavigation(
        key: const ValueKey('home-scroll-chrome-navigation'),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          if (index == 1) {
            ref.read(dailyPlannerDateRequestProvider.notifier).state = _today();
          }
          _selectTab(index);
        },
        destinations: [
          FlorienNavDestination(
            label: context.l10n('To-do'),
            icon: Icons.check_box_outlined,
            selectedIcon: Icons.check_box_rounded,
          ),
          FlorienNavDestination(
            label: context.l10n('Günlük'),
            icon: Icons.calendar_today_outlined,
            selectedIcon: Icons.calendar_today_rounded,
          ),
          FlorienNavDestination(
            label: context.l10n('İstatistik'),
            icon: Icons.bar_chart_rounded,
            selectedIcon: Icons.bar_chart_rounded,
          ),
        ],
        onAiPressed: () => unawaited(_openPlannerAi()),
        aiTooltip: context.l10n('Plan asistanını aç'),
      ),
    );
  }
}
