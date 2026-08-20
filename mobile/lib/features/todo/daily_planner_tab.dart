import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' hide DayPeriod;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/data/routine_catalog.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/models/recurrence.dart';
import 'package:florien/core/models/task_usage_summary.dart';
import 'package:florien/core/services/speech_input_service.dart';
import 'package:florien/core/services/task_alarm_service.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/utils/subtask_sequence.dart';
import 'package:florien/core/utils/task_icons.dart';
import 'package:florien/core/widgets/delayed_scroll_chrome.dart';
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
import 'package:florien/features/todo/todo_list_tab.dart';

typedef DailyTaskGroupMover =
    Future<void> Function(TaskModel task, DayPeriod? period, DateTime date);
typedef DailyTaskRescheduler =
    Future<void> Function(TaskModel task, DateTime date);
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
    required this.alarmAt,
    required this.subtasks,
    required this.icon,
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
  final DateTime? alarmAt;
  final List<String> subtasks;
  final String icon;
}

typedef DailyTaskUpdater =
    Future<void> Function(TaskModel task, DailyTaskEditInput input);

final dailyTaskUpdaterProvider = Provider<DailyTaskUpdater>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  final alarms = ref.watch(taskAlarmServiceProvider);
  return (task, input) async {
    final previousDate = _dateOnly(task.scheduledAt ?? input.date);
    final scheduledAt = input.isTimed
        ? input.startsAt!
        : _scheduledAt(input.date, input.period);
    final durationMinutes = input.isTimed
        ? input.endsAt!.difference(input.startsAt!).inMinutes
        : input.durationMinutes;
    await repository.updateTask(
      id: task.id,
      title: input.title,
      description: input.description.trim().isEmpty ? null : input.description,
      clearDescription: input.description.trim().isEmpty,
      icon: input.icon,
      durationMinutes: durationMinutes,
      scheduledAt: scheduledAt,
      alarmAt: input.alarmAt,
      clearAlarmAt: input.alarmAt == null,
      isTimed: input.isTimed,
      recurrence: input.recurrence,
      dayPeriod: input.period,
      isInbox: false,
    );
    await repository.replaceSubtasks(parentId: task.id, titles: input.subtasks);
    try {
      if (input.alarmAt == null) {
        await alarms.cancel(task.id);
      } else {
        final scheduled = await alarms.schedule(
          taskId: task.id,
          title: input.title,
          alarmAt: input.alarmAt!,
        );
        if (!scheduled) {
          debugPrint('Updated daily task alarm was not scheduled.');
        }
      }
    } catch (error) {
      debugPrint('Updated daily task alarm failed: $error');
      // Notification setup must not prevent the task update from completing.
    }
    ref.invalidate(dailyTimelineProvider(previousDate));
    ref.invalidate(dailyTimelineProvider(_dateOnly(input.date)));
  };
});

final dailyTaskGroupMoverProvider = Provider<DailyTaskGroupMover>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  return (task, period, date) async {
    if (period == null) {
      if (!task.isCompleted) await repository.completeTask(task.id);
    } else {
      if (task.isCompleted) await repository.uncompleteTask(task.id);
      if (task.dayPeriod != period || task.isCompleted) {
        await repository.updateTask(
          id: task.id,
          dayPeriod: period,
          scheduledAt: _scheduledAt(date, period),
        );
      }
    }
    ref.invalidate(dailyTimelineProvider(_dateOnly(date)));
  };
});

final dailyTaskReschedulerProvider = Provider<DailyTaskRescheduler>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  return (task, date) async {
    if (task.isCompleted) await repository.uncompleteTask(task.id);
    await repository.updateTask(
      id: task.id,
      scheduledAt: _scheduledAt(date, task.dayPeriod),
      dayPeriod: task.dayPeriod,
      isInbox: false,
    );
    final previousDate = task.scheduledAt;
    if (previousDate != null) {
      ref.invalidate(dailyTimelineProvider(_dateOnly(previousDate)));
    }
    ref.invalidate(dailyTimelineProvider(_dateOnly(date)));
  };
});

final dailyTaskCompleterProvider = Provider<DailyTaskCompleter>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  return (taskId) async {
    await repository.completeTask(taskId);
    ref.invalidate(inboxProvider);
    ref.invalidate(dailyTimelineProvider);
    return ref.read(manualCompletionSummaryProvider)(taskId);
  };
});

class DailyPlannerTab extends ConsumerStatefulWidget {
  const DailyPlannerTab({
    super.key,
    this.quickAddSignal = 0,
    this.scrollChromeEnabled = true,
    this.showPremiumUpsell = false,
    this.onPremiumUpsellPressed,
    this.onScrollChromeVisibilityChanged,
  });

  final int quickAddSignal;
  final bool scrollChromeEnabled;
  final bool showPremiumUpsell;
  final VoidCallback? onPremiumUpsellPressed;
  final ValueChanged<bool>? onScrollChromeVisibilityChanged;

  @override
  ConsumerState<DailyPlannerTab> createState() => _DailyPlannerTabState();
}

enum DailyPlannerGrouping { list, timeline }

class _DailyPlannerTabState extends ConsumerState<DailyPlannerTab> {
  late DateTime _selectedDate = _dateOnly(DateTime.now());
  final Set<DayPeriod> _collapsed = {};
  DailyPlannerGrouping _grouping = DailyPlannerGrouping.list;
  bool _scrollChromeVisible = true;

