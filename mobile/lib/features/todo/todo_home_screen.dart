import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/todo/daily_planner_tab.dart';
import 'package:florien/features/todo/focus_timer_tab.dart';
import 'package:florien/features/todo/planner_ai_chat_screen.dart';
import 'package:florien/features/todo/todo_list_tab.dart';

class TodoHomeScreen extends ConsumerStatefulWidget {
  const TodoHomeScreen({super.key});

  @override
  ConsumerState<TodoHomeScreen> createState() => _TodoHomeScreenState();
}

class _TodoHomeScreenState extends ConsumerState<TodoHomeScreen> {
  int _selectedIndex = 0;
  late final ProviderSubscription<FocusTaskLaunch?> _focusLaunchSubscription;
  FocusTaskLaunch? _scheduledFocusLaunch;
  Timer? _scheduledFocusClock;
  bool _refreshingScheduledFocus = false;

  @override
  void initState() {
    super.initState();
    _focusLaunchSubscription = ref.listenManual(focusTaskLaunchProvider, (
      _,
      request,
    ) {
      if (request != null && mounted && _selectedIndex != 2) {
        setState(() => _selectedIndex = 2);
      }
    });
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
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final requestedFocus = ref.watch(focusTaskLaunchProvider);
    return Scaffold(
      appBar: _selectedIndex == 0
          ? AppBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          FlorienColors.primaryLight,
                          FlorienColors.primary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: FlorienColors.primary.withValues(alpha: .22),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_florist_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(_selectedIndex == 0 ? 'Florien' : 'Odaklan'),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    tooltip: 'Çıkış yap',
                    onPressed: () =>
                        ref.read(authStateProvider.notifier).logout(),
                    style: IconButton.styleFrom(
                      backgroundColor: context.palette.surfaceMuted,
                      foregroundColor: context.palette.textSecondary,
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 19),
                  ),
                ),
              ],
            )
          : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const TodoListTab(),
          const DailyPlannerTab(),
          FocusTimerTab(
            launchRequest: requestedFocus ?? _scheduledFocusLaunch,
            resetSignal: ref.watch(focusTimerResetSignalProvider),
            onStandaloneFocusStarted: _createStandaloneFocusTask,
            onTaskProgressChanged: (progress) =>
                ref.read(activeFocusTaskProvider.notifier).state = progress,
            onTaskCompleted: _completeFocusedTask,
            onSessionClosed: () {
              if (ref.read(focusTaskLaunchProvider) != null) {
                ref.read(focusTaskLaunchProvider.notifier).state = null;
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(FlorienRadius.xl),
                    border: Border.all(color: context.palette.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .07),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(FlorienRadius.xl),
                    child: NavigationBar(
                      height: 64,
                      selectedIndex: _selectedIndex,
                      onDestinationSelected: (index) =>
                          setState(() => _selectedIndex = index),
                      destinations: const [
                        NavigationDestination(
                          icon: Icon(Icons.check_box_outlined),
                          selectedIcon: Icon(Icons.check_box_rounded),
                          label: 'To-do',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.calendar_today_outlined),
                          selectedIcon: Icon(Icons.calendar_today_rounded),
                          label: 'Günlük',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.timelapse_outlined),
                          selectedIcon: Icon(Icons.timelapse_rounded),
                          label: 'Odaklan',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                key: const ValueKey('planner-ai-chat-button'),
                color: FlorienColors.primary,
                shape: const CircleBorder(),
                elevation: 4,
                shadowColor: FlorienColors.primary,
                child: IconButton(
                  tooltip: 'Plan asistanını aç',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PlannerAiChatScreen(),
                    ),
                  ),
                  constraints: const BoxConstraints.tightFor(
                    width: 58,
                    height: 58,
                  ),
                  color: Colors.white,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 25),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
