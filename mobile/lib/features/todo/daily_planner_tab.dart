import 'package:flutter/material.dart' hide DayPeriod;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/models/recurrence.dart';
import 'package:florien/core/repositories/repositories.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/utils/task_icons.dart';
import 'package:florien/core/widgets/florien_soft_overlay.dart';
import 'package:florien/features/providers.dart';

typedef DailyTaskGroupMover =
    Future<void> Function(TaskModel task, DayPeriod? period, DateTime date);

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

class DailyPlannerTab extends ConsumerStatefulWidget {
  const DailyPlannerTab({super.key});

  @override
  ConsumerState<DailyPlannerTab> createState() => _DailyPlannerTabState();
}

class _DailyPlannerTabState extends ConsumerState<DailyPlannerTab> {
  late DateTime _selectedDate = _dateOnly(DateTime.now());
  final Set<DayPeriod> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    final timeline = ref.watch(dailyTimelineProvider(_selectedDate));
    return SafeArea(
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
            onToggleSection: _toggleSection,
            onAdd: _showQuickAdd,
            onMoveTask: _moveTaskToGroup,
          ),
          data: (value) => _DailyBody(
            selectedDate: _selectedDate,
            tasks: value.tasks,
            collapsed: _collapsed,
            onSelectDate: _selectDate,
            onToggleSection: _toggleSection,
            onAdd: _showQuickAdd,
            onMoveTask: _moveTaskToGroup,
          ),
        ),
      ),
    );
  }

  void _selectDate(DateTime value) {
    setState(() => _selectedDate = _dateOnly(value));
  }

  void _toggleSection(DayPeriod period) {
    setState(() {
      if (!_collapsed.add(period)) _collapsed.remove(period);
    });
  }

  Future<void> _showQuickAdd(DayPeriod period) async {
    final draft = await showFlorienBottomSheet<_DailyTaskDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DailyQuickAddSheet(
        initialDraft: _DailyTaskDraft(date: _selectedDate, period: period),
      ),
    );
    if (draft == null || !mounted) return;
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
}

class _DailyBody extends StatelessWidget {
  const _DailyBody({
    required this.selectedDate,
    required this.tasks,
    required this.collapsed,
    required this.onSelectDate,
    required this.onToggleSection,
    required this.onAdd,
    required this.onMoveTask,
  });

  final DateTime selectedDate;
  final List<TaskModel> tasks;
  final Set<DayPeriod> collapsed;
  final ValueChanged<DateTime> onSelectDate;
  final ValueChanged<DayPeriod> onToggleSection;
  final ValueChanged<DayPeriod> onAdd;
  final Future<void> Function(TaskModel task, DayPeriod? period) onMoveTask;

  @override
  Widget build(BuildContext context) {
    final activeTasks = tasks.where((task) => !task.isCompleted).toList();
    final completedTasks = tasks.where((task) => task.isCompleted).toList();
    return ListView(
      key: const ValueKey('daily-planner-page'),
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
      children: [
        _DailyHeader(
          selectedDate: selectedDate,
          onSelectDate: onSelectDate,
          onAdd: () => onAdd(DayPeriod.anytime),
        ),
        const SizedBox(height: 24),
        for (final period in DayPeriod.values) ...[
          _DailySection(
            period: period,
            tasks: activeTasks
                .where((task) => task.dayPeriod == period)
                .toList(),
            selectedDate: selectedDate,
            collapsed: collapsed.contains(period),
            onToggle: () => onToggleSection(period),
            onAdd: () => onAdd(period),
            onTaskDropped: (task) => onMoveTask(task, period),
          ),
          const SizedBox(height: 16),
        ],
        if (completedTasks.isNotEmpty)
          _DailyCompletedSection(
            tasks: completedTasks,
            selectedDate: selectedDate,
            onTaskDropped: (task) => onMoveTask(task, null),
          ),
      ],
    );
  }
}