  @override
  void didUpdateWidget(covariant DailyPlannerTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollChromeEnabled && !widget.scrollChromeEnabled) {
      _scrollChromeVisible = true;
    }
    if (widget.quickAddSignal == oldWidget.quickAddSignal) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_showQuickAdd(DayPeriod.anytime));
    });
  }

  @override
  Widget build(BuildContext context) {
    final timeline = ref.watch(dailyTimelineProvider(_selectedDate));
    return SafeArea(
      child: DelayedScrollChrome(
        enabled: widget.scrollChromeEnabled,
        hideOffset: 120,
        onVisibilityChanged: _handleScrollChromeVisibility,
        child: RefreshIndicator(
          onRefresh: () async =>
              ref.refresh(dailyTimelineProvider(_selectedDate).future),
          child: timeline.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _DailyBody(
              selectedDate: _selectedDate,
              tasks: const [],
              collapsed: _collapsed,
              onSelectDate: _selectDate,
              onOpenDatePicker: _showDatePicker,
              onToggleSection: _toggleSection,
              onAdd: _showQuickAdd,
              onMoveTask: _moveTaskToGroup,
              grouping: _grouping,
              onGroupingChanged: _setGrouping,
              onRescheduleTasks: () => _showRescheduleReview(const []),
              onDiscoverRoutines: _showRoutineDiscovery,
              onShare: () => _showDailyShare(const []),
              showPremiumUpsell: widget.showPremiumUpsell,
              onPremiumUpsellPressed: widget.onPremiumUpsellPressed,
              scrollChromeVisible: _scrollChromeVisible,
            ),
            data: (value) => _DailyBody(
              selectedDate: _selectedDate,
              tasks: value.tasks,
              collapsed: _collapsed,
              onSelectDate: _selectDate,
              onOpenDatePicker: _showDatePicker,
              onToggleSection: _toggleSection,
              onAdd: _showQuickAdd,
              onMoveTask: _moveTaskToGroup,
              grouping: _grouping,
              onGroupingChanged: _setGrouping,
              onRescheduleTasks: () => _showRescheduleReview(value.tasks),
              onDiscoverRoutines: _showRoutineDiscovery,
              onShare: () => _showDailyShare(value.tasks),
              showPremiumUpsell: widget.showPremiumUpsell,
              onPremiumUpsellPressed: widget.onPremiumUpsellPressed,
              scrollChromeVisible: _scrollChromeVisible,
            ),
          ),
        ),
      ),
    );
  }

  void _handleScrollChromeVisibility(bool visible) {
    if (_scrollChromeVisible == visible) return;
    setState(() => _scrollChromeVisible = visible);
    widget.onScrollChromeVisibilityChanged?.call(visible);
  }

  void _selectDate(DateTime value) {
    setState(() => _selectedDate = _dateOnly(value));
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
    }
  }

  Future<void> _moveTaskToGroup(TaskModel task, DayPeriod? period) async {
    await ref.read(dailyTaskGroupMoverProvider)(task, period, _selectedDate);
  }

  Future<void> _showRescheduleReview(List<TaskModel> tasks) async {
    await pushFlorienOverlayRoute<void>(
      context: context,
      builder: (_) => DailyRescheduleReviewFlow(
        selectedDate: _selectedDate,
        tasks: tasks,
        onReschedule: (task, date) =>
            ref.read(dailyTaskReschedulerProvider)(task, date),
      ),
    );
    if (mounted) ref.invalidate(dailyTimelineProvider(_selectedDate));
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
    required this.onRescheduleTasks,
    required this.onDiscoverRoutines,
    required this.onShare,
    required this.showPremiumUpsell,
    required this.onPremiumUpsellPressed,
    required this.scrollChromeVisible,
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
  final VoidCallback onRescheduleTasks;
  final Future<void> Function() onDiscoverRoutines;
  final VoidCallback onShare;
  final bool showPremiumUpsell;
  final VoidCallback? onPremiumUpsellPressed;
  final bool scrollChromeVisible;

  @override
  Widget build(BuildContext context) {
    final activeTasks = tasks.where((task) => !task.isCompleted).toList();
    final completedTasks = tasks.where((task) => task.isCompleted).toList();
    return CustomScrollView(
      key: const ValueKey('daily-planner-page'),
      paintOrder: SliverPaintOrder.firstIsTop,
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      slivers: [
        SliverAppBar(
          key: const ValueKey('daily-floating-date-header'),
          primary: false,
          automaticallyImplyLeading: false,
          floating: true,
          snap: false,
          pinned: true,
          toolbarHeight: 0,
          collapsedHeight: 64,
          expandedHeight: 232,
          clipBehavior: Clip.hardEdge,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: context.palette.background,
          surfaceTintColor: Colors.transparent,
          flexibleSpace: ColoredBox(
            color: context.palette.background,
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                layoutBuilder: (currentChild, previousChildren) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previousChildren, ?currentChild],
                ),
                child: scrollChromeVisible
                    ? OverflowBox(
                        key: const ValueKey('daily-scroll-chrome-header'),
                        alignment: Alignment.topCenter,
                        minHeight: 232,
                        maxHeight: 232,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                          child: _DailyHeader(
                            selectedDate: selectedDate,
                            onSelectDate: onSelectDate,
                            onOpenDatePicker: onOpenDatePicker,
                            onAdd: () => onAdd(DayPeriod.anytime),
                            grouping: grouping,
                            onGroupingChanged: onGroupingChanged,
                            onRescheduleTasks: onRescheduleTasks,
                            onDiscoverRoutines: onDiscoverRoutines,
                            onShare: onShare,
                            showPremiumUpsell: showPremiumUpsell,
                            onPremiumUpsellPressed: onPremiumUpsellPressed,
                          ),
                        ),
                      )
                    : Padding(
                        key: const ValueKey('daily-focused-header'),
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
                        child: _DailyFocusedHeader(
                          selectedDate: selectedDate,
                          onAdd: () => onAdd(DayPeriod.anytime),
                        ),
                      ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 20),
              if (grouping == DailyPlannerGrouping.list)
                _DailyListSections(
                  key: const ValueKey('daily-list-view'),
                  tasks: activeTasks,
                  selectedDate: selectedDate,
                  collapsed: collapsed,
                  onToggleSection: onToggleSection,
                  onAdd: onAdd,
                  onMoveTask: onMoveTask,
                )
              else
                _DailyTimelineSections(
                  key: const ValueKey('daily-timeline-view'),
                  tasks: activeTasks,
                  selectedDate: selectedDate,
                  onAdd: () => onAdd(DayPeriod.anytime),
                ),
              if (completedTasks.isNotEmpty)
                _DailyCompletedSection(
                  tasks: completedTasks,
                  selectedDate: selectedDate,
                  onTaskDropped: (task) => onMoveTask(task, null),
                ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _DailyFocusedHeader extends StatelessWidget {
  const _DailyFocusedHeader({required this.selectedDate, required this.onAdd});

  final DateTime selectedDate;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          _focusedDateLabel(selectedDate),
          key: const ValueKey('daily-focused-date'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      _SquareButton(
        key: const ValueKey('daily-focused-add'),
        tooltip: 'Günlük görev ekle',
        icon: Icons.add_rounded,
        emphasized: true,
        onTap: onAdd,
      ),
    ],
  );
}

class _DailyHeader extends StatelessWidget {
  const _DailyHeader({
    required this.selectedDate,
    required this.onSelectDate,
    required this.onOpenDatePicker,
    required this.onAdd,
    required this.grouping,
    required this.onGroupingChanged,
    required this.onRescheduleTasks,
    required this.onDiscoverRoutines,
    required this.onShare,
    required this.showPremiumUpsell,
    required this.onPremiumUpsellPressed,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onOpenDatePicker;
  final VoidCallback onAdd;
  final DailyPlannerGrouping grouping;
  final ValueChanged<DailyPlannerGrouping> onGroupingChanged;
  final VoidCallback onRescheduleTasks;
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
            _HeaderButton(
              key: ValueKey(
                isToday ? 'daily-open-date-picker' : 'daily-return-today',
              ),
              label: isToday ? 'Tarih seç' : 'Bugüne dön',
              icon: isToday
                  ? Icons.calendar_month_outlined
                  : Icons.today_rounded,
              onTap: isToday ? onOpenDatePicker : () => onSelectDate(today),
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
              tooltip: 'Günü paylaş',
              icon: Icons.ios_share_rounded,
              onTap: onShare,
            ),
            const SizedBox(width: 6),
            _SquareButton(
              tooltip: 'Günlük seçenekleri',
              icon: Icons.more_horiz_rounded,
              onTap: () => _showDailyOptions(
                context,
                grouping: grouping,
                onGroupingChanged: onGroupingChanged,
                onRescheduleTasks: onRescheduleTasks,
                onDiscoverRoutines: onDiscoverRoutines,
              ),
            ),
            const SizedBox(width: 6),
            _SquareButton(
              key: const ValueKey('daily-top-add'),
              tooltip: 'Günlük görev ekle',
              icon: Icons.add_rounded,
              emphasized: true,
              onTap: onAdd,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Semantics(
          button: true,
          label: 'Tarih seç',
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
      ],
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
                  tooltip: 'Kapat',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
                Expanded(
                  child: Text(
                    'Tarihe git',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Seçilen tarihe git',
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
                label: 'Bugüne dön',
                onTap: () => Navigator.pop(context, today),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _showDailyOptions(
  BuildContext context, {
  required DailyPlannerGrouping grouping,
  required ValueChanged<DailyPlannerGrouping> onGroupingChanged,
  required VoidCallback onRescheduleTasks,
  required Future<void> Function() onDiscoverRoutines,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Günlük seçeneklerini kapat',
  barrierColor: Colors.black.withValues(alpha: .24),
  transitionDuration: const Duration(milliseconds: 180),
  pageBuilder: (context, _, _) => _DailyOptionsOverlay(
    grouping: grouping,
    onGroupingChanged: onGroupingChanged,
    onRescheduleTasks: onRescheduleTasks,
    onDiscoverRoutines: onDiscoverRoutines,
  ),
  transitionBuilder: (context, animation, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: child,
  ),
);

class _DailyOptionsOverlay extends StatefulWidget {
  const _DailyOptionsOverlay({
    required this.grouping,
    required this.onGroupingChanged,
    required this.onRescheduleTasks,
    required this.onDiscoverRoutines,
  });

  final DailyPlannerGrouping grouping;
  final ValueChanged<DailyPlannerGrouping> onGroupingChanged;
  final VoidCallback onRescheduleTasks;
  final Future<void> Function() onDiscoverRoutines;

  @override
  State<_DailyOptionsOverlay> createState() => _DailyOptionsOverlayState();
}

class _DailyOptionsOverlayState extends State<_DailyOptionsOverlay> {
  bool _groupingOpen = false;

  @override
  Widget build(BuildContext context) {
    final width = math.min(350.0, MediaQuery.sizeOf(context).width - 28);
    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              top: 10,
              right: 14,
              child: SizedBox(
                width: width,
                height: 450,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: _DailyMenuCard(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IgnorePointer(
                              ignoring: _groupingOpen,
                              child: AnimatedOpacity(
                                opacity: _groupingOpen ? .38 : 1,
                                duration: const Duration(milliseconds: 140),
                                child: Column(
                                  children: [
                                    _DailyMenuTile(
                                      key: const ValueKey(
                                        'daily-menu-reschedule',
                                      ),
                                      icon: Icons.calendar_month_outlined,
                                      label: 'Görevleri yeniden zamanlama',
                                      onTap: () {
                                        Navigator.pop(context);
                                        widget.onRescheduleTasks();
                                      },
                                    ),
                                    _DailyMenuTile(
                                      key: const ValueKey(
                                        'daily-menu-routines',
                                      ),
                                      icon: Icons.search_rounded,
                                      label: 'Rutinleri keşfedin',
                                      onTap: () {
                                        Navigator.pop(context);
                                        widget.onDiscoverRoutines();
                                      },
                                    ),
                                    _DailyMenuTile(
                                      key: const ValueKey('daily-menu-mode'),
                                      icon: Icons.favorite_border_rounded,
                                      label: 'Günlük modu',
                                      onTap: () {},
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Divider(
                              height: 1,
                              indent: 18,
                              endIndent: 18,
                              color: context.palette.border,
                            ),
                            _DailyMenuTile(
                              key: const ValueKey('daily-menu-grouping'),
                              icon: Icons.account_tree_outlined,
                              label: 'Gruplama seçenekleri',
                              trailing: Icon(
                                _groupingOpen
                                    ? Icons.keyboard_arrow_down_rounded
                                    : Icons.chevron_right_rounded,
                              ),
                              onTap: () => setState(() => _groupingOpen = true),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_groupingOpen)
                      Positioned(
                        top: 205,
                        left: 8,
                        right: 0,
                        child: _DailyMenuCard(
                          key: const ValueKey('daily-grouping-submenu'),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _DailyMenuTile(
                                icon: Icons.tune_rounded,
                                label: 'Gruplama seçenekleri',
                                trailing: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                ),
                                bold: true,
                                onTap: () =>
                                    setState(() => _groupingOpen = false),
                              ),
                              Divider(
                                height: 1,
                                indent: 18,
                                endIndent: 18,
                                color: context.palette.border,
                              ),
                              _DailyMenuTile(
                                key: const ValueKey('daily-grouping-list'),
                                icon: Icons.format_list_bulleted_rounded,
                                label: 'Liste',
                                leading:
                                    widget.grouping == DailyPlannerGrouping.list
                                    ? const Icon(Icons.check_rounded)
                                    : null,
                                onTap: () {
                                  widget.onGroupingChanged(
                                    DailyPlannerGrouping.list,
                                  );
                                  Navigator.pop(context);
                                },
                              ),
                              _DailyMenuTile(
                                key: const ValueKey('daily-grouping-timeline'),
                                icon: Icons.view_timeline_outlined,
                                label: 'Zaman çizelgesi',
                                leading:
                                    widget.grouping ==
                                        DailyPlannerGrouping.timeline
                                    ? const Icon(Icons.check_rounded)
                                    : null,
                                onTap: () {
                                  widget.onGroupingChanged(
                                    DailyPlannerGrouping.timeline,
                                  );
                                  Navigator.pop(context);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyMenuCard extends StatelessWidget {
  const _DailyMenuCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(FlorienRadius.xl),
      border: Border.all(
        color: context.palette.border,
        width: FlorienBorders.thin,
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(FlorienRadius.xl - 1),
      child: Material(color: Colors.transparent, child: child),
    ),
  );
}

class _DailyMenuTile extends StatelessWidget {
  const _DailyMenuTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.leading,
    this.trailing,
    this.bold = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? leading;
  final Widget? trailing;
  final bool bold;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child:
                leading ??
                Icon(icon, size: 23, color: context.palette.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    ),
  );
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
  });

  final List<TaskModel> tasks;
  final DateTime selectedDate;
  final Set<DayPeriod> collapsed;
  final ValueChanged<DayPeriod> onToggleSection;
  final ValueChanged<DayPeriod> onAdd;
  final Future<void> Function(TaskModel task, DayPeriod? period) onMoveTask;

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
  });

  final List<TaskModel> tasks;
  final DateTime selectedDate;
  final VoidCallback onAdd;

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
          label: 'HERHANGİ BİR ZAMAN (${anytime.length})',
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
                  'Belirli saatli görev yok',
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
            'PLANLANDI ($count)',
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
        tooltip: 'Zaman çizelgesine görev ekle',
        icon: Icons.add_rounded,
        compact: true,
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
  });

  final TaskModel task;
  final DateTime selectedDate;
  final DateTime now;
  final double? progress;

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
                    tooltip: '${_periodLabel(period)} görevi ekle',
                    icon: Icons.add_rounded,
                    compact: true,
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
  });

  final List<TaskModel> tasks;
  final DateTime selectedDate;
  final Future<void> Function(TaskModel task) onTaskDropped;

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
                    'TAMAMLANDI (${tasks.length})',
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
    this.timelineStyle = false,
    this.scheduledProgress,
    this.scheduledRemaining,
  });

  final TaskModel task;
  final DateTime selectedDate;
  final bool showTimeRange;
  final bool timelineStyle;
  final double? scheduledProgress;
  final Duration? scheduledRemaining;

  @override
  Widget build(BuildContext context) {
    final card = _DailyTaskCard(
      task: task,
      selectedDate: selectedDate,
      showTimeRange: showTimeRange,
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
              child: _DailyDragPreview(task: task),
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
  const _DailyDragPreview({required this.task});

  final TaskModel task;

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
    this.timelineStyle = false,
    this.scheduledProgress,
    this.scheduledRemaining,
  });

  final TaskModel task;
  final DateTime selectedDate;
  final bool showTimeRange;
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
      tooltip: task.isCompleted ? 'Tamamlanmadı' : 'Tamamla',
      iconSize: timelineStyle ? 22 : 20,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints.tightFor(
        width: timelineStyle ? 30 : 26,
        height: timelineStyle ? 30 : 26,
      ),
      onPressed: () async {
        try {
          if (task.isCompleted) {
            await ref.read(taskRepositoryProvider).uncompleteTask(task.id);
          } else {
            final counts = await ref.read(dailyTaskCompleterProvider)(task.id);
            if (!context.mounted) return;
            await showTaskCompletionFeedback(context, ref, counts);
          }
        } on StateError {
          if (!context.mounted) return;
          ref.invalidate(dailyTimelineProvider(selectedDate));
          return;
        } catch (error) {
          debugPrint('Daily task completion could not be changed: $error');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Görev durumu güncellenemedi.')),
            );
          }
        }
        if (!context.mounted) return;
        ref.invalidate(dailyTimelineProvider(selectedDate));
      },
      icon: Icon(
        task.isCompleted ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: task.isCompleted
            ? Theme.of(context).colorScheme.primary
            : context.palette.textSecondary,
      ),
    );
    if (timelineStyle) {
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
              color: progress == null
                  ? context.palette.border
                  : color.withValues(alpha: .55),
              width: FlorienBorders.thin,
            ),
          ),
          child: InkWell(
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
                        const SizedBox(height: 2),
                        Text(
                          scheduledRemaining == null
                              ? _durationLabel(task.durationMinutes)
                              : _remainingTimelineLabel(scheduledRemaining!),
                          key: ValueKey('timeline-task-status-${task.id}'),
                          style: TextStyle(
                            color: context.palette.textSecondary,
                            fontSize: 11,
                          ),
                        ),
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
          ),
        ),
      );
    }
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
            color: context.palette.border,
            width: FlorienBorders.thin,
          ),
        ),
        child: ListTile(
          dense: true,
          visualDensity: const VisualDensity(vertical: -4),
          minTileHeight: 42,
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
          subtitle: Text(
            progress != null && scheduledRemaining != null
                ? _remainingTimelineLabel(scheduledRemaining!)
                : showTimeRange && task.isTimed && task.scheduledAt != null
                ? '${_clockLabel(task.scheduledAt!)} → ${_clockLabel(task.scheduledAt!.add(Duration(minutes: task.durationMinutes)))}'
                : _durationLabel(task.durationMinutes),
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
              icon: Icons.copy_all_outlined,
              label: 'Bir kopya oluştur',
              onTap: () =>
                  Navigator.pop(context, _DailyTaskMenuAction.createCopy),
            ),
            _DailyTaskActionTile(
              icon: Icons.move_to_inbox_outlined,
              label: 'Yapılacaklara taşı',
              onTap: () =>
                  Navigator.pop(context, _DailyTaskMenuAction.moveToTodo),
            ),
            _DailyTaskActionTile(
              icon: Icons.calendar_month_outlined,
              label: 'Yeniden planla',
              onTap: () =>
                  Navigator.pop(context, _DailyTaskMenuAction.reschedule),
            ),
            _DailyTaskActionTile(
              icon: Icons.redo_rounded,
              label: 'Yarın için yeniden planla',
              onTap: () =>
                  Navigator.pop(context, _DailyTaskMenuAction.tomorrow),
            ),
            const _DailyTaskActionTile(
              icon: Icons.auto_awesome_rounded,
              label: 'Ayrım öner',
            ),
            _DailyTaskActionTile(
              icon: Icons.restart_alt_rounded,
              label: task.isCompleted
                  ? 'Görevi yeniden başlat'
                  : 'Görevi başlat',
              onTap: () =>
                  Navigator.pop(context, _DailyTaskMenuAction.startFocus),
            ),
            _DailyTaskActionTile(
              icon: Icons.edit_outlined,
              label: 'Görevi düzenle',
              onTap: () => Navigator.pop(context, _DailyTaskMenuAction.edit),
            ),
            _DailyTaskActionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Görevi sil',
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
        await ref.read(dailyTaskReschedulerProvider)(
          task,
          _dateOnly(selectedDate).add(const Duration(days: 1)),
        );
      case _DailyTaskMenuAction.startFocus:
        await ref.read(startTaskFocusProvider)(task);
        if (!context.mounted) return;
        ref.read(focusTaskLaunchProvider.notifier).state = FocusTaskLaunch(
          taskId: task.id,
          title: task.title,
          durationMinutes: task.durationMinutes,
          icon: task.icon,
          color: task.color,
        );
      case _DailyTaskMenuAction.edit:
        await _showEdit(context, ref);
      case _DailyTaskMenuAction.delete:
        await ref.read(dailyDeleteTaskProvider)(task.id);
        ref.invalidate(dailyTimelineProvider(selectedDate));
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
          title: '${task.title} (Kopya)',
          description: task.description ?? '',
          durationMinutes: task.durationMinutes,
          recurrence: RecurrenceSelection(type: task.recurrenceType),
          alarmAt: task.alarmAt,
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
          alarmAt: task.alarmAt,
          isTimed: task.isTimed,
          startsAt: task.isTimed ? task.scheduledAt : null,
          endsAt: task.isTimed && task.scheduledAt != null
              ? task.scheduledAt!.add(Duration(minutes: task.durationMinutes))
              : null,
          subtasks: task.subtasks.map((subtask) => subtask.title).toList(),
          icon: task.icon,
          color: task.color,
        ),
        onSave: (draft) => ref.read(dailyTaskUpdaterProvider)(
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
            alarmAt: draft.alarmAt,
            subtasks: draft.subtasks,
            icon: draft.icon,
          ),
        ),
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
                'Yapılacaklara Taşı',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _DailyTodoListChoice(
                key: const ValueKey('daily-move-list-default'),
                name: 'To-do',
                description: 'Varsayılan yapılacaklar listesi',
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
    await ref.read(dailyTaskReschedulerProvider)(task, date);
  }
}

