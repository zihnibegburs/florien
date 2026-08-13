import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/todo/daily_planner_tab.dart';
import 'package:florien/features/todo/focus_timer_tab.dart';
import 'package:florien/features/todo/todo_list_tab.dart';

class TodoHomeScreen extends ConsumerStatefulWidget {
  const TodoHomeScreen({super.key});

  @override
  ConsumerState<TodoHomeScreen> createState() => _TodoHomeScreenState();
}

class _TodoHomeScreenState extends ConsumerState<TodoHomeScreen> {
  int _selectedIndex = 0;
  late final ProviderSubscription<FocusTaskLaunch?> _focusLaunchSubscription;

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
  }

  @override
  void dispose() {
    _focusLaunchSubscription.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
          launchRequest: ref.watch(focusTaskLaunchProvider),
          resetSignal: ref.watch(focusTimerResetSignalProvider),
          onTaskProgressChanged: (progress) =>
              ref.read(activeFocusTaskProvider.notifier).state = progress,
          onTaskCompleted: (taskId) =>
              ref.read(completeFocusedTaskProvider)(taskId),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
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
    ),
  );
}
