import 'dart:async';

import 'package:flutter/material.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/task_icon/presentation/task_icon_badge.dart';

typedef ReviewTaskRescheduler =
    Future<void> Function(TaskModel task, DateTime date);

enum _ReviewPhase { completed, remaining, finished }

class DailyRescheduleReviewFlow extends StatefulWidget {
  const DailyRescheduleReviewFlow({
    super.key,
    required this.selectedDate,
    required this.tasks,
    required this.onReschedule,
  });

  final DateTime selectedDate;
  final List<TaskModel> tasks;
  final ReviewTaskRescheduler onReschedule;

  @override
  State<DailyRescheduleReviewFlow> createState() =>
      _DailyRescheduleReviewFlowState();
}

class _DailyRescheduleReviewFlowState extends State<DailyRescheduleReviewFlow> {
  late final List<TaskModel> _completed = widget.tasks
      .where((task) => task.isCompleted)
      .toList();
  late final List<TaskModel> _remaining = widget.tasks
      .where((task) => !task.isCompleted)
      .toList();
  late Set<String> _selectedIds = _remaining.map((task) => task.id).toSet();
  late _ReviewPhase _phase = _completed.isNotEmpty
      ? _ReviewPhase.completed
      : _remaining.isEmpty
      ? _ReviewPhase.finished
      : _ReviewPhase.remaining;
  Timer? _phaseTimer;
  bool _moving = false;

  @override
  void initState() {
    super.initState();
    if (_phase == _ReviewPhase.completed) {
      _phaseTimer = Timer(const Duration(seconds: 3), _leaveCompletedSummary);
    } else if (_phase == _ReviewPhase.finished) {
      _scheduleClose();
    }
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    super.dispose();
  }

  void _leaveCompletedSummary() {
    if (!mounted) return;
    if (_remaining.isEmpty) {
      _showFinished();
      return;
    }
    setState(() => _phase = _ReviewPhase.remaining);
  }

  void _showFinished() {
    _phaseTimer?.cancel();
    setState(() {
      _phase = _ReviewPhase.finished;
      _moving = false;
    });
    _scheduleClose();
  }

  void _scheduleClose() {
    _phaseTimer?.cancel();
    _phaseTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) Navigator.maybePop(context);
    });
  }

  void _close() {
    _phaseTimer?.cancel();
    Navigator.maybePop(context);
  }

  void _toggleTask(String taskId) {
    if (_moving) return;
    setState(() {
      if (!_selectedIds.add(taskId)) _selectedIds.remove(taskId);
    });
  }

  Future<void> _moveSelected(DateTime date) async {
    if (_moving || _selectedIds.isEmpty) return;
    final movingIds = Set<String>.of(_selectedIds);
    final movingTasks = _remaining
        .where((task) => movingIds.contains(task.id))
        .toList();
    setState(() => _moving = true);
    try {
      for (final task in movingTasks) {
        await widget.onReschedule(task, _dateOnly(date));
      }
      if (!mounted) return;
      setState(() {
        _remaining.removeWhere((task) => movingIds.contains(task.id));
        _selectedIds = _remaining.map((task) => task.id).toSet();
        _moving = false;
      });
      if (_remaining.isEmpty) _showFinished();
    } catch (_) {
      if (!mounted) return;
      setState(() => _moving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Görevler taşınamadı. Tekrar deneyin.')),
      );
    }
  }

  Future<void> _showMoreDates() async {
    if (_moving || _selectedIds.isEmpty) return;
    final tomorrow = _dateOnly(
      widget.selectedDate.add(const Duration(days: 1)),
    );
    final date = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewDatePickerSheet(initialDate: tomorrow),
    );
    if (date != null && mounted) await _moveSelected(date);
  }

  @override
  Widget build(BuildContext context) => Material(
    color: context.palette.background,
    child: SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: switch (_phase) {
                _ReviewPhase.completed => _CompletedReview(
                  key: const ValueKey('daily-review-completed'),
                  date: widget.selectedDate,
                  tasks: _completed,
                ),
                _ReviewPhase.remaining => _RemainingReview(
                  key: const ValueKey('daily-review-remaining'),
                  sourceDate: widget.selectedDate,
                  tasks: _remaining,
                  selectedIds: _selectedIds,
                  moving: _moving,
                  onToggle: _toggleTask,
                  onTomorrow: () => _moveSelected(
                    widget.selectedDate.add(const Duration(days: 1)),
                  ),
                  onMoreDates: _showMoreDates,
                  onFinish: _showFinished,
                ),
                _ReviewPhase.finished => const _FinishedReview(
                  key: ValueKey('daily-review-finished'),
                ),
              },
            ),
          ),
          Positioned(
            top: 8,
            right: 12,
            child: _ReviewCloseButton(onTap: _close),
          ),
        ],
      ),
    ),
  );
}

