import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide DayPeriod;
import 'package:florien/core/l10n/app_strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/data/routine_catalog.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/models/recurrence.dart';
import 'package:florien/core/models/task_usage_summary.dart';
import 'package:florien/core/services/planner_ai_service.dart';
import 'package:florien/core/services/speech_input_service.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/utils/subtask_sequence.dart';
import 'package:florien/core/utils/task_icons.dart';
import 'package:florien/core/widgets/florien_card.dart';
import 'package:florien/core/widgets/florien_duration_picker.dart';
import 'package:florien/core/widgets/florien_soft_overlay.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/premium/premium_gate.dart';
import 'package:florien/features/premium/premium_membership.dart';
import 'package:florien/features/premium/premium_upsell_button.dart';
import 'package:florien/features/task_icon/domain/task_category.dart';
import 'package:florien/features/task_icon/presentation/realtime_task_icon_controller.dart';
import 'package:florien/features/task_icon/presentation/task_icon_badge.dart';
import 'package:florien/features/todo/completion_celebration_screen.dart';
import 'package:florien/features/todo/daily_plan_share_sheet.dart';
import 'package:florien/features/todo/daily_reschedule_review_flow.dart';
import 'package:florien/features/todo/routine_discovery_screen.dart';
import 'package:florien/features/todo/task_breakdown_action.dart';
import 'package:florien/features/todo/todo_list_tab.dart';

typedef DailyTaskGroupMover =
    Future<void> Function(
      TaskModel task,
      DayPeriod? period,
      DateTime date, {
      RecurrenceScope scope,
    });
typedef DailyTaskRescheduler =
    Future<void> Function(
      TaskModel task,
      DateTime date, {
      RecurrenceScope scope,
    });
typedef DailyTaskCompleter = Future<CompletionCounts> Function(String taskId);

class DailyTaskEditInput {
  const DailyTaskEditInput({
    required this.title,
    required this.description,
    required this.date,
    required this.period,
    required this.durationMinutes,
    required this.isTimed,
    required this.startsAt,
    required this.endsAt,
    required this.recurrence,
    required this.subtasks,
    required this.icon,
    this.scope = RecurrenceScope.thisOccurrence,
  });

  final String title;
  final String description;
  final DateTime date;
  final DayPeriod period;
  final int durationMinutes;
  final bool isTimed;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final RecurrenceSelection recurrence;
  final List<String> subtasks;
  final String icon;
  final RecurrenceScope scope;
}

typedef DailyTaskUpdater =
    Future<void> Function(TaskModel task, DailyTaskEditInput input);

final dailyTaskUpdaterProvider = Provider<DailyTaskUpdater>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  return (task, input) async {
    final scheduledAt = input.isTimed
        ? input.startsAt!
        : _scheduledAt(input.date, input.period);
    final durationMinutes = input.isTimed
        ? input.endsAt!.difference(input.startsAt!).inMinutes
        : input.durationMinutes;
    final updated = await repository.updateRecurringTask(
      id: task.id,
      scope: input.scope,
      title: input.title,
      description: input.description.trim().isEmpty ? null : input.description,
      clearDescription: input.description.trim().isEmpty,
      icon: input.icon,
      durationMinutes: durationMinutes,
      scheduledAt: scheduledAt,
      isTimed: input.isTimed,
      recurrence: input.recurrence,
      dayPeriod: input.period,
      isInbox: false,
    );
    if (task.isRecurring && input.scope != RecurrenceScope.thisOccurrence) {
      await repository.replaceSubtasksForSeries(
        id: updated.id,
        titles: input.subtasks,
      );
    } else {
      await repository.replaceSubtasks(
        parentId: updated.id,
        titles: input.subtasks,
      );
    }
    try {
      await ref.read(notificationReconcileProvider)();
    } catch (error) {
      debugPrint('Updated daily task notifications failed: $error');
    }
    invalidateDailyTimelines(ref);
  };
});

final dailyTaskGroupMoverProvider = Provider<DailyTaskGroupMover>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  return (
    task,
    period,
    date, {
    RecurrenceScope scope = RecurrenceScope.thisOccurrence,
  }) async {
    if (period == null) {
      if (!task.isCompleted) await repository.completeTask(task.id);
      await ref.read(taskAlarmServiceProvider).cancel(task.id);
    } else {
      if (task.isCompleted) await repository.uncompleteTask(task.id);
      if (task.dayPeriod != period || task.isCompleted || task.isRecurring) {
        await repository.updateRecurringTask(
          id: task.id,
          scope: scope,
          dayPeriod: period,
          scheduledAt: _scheduledAt(date, period),
        );
      }
    }
    invalidateDailyTimelines(ref);
    ref.invalidate(completionCountsProvider);
    unawaited(ref.read(notificationReconcileProvider)());
  };
});

final dailyTaskReschedulerProvider = Provider<DailyTaskRescheduler>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  return (
    task,
    date, {
    RecurrenceScope scope = RecurrenceScope.thisOccurrence,
  }) async {
    if (task.isCompleted) await repository.uncompleteTask(task.id);
    final leavesToday = florienRescheduleLeavesToday(date, DateTime.now());
    if (task.isRecurring) {
      await repository.updateRecurringTask(
        id: task.id,
        scope: scope,
        scheduledAt: _scheduledAt(date, task.dayPeriod),
        dayPeriod: task.dayPeriod,
        isInbox: false,
      );
    } else {
      await repository.updateTask(
        id: task.id,
        scheduledAt: _scheduledAt(date, task.dayPeriod),
        dayPeriod: task.dayPeriod,
        isInbox: false,
        status: leavesToday ? TaskStatus.pending : null,
        clearStartedAt: leavesToday,
      );
    }
    if (leavesToday) abandonFocusForTask(ref, task.id);
    invalidateDailyTimelines(ref);
    ref.invalidate(completionCountsProvider);
    unawaited(ref.read(notificationReconcileProvider)());
  };
});

final dailyTaskCompleterProvider = Provider<DailyTaskCompleter>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  return (taskId) async {
    await repository.completeTask(taskId);
    await ref.read(taskAlarmServiceProvider).cancel(taskId);
    ref.invalidate(inboxProvider);
    invalidateDailyTimelines(ref);
    unawaited(ref.read(notificationReconcileProvider)());
    return ref.read(manualCompletionSummaryProvider)(taskId);
  };
});

class DailyPlannerTab extends ConsumerStatefulWidget {
  const DailyPlannerTab({
    super.key,
    this.quickAddSignal = 0,
    this.showPremiumUpsell = false,
    this.onPremiumUpsellPressed,
  });

  final int quickAddSignal;
  final bool showPremiumUpsell;
  final VoidCallback? onPremiumUpsellPressed;

  @override
  ConsumerState<DailyPlannerTab> createState() => _DailyPlannerTabState();
}

enum DailyPlannerGrouping { list, timeline }