class _DailyHeader extends StatelessWidget {
  const _DailyHeader({
    required this.selectedDate,
    required this.onSelectDate,
    required this.onAdd,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelectDate;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _HeaderButton(
              label: 'Bugün',
              icon: Icons.today_rounded,
              onTap: () => onSelectDate(today),
            ),
            const Spacer(),
            _SquareButton(
              tooltip: 'Günlük seçenekleri',
              icon: Icons.more_horiz_rounded,
              onTap: () {},
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
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                _weekdayName(selectedDate),
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1,
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
          ],
        ),
        const SizedBox(height: 14),
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

class _DailySection extends StatelessWidget {
  const _DailySection({
    required this.period,
    required this.tasks,
    required this.selectedDate,
    required this.collapsed,
    required this.onToggle,
    required this.onAdd,
    required this.onTaskDropped,
  });

  final DayPeriod period;
  final List<TaskModel> tasks;
  final DateTime selectedDate;
  final bool collapsed;
  final VoidCallback onToggle;
  final VoidCallback onAdd;
  final Future<void> Function(TaskModel task) onTaskDropped;

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
      borderRadius: BorderRadius.circular(FlorienRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: context.palette.surface.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(FlorienRadius.md),
          border: Border.all(color: context.palette.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _periodHint(period),
                style: TextStyle(
                  color: context.palette.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.add_circle_outline_rounded,
              color: context.palette.textSecondary,
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
  });

  final TaskModel task;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context) {
    final card = _DailyTaskCard(task: task, selectedDate: selectedDate);
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
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(FlorienRadius.md),
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
          CircleAvatar(
            radius: 19,
            backgroundColor: color.withValues(alpha: .16),
            child: Icon(
              TaskIcons.iconForTask(title: task.title, icon: task.icon),
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  _durationLabel(task.durationMinutes),
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.drag_indicator_rounded, color: color),
        ],
      ),
    );
  }
}

class _DailyTaskCard extends ConsumerWidget {
  const _DailyTaskCard({required this.task, required this.selectedDate});

  final TaskModel task;
  final DateTime selectedDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _periodColor(task.dayPeriod);
    final focus = ref.watch(activeFocusTaskProvider);
    final activeFocus = focus?.taskId == task.id ? focus : null;
    return AnimatedOpacity(
      opacity: task.isCompleted ? .55 : 1,
      duration: const Duration(milliseconds: 180),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(FlorienRadius.md),
          border: Border.all(color: context.palette.border),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
          leading: _DailyTaskIcon(
            task: task,
            color: color,
            activeFocus: activeFocus,
          ),
          title: Text(
            task.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              decoration: task.isCompleted
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
            ),
          ),
          subtitle: Text(
            _durationLabel(task.durationMinutes),
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 12,
              decoration: task.isCompleted
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
            ),
          ),
          trailing: IconButton(
            tooltip: task.isCompleted ? 'Tamamlanmadı' : 'Tamamla',
            onPressed: () async {
              final repository = ref.read(taskRepositoryProvider);
              if (task.isCompleted) {
                await repository.uncompleteTask(task.id);
              } else {
                await repository.completeTask(task.id);
              }
              ref.invalidate(dailyTimelineProvider(selectedDate));
            },
            icon: Icon(
              task.isCompleted
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: task.isCompleted
                  ? Theme.of(context).colorScheme.primary
                  : context.palette.textSecondary,
            ),
          ),
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
            const _DailyTaskActionTile(
              icon: Icons.copy_all_outlined,
              label: 'Bir kopya oluştur',
            ),
            _DailyTaskActionTile(
              icon: Icons.move_to_inbox_outlined,
              label: 'Yapılacaklara taşı',
              onTap: () =>
                  Navigator.pop(context, _DailyTaskMenuAction.moveToTodo),
            ),
            const _DailyTaskActionTile(
              icon: Icons.calendar_month_outlined,
              label: 'Yeniden planla',
            ),
            const _DailyTaskActionTile(
              icon: Icons.redo_rounded,
              label: 'Yarın için yeniden planla',
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
              onTap: () async {
                Navigator.pop(context);
                await ref.read(startTaskFocusProvider)(task);
                if (!context.mounted) return;
                ref
                    .read(focusTaskLaunchProvider.notifier)
                    .state = FocusTaskLaunch(
                  taskId: task.id,
                  title: task.title,
                  durationMinutes: task.durationMinutes,
                  icon: task.icon,
                  color: task.color,
                );
              },
            ),
            const _DailyTaskActionTile(
              icon: Icons.edit_outlined,
              label: 'Görevi düzenle',
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
      case _DailyTaskMenuAction.moveToTodo:
        await ref.read(dailyMoveToTodoProvider)(task.id);
      case _DailyTaskMenuAction.delete:
        await ref.read(dailyDeleteTaskProvider)(task.id);
        ref.invalidate(dailyTimelineProvider(selectedDate));
      case null:
        return;
    }
  }
}

