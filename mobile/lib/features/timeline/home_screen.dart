import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mimio/core/l10n/app_strings.dart';
import 'package:mimio/core/models/models.dart';
import 'package:mimio/core/models/recurrence.dart';
import 'package:mimio/core/theme/mimio_theme.dart';
import 'package:mimio/core/widgets/liquid_glass.dart';
import 'package:mimio/core/widgets/mimio_soft_overlay.dart';
import 'package:mimio/features/achievements/achievement_unlock_listener.dart';
import 'package:mimio/features/onboarding/onboarding_screen.dart';
import 'package:mimio/features/timeline/task_completion_helper.dart';
import 'package:mimio/features/timeline/widgets/now_mode_view.dart';
import 'package:mimio/core/storage/adhd_settings_storage.dart';
import 'package:mimio/core/storage/settings_storage.dart';
import 'package:mimio/core/utils/schedule_utils.dart';
import 'package:mimio/features/focus/focus_session_actions.dart';
import 'package:mimio/features/focus/focus_tab_view.dart';
import 'package:mimio/features/focus/widgets/active_task_banner.dart';
import 'package:mimio/features/providers.dart';
import 'package:mimio/features/timeline/home_tab.dart';
import 'package:mimio/features/timeline/widgets/add_task_sheet.dart';
import 'package:mimio/features/timeline/widgets/delete_task_dialog.dart';
import 'package:mimio/features/timeline/widgets/inbox_section.dart';
import 'package:mimio/features/timeline/widgets/more_tab_view.dart';
import 'package:mimio/features/timeline/widgets/task_action_sheet.dart';
import 'package:mimio/features/timeline/widgets/modern_bottom_bar.dart';
import 'package:mimio/features/timeline/widgets/schedule_warning_banner.dart';
import 'package:mimio/features/timeline/widgets/task_card.dart';
import 'package:mimio/features/timeline/widgets/timeline_hour_grid.dart';
import 'package:mimio/features/timeline/widgets/week_strip.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(homeTabProvider);
    final auth = ref.watch(authStateProvider).value;
    final selectedDate = ref.watch(selectedDateProvider);
    final s = ref.watch(stringsProvider);

    return AchievementUnlockListener(
      child: _OnboardingHost(
        child: Scaffold(
          extendBody: true,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: LiquidGlassAppBar(
              child: SafeArea(
                bottom: false,
                child: AppBar(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.hello(auth?.firstName ?? '')),
                      Text(
                        _tabSubtitle(tab, selectedDate, ref, s),
                        style: TextStyle(
                          fontSize: 13,
                          color: context.palette.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.auto_awesome_rounded),
                      tooltip: s.aiPlanner,
                      onPressed: () => context.push('/ai'),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: InkWell(
                        onTap: () => context.push('/profile'),
                        customBorder: const CircleBorder(),
                        child: CircleAvatar(
                          radius: 19,
                          backgroundColor: auth != null
                              ? MimioColors.fromHex(auth.avatarColor)
                              : MimioColors.primary,
                          child: Text(
                            (auth?.displayName.isNotEmpty ?? false)
                                ? auth!.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: IndexedStack(
            index: tab.index,
            children: const [_TodayTab(), FocusTabView(), MoreTabView()],
          ),
          bottomNavigationBar: ModernBottomBar(
            selectedIndex: tab.index,
            onSelected: (i) =>
                ref.read(homeTabProvider.notifier).state = HomeTab.values[i],
            // Always pass a callback on Today; bar keeps a fixed slot so
            // tabs never shift when switching away from Today.
            onAdd: tab == HomeTab.today
                ? () {
                    final date = ref.read(selectedDateProvider);
                    _showAddTask(context, ref, date);
                  }
                : null,
            addTooltip: s.addTask,
            items: [
              ModernNavItem(
                icon: Icons.today_outlined,
                selectedIcon: Icons.today_rounded,
                label: s.today,
              ),
              ModernNavItem(
                icon: Icons.timer_outlined,
                selectedIcon: Icons.timer_rounded,
                label: s.focus,
              ),
              ModernNavItem(
                icon: Icons.grid_view_outlined,
                selectedIcon: Icons.grid_view_rounded,
                label: s.more,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _tabSubtitle(HomeTab tab, DateTime selectedDate, WidgetRef ref, S s) {
    final lang = ref.watch(appLanguageProvider).valueOrNull ?? 'tr';
    final locale = dateLocaleFor(lang);
    return switch (tab) {
      HomeTab.today => DateFormat(
        'd MMMM yyyy, EEEE',
        locale,
      ).format(selectedDate),
      HomeTab.focus => s.focusTimer,
      HomeTab.more => s.moreSubtitle,
    };
  }

  void _showAddTask(BuildContext context, WidgetRef ref, DateTime date) {
    showMimioBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddTaskSheet(selectedDate: date),
    );
  }
}

class _OnboardingHost extends ConsumerStatefulWidget {
  const _OnboardingHost({required this.child});

  final Widget child;

  @override
  ConsumerState<_OnboardingHost> createState() => _OnboardingHostState();
}

class _OnboardingHostState extends ConsumerState<_OnboardingHost> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowOnboarding());
  }

  Future<void> _maybeShowOnboarding() async {
    if (_checked || !mounted) return;
    _checked = true;

    final prefs =
        ref.read(adhdPreferencesProvider).valueOrNull ??
        await ref.read(adhdSettingsStorageProvider).load();
    final hasTheme = await ref
        .read(settingsStorageProvider)
        .hasThemePreference();

    if (!mounted) return;

    if (!prefs.onboardingCompleted) {
      await pushMimioOverlayRoute(
        context: context,
        builder: (_) => const OnboardingScreen(),
      );
    } else if (!hasTheme) {
      await pushMimioOverlayRoute(
        context: context,
        builder: (_) => const OnboardingScreen(themeOnly: true),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _TodayTab extends ConsumerStatefulWidget {
  const _TodayTab();

  @override
  ConsumerState<_TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends ConsumerState<_TodayTab> {
  @override
  Widget build(BuildContext context) {
    final timelineAsync = ref.watch(timelineProvider);
    final session = ref.watch(focusSessionProvider).valueOrNull;
    final viewMode = ref.watch(timelineViewModeProvider);
    final selectedDate = ref.watch(selectedDateProvider);
    final s = ref.watch(stringsProvider);

    final overwhelm =
        ref.watch(adhdPreferencesProvider).valueOrNull?.overwhelmMode ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const WeekStrip(),
        Expanded(
          child: timelineAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorView(
              error: '$e',
              onRetry: () => ref.invalidate(timelineProvider),
              s: s,
            ),
            data: (timeline) {
              final dailyEnergy = ref
                  .watch(adhdPreferencesProvider)
                  .valueOrNull
                  ?.dailyEnergyLevel;
              final tasks = filterByEnergy(timeline.tasks, dailyEnergy);

              return RefreshIndicator(
                onRefresh: () async {
                  await ref.read(timelineProvider.notifier).refresh();
                  ref.invalidate(inboxProvider);
                },
                child: CustomScrollView(
                  slivers: [
                    if (session != null)
                      SliverToBoxAdapter(
                        child: ActiveTaskBanner(session: session),
                      ),
                    const SliverToBoxAdapter(child: InboxSection()),
                    SliverToBoxAdapter(
                      child: ScheduleWarningBanner(tasks: tasks),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                        child: Row(
                          children: [
                            Text(
                              overwhelm ? s.overwhelmMode : s.todaysPlan,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const Spacer(),
                            _PlanViewButton(
                              tooltip: s.overwhelmMode,
                              selected: overwhelm,
                              icon: Icons.filter_center_focus_rounded,
                              onPressed: () => ref
                                  .read(adhdPreferencesProvider.notifier)
                                  .patch(
                                    (p) => p.copyWith(
                                      overwhelmMode: !p.overwhelmMode,
                                    ),
                                  ),
                            ),
                            const SizedBox(width: 4),
                            _PlanViewButton(
                              tooltip: viewMode == TimelineViewMode.list
                                  ? s.hourView
                                  : s.listView,
                              selected: viewMode == TimelineViewMode.grid,
                              icon: viewMode == TimelineViewMode.list
                                  ? Icons.view_timeline_outlined
                                  : Icons.view_agenda_outlined,
                              onPressed: () {
                                ref
                                    .read(timelineViewModeProvider.notifier)
                                    .state = viewMode == TimelineViewMode.list
                                    ? TimelineViewMode.grid
                                    : TimelineViewMode.list;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                        child: Text(
                          s.taskCount(tasks.length),
                          style: TextStyle(
                            fontSize: 13,
                            color: context.palette.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    if (tasks.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyTimeline(
                          onAdd: () => _showAddTask(context, ref, selectedDate),
                          s: s,
                        ),
                      )
                    else if (overwhelm)
                      SliverToBoxAdapter(
                        child: NowModeView(
                          tasks: tasks,
                          onTaskTap: (task) => _showTaskActions(
                            context,
                            ref,
                            task,
                            selectedDate,
                          ),
                          onStart: (task) => _startTask(context, ref, task.id),
                          onComplete: (task) =>
                              _completeTask(context, ref, task),
                        ),
                      )
                    else if (viewMode == TimelineViewMode.grid)
                      SliverToBoxAdapter(
                        child: TimelineHourGrid(
                          tasks: tasks,
                          onTaskTap: (task) =>
                              _handleTaskTap(context, ref, task),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final task = tasks[index];
                            return TaskCard(
                              task: task,
                              onTap: () => _showTaskActions(
                                context,
                                ref,
                                task,
                                selectedDate,
                              ),
                              onStart: () => _startTask(context, ref, task.id),
                              onPause: () => _togglePause(ref, task.id),
                              onComplete: () =>
                                  _completeTask(context, ref, task),
                              onCancel: () => _cancelTask(context, ref, task),
                              onDelete: () => _deleteTask(context, ref, task),
                              onSubtaskTap: (sub) => _showTaskActions(
                                context,
                                ref,
                                sub,
                                selectedDate,
                              ),
                              onSubtaskStart: (sub) =>
                                  _startTask(context, ref, sub.id),
                              onSubtaskPause: (sub) =>
                                  _togglePause(ref, sub.id),
                              onSubtaskComplete: (sub) =>
                                  _completeTask(context, ref, sub),
                              onSubtaskCancel: (sub) =>
                                  _cancelTask(context, ref, sub),
                            );
                          }, childCount: tasks.length),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 88)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _startTask(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    await startTaskAndOpenFocus(context, ref, id);
  }

  Future<void> _togglePause(WidgetRef ref, String id) async {
    final session = ref.read(focusSessionProvider).valueOrNull;
    if (session?.taskId == id && session!.isPaused) {
      await ref.read(timelineProvider.notifier).resumeTask(id);
    } else {
      await ref.read(timelineProvider.notifier).pauseTask(id);
    }
  }

  Future<void> _completeTask(
    BuildContext context,
    WidgetRef ref,
    TaskModel task,
  ) async {
    final s = ref.read(stringsProvider);
    try {
      final completed = await ref
          .read(timelineProvider.notifier)
          .completeTask(task.id);
      if (!context.mounted) return;
      await handleTaskCompleted(context, ref, task, completed);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.friendlyTaskActionError(e)),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  Future<void> _cancelTask(
    BuildContext context,
    WidgetRef ref,
    TaskModel task,
  ) async {
    final s = ref.read(stringsProvider);
    try {
      await ref
          .read(timelineProvider.notifier)
          .deleteTask(task.id, scope: DeleteRecurrenceScope.thisOccurrence);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.friendlyTaskActionError(e)),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  Future<void> _uncompleteTask(
    BuildContext context,
    WidgetRef ref,
    TaskModel task,
  ) async {
    final s = ref.read(stringsProvider);
    try {
      await ref.read(timelineProvider.notifier).uncompleteTask(task.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.friendlyTaskActionError(e)),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  Future<void> _deleteTask(
    BuildContext context,
    WidgetRef ref,
    TaskModel task,
  ) async {
    final s = ref.read(stringsProvider);
    final scope = await showDeleteTaskDialog(
      context: context,
      s: s,
      task: task,
    );
    if (scope == null) return;

    try {
      await ref
          .read(timelineProvider.notifier)
          .deleteTask(task.id, scope: scope);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.friendlyTaskActionError(e)),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  void _handleTaskTap(BuildContext context, WidgetRef ref, TaskModel task) {
    final date = ref.read(selectedDateProvider);
    _showTaskActions(context, ref, task, date);
  }

  void _showTaskActions(
    BuildContext context,
    WidgetRef ref,
    TaskModel task,
    DateTime date,
  ) {
    final session = ref.read(focusSessionProvider).valueOrNull;
    showTaskActionSheet(
      context: context,
      ref: ref,
      task: task,
      selectedDate: date,
      onStart: () => _startTask(context, ref, task.id),
      onPause: () => _togglePause(ref, task.id),
      onComplete: () => _completeTask(context, ref, task),
      onUncomplete: () => _uncompleteTask(context, ref, task),
      onDelete: (scope) =>
          ref.read(timelineProvider.notifier).deleteTask(task.id, scope: scope),
      onFocus: session?.taskId == task.id
          ? () => ref.read(homeTabProvider.notifier).state = HomeTab.focus
          : null,
    );
  }

  void _showAddTask(BuildContext context, WidgetRef ref, DateTime date) {
    showMimioBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddTaskSheet(selectedDate: date),
    );
  }
}

class _PlanViewButton extends StatelessWidget {
  const _PlanViewButton({
    required this.tooltip,
    required this.selected,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final bool selected;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          backgroundColor: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : context.palette.surface,
          foregroundColor: selected
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : context.palette.textSecondary,
          side: BorderSide(color: context.palette.border),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.error,
    required this.onRetry,
    required this.s,
  });

  final String error;
  final VoidCallback onRetry;
  final S s;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 48,
            color: context.palette.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            s.connectionError,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.palette.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: Text(s.retry)),
        ],
      ),
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  const _EmptyTimeline({required this.onAdd, required this.s});

  final VoidCallback onAdd;
  final S s;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: MimioColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wb_sunny_rounded,
                size: 44,
                color: MimioColors.primary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              s.noPlanToday,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              s.emptyPlanHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.palette.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        MimioColors.primary,
                        MimioColors.primary.withValues(alpha: 0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: MimioColors.primary.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        s.addFirstTask,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