class _DailyPlannerTabState extends ConsumerState<DailyPlannerTab> {
  late DateTime _selectedDate = _dateOnly(DateTime.now());
  final Map<String, List<TaskModel>> _timelineTasksByDate = {};
  final Set<DayPeriod> _collapsed = {};
  DailyPlannerGrouping _grouping = DailyPlannerGrouping.list;
  bool _showDuration = true;
  late final ProviderSubscription<DateTime?> _dateRequestSubscription;
  late final ProviderSubscription<int> _reviewLaunchSubscription;
  int _lastReviewLaunchSignal = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _prefetchAdjacentDates(_selectedDate);
    });
    _dateRequestSubscription = ref.listenManual(
      dailyPlannerDateRequestProvider,
      (_, date) {
        if (date == null || !mounted) return;
        ref.read(dailyPlannerDateRequestProvider.notifier).state = null;
        _selectDate(date);
      },
      fireImmediately: true,
    );
    _lastReviewLaunchSignal = ref.read(dailyReviewLaunchSignalProvider);
    _reviewLaunchSubscription = ref.listenManual(
      dailyReviewLaunchSignalProvider,
      (previous, next) {
        if (!mounted || next == _lastReviewLaunchSignal) return;
        _lastReviewLaunchSignal = next;
        final tasks =
            ref.read(dailyTimelineProvider(_selectedDate)).valueOrNull?.tasks ??
            const <TaskModel>[];
        if (!tasks.any((task) => !task.isCompleted)) return;
        unawaited(_showRescheduleReview(tasks));
      },
    );
  }

  @override
  void dispose() {
    _dateRequestSubscription.close();
    _reviewLaunchSubscription.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DailyPlannerTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.quickAddSignal == oldWidget.quickAddSignal) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_showQuickAdd(DayPeriod.anytime));
    });
  }

  @override
  Widget build(BuildContext context) {
    final timeline = ref.watch(dailyTimelineProvider(_selectedDate));
    final dateKey = _timelineCacheKey(_selectedDate);
    final resolved = timeline.valueOrNull;
    if (timeline.isRefreshing) {
      _timelineTasksByDate.clear();
    }
    if (resolved != null) {
      _timelineTasksByDate[dateKey] = resolved.tasks;
    }
    final tasks =
        resolved?.tasks ?? _timelineTasksByDate[dateKey] ?? const <TaskModel>[];
    final isLoadingNewDate = timeline.isLoading && resolved == null;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          _timelineTasksByDate.clear();
          ref.invalidate(dailyTimelineProvider);
          await ref.read(dailyTimelineProvider(_selectedDate).future);
        },
        child: Stack(
          children: [
            _DailyBody(
              selectedDate: _selectedDate,
              tasks: tasks,
              collapsed: _collapsed,
              onSelectDate: _selectDate,
              onOpenDatePicker: _showDatePicker,
              onToggleSection: _toggleSection,
              onAdd: _showQuickAdd,
              onMoveTask: _moveTaskToGroup,
              grouping: _grouping,
              onGroupingChanged: _setGrouping,
              showDuration: _showDuration,
              onShowDurationSettings: _showDurationSettings,
              onRescheduleTasks: tasks.any((task) => !task.isCompleted)
                  ? () => _showRescheduleReview(tasks)
                  : null,
              onDiscoverRoutines: _showRoutineDiscovery,
              onShare: () => _showDailyShare(tasks),
              showPremiumUpsell: widget.showPremiumUpsell,
              onPremiumUpsellPressed: widget.onPremiumUpsellPressed,
            ),
            if (isLoadingNewDate)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  key: ValueKey('daily-timeline-loading-$dateKey'),
                  minHeight: 2,
                  color: context.palette.selection,
                  backgroundColor: context.palette.surfaceMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _prefetchAdjacentDates(DateTime date) {
    final previous = _dateOnly(date.subtract(const Duration(days: 1)));
    final next = _dateOnly(date.add(const Duration(days: 1)));
    unawaited(ref.read(dailyTimelineProvider(previous).future));
    unawaited(ref.read(dailyTimelineProvider(next).future));
  }

  String _timelineCacheKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

  void _selectDate(DateTime value) {
    final date = _dateOnly(value);
    setState(() => _selectedDate = date);
    _prefetchAdjacentDates(date);
  }

  Future<void> _showDatePicker() async {
    final selectedDate = await showFlorienBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (_) => _DailyDatePickerSheet(initialDate: _selectedDate),
    );
    if (selectedDate == null || !mounted) return;
    _selectDate(selectedDate);
  }

  void _toggleSection(DayPeriod period) {
    setState(() {
      if (!_collapsed.add(period)) _collapsed.remove(period);
    });
  }

  void _setGrouping(DailyPlannerGrouping value) {
    setState(() => _grouping = value);
  }

  Future<void> _showDurationSettings() async {
    await showFlorienSoftDialog<void>(
      context: context,
      maxWidth: 340,
      builder: (_) => TaskDurationVisibilityDialog(
        showDuration: _showDuration,
        onChanged: (value) => setState(() => _showDuration = value),
      ),
    );
  }

  Future<void> _showDailyShare(List<TaskModel> tasks) =>
      showDailyPlanShareSheet(context, date: _selectedDate, tasks: tasks);

  Future<void> _showQuickAdd(DayPeriod period) async {
    final draft = await showFlorienBottomSheet<_DailyTaskDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(),
      builder: (_) => _DailyQuickAddSheet(
        initialDraft: _DailyTaskDraft(date: _selectedDate, period: period),
      ),
    );
    if (draft == null || !mounted) return;
    if (draft.openTodo) {
      await showTodoQuickAdd(
        context: context,
        ref: ref,
        initialTitle: draft.title,
      );
      return;
    }
    if (draft.openDetails) {
      await pushFlorienOverlayRoute<bool>(
        context: context,
        builder: (_) => _DailyTaskDetailScreen(initialDraft: draft),
      );
    } else {
      await _createDailyTask(ref, draft);
      if (mounted) _prefetchAdjacentDates(_selectedDate);
    }
  }

  Future<void> _moveTaskToGroup(TaskModel task, DayPeriod? period) async {
    var scope = RecurrenceScope.thisOccurrence;
    if (period != null && task.isRecurring) {
      if (task.hasUniqueOccurrenceTitle) {
        scope = RecurrenceScope.thisOccurrence;
      } else {
        final selected = await _showRecurrenceScopeSheet(
          context,
          prompt: _RecurrenceScopePrompt.move,
        );
        if (!mounted || selected == null) return;
        scope = selected;
      }
    }
    await ref.read(dailyTaskGroupMoverProvider)(
      task,
      period,
      _selectedDate,
      scope: scope,
    );
  }

  Future<void> _showRescheduleReview(List<TaskModel> tasks) async {
    if (!tasks.any((task) => !task.isCompleted)) return;
    await pushFlorienOverlayRoute<void>(
      context: context,
      builder: (_) => DailyRescheduleReviewFlow(
        selectedDate: _selectedDate,
        tasks: tasks,
        onReschedule: (task, date) =>
            ref.read(dailyTaskReschedulerProvider)(task, date),
      ),
    );
    if (mounted) {
      _timelineTasksByDate.clear();
      ref.invalidate(dailyTimelineProvider);
    }
  }

  Future<void> _showRoutineDiscovery() async {
    List<TaskUsageSummary> frequentlyUsedTasks = const [];
    try {
      frequentlyUsedTasks = await ref
          .read(taskRepositoryProvider)
          .getFrequentlyUsedTasks();
    } catch (error) {
      debugPrint('Frequently used tasks could not be loaded: $error');
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RoutineDiscoveryScreen(
          frequentlyUsedTasks: frequentlyUsedTasks,
          onFrequentlyUsedTaskSelected: (summary) async {
            final task = summary.task;
            if (task.subtasks.isNotEmpty &&
                !await requirePremiumAccess(
                  context,
                  ref,
                  PremiumFeature.subtasks,
                )) {
              return;
            }
            if (!mounted) return;
            await pushFlorienOverlayRoute<bool>(
              context: context,
              builder: (_) => _DailyTaskDetailScreen(
                initialDraft: _DailyTaskDraft(
                  date: _selectedDate,
                  period: task.dayPeriod,
                  title: task.title,
                  description: task.description ?? '',
                  durationMinutes: task.durationMinutes,
                  icon: task.icon,
                  color: task.color,
                  subtasks: task.subtasks
                      .map((subtask) => subtask.title)
                      .toList(),
                  openDetails: true,
                ),
              ),
            );
          },
          onTaskSelected: (task, _) async {
            if (!mounted) return;
            await pushFlorienOverlayRoute<bool>(
              context: context,
              builder: (_) => _DailyTaskDetailScreen(
                initialDraft: _DailyTaskDraft(
                  date: _selectedDate,
                  period: task.period,
                  title: task.title,
                  description: task.description,
                  durationMinutes: task.durationMinutes,
                  icon: task.icon,
                  color: readyRoutineTaskColor,
                  presetSubtasks: task.subtasks,
                  openDetails: true,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DailyBody extends StatelessWidget {
  const _DailyBody({
    required this.selectedDate,
    required this.tasks,
    required this.collapsed,
    required this.onSelectDate,
    required this.onOpenDatePicker,
    required this.onToggleSection,
    required this.onAdd,
    required this.onMoveTask,
    required this.grouping,
    required this.onGroupingChanged,
    required this.showDuration,
    required this.onShowDurationSettings,
    required this.onRescheduleTasks,
    required this.onDiscoverRoutines,
    required this.onShare,
    required this.showPremiumUpsell,
    required this.onPremiumUpsellPressed,
  });

  final DateTime selectedDate;
  final List<TaskModel> tasks;
  final Set<DayPeriod> collapsed;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onOpenDatePicker;
  final ValueChanged<DayPeriod> onToggleSection;
  final ValueChanged<DayPeriod> onAdd;
  final Future<void> Function(TaskModel task, DayPeriod? period) onMoveTask;
  final DailyPlannerGrouping grouping;
  final ValueChanged<DailyPlannerGrouping> onGroupingChanged;
  final bool showDuration;
  final VoidCallback onShowDurationSettings;
  final VoidCallback? onRescheduleTasks;
  final Future<void> Function() onDiscoverRoutines;
  final VoidCallback onShare;
  final bool showPremiumUpsell;
  final VoidCallback? onPremiumUpsellPressed;

  @override
  Widget build(BuildContext context) {
    final activeTasks = tasks.where((task) => !task.isCompleted).toList();
    final completedTasks = tasks.where((task) => task.isCompleted).toList();
    return Column(
      key: const ValueKey('daily-planner-page'),
      children: [
        ColoredBox(
          color: context.palette.background,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: _DailyHeader(
              selectedDate: selectedDate,
              onSelectDate: onSelectDate,
              onOpenDatePicker: onOpenDatePicker,
              grouping: grouping,
              onGroupingChanged: onGroupingChanged,
              showDuration: showDuration,
              onShowDurationSettings: onShowDurationSettings,
              onRescheduleTasks: onRescheduleTasks,
              onDiscoverRoutines: onDiscoverRoutines,
              onShare: onShare,
              showPremiumUpsell: showPremiumUpsell,
              onPremiumUpsellPressed: onPremiumUpsellPressed,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            key: const ValueKey('daily-planner-list'),
            physics: const AlwaysScrollableScrollPhysics(
              parent: ClampingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
            children: [
              if (grouping == DailyPlannerGrouping.list)
                _DailyListSections(
                  key: const ValueKey('daily-list-view'),
                  tasks: activeTasks,
                  selectedDate: selectedDate,
                  collapsed: collapsed,
                  onToggleSection: onToggleSection,
                  onAdd: onAdd,
                  onMoveTask: onMoveTask,
                  showDuration: showDuration,
                )
              else
                _DailyTimelineSections(
                  key: const ValueKey('daily-timeline-view'),
                  tasks: activeTasks,
                  selectedDate: selectedDate,
                  onAdd: () => onAdd(DayPeriod.anytime),
                  showDuration: showDuration,
                ),
              if (completedTasks.isNotEmpty)
                _DailyCompletedSection(
                  tasks: completedTasks,
                  selectedDate: selectedDate,
                  onTaskDropped: (task) => onMoveTask(task, null),
                  showDuration: showDuration,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DailyHeader extends StatelessWidget {
  const _DailyHeader({
    required this.selectedDate,
    required this.onSelectDate,
    required this.onOpenDatePicker,
    required this.grouping,
    required this.onGroupingChanged,
    required this.showDuration,
    required this.onShowDurationSettings,
    required this.onRescheduleTasks,
    required this.onDiscoverRoutines,
    required this.onShare,
    required this.showPremiumUpsell,
    required this.onPremiumUpsellPressed,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onOpenDatePicker;
  final DailyPlannerGrouping grouping;
  final ValueChanged<DailyPlannerGrouping> onGroupingChanged;
  final bool showDuration;
  final VoidCallback onShowDurationSettings;
  final VoidCallback? onRescheduleTasks;
  final Future<void> Function() onDiscoverRoutines;
  final VoidCallback onShare;
  final bool showPremiumUpsell;
  final VoidCallback? onPremiumUpsellPressed;

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final isToday = _sameDate(selectedDate, today);
    return Column(
      key: const ValueKey('daily-date-header'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _HeaderButton(
                  key: ValueKey(
                    isToday ? 'daily-open-date-picker' : 'daily-return-today',
                  ),
                  label: isToday
                      ? context.l10n('Tarih seç')
                      : context.l10n('Bugüne dön'),
                  icon: isToday
                      ? Icons.calendar_month_outlined
                      : Icons.today_rounded,
                  onTap: isToday ? onOpenDatePicker : () => onSelectDate(today),
                ),
              ),
            ),
            if (showPremiumUpsell && onPremiumUpsellPressed != null) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: PremiumUpsellButton(
                      onPressed: onPremiumUpsellPressed!,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ] else
              const Spacer(),
            _SquareButton(
              key: const ValueKey('daily-share-plan'),
              tooltip: context.l10n('Günü paylaş'),
              icon: Icons.ios_share_rounded,
              onTap: onShare,
            ),
            const SizedBox(width: 6),
            _SquareButton(
              key: const ValueKey('daily-duration-settings'),
              tooltip: context.l10n('Görünüm ayarları'),
              icon: showDuration
                  ? Icons.timer_outlined
                  : Icons.timer_off_outlined,
              onTap: onShowDurationSettings,
            ),
            const SizedBox(width: 6),
            _DailyViewToggle(grouping: grouping, onChanged: onGroupingChanged),
          ],
        ),
        const SizedBox(height: 18),
        Semantics(
          button: true,
          label: context.l10n('Tarih seç'),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('daily-date-picker-trigger'),
              onTap: onOpenDatePicker,
              borderRadius: BorderRadius.circular(FlorienRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        _weekdayName(selectedDate),
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1,
                              height: 1.05,
                            ),
                      ),
                    ),
                    Text(
                      '${_monthName(selectedDate.month).toUpperCase()} ${selectedDate.year}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: context.palette.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: context.palette.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (var offset = -3; offset <= 3; offset++)
              Expanded(
                child: _DayButton(
                  date: selectedDate.add(Duration(days: offset)),
                  selected: offset == 0,
                  today: _sameDate(
                    selectedDate.add(Duration(days: offset)),
                    today,
                  ),
                  onTap: onSelectDate,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _DailyUtilityActions(
          onRescheduleTasks: onRescheduleTasks,
          onDiscoverRoutines: onDiscoverRoutines,
        ),
      ],
    );
  }
}

class _DailyUtilityActions extends StatelessWidget {
  const _DailyUtilityActions({
    required this.onRescheduleTasks,
    required this.onDiscoverRoutines,
  });

  final VoidCallback? onRescheduleTasks;
  final Future<void> Function() onDiscoverRoutines;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onRescheduleTasks != null) ...[
          _QuietActionChip(
            key: const ValueKey('daily-menu-reschedule'),
            icon: Icons.event_repeat_rounded,
            label: context.l10n('Yeniden zamanla'),
            tooltip: context.l10n('Görevleri yeniden zamanla'),
            onTap: onRescheduleTasks!,
          ),
          const SizedBox(width: 8),
        ],
        _QuietActionChip(
          key: const ValueKey('daily-menu-routines'),
          icon: Icons.auto_awesome_outlined,
          label: context.l10n('Rutinler'),
          tooltip: context.l10n('Rutinleri keşfet'),
          onTap: () => onDiscoverRoutines(),
        ),
      ],
    );
  }
}

class _QuietActionChip extends StatelessWidget {
  const _QuietActionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = context.palette.textSecondary;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: context.palette.surfaceMuted,
        shape: StadiumBorder(
          side: BorderSide(
            color: context.palette.border.withValues(alpha: 0.35),
            width: FlorienBorders.thin,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: muted),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: muted,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DailyDatePickerSheet extends StatefulWidget {
  const _DailyDatePickerSheet({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_DailyDatePickerSheet> createState() => _DailyDatePickerSheetState();
}

class _DailyDatePickerSheetState extends State<_DailyDatePickerSheet> {
  late DateTime _selectedDate = _dateOnly(widget.initialDate);

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final firstYear = math.min(today.year - 10, _selectedDate.year - 1);
    final lastYear = math.max(today.year + 10, _selectedDate.year + 1);
    final isToday = _sameDate(_selectedDate, today);

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: context.palette.border)),
        ),
        child: ListView(
          key: const ValueKey('daily-date-picker-sheet'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: context.palette.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: context.l10n('Kapat'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
                Expanded(
                  child: Text(
                    context.l10n('Tarihe git'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton.filled(
                  tooltip: context.l10n('Seçilen tarihe git'),
                  onPressed: () => Navigator.pop(context, _selectedDate),
                  icon: const Icon(Icons.check_rounded),
                ),
              ],
            ),
            CalendarDatePicker(
              initialDate: _selectedDate,
              currentDate: today,
              firstDate: DateTime(firstYear),
              lastDate: DateTime(lastYear, 12, 31),
              onDateChanged: (value) =>
                  setState(() => _selectedDate = _dateOnly(value)),
            ),
            if (!isToday) ...[
              const Divider(height: 18),
              _DailyRescheduleShortcut(
                icon: Icons.today_rounded,
                label: context.l10n('Bugüne dön'),
                onTap: () => Navigator.pop(context, today),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DailyViewToggle extends StatelessWidget {
  const _DailyViewToggle({required this.grouping, required this.onChanged});

  final DailyPlannerGrouping grouping;
  final ValueChanged<DailyPlannerGrouping> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      label: context.l10n('Görünüm'),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.surfaceMuted,
          borderRadius: BorderRadius.circular(FlorienRadius.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DailyViewToggleSegment(
                key: const ValueKey('daily-grouping-list'),
                tooltip: context.l10n('Liste görünümü'),
                icon: Icons.format_list_bulleted_rounded,
                selected: grouping == DailyPlannerGrouping.list,
                onTap: () => onChanged(DailyPlannerGrouping.list),
              ),
              _DailyViewToggleSegment(
                key: const ValueKey('daily-grouping-timeline'),
                tooltip: context.l10n('Zaman çizelgesi'),
                icon: Icons.view_timeline_outlined,
                selected: grouping == DailyPlannerGrouping.timeline,
                onTap: () => onChanged(DailyPlannerGrouping.timeline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyViewToggleSegment extends StatelessWidget {
  const _DailyViewToggleSegment({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(FlorienRadius.sm - 4);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: selected ? palette.surface : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            width: 36,
            height: 34,
            child: Icon(
              icon,
              size: 18,
              color: selected
                  ? palette.textPrimary
                  : palette.textSecondary.withValues(alpha: 0.62),
            ),
          ),
        ),
      ),
    );
  }
}

TaskModel? activeScheduledTaskAt({
  required List<TaskModel> tasks,
  required DateTime selectedDate,
  required DateTime now,
}) {
  if (_dateOnly(selectedDate) != _dateOnly(now)) return null;
  final active = tasks.where((task) {
    final start = task.scheduledAt;
    if (!task.isTimed || task.isCompleted || start == null) return false;
    final end = start.add(Duration(minutes: task.durationMinutes));
    return !now.isBefore(start) && now.isBefore(end);
  }).toList()..sort(_compareScheduledTasks);
  return active.firstOrNull;
}

double scheduledTaskProgressAt(TaskModel task, DateTime now) {
  final start = task.scheduledAt;
  if (start == null || task.durationMinutes <= 0) return 0;
  final elapsed = now.difference(start).inMilliseconds;
  final total = Duration(minutes: task.durationMinutes).inMilliseconds;
  return (elapsed / total).clamp(0, 1);
}

int _compareScheduledTasks(TaskModel a, TaskModel b) {
  final timeResult = (a.scheduledAt ?? DateTime(0)).compareTo(
    b.scheduledAt ?? DateTime(0),
  );
  if (timeResult != 0) return timeResult;
  final orderResult = a.sortOrder.compareTo(b.sortOrder);
  if (orderResult != 0) return orderResult;
  return a.id.compareTo(b.id);
}

class _DailyListSections extends ConsumerStatefulWidget {
  const _DailyListSections({
    super.key,
    required this.tasks,
    required this.selectedDate,
    required this.collapsed,
    required this.onToggleSection,
    required this.onAdd,
    required this.onMoveTask,
    required this.showDuration,
  });

  final List<TaskModel> tasks;
  final DateTime selectedDate;
  final Set<DayPeriod> collapsed;
  final ValueChanged<DayPeriod> onToggleSection;
  final ValueChanged<DayPeriod> onAdd;
  final Future<void> Function(TaskModel task, DayPeriod? period) onMoveTask;
  final bool showDuration;

  @override
  ConsumerState<_DailyListSections> createState() => _DailyListSectionsState();
}

class _DailyListSectionsState extends ConsumerState<_DailyListSections> {
  late DateTime _now = DateTime.now();
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focus = ref.watch(activeFocusTaskProvider);
    final isToday = _dateOnly(widget.selectedDate) == _dateOnly(_now);
    final focusedTask = isToday
        ? widget.tasks.where((task) => task.id == focus?.taskId).firstOrNull
        : null;
    final automaticallyActiveTask = activeScheduledTaskAt(
      tasks: widget.tasks,
      selectedDate: widget.selectedDate,
      now: _now,
    );
    final progressTask = focusedTask ?? automaticallyActiveTask;
    final progress = progressTask == null
        ? null
        : focusedTask != null
        ? focus!.progress
        : scheduledTaskProgressAt(progressTask, _now);
    final remaining = progressTask == null
        ? null
        : focusedTask != null
        ? Duration(seconds: focus!.remainingSeconds)
        : progressTask.scheduledAt!
              .add(Duration(minutes: progressTask.durationMinutes))
              .difference(_now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final period in DayPeriod.values) ...[
          _DailySection(
            period: period,
            tasks: widget.tasks
                .where((task) => task.dayPeriod == period)
                .toList(),
            selectedDate: widget.selectedDate,
            collapsed: widget.collapsed.contains(period),
            onToggle: () => widget.onToggleSection(period),
            onAdd: () => widget.onAdd(period),
            onTaskDropped: (task) => widget.onMoveTask(task, period),
            progressTaskId: progressTask?.id,
            progress: progress,
            remaining: remaining,
            showDuration: widget.showDuration,
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _DailyTimelineSections extends ConsumerStatefulWidget {
  const _DailyTimelineSections({
    super.key,
    required this.tasks,
    required this.selectedDate,
    required this.onAdd,
    required this.showDuration,
  });

  final List<TaskModel> tasks;
  final DateTime selectedDate;
  final VoidCallback onAdd;
  final bool showDuration;

  @override
  ConsumerState<_DailyTimelineSections> createState() =>
      _DailyTimelineSectionsState();
}

class _DailyTimelineSectionsState
    extends ConsumerState<_DailyTimelineSections> {
  late DateTime _now = DateTime.now();
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anytime = widget.tasks
        .where((task) => !task.isTimed || task.scheduledAt == null)
        .toList();
    final scheduled =
        widget.tasks
            .where((task) => task.isTimed && task.scheduledAt != null)
            .toList()
          ..sort(_compareScheduledTasks);
    final automaticallyActiveTask = activeScheduledTaskAt(
      tasks: scheduled,
      selectedDate: widget.selectedDate,
      now: _now,
    );
    final focus = ref.watch(activeFocusTaskProvider);
    final focusedScheduledTask =
        _dateOnly(widget.selectedDate) == _dateOnly(_now)
        ? scheduled.where((task) => task.id == focus?.taskId).firstOrNull
        : null;
    final progressTask = focusedScheduledTask ?? automaticallyActiveTask;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TimelineGroupHeader(
          icon: Icons.schedule_rounded,
          label: context.l10n('HERHANGİ BİR ZAMAN ({count})', {
            'count': '${anytime.length}',
          }),
          onAdd: widget.onAdd,
        ),
        const SizedBox(height: 5),
        Container(
          key: const ValueKey('daily-timeline-anytime'),
          child: anytime.isEmpty
              ? _DailyEmptyState(period: DayPeriod.anytime, onTap: widget.onAdd)
              : Column(
                  children: [
                    for (final task in anytime)
                      _DailyDraggableTask(
                        key: ValueKey('timeline-anytime-${task.id}'),
                        task: task,
                        selectedDate: widget.selectedDate,
                        showDuration: widget.showDuration,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 18),
        _PlannedTimelineHeader(count: scheduled.length),
        const SizedBox(height: 14),
        Container(
          key: const ValueKey('daily-timeline-scheduled'),
          child: scheduled.isEmpty
              ? Text(
                  context.l10n('Belirli saatli görev yok'),
                  style: TextStyle(color: context.palette.textSecondary),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TimelineDayMarker(
                      markerKey: const ValueKey('daily-timeline-sun-marker'),
                      icon: Icons.wb_sunny_outlined,
                      color: _periodColor(DayPeriod.morning),
                    ),
                    for (final task in scheduled)
                      _TimelineTaskRow(
                        task: task,
                        selectedDate: widget.selectedDate,
                        now: _now,
                        progress: progressTask?.id == task.id
                            ? focusedScheduledTask?.id == task.id
                                  ? focus!.progress
                                  : scheduledTaskProgressAt(task, _now)
                            : null,
                        showDuration: widget.showDuration,
                      ),
                    _TimelinePlanGap(tasks: scheduled),
                    const SizedBox(height: 10),
                    _TimelineDayMarker(
                      markerKey: const ValueKey('daily-timeline-moon-marker'),
                      icon: Icons.nightlight_round,
                      color: _periodColor(DayPeriod.evening),
                    ),
                    Text(
                      '23:59',
                      key: const ValueKey('daily-timeline-day-end'),
                      style: TextStyle(
                        color: context.palette.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _PlannedTimelineHeader extends StatelessWidget {
  const _PlannedTimelineHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(FlorienRadius.sm),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${context.l10n('PLANLANDI')} ($count)',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: .9,
            ),
          ),
          const SizedBox(width: 9),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
        ],
      ),
    ),
  );
}

class _TimelineDayMarker extends StatelessWidget {
  const _TimelineDayMarker({
    required this.markerKey,
    required this.icon,
    required this.color,
  });

  final Key markerKey;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Icon(icon, key: markerKey, color: color, size: 20),
    ),
  );
}

class _TimelineGroupHeader extends StatelessWidget {
  const _TimelineGroupHeader({
    required this.icon,
    required this.label,
    required this.onAdd,
  });

  final IconData icon;
  final String label;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: context.palette.surfaceMuted,
          borderRadius: BorderRadius.circular(FlorienRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: context.palette.textSecondary),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: .7,
              ),
            ),
          ],
        ),
      ),
      const Spacer(),
      _SquareButton(
        tooltip: context.l10n('Zaman çizelgesine görev ekle'),
        icon: Icons.add_rounded,
        compact: true,
        emphasized: true,
        onTap: onAdd,
      ),
    ],
  );
}

class _TimelineTaskRow extends StatelessWidget {
  const _TimelineTaskRow({
    required this.task,
    required this.selectedDate,
    required this.now,
    required this.progress,
    required this.showDuration,
  });

  final TaskModel task;
  final DateTime selectedDate;
  final DateTime now;
  final double? progress;
  final bool showDuration;

  @override
  Widget build(BuildContext context) {
    final start = task.scheduledAt ?? selectedDate;
    final end = start.add(Duration(minutes: task.durationMinutes));
    return Padding(
      key: ValueKey('timeline-task-${task.id}'),
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _clockLabel(start),
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          _DailyDraggableTask(
            task: task,
            selectedDate: selectedDate,
            timelineStyle: true,
            scheduledProgress: progress,
            scheduledRemaining: progress == null ? null : end.difference(now),
            showDuration: showDuration,
          ),
          Text(
            _clockLabel(end),
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelinePlanGap extends StatelessWidget {
  const _TimelinePlanGap({required this.tasks});

  final List<TaskModel> tasks;

  @override
  Widget build(BuildContext context) {
    final latestEnd = tasks
        .map(
          (task) =>
              task.scheduledAt!.add(Duration(minutes: task.durationMinutes)),
        )
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final endOfDay = DateTime(
      latestEnd.year,
      latestEnd.month,
      latestEnd.day,
      23,
      59,
    );
    final gap = endOfDay.difference(latestEnd);
    if (gap <= Duration.zero) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 20,
                child: Column(
                  children: [
                    for (var index = 0; index < 3; index++) ...[
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.palette.border,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (index < 2) const SizedBox(height: 4),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_timelineGapLabel(gap)} → Plan yok',
                style: TextStyle(
                  color: context.palette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _timelineGapLabel(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '${minutes}d';
  if (minutes == 0) return '${hours}sa';
  return '${hours}sa ${minutes}d';
}

class _DailySection extends StatelessWidget {
  const _DailySection({
    required this.period,
    required this.tasks,
    required this.selectedDate,
    required this.collapsed,
    required this.onToggle,
    required this.onAdd,
    required this.onTaskDropped,
    required this.progressTaskId,
    required this.progress,
    required this.remaining,
    required this.showDuration,
  });

  final DayPeriod period;
  final List<TaskModel> tasks;
  final DateTime selectedDate;
  final bool collapsed;
  final VoidCallback onToggle;
  final VoidCallback onAdd;
  final Future<void> Function(TaskModel task) onTaskDropped;
  final String? progressTaskId;
  final double? progress;
  final Duration? remaining;
  final bool showDuration;

  @override
  Widget build(BuildContext context) {
    final color = _periodColor(period);
    return DragTarget<TaskModel>(
      key: ValueKey('daily-drop-${period.name}'),
      onWillAcceptWithDetails: (details) =>
          details.data.isCompleted || details.data.dayPeriod != period,
      onAcceptWithDetails: (details) => onTaskDropped(details.data),
      builder: (context, candidates, rejected) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: candidates.isEmpty ? EdgeInsets.zero : const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: candidates.isEmpty
              ? Colors.transparent
              : color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(FlorienRadius.md),
          border: candidates.isEmpty
              ? null
              : Border.all(color: color.withValues(alpha: .5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Material(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(FlorienRadius.sm),
                  child: InkWell(
                    onTap: onToggle,
                    borderRadius: BorderRadius.circular(FlorienRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 8,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_periodIcon(period), size: 17, color: color),
                          const SizedBox(width: 7),
                          Text(
                            '${_periodLabel(period).toUpperCase()} (${tasks.length})',
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .7,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            collapsed
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.keyboard_arrow_up_rounded,
                            size: 20,
                            color: color,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                if (tasks.isNotEmpty)
                  _SquareButton(
                    tooltip: context.l10n('{period} görevi ekle', {
                      'period': _periodLabel(period),
                    }),
                    icon: Icons.add_rounded,
                    compact: true,
                    emphasized: true,
                    onTap: onAdd,
                  ),
              ],
            ),
            if (!collapsed) ...[
              const SizedBox(height: 9),
              if (tasks.isEmpty)
                _DailyEmptyState(period: period, onTap: onAdd)
              else
                for (final task in tasks)
                  _DailyDraggableTask(
                    key: ValueKey(task.id),
                    task: task,
                    selectedDate: selectedDate,
                    showTimeRange: true,
                    showDuration: showDuration,
                    scheduledProgress: progressTaskId == task.id
                        ? progress
                        : null,
                    scheduledRemaining: progressTaskId == task.id
                        ? remaining
                        : null,
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DailyEmptyState extends StatelessWidget {
  const _DailyEmptyState({required this.period, required this.onTap});

  final DayPeriod period;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(FlorienRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: context.palette.surfaceMuted.withValues(alpha: .42),
          borderRadius: BorderRadius.circular(FlorienRadius.sm),
        ),
        child: Row(
          children: [
            Icon(
              Icons.add_rounded,
              size: 16,
              color: context.palette.textSecondary.withValues(alpha: .68),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _periodHint(period),
                style: TextStyle(
                  color: context.palette.textSecondary.withValues(alpha: .72),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DailyCompletedSection extends StatelessWidget {
  const _DailyCompletedSection({
    required this.tasks,
    required this.selectedDate,
    required this.onTaskDropped,
    required this.showDuration,
  });

  final List<TaskModel> tasks;
  final DateTime selectedDate;
  final Future<void> Function(TaskModel task) onTaskDropped;
  final bool showDuration;

  @override
  Widget build(BuildContext context) => DragTarget<TaskModel>(
    key: const ValueKey('daily-drop-completed'),
    onWillAcceptWithDetails: (details) => !details.data.isCompleted,
    onAcceptWithDetails: (details) => onTaskDropped(details.data),
    builder: (context, candidates, rejected) => AnimatedContainer(
      key: const ValueKey('daily-completed-section'),
      duration: const Duration(milliseconds: 150),
      padding: candidates.isEmpty ? EdgeInsets.zero : const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: candidates.isEmpty
            ? Colors.transparent
            : FlorienColors.success.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(FlorienRadius.md),
        border: candidates.isEmpty
            ? null
            : Border.all(color: FlorienColors.success.withValues(alpha: .5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: FlorienColors.success.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(FlorienRadius.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 17,
                    color: FlorienColors.success,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '${context.l10n('TAMAMLANDI')} (${tasks.length})',
                    style: TextStyle(
                      color: FlorienColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .7,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
          for (final task in tasks)
            _DailyDraggableTask(
              key: ValueKey('completed-${task.id}'),
              task: task,
              selectedDate: selectedDate,
              showDuration: showDuration,
            ),
        ],
      ),
    ),
  );
}

class _DailyDraggableTask extends StatelessWidget {
  const _DailyDraggableTask({
    super.key,
    required this.task,
    required this.selectedDate,
    this.showTimeRange = false,
    this.showDuration = true,
    this.timelineStyle = false,
    this.scheduledProgress,
    this.scheduledRemaining,
  });

  final TaskModel task;
  final DateTime selectedDate;
  final bool showTimeRange;
  final bool showDuration;
  final bool timelineStyle;
  final double? scheduledProgress;
  final Duration? scheduledRemaining;

  @override
  Widget build(BuildContext context) {
    final card = _DailyTaskCard(
      task: task,
      selectedDate: selectedDate,
      showTimeRange: showTimeRange,
      showDuration: showDuration,
      timelineStyle: timelineStyle,
      scheduledProgress: scheduledProgress,
      scheduledRemaining: scheduledRemaining,
    );
    return LongPressDraggable<TaskModel>(
      data: task,
      delay: const Duration(milliseconds: 280),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width - 36,
          child: Transform.scale(
            scale: .92,
            child: Opacity(
              key: ValueKey('daily-drag-feedback-${task.id}'),
              opacity: .72,
              child: _DailyDragPreview(task: task, showDuration: showDuration),
            ),
          ),
        ),
      ),
      childWhenDragging: Transform.scale(
        scale: .96,
        child: Opacity(
          key: ValueKey('daily-drag-placeholder-${task.id}'),
          opacity: .18,
          child: card,
        ),
      ),
      child: card,
    );
  }
}

class _DailyDragPreview extends StatelessWidget {
  const _DailyDragPreview({required this.task, required this.showDuration});

  final TaskModel task;
  final bool showDuration;

  @override
  Widget build(BuildContext context) {
    final color = _periodColor(task.dayPeriod);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(FlorienRadius.sm),
        border: Border.all(color: color.withValues(alpha: .45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .14),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          TaskIconBadge.forTask(icon: task.icon, size: 34),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (showDuration)
                  Text(
                    _durationLabel(task.durationMinutes),
                    style: TextStyle(
                      color: context.palette.textSecondary,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          Icon(Icons.drag_indicator_rounded, color: color, size: 18),
        ],
      ),
    );
  }
}

class _DailyTaskCard extends ConsumerWidget {
  const _DailyTaskCard({
    required this.task,
    required this.selectedDate,
    this.showTimeRange = false,
    this.showDuration = true,
    this.timelineStyle = false,
    this.scheduledProgress,
    this.scheduledRemaining,
  });

  final TaskModel task;
  final DateTime selectedDate;
  final bool showTimeRange;
  final bool showDuration;
  final bool timelineStyle;
  final double? scheduledProgress;
  final Duration? scheduledRemaining;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = timelineStyle
        ? FlorienColors.fromHex(task.color)
        : _periodColor(task.dayPeriod);
    final focus = ref.watch(activeFocusTaskProvider);
    final activeFocus = focus?.taskId == task.id ? focus : null;
    final progress = timelineStyle
        ? scheduledProgress
        : (activeFocus?.progress ?? scheduledProgress);
    final completionButton = IconButton(
      tooltip: task.isCompleted
          ? context.l10n('Tamamlanmadı')
          : context.l10n('Tamamla'),
      iconSize: 24,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints.tightFor(width: 32, height: 32),
      onPressed: () async {
        try {
          if (task.isCompleted) {
            await ref.read(taskRepositoryProvider).uncompleteTask(task.id);
            ref.invalidate(completionCountsProvider);
            unawaited(ref.read(notificationReconcileProvider)());
          } else {
            final counts = await ref.read(dailyTaskCompleterProvider)(task.id);
            if (!context.mounted) return;
            await showTaskCompletionFeedback(context, ref, counts);
          }
        } on StateError {
          if (!context.mounted) return;
          ref.invalidate(dailyTimelineProvider);
          return;
        } catch (error) {
          debugPrint('Daily task completion could not be changed: $error');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n('Görev durumu güncellenemedi.')),
              ),
            );
          }
        }
        if (!context.mounted) return;
        ref.invalidate(dailyTimelineProvider);
      },
      icon: Icon(
        task.isCompleted ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: task.isCompleted
            ? Theme.of(context).colorScheme.primary
            : context.palette.textSecondary,
      ),
    );
    final remainingLabel =
        scheduledRemaining != null && (timelineStyle || progress != null)
        ? _remainingTimelineLabel(scheduledRemaining!)
        : null;
    final durationLabel = !showDuration
        ? null
        : showTimeRange && task.isTimed && task.scheduledAt != null
        ? '${_clockLabel(task.scheduledAt!)} → ${_clockLabel(task.scheduledAt!.add(Duration(minutes: task.durationMinutes)))}'
        : _durationLabel(task.durationMinutes);
    final statusLabel = remainingLabel ?? durationLabel;
    final header = timelineStyle
        ? InkWell(
            onTap: () => _showTaskActions(context, ref),
            borderRadius: BorderRadius.circular(FlorienRadius.lg),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 4, 2),
              child: Row(
                children: [
                  Container(
                    key: ValueKey('timeline-task-bar-${task.id}'),
                    width: 3,
                    height: 22,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (statusLabel != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            statusLabel,
                            key: ValueKey('timeline-task-status-${task.id}'),
                            style: TextStyle(
                              color: context.palette.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _DailyTaskIcon(
                    task: task,
                    color: color,
                    progress: progress,
                    dimension: 24,
                  ),
                  completionButton,
                ],
              ),
            ),
          )
        : ListTile(
            dense: true,
            visualDensity: const VisualDensity(vertical: -4),
            minTileHeight: statusLabel == null ? 38 : 42,
            minVerticalPadding: 0,
            contentPadding: const EdgeInsets.fromLTRB(10, 0, 4, 0),
            leading: _DailyTaskIcon(
              task: task,
              color: color,
              progress: progress,
              dimension: 24,
            ),
            title: Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                decoration: task.isCompleted
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
            subtitle: statusLabel == null
                ? null
                : Text(
                    statusLabel,
                    key: ValueKey('daily-task-status-${task.id}'),
                    style: TextStyle(
                      color: context.palette.textSecondary,
                      fontSize: 11,
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
            trailing: completionButton,
            onTap: () => _showTaskActions(context, ref),
          );
    return AnimatedOpacity(
      opacity: task.isCompleted ? .55 : 1,
      duration: const Duration(milliseconds: 180),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            color.withValues(alpha: task.isCompleted ? 0.04 : 0.10),
            context.palette.surface,
          ),
          borderRadius: BorderRadius.circular(FlorienRadius.lg),
          border: Border.all(
            color: timelineStyle && progress != null
                ? color.withValues(alpha: .55)
                : context.palette.border,
            width: FlorienBorders.thin,
          ),
        ),
        child: Column(
          children: [
            header,
            if (task.hasSubtasks) _DailyTaskSubtasks(task: task),
          ],
        ),
      ),
    );
  }

  Future<void> _showTaskActions(BuildContext context, WidgetRef ref) async {
    final action = await showModalBottomSheet<_DailyTaskMenuAction>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
          children: [
            _DailyTaskActionTile(
              icon: Icons.restart_alt_rounded,
              label: task.isCompleted
                  ? context.l10n('Görevi yeniden başlat')
                  : context.l10n('Görevi başlat'),
              onTap: () =>
                  Navigator.pop(context, _DailyTaskMenuAction.startFocus),
            ),
            _DailyTaskActionTile(
              icon: Icons.copy_all_outlined,
              label: context.l10n('Bir kopya oluştur'),
              onTap: () =>
                  Navigator.pop(context, _DailyTaskMenuAction.createCopy),
            ),
            _DailyTaskActionTile(
              icon: Icons.move_to_inbox_outlined,
              label: context.l10n('Yapılacaklara taşı'),
              onTap: () =>
                  Navigator.pop(context, _DailyTaskMenuAction.moveToTodo),
            ),
            _DailyTaskActionTile(
              icon: Icons.calendar_month_outlined,
              label: context.l10n('Yeniden planla'),
              onTap: () =>
                  Navigator.pop(context, _DailyTaskMenuAction.reschedule),
            ),
            _DailyTaskActionTile(
              icon: Icons.redo_rounded,
              label: context.l10n('Yarın için yeniden planla'),
              onTap: () =>
                  Navigator.pop(context, _DailyTaskMenuAction.tomorrow),
            ),
            if (!task.hasSubtasks)
              _DailyTaskActionTile(
                icon: Icons.account_tree_rounded,
                label: context.l10n('Ayrım öner'),
                onTap: () => Navigator.pop(
                  context,
                  _DailyTaskMenuAction.suggestBreakdown,
                ),
              ),
            _DailyTaskActionTile(
              icon: Icons.edit_outlined,
              label: context.l10n('Görevi düzenle'),
              onTap: () => Navigator.pop(context, _DailyTaskMenuAction.edit),
            ),
            _DailyTaskActionTile(
              icon: Icons.delete_outline_rounded,
              label: context.l10n('Görevi sil'),
              destructive: true,
              onTap: () => Navigator.pop(context, _DailyTaskMenuAction.delete),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case _DailyTaskMenuAction.createCopy:
        await _showCopyCreation(context);
      case _DailyTaskMenuAction.moveToTodo:
        await _showMoveToTodo(context, ref);
      case _DailyTaskMenuAction.reschedule:
        await _showReschedule(context, ref);
      case _DailyTaskMenuAction.tomorrow:
        var scope = RecurrenceScope.thisOccurrence;
        if (task.isRecurring) {
          final selected = await _showRecurrenceScopeSheet(context);
          if (!context.mounted || selected == null) return;
          scope = selected;
        }
        await ref.read(dailyTaskReschedulerProvider)(
          task,
          _dateOnly(selectedDate).add(const Duration(days: 1)),
          scope: scope,
        );
      case _DailyTaskMenuAction.suggestBreakdown:
        await suggestTaskBreakdown(context: context, ref: ref, task: task);
      case _DailyTaskMenuAction.startFocus:
        final started = await ref.read(startTaskFocusProvider)(task);
        if (!context.mounted) return;
        ref.read(focusTaskLaunchProvider.notifier).state = FocusTaskLaunch(
          taskId: started.id,
          title: started.title,
          durationMinutes: started.durationMinutes,
          icon: started.icon,
          color: started.color,
        );
      case _DailyTaskMenuAction.edit:
        await _showEdit(context, ref);
      case _DailyTaskMenuAction.delete:
        var scope = RecurrenceScope.thisOccurrence;
        if (task.isRecurring) {
          final selected = await _showRecurrenceScopeSheet(
            context,
            prompt: _RecurrenceScopePrompt.delete,
          );
          if (!context.mounted || selected == null) return;
          scope = selected;
        }
        await ref.read(dailyDeleteTaskProvider)(task.id, scope: scope);
        ref.invalidate(dailyTimelineProvider);
      case null:
        return;
    }
  }

  Future<void> _showCopyCreation(BuildContext context) async {
    await pushFlorienOverlayRoute<bool>(
      context: context,
      builder: (_) => _DailyTaskDetailScreen(
        initialDraft: _DailyTaskDraft(
          date: _dateOnly(task.scheduledAt ?? selectedDate),
          period: task.dayPeriod,
          title: context.l10n('{title} (Kopya)', {'title': task.title}),
          description: task.description ?? '',
          durationMinutes: task.durationMinutes,
          recurrence: const RecurrenceSelection(),
          isTimed: task.isTimed,
          startsAt: task.isTimed ? task.scheduledAt : null,
          endsAt: task.isTimed && task.scheduledAt != null
              ? task.scheduledAt!.add(Duration(minutes: task.durationMinutes))
              : null,
          subtasks: task.subtasks.map((subtask) => subtask.title).toList(),
          icon: task.icon,
          color: task.color,
        ),
      ),
    );
  }

  Future<void> _showEdit(BuildContext context, WidgetRef ref) async {
    await pushFlorienOverlayRoute<bool>(
      context: context,
      builder: (_) => _DailyTaskDetailScreen(
        screenTitle: 'Görevi düzenle',
        initialDraft: _DailyTaskDraft(
          date: _dateOnly(task.scheduledAt ?? selectedDate),
          period: task.dayPeriod,
          title: task.title,
          description: task.description ?? '',
          durationMinutes: task.durationMinutes,
          recurrence: RecurrenceSelection(type: task.recurrenceType),
          isTimed: task.isTimed,
          startsAt: task.isTimed ? task.scheduledAt : null,
          endsAt: task.isTimed && task.scheduledAt != null
              ? task.scheduledAt!.add(Duration(minutes: task.durationMinutes))
              : null,
          subtasks: task.subtasks.map((subtask) => subtask.title).toList(),
          icon: task.icon,
          color: task.color,
        ),
        onSave: (draft) async {
          var scope = RecurrenceScope.thisOccurrence;
          if (task.isRecurring) {
            final selected = await _showRecurrenceScopeSheet(context);
            if (selected == null) throw const _RecurrenceScopeCancelled();
            scope = selected;
          }
          await ref.read(dailyTaskUpdaterProvider)(
            task,
            DailyTaskEditInput(
              title: draft.title,
              description: draft.description,
              date: draft.date,
              period: draft.period,
              durationMinutes: draft.durationMinutes,
              isTimed: draft.isTimed,
              startsAt: draft.startsAt,
              endsAt: draft.endsAt,
              recurrence: draft.recurrence,
              subtasks: draft.subtasks,
              icon: draft.icon,
              scope: scope,
            ),
          );
        },
      ),
    );
  }

  Future<void> _showMoveToTodo(BuildContext context, WidgetRef ref) async {
    const defaultList = '__default_todo_list__';
    final lists = await ref.read(todoListsProvider.future);
    if (!context.mounted) return;
    final selected = await showFlorienBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .72,
          ),
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: context.palette.border)),
          ),
          child: ListView(
            key: const ValueKey('daily-move-to-todo-sheet'),
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.palette.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                context.l10n('Yapılacaklara Taşı'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _DailyTodoListChoice(
                key: const ValueKey('daily-move-list-default'),
                name: context.l10n('To-do'),
                description: context.l10n('Varsayılan yapılacaklar listesi'),
                onTap: () => Navigator.pop(context, defaultList),
              ),
              for (final list in lists) ...[
                const SizedBox(height: 10),
                _DailyTodoListChoice(
                  key: ValueKey('daily-move-list-${list.id}'),
                  name: list.name,
                  description: list.description,
                  onTap: () => Navigator.pop(context, list.id),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (selected == null || !context.mounted) return;
    await ref.read(dailyMoveToTodoProvider)(
      task.id,
      selected == defaultList ? null : selected,
    );
  }

  Future<void> _showReschedule(BuildContext context, WidgetRef ref) async {
    final date = await showFlorienBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DailyRescheduleSheet(
        initialDate: _dateOnly(task.scheduledAt ?? selectedDate),
      ),
    );
    if (date == null || !context.mounted) return;
    var scope = RecurrenceScope.thisOccurrence;
    if (task.isRecurring) {
      final selected = await _showRecurrenceScopeSheet(context);
      if (!context.mounted || selected == null) return;
      scope = selected;
    }
    await ref.read(dailyTaskReschedulerProvider)(task, date, scope: scope);
  }
}

enum _DailyTaskMenuAction {
  createCopy,
  moveToTodo,
  reschedule,
  tomorrow,
  suggestBreakdown,
  startFocus,
  edit,
  delete,
}

class _DailyTaskSubtasks extends ConsumerStatefulWidget {
  const _DailyTaskSubtasks({required this.task});

  final TaskModel task;

  @override
  ConsumerState<_DailyTaskSubtasks> createState() => _DailyTaskSubtasksState();
}

class _DailyTaskSubtasksState extends ConsumerState<_DailyTaskSubtasks> {
  bool _expanded = true;

  @override
  void didUpdateWidget(covariant _DailyTaskSubtasks oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.task.hasSubtasks) _expanded = true;
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final completedSubtasks = task.completedSubtaskCount;
    final subtaskProgress = completedSubtasks / task.subtasks.length;
    return Column(
      children: [
        Divider(height: 1, color: context.palette.border),
        Tooltip(
          message: _expanded
              ? context.l10n('Alt görevleri gizle')
              : context.l10n('Alt görevleri göster'),
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 5, 8, 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: subtaskProgress,
                        minHeight: 4,
                        backgroundColor: context.palette.surfaceMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      context.l10n('{done} / {total} alt görev', {
                        'done': '$completedSubtasks',
                        'total': '${task.subtasks.length}',
                      }),
                      style: TextStyle(
                        color: context.palette.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? .5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: context.palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            child: _expanded
                ? Column(
                    children: [
                      for (final subtask in task.subtasks)
                        _DailySubtaskRow(parent: task, subtask: subtask),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _DailySubtaskRow extends ConsumerWidget {
  const _DailySubtaskRow({required this.parent, required this.subtask});

  final TaskModel parent;
  final TaskModel subtask;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AnimatedOpacity(
    duration: const Duration(milliseconds: 180),
    opacity: subtask.isCompleted ? .55 : 1,
    child: Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.palette.border)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      child: Row(
        children: [
          TaskIconBadge.forTask(icon: subtask.icon, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              subtask.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                decoration: subtask.isCompleted
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                decorationThickness: 2,
              ),
            ),
          ),
          IconButton(
            tooltip: subtask.isCompleted
                ? context.l10n('{title} tamamlanmadı olarak işaretle', {
                    'title': subtask.title,
                  })
                : context.l10n('{title} tamamla', {'title': subtask.title}),
            iconSize: 20,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 26, height: 26),
            onPressed: () => _toggleCompletion(ref),
            icon: Icon(
              subtask.isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: subtask.isCompleted
                  ? Theme.of(context).colorScheme.primary
                  : context.palette.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _toggleCompletion(WidgetRef ref) async {
    try {
      await ref
          .read(taskRepositoryProvider)
          .toggleSubtask(parentId: parent.id, subtaskId: subtask.id);
    } catch (error) {
      debugPrint('Daily subtask completion could not be changed: $error');
    }
    ref.invalidate(dailyTimelineProvider);
    ref.invalidate(completionCountsProvider);
  }
}

class _DailyTaskIcon extends StatelessWidget {
  const _DailyTaskIcon({
    required this.task,
    required this.color,
    required this.progress,
    this.dimension = 42,
  });

  final TaskModel task;
  final Color color;
  final double? progress;
  final double dimension;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: dimension,
    child: Stack(
      alignment: Alignment.center,
      children: [
        CircleAvatar(
          radius: dimension / 2 - 4,
          backgroundColor: Colors.transparent,
          child: TaskIconBadge.forTask(
            icon: task.icon,
            size: dimension - 8,
            circular: true,
          ),
        ),
        if (progress != null)
          SizedBox.square(
            dimension: dimension,
            child: CircularProgressIndicator(
              key: ValueKey('daily-task-progress-${task.id}'),
              value: progress,
              strokeWidth: 3.2,
              strokeCap: StrokeCap.round,
              backgroundColor: color.withValues(alpha: .16),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
      ],
    ),
  );
}

String _remainingTimelineLabel(Duration duration) {
  final safe = duration.isNegative ? Duration.zero : duration;
  final hours = safe.inHours;
  final minutes = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

class _DailyTaskActionTile extends StatelessWidget {
  const _DailyTaskActionTile({
    required this.icon,
    required this.label,
    this.destructive = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool destructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? Theme.of(context).colorScheme.error
        : context.palette.textPrimary;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: TextStyle(color: color)),
      onTap: onTap ?? () {},
    );
  }
}

class _DailyRescheduleSheet extends StatefulWidget {
  const _DailyRescheduleSheet({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_DailyRescheduleSheet> createState() => _DailyRescheduleSheetState();
}

class _DailyRescheduleSheetState extends State<_DailyRescheduleSheet> {
  late DateTime _selectedDate = _dateOnly(widget.initialDate);

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final nextWeekSameDay = _dateOnly(
      widget.initialDate.add(const Duration(days: 7)),
    );
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: context.palette.border)),
        ),
        child: ListView(
          key: const ValueKey('daily-reschedule-sheet'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: context.palette.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: context.l10n('Kapat'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
                Expanded(
                  child: Text(
                    'Yeniden planla',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton.filled(
                  tooltip: context.l10n('Tarihi onayla'),
                  onPressed: () => Navigator.pop(context, _selectedDate),
                  icon: const Icon(Icons.check_rounded),
                ),
              ],
            ),
            CalendarDatePicker(
              initialDate: _selectedDate,
              currentDate: today,
              firstDate: DateTime(today.year - 1),
              lastDate: DateTime(today.year + 5, 12, 31),
              onDateChanged: (value) =>
                  setState(() => _selectedDate = _dateOnly(value)),
            ),
            const Divider(height: 18),
            _DailyRescheduleShortcut(
              icon: Icons.today_outlined,
              label: context.l10n('Bugün ({weekday})', {
                'weekday': _weekdayShortLabel(today),
              }),
              onTap: () => Navigator.pop(context, today),
            ),
            _DailyRescheduleShortcut(
              icon: Icons.redo_rounded,
              label: context.l10n('Gelecek hafta ({date})', {
                'date':
                    '${nextWeekSameDay.day} ${_monthShortLabel(nextWeekSameDay)} ${_weekdayShortLabel(nextWeekSameDay)}',
              }),
              onTap: () => Navigator.pop(context, nextWeekSameDay),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyRescheduleShortcut extends StatelessWidget {
  const _DailyRescheduleShortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) =>
      ListTile(leading: Icon(icon), title: Text(label), onTap: onTap);
}

class _DailyTodoListChoice extends StatelessWidget {
  const _DailyTodoListChoice({
    super.key,
    required this.name,
    required this.description,
    required this.onTap,
  });

  final String name;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: context.palette.surfaceMuted,
    borderRadius: BorderRadius.circular(FlorienRadius.md),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(FlorienRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            Icon(Icons.checklist_rounded, color: context.palette.textSecondary),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (description.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.palette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

class _DailyQuickAddSheet extends ConsumerStatefulWidget {
  const _DailyQuickAddSheet({required this.initialDraft});

  final _DailyTaskDraft initialDraft;

  @override
  ConsumerState<_DailyQuickAddSheet> createState() =>
      _DailyQuickAddSheetState();
}

class _DailyQuickAddSheetState extends ConsumerState<_DailyQuickAddSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.initialDraft.title,
  );
  late DayPeriod _period = widget.initialDraft.period;
  late RecurrenceType _recurrence = widget.initialDraft.recurrence.type;
  late bool _isTimed = widget.initialDraft.isTimed;
  late DateTime? _startsAt = widget.initialDraft.startsAt;
  late DateTime? _endsAt = widget.initialDraft.endsAt;
  final _speech = SpeechInputService();
  bool _listening = false;
  late final RealtimeTaskIconController _taskIcon = RealtimeTaskIconController(
    initialCategory: widget.initialDraft.icon,
  );

  @override
  void initState() {
    super.initState();
    if (widget.initialDraft.title.trim().isNotEmpty) {
      _taskIcon.onTaskChanged(widget.initialDraft.title);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _taskIcon.dispose();
    _speech.dispose();
    super.dispose();
  }

  Future<void> _toggleVoiceInput() async {
    if (_listening) {
      await _speech.stop();
      return;
    }
    final existingText = _title.text.trim();
    await _speech.start(
      onText: (spokenText) {
        if (!mounted) return;
        final text = existingText.isEmpty
            ? spokenText
            : '$existingText $spokenText';
        _title.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
        _taskIcon.onTaskChanged(text);
      },
      onListeningChanged: (isListening) {
        if (mounted) setState(() => _listening = isListening);
      },
      onError: _showVoiceError,
    );
  }

  void _showVoiceError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  _DailyTaskDraft _draft({required bool details}) =>
      widget.initialDraft.copyWith(
        title: _title.text.trim(),
        period: _period,
        isTimed: _isTimed,
        startsAt: _startsAt,
        endsAt: _endsAt,
        recurrence: RecurrenceSelection(type: _recurrence),
        icon: _taskIcon.value.category.storageName,
        openDetails: details,
      );

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) return;
    _taskIcon.onTaskChanged(_title.text.trim());
    if (!mounted) return;
    Navigator.pop(context, _draft(details: false));
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.only(bottom: keyboard),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: context.palette.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.palette.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: context.palette.primaryMuted,
                      borderRadius: BorderRadius.circular(FlorienRadius.sm),
                      border: Border.all(color: context.palette.border),
                    ),
                    child: const Icon(Icons.add_task_rounded, size: 21),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.l10n('Yeni görev'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n('Kapat'),
                    onPressed: () => Navigator.pop(context),
                    iconSize: 19,
                    style: IconButton.styleFrom(
                      fixedSize: const Size.square(36),
                      padding: EdgeInsets.zero,
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: context.palette.primaryMuted,
                  borderRadius: BorderRadius.circular(FlorienRadius.md),
                  border: Border.all(
                    color: context.palette.border,
                    width: FlorienBorders.thin,
                  ),
                ),
                child: TextField(
                  key: const ValueKey('daily-quick-title'),
                  controller: _title,
                  onChanged: _taskIcon.onTaskChanged,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _submit(),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: context.l10n('Sırada ne var?'),
                    border: InputBorder.none,
                    prefixIcon: ValueListenableBuilder(
                      valueListenable: _taskIcon,
                      builder: (_, result, _) =>
                          TaskIconBadge.forResult(result, size: 34),
                    ),
                    suffixIconConstraints: const BoxConstraints(),
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: const ValueKey('daily-quick-voice'),
                            tooltip: _listening
                                ? context.l10n('Konuşmayı bitir')
                                : context.l10n('Konuş'),
                            onPressed: _toggleVoiceInput,
                            style: IconButton.styleFrom(
                              fixedSize: const Size.square(34),
                              padding: EdgeInsets.zero,
                              backgroundColor: _listening
                                  ? FlorienColors.softPink
                                  : context.palette.surface,
                              side: BorderSide(
                                color: context.palette.border,
                                width: FlorienBorders.thin,
                              ),
                            ),
                            icon: Icon(
                              _listening
                                  ? Icons.stop_rounded
                                  : Icons.graphic_eq_rounded,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton.filled(
                            key: const ValueKey('daily-quick-submit'),
                            tooltip: context.l10n('Ekle'),
                            onPressed: _submit,
                            style: IconButton.styleFrom(
                              fixedSize: const Size.square(34),
                              padding: EdgeInsets.zero,
                            ),
                            icon: const Icon(Icons.check_rounded, size: 19),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _QuickChip(
                            key: const ValueKey('daily-period-chip'),
                            icon: _isTimed
                                ? Icons.edit_calendar_outlined
                                : _periodIcon(_period),
                            label: _isTimed
                                ? 'ZAMANINDA'
                                : _periodLabel(_period).toUpperCase(),
                            onTap: _pickPeriod,
                          ),
                          const SizedBox(width: 7),
                          _QuickChip(
                            key: const ValueKey('daily-recurrence-chip'),
                            icon: Icons.repeat_rounded,
                            label: _recurrenceLabel(_recurrence).toUpperCase(),
                            onTap: _pickRecurrence,
                          ),
                          const SizedBox(width: 7),
                          _QuickChip(
                            key: const ValueKey('daily-details-chip'),
                            tooltip: context.l10n('Ayrıntılı görev oluştur'),
                            icon: Icons.more_horiz_rounded,
                            label: '',
                            onTap: () =>
                                Navigator.pop(context, _draft(details: true)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickPeriod() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await _showDayPeriodPicker(
      context,
      _period,
      isTimed: _isTimed,
      isPremium: hasActivePremium(ref),
    );
    if (selected == null || !mounted) return;
    if (selected.isTodo) {
      Navigator.pop(context, _draft(details: false).copyWith(openTodo: true));
      return;
    }
    if (selected.isTimed) {
      if (!await requirePremiumAccess(
        context,
        ref,
        PremiumFeature.exactTaskTime,
      )) {
        return;
      }
      if (!mounted) return;
      final range = _defaultTimedRange(widget.initialDraft.date);
      _isTimed = true;
      _startsAt ??= range.$1;
      _endsAt ??= range.$2;
      Navigator.pop(context, _draft(details: true));
      return;
    }
    setState(() {
      _period = selected.period;
      _isTimed = false;
    });
  }

  Future<void> _pickRecurrence() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await _showRecurrencePicker(context, _recurrence);
    if (selected != null && mounted) setState(() => _recurrence = selected);
  }
}

class _DailyTaskDetailScreen extends ConsumerStatefulWidget {
  const _DailyTaskDetailScreen({
    required this.initialDraft,
    this.screenTitle = 'Görev ekle',
    this.onSave,
  });

  final _DailyTaskDraft initialDraft;
  final String screenTitle;
  final Future<void> Function(_DailyTaskDraft draft)? onSave;

  @override
  ConsumerState<_DailyTaskDetailScreen> createState() =>
      _DailyTaskDetailScreenState();
}

class _DailyTaskDetailScreenState
    extends ConsumerState<_DailyTaskDetailScreen> {
  late final TextEditingController _title = TextEditingController(
    text: widget.initialDraft.title,
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.initialDraft.description,
  );
  final TextEditingController _subtask = TextEditingController();
  late DateTime _date = widget.initialDraft.date;
  late DayPeriod _period = widget.initialDraft.period;
  late int _duration = widget.initialDraft.durationMinutes;
  late bool _isTimed = widget.initialDraft.isTimed;
  late DateTime _startsAt =
      widget.initialDraft.startsAt ??
      _defaultTimedRange(widget.initialDraft.date).$1;
  late DateTime _endsAt =
      widget.initialDraft.endsAt ?? _startsAt.add(const Duration(minutes: 30));
  late RecurrenceType _recurrence = widget.initialDraft.recurrence.type;
  late final List<String> _subtasks = [...widget.initialDraft.subtasks];
  late bool _subtasksExpanded = widget.initialDraft.subtasks.isNotEmpty;
  late bool _notesExpanded = widget.initialDraft.description.trim().isNotEmpty;
  bool _saving = false;
  bool _generatingSubtasks = false;
  late final RealtimeTaskIconController _taskIcon = RealtimeTaskIconController(
    initialCategory: widget.initialDraft.icon,
  );

  @override
  void initState() {
    super.initState();
    if (widget.initialDraft.title.trim().isNotEmpty) {
      _taskIcon.onTaskChanged(widget.initialDraft.title);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _subtask.dispose();
    _taskIcon.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      _taskIcon.onTaskChanged(_title.text.trim());
      final taskDate = _isTimed ? _dateOnly(_startsAt) : _date;
      final taskPeriod = _isTimed ? dayPeriodForLocalTime(_startsAt) : _period;
      final draft = widget.initialDraft.copyWith(
        title: _title.text.trim(),
        description: _notes.text.trim(),
        date: taskDate,
        period: taskPeriod,
        durationMinutes: _isTimed
            ? _endsAt.difference(_startsAt).inMinutes
            : _duration,
        isTimed: _isTimed,
        startsAt: _isTimed ? _startsAt : null,
        endsAt: _isTimed ? _endsAt : null,
        clearTimedRange: !_isTimed,
        recurrence: RecurrenceSelection(type: _recurrence),
        icon: _taskIcon.value.category.storageName,
        subtasks: _subtasks,
        openDetails: false,
      );
      final onSave = widget.onSave;
      if (onSave == null) {
        await _createDailyTask(ref, draft);
      } else {
        await onSave(draft);
      }
      if (mounted) Navigator.pop(context, true);
    } on _RecurrenceScopeCancelled {
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addSubtask() async {
    final value = _subtask.text.trim();
    if (value.isEmpty) return;
    if (!await requirePremiumAccess(context, ref, PremiumFeature.subtasks)) {
      return;
    }
    if (!mounted) return;
    if (_subtasks.length >= TaskModel.userSubtaskLimit) {
      _showSubtaskLimitWarning();
      return;
    }
    setState(() {
      _subtasks.add(value);
      _subtask.clear();
    });
  }

  void _showSubtaskLimitWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n('En fazla 30 alt görev ekleyebilirsin.')),
      ),
    );
  }

  void _onTitleChanged(String value) {
    _taskIcon.onTaskChanged(value);
    setState(() {});
  }

  Future<void> _generateSubtasks() async {
    final title = _title.text.trim();
    if (title.isEmpty || _generatingSubtasks || _subtasks.isNotEmpty) {
      return;
    }
    if (!await requirePremiumAccess(context, ref, PremiumFeature.subtasks)) {
      return;
    }
    if (!mounted) return;

    setState(() => _generatingSubtasks = true);
    try {
      final generated = widget.initialDraft.presetSubtasks.isNotEmpty
          ? widget.initialDraft.presetSubtasks
          : await ref
                .read(taskBreakdownServiceProvider)
                .generateSubtasks(title);
      if (!mounted || _title.text.trim().isEmpty) return;
      final additions = selectAiSubtaskAdditions(
        generated: generated,
        existing: _subtasks,
      );
      if (additions.isEmpty) return;
      setState(() => _subtasksExpanded = true);
      await revealSubtasksSequentially(
        subtasks: additions,
        canContinue: () => mounted && _title.text.trim() == title,
        onReveal: (subtask) => setState(() => _subtasks.add(subtask)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _generatingSubtasks = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(
      premiumMembershipProvider.select(
        (membership) => membership.valueOrNull?.hasActivePremium == true,
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n(widget.screenTitle)),
        leading: IconButton(
          tooltip: context.l10n('Kapat'),
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
            label: Text(
              _saving
                  ? context.l10n('Kaydediliyor...')
                  : context.l10n('Görevi kaydet'),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          18,
          14,
          18,
          MediaQuery.viewInsetsOf(context).bottom + 32,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.palette.primaryMuted,
              borderRadius: BorderRadius.circular(FlorienRadius.lg),
              border: Border.all(
                color: context.palette.border,
                width: FlorienBorders.thin,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.screenTitle == 'Görev ekle'
                            ? context.l10n('Bugün için küçük bir adım')
                            : context.l10n('Görevini düzenle'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('daily-detail-title'),
                  controller: _title,
                  onChanged: _onTitleChanged,
                  textCapitalization: TextCapitalization.sentences,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: context.l10n('Ne yapmak istersin?'),
                    filled: true,
                    fillColor: context.palette.surface,
                    prefixIcon: ValueListenableBuilder(
                      valueListenable: _taskIcon,
                      builder: (_, result, _) =>
                          TaskIconBadge.forResult(result, size: 34),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Column(
              children: [
                _DetailTile(
                  icon: _isTimed
                      ? Icons.edit_calendar_outlined
                      : _periodIcon(_period),
                  label: context.l10n('Günün saati'),
                  value: _isTimed
                      ? context.l10n('Zamanında')
                      : _periodLabel(_period),
                  onTap: () async {
                    final value = await _showDayPeriodPicker(
                      context,
                      _period,
                      isTimed: _isTimed,
                      isPremium: isPremium,
                    );
                    if (value == null || !context.mounted) return;
                    if (value.isTimed &&
                        !await requirePremiumAccess(
                          context,
                          ref,
                          PremiumFeature.exactTaskTime,
                        )) {
                      return;
                    }
                    if (!mounted) return;
                    setState(() {
                      _isTimed = value.isTimed;
                      _period = value.period;
                    });
                  },
                ),
                if (_isTimed) ...[
                  const Divider(height: 1),
                  _TimedDateTimeTile(
                    label: context.l10n('Başlar'),
                    value: _startsAt,
                    dateKey: const ValueKey('daily-start-date'),
                    timeKey: const ValueKey('daily-start-time'),
                    onPickDate: () => _pickTimedDate(start: true),
                    onPickTime: () => _pickTimedTime(start: true),
                  ),
                  const Divider(height: 1),
                  _TimedDateTimeTile(
                    label: context.l10n('Biter'),
                    value: _endsAt,
                    dateKey: const ValueKey('daily-end-date'),
                    timeKey: const ValueKey('daily-end-time'),
                    onPickDate: () => _pickTimedDate(start: false),
                    onPickTime: () => _pickTimedTime(start: false),
                  ),
                ] else ...[
                  const Divider(height: 1),
                  _DetailTile(
                    icon: Icons.calendar_today_outlined,
                    label: context.l10n('Tarih'),
                    value: _shortDate(_date),
                    onTap: _pickDate,
                  ),
                  const Divider(height: 1),
                  _DetailTile(
                    icon: Icons.timer_outlined,
                    label: context.l10n('Süre'),
                    value: _durationLabel(_duration),
                    onTap: _pickDuration,
                  ),
                ],
                const Divider(height: 1),
                _DetailTile(
                  icon: Icons.repeat_rounded,
                  label: context.l10n('Yinelemek'),
                  value: _recurrenceLabel(_recurrence),
                  onTap: () async {
                    final value = await _showRecurrencePicker(
                      context,
                      _recurrence,
                    );
                    if (value != null && mounted) {
                      setState(() => _recurrence = value);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FlorienFormSectionHeader(
                    key: const ValueKey('daily-subtasks-section-toggle'),
                    icon: Icons.account_tree_outlined,
                    title: context.l10n('Alt görevler'),
                    subtitle: _subtasks.isEmpty
                        ? context.l10n(
                            'Küçük adımlar başlatmayı kolaylaştırır.',
                          )
                        : context.l10n(
                            'Adımları dilediğin sırayla düzenleyebilirsin.',
                          ),
                    color: FlorienColors.aiLavender,
                    trailing: _title.text.trim().isNotEmpty && _subtasks.isEmpty
                        ? IconButton.filledTonal(
                            key: const ValueKey('daily-ai-subtasks-button'),
                            tooltip: context.l10n('AI ile alt görev oluştur'),
                            onPressed: _generatingSubtasks
                                ? null
                                : _generateSubtasks,
                            icon: _generatingSubtasks
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    isPremium
                                        ? Icons.auto_awesome_rounded
                                        : Icons.lock_outline_rounded,
                                  ),
                          )
                        : null,
                    expanded: _subtasksExpanded,
                    onTap: () =>
                        setState(() => _subtasksExpanded = !_subtasksExpanded),
                  ),
                  if (_subtasksExpanded) ...[
                    const SizedBox(height: 12),
                    for (var index = 0; index < _subtasks.length; index++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: TaskIconBadge.forTask(
                          icon: TaskIcons.nameForTitle(_subtasks[index]),
                          size: 28,
                        ),
                        title: Text(_subtasks[index]),
                        trailing: IconButton(
                          onPressed: () {
                            setState(() => _subtasks.removeAt(index));
                          },
                          icon: const Icon(Icons.close_rounded, size: 18),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('daily-detail-subtask-input'),
                            controller: _subtask,
                            onSubmitted: (_) => _addSubtask(),
                            decoration: InputDecoration(
                              hintText: context.l10n('Yeni alt görev'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: () => _addSubtask(),
                          icon: Icon(
                            isPremium
                                ? Icons.add_rounded
                                : Icons.lock_outline_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FlorienFormSectionHeader(
                    key: const ValueKey('daily-notes-section-toggle'),
                    icon: Icons.notes_rounded,
                    title: context.l10n('Notlar'),
                    subtitle: context.l10n('Hatırlamak istediğin ayrıntılar.'),
                    color: FlorienColors.softPink,
                    expanded: _notesExpanded,
                    onTap: () =>
                        setState(() => _notesExpanded = !_notesExpanded),
                  ),
                  if (_notesExpanded) ...[
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('daily-detail-notes'),
                      controller: _notes,
                      minLines: 4,
                      maxLines: 8,
                      decoration: InputDecoration(
                        hintText: context.l10n('Notlarını buraya yaz…'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (value != null && mounted) {
      setState(() {
        _date = _dateOnly(value);
      });
    }
  }

  Future<void> _pickDuration() async {
    final value = await showFlorienDurationPicker(
      context: context,
      selected: _duration,
    );
    if (value != null && mounted) setState(() => _duration = value);
  }

  Future<void> _pickTimedDate({required bool start}) async {
    if (!await requirePremiumAccess(
      context,
      ref,
      PremiumFeature.exactTaskTime,
    )) {
      return;
    }
    if (!mounted) return;
    final current = start ? _startsAt : _endsAt;
    final value = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (value == null || !mounted) return;
    final updated = DateTime(
      value.year,
      value.month,
      value.day,
      current.hour,
      current.minute,
    );
    setState(() {
      if (start) {
        _startsAt = updated;
        _date = _dateOnly(updated);
        if (!_endsAt.isAfter(_startsAt)) {
          _endsAt = _startsAt.add(const Duration(minutes: 30));
        }
      } else {
        _endsAt = updated.isAfter(_startsAt)
            ? updated
            : _startsAt.add(const Duration(minutes: 5));
      }
    });
  }

  Future<void> _pickTimedTime({required bool start}) async {
    if (!await requirePremiumAccess(
      context,
      ref,
      PremiumFeature.exactTaskTime,
    )) {
      return;
    }
    if (!mounted) return;
    final current = start ? _startsAt : _endsAt;
    final value = await _showFiveMinuteTimePicker(
      context,
      TimeOfDay.fromDateTime(current),
    );
    if (value == null || !mounted) return;
    final updated = DateTime(
      current.year,
      current.month,
      current.day,
      value.hour,
      value.minute,
    );
    setState(() {
      if (start) {
        _startsAt = updated;
        _date = _dateOnly(updated);
        if (!_endsAt.isAfter(_startsAt)) {
          _endsAt = _startsAt.add(const Duration(minutes: 30));
        }
      } else {
        _endsAt = updated.isAfter(_startsAt)
            ? updated
            : _startsAt.add(const Duration(minutes: 5));
      }
    });
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.palette.aiSurface,
                borderRadius: BorderRadius.circular(FlorienRadius.sm),
              ),
              child: Icon(icon, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: context.palette.primaryMuted,
                borderRadius: BorderRadius.circular(FlorienRadius.pill),
                border: Border.all(
                  color: context.palette.border,
                  width: FlorienBorders.thin,
                ),
              ),
              child: Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

class _TimedDateTimeTile extends StatelessWidget {
  const _TimedDateTimeTile({
    required this.label,
    required this.value,
    required this.dateKey,
    required this.timeKey,
    required this.onPickDate,
    required this.onPickTime,
  });

  final String label;
  final DateTime value;
  final Key dateKey;
  final Key timeKey;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
        _DateTimePill(
          key: dateKey,
          icon: Icons.calendar_today_outlined,
          label: _shortDate(value),
          onTap: onPickDate,
        ),
        const SizedBox(width: 8),
        _DateTimePill(
          key: timeKey,
          label: _formatAlarmTime(TimeOfDay.fromDateTime(value)),
          onTap: onPickTime,
        ),
      ],
    ),
  );
}

class _DateTimePill extends StatelessWidget {
  const _DateTimePill({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Material(
    color: context.palette.surfaceMuted,
    borderRadius: BorderRadius.circular(99),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17),
              const SizedBox(width: 6),
            ],
            Text(label),
          ],
        ),
      ),
    ),
  );
}

class _DailyPeriodSelection {
  const _DailyPeriodSelection({
    required this.period,
    this.isTimed = false,
    this.isTodo = false,
  });

  final DayPeriod period;
  final bool isTimed;
  final bool isTodo;
}

class _DayPeriodPicker extends StatelessWidget {
  const _DayPeriodPicker({
    required this.selected,
    required this.isTimed,
    required this.isPremium,
  });

  final DayPeriod selected;
  final bool isTimed;
  final bool isPremium;

  @override
  Widget build(BuildContext context) => FlorienSoftCard(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
    child: Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
            child: Text(
              context.l10n('Günün saati'),
              style: TextStyle(
                color: context.palette.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          for (final period in DayPeriod.values)
            ListTile(
              leading: SizedBox(
                width: 54,
                child: Row(
                  children: [
                    if (period == selected)
                      const Icon(Icons.check_rounded, size: 20)
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: 8),
                    Icon(_periodIcon(period), size: 21),
                  ],
                ),
              ),
              title: Text(_periodLabel(period)),
              onTap: () => Navigator.pop(
                context,
                _DailyPeriodSelection(period: period, isTimed: false),
              ),
            ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 3, 12, 3),
            child: Text(
              context.l10n('Etkinlik'),
              style: TextStyle(
                color: context.palette.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ListTile(
            key: const ValueKey('daily-timed-choice'),
            leading: SizedBox(
              width: 54,
              child: Row(
                children: [
                  if (isTimed)
                    const Icon(Icons.check_rounded, size: 20)
                  else
                    const SizedBox(width: 20),
                  const SizedBox(width: 8),
                  const Icon(Icons.edit_calendar_outlined, size: 21),
                ],
              ),
            ),
            title: Text(context.l10n('Zamanında')),
            trailing: isPremium
                ? null
                : const Icon(Icons.lock_outline_rounded, size: 20),
            onTap: () => Navigator.pop(
              context,
              _DailyPeriodSelection(period: selected, isTimed: true),
            ),
          ),
          const Divider(),
          ListTile(
            key: const ValueKey('daily-todo-choice'),
            leading: Icon(Icons.move_to_inbox_outlined),
            title: Text(context.l10n('Yapılacaklar')),
            onTap: () => Navigator.pop(
              context,
              _DailyPeriodSelection(period: selected, isTodo: true),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<_DailyPeriodSelection?> _showDayPeriodPicker(
  BuildContext context,
  DayPeriod selected, {
  bool isTimed = false,
  required bool isPremium,
}) => showFlorienSoftDialog<_DailyPeriodSelection>(
  context: context,
  maxWidth: 360,
  builder: (_) => _DayPeriodPicker(
    selected: selected,
    isTimed: isTimed,
    isPremium: isPremium,
  ),
);

Future<TimeOfDay?> _showFiveMinuteTimePicker(
  BuildContext context,
  TimeOfDay initial,
) {
  final initialDate = _ceilToFiveMinutes(
    DateTime(2020, 1, 1, initial.hour, initial.minute),
  );
  var selected = initialDate;
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    builder: (context) => SafeArea(
      top: false,
      child: SizedBox(
        height: 300,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.l10n('Vazgeç')),
                  ),
                  const Spacer(),
                  Text(
                    context.l10n('Saat seç'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      TimeOfDay.fromDateTime(selected),
                    ),
                    child: Text(context.l10n('Bitti')),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                key: const ValueKey('daily-five-minute-picker'),
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                minuteInterval: 5,
                initialDateTime: initialDate,
                onDateTimeChanged: (value) => selected = value,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<RecurrenceType?> _showRecurrencePicker(
  BuildContext context,
  RecurrenceType selected,
) => showModalBottomSheet<RecurrenceType>(
  context: context,
  builder: (context) => SafeArea(
    child: ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Text(
            'Yinelemek',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        for (final value in const [
          RecurrenceType.none,
          RecurrenceType.daily,
          RecurrenceType.weekly,
          RecurrenceType.monthly,
        ])
          ListTile(
            leading: Icon(
              value == RecurrenceType.none
                  ? Icons.repeat_on_outlined
                  : Icons.repeat_rounded,
            ),
            title: Text(_recurrenceLabel(value)),
            trailing: value == selected
                ? const Icon(Icons.check_rounded)
                : null,
            onTap: () => Navigator.pop(context, value),
          ),
      ],
    ),
  ),
);

enum _RecurrenceScopePrompt { update, delete, move }

Future<RecurrenceScope?> _showRecurrenceScopeSheet(
  BuildContext context, {
  _RecurrenceScopePrompt prompt = _RecurrenceScopePrompt.update,
}) => showFlorienBottomSheet<RecurrenceScope>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _RecurrenceScopeSheet(prompt: prompt),
);

class _RecurrenceScopeSheet extends StatelessWidget {
  const _RecurrenceScopeSheet({required this.prompt});

  final _RecurrenceScopePrompt prompt;

  @override
  Widget build(BuildContext context) {
    final deleting = prompt == _RecurrenceScopePrompt.delete;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: context.palette.border)),
        ),
        child: ListView(
          key: const ValueKey('daily-recurrence-scope-sheet'),
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: context.palette.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Text(
                context.l10n(switch (prompt) {
                  _RecurrenceScopePrompt.delete => 'Görevi sil',
                  _RecurrenceScopePrompt.move => 'Görevi taşı',
                  _RecurrenceScopePrompt.update => 'Görevi düzenle',
                }),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            for (final value in RecurrenceScope.values)
              _DailyTaskActionTile(
                icon: switch (prompt) {
                  _RecurrenceScopePrompt.delete => Icons.delete_outline_rounded,
                  _RecurrenceScopePrompt.move => Icons.swap_vert_rounded,
                  _RecurrenceScopePrompt.update => Icons.edit_outlined,
                },
                label: switch (prompt) {
                  _RecurrenceScopePrompt.delete => _recurrenceScopeDeleteLabel(
                    value,
                  ),
                  _RecurrenceScopePrompt.move => _recurrenceScopeMoveLabel(
                    value,
                  ),
                  _RecurrenceScopePrompt.update => _recurrenceScopeUpdateLabel(
                    value,
                  ),
                },
                destructive: deleting,
                onTap: () => Navigator.pop(context, value),
              ),
            _DailyTaskActionTile(
              icon: Icons.close_rounded,
              label: context.l10n('Vazgeç'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

String _recurrenceScopeUpdateLabel(RecurrenceScope value) => switch (value) {
  RecurrenceScope.thisOccurrence => ActiveLanguage.s('Bunu güncelle'),
  RecurrenceScope.future => ActiveLanguage.s('Gelecektekileri güncelle'),
  RecurrenceScope.all => ActiveLanguage.s('Hepsini güncelle'),
};

String _recurrenceScopeDeleteLabel(RecurrenceScope value) => switch (value) {
  RecurrenceScope.thisOccurrence => ActiveLanguage.s('Bunu sil'),
  RecurrenceScope.future => ActiveLanguage.s('Gelecektekileri sil'),
  RecurrenceScope.all => ActiveLanguage.s('Hepsini sil'),
};

String _recurrenceScopeMoveLabel(RecurrenceScope value) => switch (value) {
  RecurrenceScope.thisOccurrence => ActiveLanguage.s('Bunu taşı'),
  RecurrenceScope.future => ActiveLanguage.s('Gelecektekileri taşı'),
  RecurrenceScope.all => ActiveLanguage.s('Hepsini taşı'),
};

class _RecurrenceScopeCancelled implements Exception {
  const _RecurrenceScopeCancelled();
}

class _DailyTaskDraft {
  const _DailyTaskDraft({
    required this.date,
    required this.period,
    this.title = '',
    this.description = '',
    this.durationMinutes = 15,
    this.isTimed = false,
    this.startsAt,
    this.endsAt,
    this.recurrence = const RecurrenceSelection(),
    this.subtasks = const [],
    this.presetSubtasks = const [],
    this.icon = TaskIcons.defaultName,
    this.color = '#4F52B2',
    this.openDetails = false,
    this.openTodo = false,
  });

  final DateTime date;
  final DayPeriod period;
  final String title;
  final String description;
  final int durationMinutes;
  final bool isTimed;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final RecurrenceSelection recurrence;
  final List<String> subtasks;
  final List<String> presetSubtasks;
  final String icon;
  final String color;
  final bool openDetails;
  final bool openTodo;

  _DailyTaskDraft copyWith({
    DateTime? date,
    DayPeriod? period,
    String? title,
    String? description,
    int? durationMinutes,
    bool? isTimed,
    DateTime? startsAt,
    DateTime? endsAt,
    bool clearTimedRange = false,
    RecurrenceSelection? recurrence,
    List<String>? subtasks,
    List<String>? presetSubtasks,
    String? icon,
    String? color,
    bool? openDetails,
    bool? openTodo,
  }) => _DailyTaskDraft(
    date: date ?? this.date,
    period: period ?? this.period,
    title: title ?? this.title,
    description: description ?? this.description,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    isTimed: isTimed ?? this.isTimed,
    startsAt: clearTimedRange ? null : (startsAt ?? this.startsAt),
    endsAt: clearTimedRange ? null : (endsAt ?? this.endsAt),
    recurrence: recurrence ?? this.recurrence,
    subtasks: subtasks ?? this.subtasks,
    presetSubtasks: presetSubtasks ?? this.presetSubtasks,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    openDetails: openDetails ?? this.openDetails,
    openTodo: openTodo ?? this.openTodo,
  );
}

Future<void> _createDailyTask(WidgetRef ref, _DailyTaskDraft draft) async {
  final scheduledAt = draft.isTimed
      ? draft.startsAt!
      : _scheduledAt(draft.date, draft.period);
  final durationMinutes = draft.isTimed
      ? draft.endsAt!.difference(draft.startsAt!).inMinutes
      : draft.durationMinutes;
  final task = await ref
      .read(taskRepositoryProvider)
      .createTask(
        title: draft.title,
        description: draft.description.trim().isEmpty
            ? null
            : draft.description,
        durationMinutes: durationMinutes,
        scheduledAt: scheduledAt,
        isTimed: draft.isTimed,
        isInbox: false,
        recurrence: draft.recurrence,
        icon: draft.icon,
        color: draft.color,
        dayPeriod: draft.period,
      );
  if (draft.subtasks.isNotEmpty) {
    await ref
        .read(taskRepositoryProvider)
        .addSubtasksToTask(
          parentId: task.id,
          subtasks: draft.subtasks
              .map(
                (title) =>
                    (title: title, durationMinutes: 5, color: task.color),
              )
              .toList(),
        );
  }
  try {
    await ref.read(notificationReconcileProvider)();
  } catch (error) {
    debugPrint('Created daily task notifications failed: $error');
  }
  ref.invalidate(dailyTimelineProvider);
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: context.palette.surface,
    shape: StadiumBorder(side: BorderSide(color: context.palette.border)),
    child: InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 7),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    ),
  );
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.emphasized = false,
    this.compact = false,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;
  final bool emphasized;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 34.0 : 40.0;
    final palette = context.palette;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: emphasized ? palette.primaryMuted : palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlorienRadius.sm),
          side: BorderSide(
            color: palette.border.withValues(alpha: emphasized ? 0.18 : 1),
            width: FlorienBorders.thin,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FlorienRadius.sm),
          child: SizedBox.square(
            dimension: size,
            child: Icon(
              icon,
              size: compact ? 18 : 21,
              color: emphasized ? palette.background : palette.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.date,
    required this.selected,
    required this.today,
    required this.onTap,
  });
  final DateTime date;
  final bool selected;
  final bool today;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(date),
          borderRadius: BorderRadius.circular(FlorienRadius.md),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? context.palette.primaryMuted
                  : today
                  ? context.palette.accent.withValues(
                      alpha: isDark ? 0.18 : 0.14,
                    )
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(FlorienRadius.md),
              border: selected || today
                  ? Border.all(
                      color: selected
                          ? context.palette.border.withValues(alpha: 0.18)
                          : context.palette.accent.withValues(alpha: 0.5),
                      width: FlorienBorders.thin,
                    )
                  : null,
            ),
            child: Column(
              children: [
                Text(
                  _weekdayShort(date),
                  style: TextStyle(
                    color: selected
                        ? FlorienColors.onPrimary
                        : today
                        ? context.palette.textPrimary.withValues(alpha: 0.82)
                        : context.palette.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${date.day}',
                  style: TextStyle(
                    color: selected
                        ? FlorienColors.onPrimary
                        : context.palette.textPrimary,
                    fontSize: 20,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.tooltip,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip ?? label,
    child: Material(
      color: context.palette.surfaceMuted,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: label.isEmpty ? 8 : 8,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 54),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime nextDailyAlarmSlot(DateTime now) {
  final local = now.toLocal();
  if (local.minute < 30) {
    return DateTime(local.year, local.month, local.day, local.hour, 30);
  }
  final nextHour = DateTime(
    local.year,
    local.month,
    local.day,
    local.hour,
  ).add(const Duration(hours: 1));
  return nextHour;
}

/// Default start for a timed plan: next :00 or :30 from [now], mapped onto
/// [date] when the plan is on another day.
DateTime defaultDailyAlarmAt(DateTime date, [DateTime? now]) {
  final current = (now ?? DateTime.now()).toLocal();
  final nextSlot = nextDailyAlarmSlot(current);
  return _sameDate(date, current)
      ? nextSlot
      : DateTime(
          date.year,
          date.month,
          date.day,
          nextSlot.hour,
          nextSlot.minute,
        );
}

(DateTime, DateTime) _defaultTimedRange(DateTime date) {
  final start = defaultDailyAlarmAt(date);
  return (start, start.add(const Duration(minutes: 30)));
}

DateTime _ceilToFiveMinutes(DateTime value) {
  final hasPartialMinute = value.second != 0 || value.millisecond != 0;
  var minutesToAdd = (5 - value.minute % 5) % 5;
  if (hasPartialMinute && minutesToAdd == 0) minutesToAdd = 5;
  final rounded = value.add(Duration(minutes: minutesToAdd));
  return DateTime(
    rounded.year,
    rounded.month,
    rounded.day,
    rounded.hour,
    rounded.minute,
  );
}

String _formatAlarmTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

String _clockLabel(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

bool _sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateTime _scheduledAt(DateTime date, DayPeriod period) {
  final hour = switch (period) {
    DayPeriod.anytime => 12,
    DayPeriod.morning => 8,
    DayPeriod.daytime => 13,
    DayPeriod.evening => 19,
  };
  return DateTime(date.year, date.month, date.day, hour);
}

String _periodLabel(DayPeriod period) => switch (period) {
  DayPeriod.anytime => ActiveLanguage.s('Her zaman'),
  DayPeriod.morning => ActiveLanguage.s('Sabah'),
  DayPeriod.daytime => ActiveLanguage.s('Gündüz'),
  DayPeriod.evening => ActiveLanguage.s('Akşam'),
};

String _periodHint(DayPeriod period) => switch (period) {
  DayPeriod.anytime => ActiveLanguage.s('Bu gruba görev ekle'),
  DayPeriod.morning => ActiveLanguage.s('Sabah için görev ekle'),
  DayPeriod.daytime => ActiveLanguage.s('Gündüz için görev ekle'),
  DayPeriod.evening => ActiveLanguage.s('Akşam için görev ekle'),
};

IconData _periodIcon(DayPeriod period) => switch (period) {
  DayPeriod.anytime => Icons.schedule_rounded,
  DayPeriod.morning => Icons.wb_twilight_rounded,
  DayPeriod.daytime => Icons.light_mode_outlined,
  DayPeriod.evening => Icons.nightlight_round,
};

Color _periodColor(DayPeriod period) => switch (period) {
  DayPeriod.anytime => const Color(0xFF6D6D78),
  DayPeriod.morning => const Color(0xFFB39835),
  DayPeriod.daytime => const Color(0xFF9A5A82),
  DayPeriod.evening => const Color(0xFF655A91),
};

String _recurrenceLabel(RecurrenceType value) => switch (value) {
  RecurrenceType.none => ActiveLanguage.s('Hayır'),
  RecurrenceType.daily => ActiveLanguage.s('Her gün'),
  RecurrenceType.weekly => ActiveLanguage.s('Her hafta'),
  RecurrenceType.monthly => ActiveLanguage.s('Her ay'),
  RecurrenceType.yearly => ActiveLanguage.s('Her yıl'),
  RecurrenceType.custom => ActiveLanguage.s('Özel'),
};

String _durationLabel(int minutes) => switch (minutes) {
  60 => ActiveLanguage.s('1 saat'),
  90 => ActiveLanguage.s('1,5 saat'),
  120 => ActiveLanguage.s('2 saat'),
  _ => ActiveLanguage.s('{minutes} dk', {'minutes': '$minutes'}),
};

String _shortDate(DateTime date) =>
    '${date.day} ${_monthShortLabel(date)} ${date.year}';

String _weekdayName(DateTime date) => [
  ActiveLanguage.s('Pazartesi'),
  ActiveLanguage.s('Salı'),
  ActiveLanguage.s('Çarşamba'),
  ActiveLanguage.s('Perşembe'),
  ActiveLanguage.s('Cuma'),
  ActiveLanguage.s('Cumartesi'),
  ActiveLanguage.s('Pazar'),
][date.weekday - 1];

String _weekdayShortLabel(DateTime date) => [
  ActiveLanguage.s('Pzt'),
  ActiveLanguage.s('Sal'),
  ActiveLanguage.s('Çar'),
  ActiveLanguage.s('Per'),
  ActiveLanguage.s('Cum'),
  ActiveLanguage.s('Cmt'),
  ActiveLanguage.s('Paz'),
][date.weekday - 1];

String _weekdayShort(DateTime date) {
  final label = _weekdayShortLabel(date);
  if (label.isEmpty) return '';
  return String.fromCharCodes(label.runes.take(1));
}

String _monthShortLabel(DateTime date) => [
  ActiveLanguage.s('Oca'),
  ActiveLanguage.s('Şub'),
  ActiveLanguage.s('Mar'),
  ActiveLanguage.s('Nis'),
  ActiveLanguage.s('May'),
  ActiveLanguage.s('Haz'),
  ActiveLanguage.s('Tem'),
  ActiveLanguage.s('Ağu'),
  ActiveLanguage.s('Eyl'),
  ActiveLanguage.s('Eki'),
  ActiveLanguage.s('Kas'),
  ActiveLanguage.s('Ara'),
][date.month - 1];

String _monthName(int month) => [
  ActiveLanguage.s('Ocak'),
  ActiveLanguage.s('Şubat'),
  ActiveLanguage.s('Mart'),
  ActiveLanguage.s('Nisan'),
  ActiveLanguage.s('Mayıs'),
  ActiveLanguage.s('Haziran'),
  ActiveLanguage.s('Temmuz'),
  ActiveLanguage.s('Ağustos'),
  ActiveLanguage.s('Eylül'),
  ActiveLanguage.s('Ekim'),
  ActiveLanguage.s('Kasım'),
  ActiveLanguage.s('Aralık'),
][month - 1];