class _CompletedReview extends StatelessWidget {
  const _CompletedReview({super.key, required this.date, required this.tasks});

  final DateTime date;
  final List<TaskModel> tasks;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 88, 24, 24),
    child: Column(
      children: [
        _DatePill(date: date),
        const SizedBox(height: 18),
        Text(
          'Bu oldu',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
            fontSize: 34,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Bu kadardı. Kendine övgü ver!',
          style: TextStyle(color: context.palette.textSecondary, fontSize: 16),
        ),
        const SizedBox(height: 54),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '${tasks.length} görev tamamladın',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.separated(
            itemCount: tasks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, index) =>
                _ReviewTaskCard(task: tasks[index], completed: true),
          ),
        ),
      ],
    ),
  );
}

class _RemainingReview extends StatelessWidget {
  const _RemainingReview({
    super.key,
    required this.sourceDate,
    required this.tasks,
    required this.selectedIds,
    required this.moving,
    required this.onToggle,
    required this.onTomorrow,
    required this.onMoreDates,
    required this.onFinish,
  });

  final DateTime sourceDate;
  final List<TaskModel> tasks;
  final Set<String> selectedIds;
  final bool moving;
  final ValueChanged<String> onToggle;
  final VoidCallback onTomorrow;
  final VoidCallback onMoreDates;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final selectedCount = selectedIds.length;
    final tomorrow = sourceDate.add(const Duration(days: 1));
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 78, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _DatePill(date: tomorrow),
          ),
          const SizedBox(height: 16),
          Text(
            'Kalan görevler',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Başka bir güne taşımak istediklerini seç.',
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 34),
          Text(
            '$selectedCount yarın taşınsın mı?',
            key: const ValueKey('daily-review-selection-count'),
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: tasks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final task = tasks[index];
                final selected = selectedIds.contains(task.id);
                return _SelectableReviewTask(
                  key: ValueKey('daily-review-task-${task.id}'),
                  task: task,
                  selected: selected,
                  enabled: !moving,
                  onTap: () => onToggle(task.id),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const ValueKey('daily-review-move-tomorrow'),
            onPressed: selectedCount == 0 || moving ? null : onTomorrow,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
            child: moving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('($selectedCount) yarına taşı'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const ValueKey('daily-review-more-dates'),
            onPressed: selectedCount == 0 || moving ? null : onMoreDates,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              shape: const StadiumBorder(),
            ),
            child: Text('($selectedCount) taşımak için daha fazla seçenek'),
          ),
          TextButton(
            key: const ValueKey('daily-review-finish'),
            onPressed: moving ? null : onFinish,
            child: const Text(
              'Değerlendirmem bitti',
              style: TextStyle(decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectableReviewTask extends StatelessWidget {
  const _SelectableReviewTask({
    super.key,
    required this.task,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final TaskModel task;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    checked: selected,
    button: true,
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(FlorienRadius.sm),
      child: Row(
        children: [
          AnimatedContainer(
            key: ValueKey('daily-review-select-${task.id}'),
            duration: const Duration(milliseconds: 160),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : context.palette.border,
                width: 1.5,
              ),
            ),
            child: selected
                ? Icon(
                    Icons.check_rounded,
                    size: 19,
                    color: Theme.of(context).colorScheme.onPrimary,
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(child: _ReviewTaskCard(task: task)),
        ],
      ),
    ),
  );
}

class _ReviewTaskCard extends StatelessWidget {
  const _ReviewTaskCard({required this.task, this.completed = false});

  final TaskModel task;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 9, 8),
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(FlorienRadius.sm),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(
        children: [
          TaskIconBadge.forTask(icon: task.icon, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    decoration: completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  _taskScheduleLabel(task),
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontSize: 11.5,
                    decoration: completed ? TextDecoration.lineThrough : null,
                  ),
                ),
              ],
            ),
          ),
          if (completed)
            Icon(
              Icons.check_circle_rounded,
              color: context.palette.textSecondary,
              size: 25,
            ),
        ],
      ),
    );
  }
}