enum _DailyTaskMenuAction {
  createCopy,
  moveToTodo,
  reschedule,
  tomorrow,
  startFocus,
  edit,
  delete,
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
                  tooltip: 'Kapat',
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
                  tooltip: 'Tarihi onayla',
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
              label: 'Bugün (${_weekdayShortLabel(today)})',
              onTap: () => Navigator.pop(context, today),
            ),
            _DailyRescheduleShortcut(
              icon: Icons.redo_rounded,
              label:
                  'Gelecek hafta (${nextWeekSameDay.day} ${_monthShortLabel(nextWeekSameDay)} ${_weekdayShortLabel(nextWeekSameDay)})',
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
                      'Yeni görev',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kapat',
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
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _submit(),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: 'Sırada ne var?',
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
                            tooltip: _listening ? 'Konuşmayı bitir' : 'Konuş',
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
                            tooltip: 'Ekle',
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
                            tooltip: 'Ayrıntılı görev oluştur',
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
  late bool _alarm = widget.initialDraft.alarmAt != null;
  late TimeOfDay _alarmTime = TimeOfDay.fromDateTime(
    widget.initialDraft.alarmAt ?? nextDailyAlarmSlot(DateTime.now()),
  );
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
      final alarmAt = _alarm ? _alarmDateTime(taskDate, _alarmTime) : null;
      if (alarmAt != null) {
        final readiness = await ref
            .read(taskAlarmServiceProvider)
            .prepareTaskAlarm(alarmAt);
        if (readiness != TaskAlarmReadiness.ready) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(_alarmReadinessMessage(readiness))),
            );
          }
          return;
        }
        if (!mounted) return;
      }
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
        alarmAt: alarmAt,
        clearAlarmAt: !_alarm,
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
      const SnackBar(content: Text('En fazla 30 alt görev ekleyebilirsin.')),
    );
  }

  void _onTitleChanged(String value) {
    _taskIcon.onTaskChanged(value);
    setState(() {});
  }

  Future<void> _generateSubtasks() async {
    final title = _title.text.trim();
    if (title.isEmpty ||
        _generatingSubtasks ||
        _subtasks.length >= TaskModel.userSubtaskLimit) {
      return;
    }
    if (!await requirePremiumAccess(context, ref, PremiumFeature.subtasks)) {
      return;
    }
    if (!mounted) return;

    setState(() => _generatingSubtasks = true);
    try {
      final generated = widget.initialDraft.presetSubtasks.isNotEmpty
          ? await Future<List<String>>.delayed(
              const Duration(milliseconds: 450),
              () => widget.initialDraft.presetSubtasks,
            )
          : await ref
                .read(taskBreakdownServiceProvider)
                .generateSubtasks(title);
      if (!mounted || _title.text.trim().isEmpty) return;
      final existing = _subtasks.map((item) => item.toLowerCase()).toSet();
      final remaining = TaskModel.userSubtaskLimit - _subtasks.length;
      final additions = generated
          .where((item) => existing.add(item.toLowerCase()))
          .take(math.min(TaskModel.aiSubtaskLimit, remaining))
          .toList();
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
        (membership) => membership.valueOrNull?.isPremium == true,
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.screenTitle),
        leading: IconButton(
          tooltip: 'Kapat',
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
            label: Text(_saving ? 'Kaydediliyor...' : 'Görevi kaydet'),
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
                            ? 'Bugün için küçük bir adım'
                            : 'Görevini düzenle',
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
                  autofocus: _title.text.trim().isEmpty,
                  textCapitalization: TextCapitalization.sentences,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: 'Ne yapmak istersin?',
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
                  label: 'Günün saati',
                  value: _isTimed ? 'Zamanında' : _periodLabel(_period),
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
                    label: 'Başlar',
                    value: _startsAt,
                    dateKey: const ValueKey('daily-start-date'),
                    timeKey: const ValueKey('daily-start-time'),
                    onPickDate: () => _pickTimedDate(start: true),
                    onPickTime: () => _pickTimedTime(start: true),
                  ),
                  const Divider(height: 1),
                  _TimedDateTimeTile(
                    label: 'Biter',
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
                    label: 'Tarih',
                    value: _shortDate(_date),
                    onTap: _pickDate,
                  ),
                  const Divider(height: 1),
                  _DetailTile(
                    icon: Icons.timer_outlined,
                    label: 'Süre',
                    value: _durationLabel(_duration),
                    onTap: _pickDuration,
                  ),
                ],
                const Divider(height: 1),
                _DetailTile(
                  icon: Icons.repeat_rounded,
                  label: 'Yinelemek',
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
                const Divider(height: 1),
                SwitchListTile(
                  secondary: Icon(
                    isPremium
                        ? Icons.alarm_outlined
                        : Icons.lock_outline_rounded,
                  ),
                  title: const Text('Alarm'),
                  subtitle: const Text('Belirlediğiniz saatte hatırlatır'),
                  value: _alarm,
                  onChanged: (value) async {
                    if (value &&
                        !await requirePremiumAccess(
                          context,
                          ref,
                          PremiumFeature.reminders,
                        )) {
                      return;
                    }
                    if (mounted) setState(() => _alarm = value);
                  },
                ),
                if (_alarm) ...[
                  const Divider(height: 1),
                  _DetailTile(
                    key: const ValueKey('daily-alarm-time'),
                    icon: Icons.access_time_rounded,
                    label: 'Alarm saati',
                    value: _formatAlarmTime(_alarmTime),
                    onTap: _pickAlarmTime,
                  ),
                ],
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
                  _DailyFormSectionHeader(
                    key: const ValueKey('daily-subtasks-section-toggle'),
                    icon: Icons.account_tree_outlined,
                    title: 'Alt görevler',
                    subtitle: _subtasks.isEmpty
                        ? 'Küçük adımlar başlatmayı kolaylaştırır.'
                        : 'Adımları dilediğin sırayla düzenleyebilirsin.',
                    color: FlorienColors.aiLavender,
                    trailing:
                        _title.text.trim().isNotEmpty &&
                            _subtasks.length < TaskModel.userSubtaskLimit
                        ? IconButton.filledTonal(
                            key: const ValueKey('daily-ai-subtasks-button'),
                            tooltip:
                                widget.initialDraft.presetSubtasks.isNotEmpty
                                ? 'Hazır alt görevleri ekle'
                                : 'AI ile alt görev oluştur',
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
                                    !isPremium
                                        ? Icons.lock_outline_rounded
                                        : widget
                                              .initialDraft
                                              .presetSubtasks
                                              .isNotEmpty
                                        ? Icons.playlist_add_check_rounded
                                        : Icons.auto_awesome_rounded,
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
                        leading: const Icon(Icons.circle_outlined, size: 18),
                        title: Text(_subtasks[index]),
                        trailing: IconButton(
                          onPressed: () =>
                              setState(() => _subtasks.removeAt(index)),
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
                            decoration: const InputDecoration(
                              hintText: 'Yeni alt görev',
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
                  _DailyFormSectionHeader(
                    key: const ValueKey('daily-notes-section-toggle'),
                    icon: Icons.notes_rounded,
                    title: 'Notlar',
                    subtitle: 'Hatırlamak istediğin ayrıntılar.',
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
                      decoration: const InputDecoration(
                        hintText: 'Notlarını buraya yaz…',
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
    if (value != null && mounted) setState(() => _date = _dateOnly(value));
  }

  Future<void> _pickDuration() async {
    final value = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [5, 10, 15, 30, 45, 60, 90, 120]
              .map(
                (duration) => ListTile(
                  title: Text(_durationLabel(duration)),
                  trailing: duration == _duration
                      ? const Icon(Icons.check_rounded)
                      : null,
                  onTap: () => Navigator.pop(context, duration),
                ),
              )
              .toList(),
        ),
      ),
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

  Future<void> _pickAlarmTime() async {
    if (!await requirePremiumAccess(context, ref, PremiumFeature.reminders)) {
      return;
    }
    if (!mounted) return;
    final value = await showTimePicker(
      context: context,
      initialTime: _alarmTime,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (value != null && mounted) setState(() => _alarmTime = value);
  }
}

class _DailyFormSectionHeader extends StatelessWidget {
  const _DailyFormSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.trailing,
    this.expanded,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget? trailing;
  final bool? expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(FlorienRadius.md),
        border: Border.all(
          color: context.palette.border,
          width: FlorienBorders.thin,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
          if (expanded case final expanded?)
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
            ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(FlorienRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FlorienRadius.md),
        child: content,
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    super.key,
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
              'Günün saati',
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
              'Etkinlik',
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
            title: const Text('Zamanında'),
            trailing: isPremium
                ? null
                : const Icon(Icons.lock_outline_rounded, size: 20),
            onTap: () => Navigator.pop(
              context,
              _DailyPeriodSelection(period: selected, isTimed: true),
            ),
          ),
          const ListTile(
            enabled: false,
            leading: Icon(Icons.schedule_outlined),
            title: Text('Tüm gün'),
          ),
          const Divider(),
          ListTile(
            key: const ValueKey('daily-todo-choice'),
            leading: Icon(Icons.move_to_inbox_outlined),
            title: const Text('Yapılacaklar'),
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
                    child: const Text('Vazgeç'),
                  ),
                  const Spacer(),
                  Text(
                    'Saat seç',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      TimeOfDay.fromDateTime(selected),
                    ),
                    child: const Text('Bitti'),
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
    this.alarmAt,
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
  final DateTime? alarmAt;
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
    DateTime? alarmAt,
    bool clearAlarmAt = false,
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
    alarmAt: clearAlarmAt ? null : (alarmAt ?? this.alarmAt),
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
        alarmAt: draft.alarmAt,
        isTimed: draft.isTimed,
        isInbox: false,
        recurrence: draft.recurrence,
        icon: draft.icon,
        color: draft.color,
        dayPeriod: draft.period,
      );
  final alarmAt = draft.alarmAt;
  if (alarmAt != null) {
    try {
      final scheduled = await ref
          .read(taskAlarmServiceProvider)
          .schedule(taskId: task.id, title: task.title, alarmAt: alarmAt);
      if (!scheduled) {
        debugPrint('Created daily task alarm was not scheduled.');
      }
    } catch (error) {
      debugPrint('Created daily task alarm failed: $error');
      // Notification setup must not prevent the task itself from being saved.
    }
  }
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
  ref.invalidate(dailyTimelineProvider(_dateOnly(draft.date)));
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
    return Tooltip(
      message: tooltip,
      child: Material(
        color: emphasized ? FlorienColors.primary : context.palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlorienRadius.sm),
          side: BorderSide(
            color: context.palette.border,
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
              color: emphasized
                  ? FlorienColors.onPrimary
                  : context.palette.textSecondary,
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
  Widget build(BuildContext context) => Padding(
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
            color: selected ? FlorienColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(FlorienRadius.md),
            border: selected
                ? Border.all(
                    color: context.palette.border,
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
                      ? FlorienColors.onPrimary.withValues(alpha: 0.7)
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

(DateTime, DateTime) _defaultTimedRange(DateTime date) {
  final now = DateTime.now();
  final nextSlot = nextDailyAlarmSlot(now);
  final start = _sameDate(date, now)
      ? nextSlot
      : DateTime(
          date.year,
          date.month,
          date.day,
          nextSlot.hour,
          nextSlot.minute,
        );
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

DateTime _alarmDateTime(DateTime date, TimeOfDay time) =>
    DateTime(date.year, date.month, date.day, time.hour, time.minute);

String _alarmReadinessMessage(
  TaskAlarmReadiness readiness,
) => switch (readiness) {
  TaskAlarmReadiness.past => 'Alarm saati gelecekte olmalı.',
  TaskAlarmReadiness.remindersDisabled =>
    'Görev hatırlatıcıları kapalı. Ayarlar > Bildirimler bölümünden açabilirsin.',
  TaskAlarmReadiness.permissionDenied =>
    'Bildirim izni kapalı. Cihaz Ayarları > Florien > Bildirimler bölümünden açabilirsin.',
  TaskAlarmReadiness.unsupported => 'Bu cihazda plan alarmı kullanılamıyor.',
  TaskAlarmReadiness.ready => '',
};

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
  DayPeriod.anytime => 'Her zaman',
  DayPeriod.morning => 'Sabah',
  DayPeriod.daytime => 'Gündüz',
  DayPeriod.evening => 'Akşam',
};

String _periodHint(DayPeriod period) => switch (period) {
  DayPeriod.anytime => 'Bu gruba görev ekle',
  DayPeriod.morning => 'Sabah için görev ekle',
  DayPeriod.daytime => 'Gündüz için görev ekle',
  DayPeriod.evening => 'Akşam için görev ekle',
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
  RecurrenceType.none => 'Hayır',
  RecurrenceType.daily => 'Her gün',
  RecurrenceType.weekly => 'Her hafta',
  RecurrenceType.monthly => 'Her ay',
  RecurrenceType.yearly => 'Her yıl',
  RecurrenceType.custom => 'Özel',
};

String _durationLabel(int minutes) => switch (minutes) {
  60 => '1 saat',
  90 => '1,5 saat',
  120 => '2 saat',
  _ => '$minutes dk',
};

String _shortDate(DateTime date) =>
    '${date.day} ${_monthName(date.month).substring(0, 3)} ${date.year}';

String _focusedDateLabel(DateTime date) =>
    '${date.day} ${_monthName(date.month)} ${date.year}';

String _weekdayName(DateTime date) => const [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
][date.weekday - 1];

String _weekdayShort(DateTime date) =>
    const ['P', 'S', 'Ç', 'P', 'C', 'C', 'P'][date.weekday - 1];

String _weekdayShortLabel(DateTime date) =>
    const ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'][date.weekday - 1];

String _monthShortLabel(DateTime date) =>
    _monthName(date.month).substring(0, 3);

String _monthName(int month) => const [
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
][month - 1];
