import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/ai_models.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/platform/notification_service.dart';
import 'package:florien/core/repositories/ai_repository.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/features/providers.dart';
import 'package:florien/features/timeline/widgets/delete_task_dialog.dart';
import 'package:florien/features/timeline/widgets/inline_time_picker.dart';

class EditTaskSheet extends ConsumerStatefulWidget {
  const EditTaskSheet({
    super.key,
    required this.task,
    required this.selectedDate,
    this.showAiBreakdown = false,
  });

  final TaskModel task;
  final DateTime selectedDate;
  final bool showAiBreakdown;

  @override
  ConsumerState<EditTaskSheet> createState() => _EditTaskSheetState();
}

class _EditTaskSheetState extends ConsumerState<EditTaskSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _rewardController;
  late int _duration;
  late String _selectedColor;
  late TimeOfDay _time;
  bool _loadingPreview = false;
  bool _submitting = false;
  bool _breakingDown = false;
  bool _remind10Min = false;
  bool _remind1Min = false;
  bool _remindersLoaded = false;
  late Map<String, int> _subtaskDurations;
  List<AiStepModel>? _previewSteps;
  String? _error;

  bool get _isSubtask => widget.task.parentTaskId != null;
  bool get _canBreakdown => widget.showAiBreakdown && !_isSubtask && !widget.task.hasSubtasks;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _rewardController = TextEditingController(text: widget.task.reward ?? '');
    _duration = widget.task.durationMinutes;
    _selectedColor = widget.task.color;
    if (widget.task.scheduledAt != null) {
      final local = widget.task.scheduledAt!.toLocal();
      _time = TimeOfDay(hour: local.hour, minute: local.minute);
    } else {
      _time = TimeOfDay.now();
    }
    _subtaskDurations = {
      for (final sub in widget.task.subtasks) sub.id: sub.durationMinutes,
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReminders());
  }

  Future<void> _loadReminders() async {
    final settings = await ref.read(notificationServiceProvider).loadReminderSettings(widget.task.id);
    if (mounted) {
      setState(() {
        _remind10Min = settings.remind10Min;
        _remind1Min = settings.remind1Min;
        _remindersLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _rewardController.dispose();
    super.dispose();
  }

  DateTime get _scheduledAt => DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
        widget.selectedDate.day,
        _time.hour,
        _time.minute,
      );

  Future<void> _loadPreview() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() {
      _loadingPreview = true;
      _error = null;
      _previewSteps = null;
    });

    try {
      final result = await ref.read(aiRepositoryProvider).breakdown(title);
      if (mounted) setState(() => _previewSteps = result.steps);
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  String _friendlyError(Object e) => ref.read(stringsProvider).friendlyAiError(e);

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(timelineProvider.notifier).updateTask(
            id: widget.task.id,
            title: _titleController.text.trim(),
            color: _selectedColor,
            durationMinutes: _isSubtask || !widget.task.hasSubtasks ? _duration : null,
            scheduledAt: _scheduledAt,
            reward: _isSubtask || widget.task.hasSubtasks ? null : _rewardController.text.trim(),
            reminders: TaskReminderSettings(remind10Min: _remind10Min, remind1Min: _remind1Min),
          );

      if (widget.task.hasSubtasks) {
        for (final sub in widget.task.subtasks) {
          final newDuration = _subtaskDurations[sub.id];
          if (newDuration != null && newDuration != sub.durationMinutes) {
            await ref.read(timelineProvider.notifier).updateTask(
                  id: sub.id,
                  durationMinutes: newDuration,
                );
          }
        }
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _applyBreakdown() async {
    setState(() {
      _breakingDown = true;
      _error = null;
    });

    try {
      var steps = _previewSteps;
      if (steps == null || steps.isEmpty) {
        final result = await ref.read(aiRepositoryProvider).breakdown(_titleController.text.trim());
        steps = result.steps;
      }

      await ref.read(timelineProvider.notifier).updateTask(
            id: widget.task.id,
            title: _titleController.text.trim(),
            color: _selectedColor,
            scheduledAt: _scheduledAt,
          );

      await ref.read(timelineProvider.notifier).addSubtasksToTask(
            parentId: widget.task.id,
            subtasks: steps
                .map((s) => (title: s.title, durationMinutes: s.durationMinutes, color: s.color))
                .toList(),
          );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _breakingDown = false);
    }
  }

  Future<void> _delete() async {
    final s = ref.read(stringsProvider);
    final scope = await showDeleteTaskDialog(
      context: context,
      s: s,
      task: widget.task,
    );

    if (scope == null || !mounted) return;

    setState(() => _submitting = true);
    try {
      await ref.read(timelineProvider.notifier).deleteTask(widget.task.id, scope: scope);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _submitting || _breakingDown;
    final s = ref.watch(stringsProvider);

    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isSubtask ? s.editStep : s.editTask,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                  onPressed: busy ? null : _delete,
                  tooltip: s.delete,
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(hintText: s.taskNameHint),
              onChanged: (_) {
                if (_previewSteps != null) setState(() => _previewSteps = null);
              },
            ),
            if (!_isSubtask && !widget.task.hasSubtasks) ...[
              const SizedBox(height: 20),
              Text(s.rewardLabel, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(
                s.rewardOptionalHint,
                style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _rewardController,
                decoration: InputDecoration(
                  hintText: s.rewardHint,
                  prefixIcon: const Icon(Icons.card_giftcard_rounded, color: FlorienColors.primary),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
            if (!_isSubtask && !widget.task.hasSubtasks) ...[
              const SizedBox(height: 20),
              Text(s.duration, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [15, 30, 45, 60, 90].map((min) {
                  final selected = _duration == min;
                  return ChoiceChip(
                    label: Text(s.minutesShort(min)),
                    selected: selected,
                    onSelected: (_) => setState(() => _duration = min),
                    selectedColor: FlorienColors.primary.withValues(alpha: 0.2),
                  );
                }).toList(),
              ),
            ] else if (_isSubtask) ...[
              const SizedBox(height: 20),
              Text(s.duration, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [5, 10, 15, 20, 30, 45].map((min) {
                  final selected = _duration == min;
                  return ChoiceChip(
                    label: Text(s.minutesShort(min)),
                    selected: selected,
                    onSelected: (_) => setState(() => _duration = min),
                    selectedColor: FlorienColors.primary.withValues(alpha: 0.2),
                  );
                }).toList(),
              ),
            ] else if (widget.task.hasSubtasks) ...[
              const SizedBox(height: 20),
              Text(s.stepDurations, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              ...widget.task.subtasks.map((sub) {
                final duration = _subtaskDurations[sub.id] ?? sub.durationMinutes;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8FC),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sub.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [5, 10, 15, 20, 30, 45].map((min) {
                          final selected = duration == min;
                          return ChoiceChip(
                            label: Text(s.minutesShort(min)),
                            selected: selected,
                            onSelected: (_) => setState(() => _subtaskDurations[sub.id] = min),
                            selectedColor: FlorienColors.primary.withValues(alpha: 0.2),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (_remindersLoaded) ...[
              const SizedBox(height: 16),
              Text(s.taskReminders, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.remind10Min, style: const TextStyle(fontWeight: FontWeight.w600)),
                value: _remind10Min,
                onChanged: busy ? null : (v) => setState(() => _remind10Min = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s.remind1Min, style: const TextStyle(fontWeight: FontWeight.w600)),
                value: _remind1Min,
                onChanged: busy ? null : (v) => setState(() => _remind1Min = v),
              ),
            ],
            const SizedBox(height: 20),
            Text(s.time, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            InlineTimePicker(
              value: _time,
              onChanged: (time) => setState(() => _time = time),
            ),
            const SizedBox(height: 20),
            Text(s.color, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: FlorienColors.taskColors.map((hex) {
                final color = FlorienColors.fromHex(hex);
                final selected = _selectedColor == hex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = hex),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: selected ? Border.all(color: context.palette.textPrimary, width: 3) : null,
                    ),
                    child: selected ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                  ),
                );
              }).toList(),
            ),
            if (_canBreakdown) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: FlorienColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    s.aiBreakdown,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                s.aiBreakdownHint,
                style: TextStyle(fontSize: 13, color: context.palette.textSecondary),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loadingPreview || _titleController.text.trim().isEmpty ? null : _loadPreview,
                  icon: _loadingPreview
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.visibility_rounded, size: 18),
                  label: Text(_loadingPreview ? s.aiThinking : s.previewSteps),
                ),
              ),
              if (_previewSteps != null) ...[
                const SizedBox(height: 12),
                ..._previewSteps!.asMap().entries.map((e) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: FlorienColors.fromHex(e.value.color).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${e.key + 1}.',
                            style: TextStyle(fontWeight: FontWeight.w700, color: context.palette.textSecondary),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e.value.title, style: const TextStyle(fontWeight: FontWeight.w600))),
                          Text(
                            s.minutesShort(e.value.durationMinutes),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: FlorienColors.fromHex(e.value.color),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : _applyBreakdown,
                    icon: _breakingDown
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: Text(_breakingDown ? s.applyingSteps : s.applySteps),
                  ),
                ),
              ],
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: busy ? null : _save,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(s.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