enum _DailyTaskMenuAction { moveToTodo, delete }

class _DailyTaskIcon extends StatelessWidget {
  const _DailyTaskIcon({
    required this.task,
    required this.color,
    required this.activeFocus,
  });

  final TaskModel task;
  final Color color;
  final ActiveFocusTask? activeFocus;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 42,
    child: Stack(
      alignment: Alignment.center,
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: color.withValues(alpha: .16),
          child: Icon(
            TaskIcons.iconForTask(title: task.title, icon: task.icon),
            color: color,
            size: 19,
          ),
        ),
        if (activeFocus != null)
          SizedBox.square(
            dimension: 42,
            child: CircularProgressIndicator(
              key: ValueKey('daily-task-progress-${task.id}'),
              value: activeFocus!.progress,
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

class _DailyQuickAddSheet extends StatefulWidget {
  const _DailyQuickAddSheet({required this.initialDraft});

  final _DailyTaskDraft initialDraft;

  @override
  State<_DailyQuickAddSheet> createState() => _DailyQuickAddSheetState();
}

class _DailyQuickAddSheetState extends State<_DailyQuickAddSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.initialDraft.title,
  );
  late DayPeriod _period = widget.initialDraft.period;
  late RecurrenceType _recurrence = widget.initialDraft.recurrence.type;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  _DailyTaskDraft _draft({required bool details}) =>
      widget.initialDraft.copyWith(
        title: _title.text.trim(),
        period: _period,
        recurrence: RecurrenceSelection(type: _recurrence),
        openDetails: details,
      );

  void _submit() {
    if (_title.text.trim().isEmpty) return;
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
              TextField(
                key: const ValueKey('daily-quick-title'),
                controller: _title,
                autofocus: true,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _submit(),
                style: Theme.of(context).textTheme.titleLarge,
                decoration: const InputDecoration(
                  hintText: 'Sırada ne var?',
                  border: InputBorder.none,
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
                            icon: _periodIcon(_period),
                            label: _periodLabel(_period).toUpperCase(),
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
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.graphic_eq_rounded, size: 18),
                    label: const Text('Konuş'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Vazgeç'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Ekle'),
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
    final selected = await _showDayPeriodPicker(context, _period);
    if (selected != null && mounted) setState(() => _period = selected);
  }

  Future<void> _pickRecurrence() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final selected = await _showRecurrencePicker(context, _recurrence);
    if (selected != null && mounted) setState(() => _recurrence = selected);
  }
}

class _DailyTaskDetailScreen extends ConsumerStatefulWidget {
  const _DailyTaskDetailScreen({required this.initialDraft});

  final _DailyTaskDraft initialDraft;

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
  late RecurrenceType _recurrence = widget.initialDraft.recurrence.type;
  late bool _alarm = widget.initialDraft.alarm;
  late final List<String> _subtasks = [...widget.initialDraft.subtasks];
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _subtask.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await _createDailyTask(
        ref,
        widget.initialDraft.copyWith(
          title: _title.text.trim(),
          description: _notes.text.trim(),
          date: _date,
          period: _period,
          durationMinutes: _duration,
          recurrence: RecurrenceSelection(type: _recurrence),
          alarm: _alarm,
          subtasks: _subtasks,
          openDetails: false,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addSubtask() {
    final value = _subtask.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _subtasks.add(value);
      _subtask.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Görev ekle'),
      leading: IconButton(
        tooltip: 'Kapat',
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close_rounded),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: IconButton.filled(
            tooltip: 'Kaydet',
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
          ),
        ),
      ],
    ),
    body: ListView(
      padding: EdgeInsets.fromLTRB(
        18,
        14,
        18,
        MediaQuery.viewInsetsOf(context).bottom + 32,
      ),
      children: [
        TextField(
          controller: _title,
          autofocus: _title.text.trim().isEmpty,
          textCapitalization: TextCapitalization.sentences,
          style: Theme.of(context).textTheme.titleLarge,
          decoration: const InputDecoration(
            hintText: 'Görev başlığı',
            prefixIcon: Icon(Icons.edit_rounded),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              _DetailTile(
                icon: _periodIcon(_period),
                label: 'Günün saati',
                value: _periodLabel(_period),
                onTap: () async {
                  final value = await _showDayPeriodPicker(context, _period);
                  if (value != null && mounted) setState(() => _period = value);
                },
              ),
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
                secondary: const Icon(Icons.alarm_outlined),
                title: const Text('Alarm'),
                subtitle: const Text('Süre sonunda bildirim sesi'),
                value: _alarm,
                onChanged: (value) => setState(() => _alarm = value),
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
                Text(
                  'Alt görevler',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
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
                        controller: _subtask,
                        onSubmitted: (_) => _addSubtask(),
                        decoration: const InputDecoration(
                          hintText: 'Yeni alt görev',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _addSubtask,
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _notes,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: 'Notlarını buraya yaz…',
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    ),
  );

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
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    trailing: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(value),
    ),
    onTap: onTap,
  );
}

class _DayPeriodPicker extends StatelessWidget {
  const _DayPeriodPicker({required this.selected});

  final DayPeriod selected;

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
              onTap: () => Navigator.pop(context, period),
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
          const ListTile(
            enabled: false,
            leading: Icon(Icons.edit_calendar_outlined),
            title: Text('Zamanında'),
          ),
          const ListTile(
            enabled: false,
            leading: Icon(Icons.schedule_outlined),
            title: Text('Tüm gün'),
          ),
          const Divider(),
          const ListTile(
            enabled: false,
            leading: Icon(Icons.move_to_inbox_outlined),
            title: Text('Yapılacaklar'),
          ),
        ],
      ),
    ),
  );
}

