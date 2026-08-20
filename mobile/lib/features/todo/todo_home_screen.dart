import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/services/home_screen_widget_service.dart';
import 'package:florien/core/widgets/florien_bottom_nav.dart';
import 'package:florien/core/widgets/florien_logo.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/premium/premium_membership.dart';
import 'package:florien/features/premium/premium_membership_screen.dart';
import 'package:florien/features/premium/premium_upsell_button.dart';
import 'package:florien/features/premium/premium_gate.dart';
import 'package:florien/features/todo/daily_planner_tab.dart';
import 'package:florien/features/todo/focus_timer_tab.dart';
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
  bool _scrollChromeVisible = true;
  late final ProviderSubscription<FocusTaskLaunch?> _focusLaunchSubscription;
  late final ProviderSubscription<HomeWidgetLaunchCommand?>
  _homeWidgetLaunchSubscription;
  late final ProviderSubscription<AsyncValue<TimelineModel>>
  _widgetTimelineSubscription;
  late final ProviderSubscription<AsyncValue<List<TaskModel>>>
  _widgetInboxSubscription;
  FocusTaskLaunch? _scheduledFocusLaunch;
  Timer? _scheduledFocusClock;
  bool _refreshingScheduledFocus = false;
  int _widgetLaunchRevision = 0;

  @override
  void initState() {
    super.initState();
    _focusLaunchSubscription = ref.listenManual(focusTaskLaunchProvider, (
      _,
      request,
    ) {
      if (request != null && mounted && _selectedIndex != 2) {
        _selectTab(2);
      }
    });
    _homeWidgetLaunchSubscription = ref.listenManual(
      homeWidgetLaunchProvider,
      (_, command) => unawaited(_handleHomeWidgetLaunch(command)),
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
    _scheduledFocusClock = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_refreshScheduledFocus()),
    );
  }

  @override
  void dispose() {
    _scheduledFocusClock?.cancel();
    _focusLaunchSubscription.close();
    _homeWidgetLaunchSubscription.close();
    _widgetTimelineSubscription.close();
    _widgetInboxSubscription.close();
    super.dispose();
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
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
        _selectTab(2);
      case HomeWidgetLaunchAction.focusStop:
        _selectTab(2);
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
  }

  Future<void> _completeWidgetTask(String taskId) async {
    try {
      await ref.read(taskRepositoryProvider).completeTask(taskId);
      ref.invalidate(inboxProvider);
      ref.invalidate(dailyTimelineProvider);
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
          const SnackBar(content: Text('To-do ekleme ekranı açılamadı.')),
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
      if (_sameScheduledLaunch(_scheduledFocusLaunch, next)) return;
      setState(() => _scheduledFocusLaunch = next);
    } catch (_) {
      if (mounted && _scheduledFocusLaunch != null) {
        setState(() => _scheduledFocusLaunch = null);
      }
    } finally {
      _refreshingScheduledFocus = false;
    }
  }

  bool _sameScheduledLaunch(FocusTaskLaunch? a, FocusTaskLaunch? b) =>
      a?.taskId == b?.taskId &&
      a?.startedAt == b?.startedAt &&
      a?.endsAt == b?.endsAt;

  Future<void> _completeFocusedTask(String taskId) async {
    if (_scheduledFocusLaunch?.taskId == taskId && mounted) {
      setState(() => _scheduledFocusLaunch = null);
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
    setState(() {
      _selectedIndex = index;
      _scrollChromeVisible = true;
    });
  }

  void _handleScrollChromeVisibility(int tabIndex, bool visible) {
    if (!mounted ||
        _selectedIndex != tabIndex ||
        _scrollChromeVisible == visible) {
      return;
    }
    setState(() => _scrollChromeVisible = visible);
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

  Future<void> _openPlannerAi({bool rootNavigator = false}) async {
    final allowed = await requirePremiumAccess(
      context,
      ref,
      PremiumFeature.aiChat,
    );
    if (!allowed || !mounted) return;
    await Navigator.of(context, rootNavigator: rootNavigator).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: animation,
          child: const PlannerAiChatScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requestedFocus = ref.watch(focusTaskLaunchProvider);
    final premium = ref.watch(premiumMembershipProvider).valueOrNull;
    final alarms = ref.read(taskAlarmServiceProvider);
    final todoFocusMode = _selectedIndex == 0 && !_scrollChromeVisible;
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: _selectedIndex == 0
          ? AppBar(
              centerTitle: todoFocusMode,
              title: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: todoFocusMode
                    ? Text(
                        _compactHomeDateLabel(_today()),
                        key: const ValueKey('todo-focused-date'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      )
                    : Row(
                        key: const ValueKey('todo-home-scroll-chrome-header'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const FlorienLogo(
                            key: ValueKey('todo-home-brand-icon'),
                            size: 34,
                          ),
                          const SizedBox(width: 10),
                          const Text('Florien'),
                        ],
                      ),
              ),
              actions: [
                if (todoFocusMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: IconButton.filled(
                      key: const ValueKey('todo-focused-add'),
                      tooltip: 'Yeni yapılacak ekle',
                      onPressed: () => setState(() => _todoQuickAddSignal++),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  )
                else if (premium != null && !premium.isPremium)
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
          TodoListTab(
            quickAddSignal: _todoQuickAddSignal,
            scrollChromeEnabled: _selectedIndex == 0,
            onScrollChromeVisibilityChanged: (visible) =>
                _handleScrollChromeVisibility(0, visible),
          ),
          DailyPlannerTab(
            quickAddSignal: ref.watch(dailyPlannerQuickAddSignalProvider),
            scrollChromeEnabled: _selectedIndex == 1,
            showPremiumUpsell: premium != null && !premium.isPremium,
            onPremiumUpsellPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PremiumMembershipScreen(),
              ),
            ),
            onScrollChromeVisibilityChanged: (visible) =>
                _handleScrollChromeVisibility(1, visible),
          ),
          FocusTimerTab(
            launchRequest: requestedFocus ?? _scheduledFocusLaunch,
            resetSignal: ref.watch(focusTimerResetSignalProvider),
            finishSignal: ref.watch(focusTimerFinishSignalProvider),
            onStandaloneFocusStarted: _createStandaloneFocusTask,
            onTaskProgressChanged: _onFocusTaskProgressChanged,
            onTaskCompleted: _completeFocusedTask,
            onFocusAlarmScheduled: (alarmAt, title) async {
              await alarms.scheduleFocusTimerAlarm(
                title: title,
                alarmAt: alarmAt,
              );
            },
            onFocusAlarmCompleted: (title) =>
                alarms.completeFocusTimerAlarm(title: title),
            onFocusAlarmCancelled: alarms.cancelFocusTimerAlarm,
            alarmAvailable: premium?.isPremium == true,
            onPremiumAlarmPressed: () => unawaited(
              requirePremiumAccess(context, ref, PremiumFeature.reminders),
            ),
            onSessionClosed: () {
              if (ref.read(focusTaskLaunchProvider) != null) {
                ref.read(focusTaskLaunchProvider.notifier).state = null;
              }
            },
          ),
          const StatisticsTab(),
        ],
      ),
      bottomNavigationBar: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: _scrollChromeVisible
            ? FlorienBottomNavigation(
                key: const ValueKey('home-scroll-chrome-navigation'),
                selectedIndex: _selectedIndex,
                onDestinationSelected: _selectTab,
                destinations: const [
                  FlorienNavDestination(
                    label: 'To-do',
                    icon: Icons.check_box_outlined,
                    selectedIcon: Icons.check_box_rounded,
                  ),
                  FlorienNavDestination(
                    label: 'Günlük',
                    icon: Icons.calendar_today_outlined,
                    selectedIcon: Icons.calendar_today_rounded,
                  ),
                  FlorienNavDestination(
                    label: 'Odaklan',
                    icon: Icons.timelapse_outlined,
                    selectedIcon: Icons.timelapse_rounded,
                  ),
                  FlorienNavDestination(
                    label: 'İstatistik',
                    icon: Icons.bar_chart_rounded,
                    selectedIcon: Icons.bar_chart_rounded,
                  ),
                ],
                trailing: FlorienAiFab(
                  key: const ValueKey('planner-ai-chat-button'),
                  tooltip: 'Plan asistanını aç',
                  onPressed: _openPlannerAi,
                ),
              )
            : const SizedBox.shrink(key: ValueKey('home-navigation-hidden')),
      ),
    );
  }
}

String _compactHomeDateLabel(DateTime date) {
  const months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