class _FinishedReview extends StatelessWidget {
  const _FinishedReview({super.key});

  @override
  Widget build(BuildContext context) {
    final background = Color.alphaBlend(
      Theme.of(context).colorScheme.primary.withValues(alpha: .22),
      context.palette.background,
    );
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [background, context.palette.background],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 28,
            top: MediaQuery.sizeOf(context).height * .26,
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .55),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Değerlendirme bitti',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Bugünün planı tamamlandı.\nDinlenme ve şarj olma zamanı.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontSize: 17,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
    decoration: BoxDecoration(
      color: context.palette.selection,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(
        color: context.palette.border,
        width: FlorienBorders.thin,
      ),
    ),
    child: Text(
      _fullDateLabel(date),
      style: const TextStyle(
        color: FlorienColors.onPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _ReviewCloseButton extends StatelessWidget {
  const _ReviewCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey('daily-review-close'),
    tooltip: 'Değerlendirmeyi kapat',
    onPressed: onTap,
    iconSize: 18,
    constraints: const BoxConstraints.tightFor(width: 34, height: 34),
    style: IconButton.styleFrom(backgroundColor: context.palette.surfaceMuted),
    icon: const Icon(Icons.close_rounded),
  );
}

class _ReviewDatePickerSheet extends StatefulWidget {
  const _ReviewDatePickerSheet({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_ReviewDatePickerSheet> createState() => _ReviewDatePickerSheetState();
}

class _ReviewDatePickerSheetState extends State<_ReviewDatePickerSheet> {
  late DateTime _selectedDate = _dateOnly(widget.initialDate);

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final initialDate = _selectedDate.isBefore(today) ? today : _selectedDate;
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .82,
        ),
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: context.palette.border)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 34),
                Expanded(
                  child: Text(
                    'Taşıma tarihi',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const ValueKey('daily-review-date-close'),
                  tooltip: 'Tarih seçimini kapat',
                  onPressed: () => Navigator.pop(context),
                  iconSize: 18,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 34,
                  ),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            CalendarDatePicker(
              key: const ValueKey('daily-review-date-picker'),
              initialDate: initialDate,
              currentDate: today,
              firstDate: today,
              lastDate: DateTime(today.year + 5, 12, 31),
              onDateChanged: (value) =>
                  setState(() => _selectedDate = _dateOnly(value)),
            ),
            FilledButton(
              key: const ValueKey('daily-review-date-apply'),
              onPressed: () => Navigator.pop(context, _selectedDate),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                shape: const StadiumBorder(),
              ),
              child: Text('${_fullDateLabel(_selectedDate)} tarihine taşı'),
            ),
          ],
        ),
      ),
    );
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _taskScheduleLabel(TaskModel task) {
  final start = task.scheduledAt;
  if (task.isTimed && start != null) {
    final end = start.add(Duration(minutes: task.durationMinutes));
    return '${_clockLabel(start)} → ${_clockLabel(end)}';
  }
  return '${task.durationMinutes} dk';
}

String _clockLabel(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:'
    '${date.minute.toString().padLeft(2, '0')}';

String _fullDateLabel(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${_weekdays[date.weekday - 1]}';

const _months = <String>[
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

const _weekdays = <String>[
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];