Future<DayPeriod?> _showDayPeriodPicker(
  BuildContext context,
  DayPeriod selected,
) => showFlorienSoftDialog<DayPeriod>(
  context: context,
  maxWidth: 360,
  builder: (_) => _DayPeriodPicker(selected: selected),
);

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
    this.recurrence = const RecurrenceSelection(),
    this.alarm = false,
    this.subtasks = const [],
    this.openDetails = false,
  });

  final DateTime date;
  final DayPeriod period;
  final String title;
  final String description;
  final int durationMinutes;
  final RecurrenceSelection recurrence;
  final bool alarm;
  final List<String> subtasks;
  final bool openDetails;

  _DailyTaskDraft copyWith({
    DateTime? date,
    DayPeriod? period,
    String? title,
    String? description,
    int? durationMinutes,
    RecurrenceSelection? recurrence,
    bool? alarm,
    List<String>? subtasks,
    bool? openDetails,
  }) => _DailyTaskDraft(
    date: date ?? this.date,
    period: period ?? this.period,
    title: title ?? this.title,
    description: description ?? this.description,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    recurrence: recurrence ?? this.recurrence,
    alarm: alarm ?? this.alarm,
    subtasks: subtasks ?? this.subtasks,
    openDetails: openDetails ?? this.openDetails,
  );
}

Future<void> _createDailyTask(WidgetRef ref, _DailyTaskDraft draft) async {
  final scheduledAt = _scheduledAt(draft.date, draft.period);
  final task = await ref
      .read(taskRepositoryProvider)
      .createTask(
        title: draft.title,
        description: draft.description.trim().isEmpty
            ? null
            : draft.description,
        durationMinutes: draft.durationMinutes,
        scheduledAt: scheduledAt,
        isInbox: false,
        recurrence: draft.recurrence,
        icon: TaskIcons.defaultName,
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
  ref.invalidate(dailyTimelineProvider(_dateOnly(draft.date)));
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
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
        color: emphasized
            ? Theme.of(context).colorScheme.primary
            : context.palette.surfaceMuted,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: SizedBox.square(
            dimension: size,
            child: Icon(
              icon,
              size: compact ? 18 : 21,
              color: emphasized
                  ? Theme.of(context).colorScheme.onPrimary
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
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Colors.transparent,
      borderRadius: BorderRadius.circular(FlorienRadius.md),
      child: InkWell(
        onTap: () => onTap(date),
        borderRadius: BorderRadius.circular(FlorienRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Column(
            children: [
              Text(
                _weekdayShort(date),
                style: TextStyle(
                  color: today
                      ? Theme.of(context).colorScheme.primary
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
                      ? Theme.of(context).colorScheme.primary
                      : context.palette.textPrimary,
                  fontSize: 20,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
  DayPeriod.anytime => 'Bugün herhangi bir zaman',
  DayPeriod.morning => 'Güne sakin bir başlangıç yapın',
  DayPeriod.daytime => 'Günün ortasına görev ekleyin',
  DayPeriod.evening => 'Günü istediğiniz gibi bitirin',
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
