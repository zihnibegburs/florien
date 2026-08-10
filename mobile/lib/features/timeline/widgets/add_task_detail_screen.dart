import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/data/routine_templates.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/adhd_models.dart';
import 'package:florien/core/models/ai_models.dart';
import 'package:florien/core/models/recurrence.dart';
import 'package:florien/core/repositories/ai_repository.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/speech_text_field.dart';
import 'package:florien/features/timeline/widgets/inline_time_picker.dart';
import 'package:florien/features/timeline/widgets/recurrence_picker.dart';
import 'package:florien/features/timeline/widgets/task_draft.dart';

class AddTaskDetailScreen extends ConsumerStatefulWidget {
  const AddTaskDetailScreen({
    super.key,
    required this.selectedDate,
    this.initialDraft,
  });

  final DateTime selectedDate;
  final TaskDraft? initialDraft;

  @override
  ConsumerState<AddTaskDetailScreen> createState() => _AddTaskDetailScreenState();
}

class _AddTaskDetailScreenState extends ConsumerState<AddTaskDetailScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _rewardController;
  late final TextEditingController _motivationController;
  late bool _useAiDuration;
  late bool _addToInbox;
  EnergyLevel? _energyLevel;
  late int _transitionBuffer;
  late bool _remind5Min;
  late int _duration;
  late String _selectedColor;
  late TimeOfDay _time;
  late RecurrenceSelection _recurrence;
  late bool _splitIntoSubtasks;
  late bool _remind10Min;
  late bool _remind1Min;
  List<AiStepModel>? _previewSteps;
  bool _loadingPreview = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final draft = widget.initialDraft ?? TaskDraft();
    _titleController = TextEditingController(text: draft.title);
    _rewardController = TextEditingController(text: draft.reward);
    _motivationController = TextEditingController(text: draft.motivation);
    _useAiDuration = draft.useAiDuration;
    _addToInbox = draft.addToInbox;
    _energyLevel = draft.energyLevel;
    _transitionBuffer = draft.transitionBuffer;
    _remind5Min = draft.remind5Min;
    _duration = draft.duration;
    _selectedColor = draft.selectedColor;
    _time = draft.time ?? TimeOfDay.now();
    _recurrence = draft.recurrence;
    _splitIntoSubtasks = draft.splitIntoSubtasks;
    _remind10Min = draft.remind10Min;
    _remind1Min = draft.remind1Min;
    _previewSteps = draft.previewSteps;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _rewardController.dispose();
    _motivationController.dispose();
    super.dispose();
  }

  TaskDraft get _draft => TaskDraft(
        title: _titleController.text,
        useAiDuration: _useAiDuration,
        addToInbox: _addToInbox,
        energyLevel: _energyLevel,
        transitionBuffer: _transitionBuffer,
        remind5Min: _remind5Min,
        duration: _duration,
        selectedColor: _selectedColor,
        time: _time,
        recurrence: _recurrence,
        splitIntoSubtasks: _splitIntoSubtasks,
        remind10Min: _remind10Min,
        remind1Min: _remind1Min,
        previewSteps: _previewSteps,
        reward: _rewardController.text,
        motivation: _motivationController.text,
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
      if (mounted) {
        setState(() => _error = ref.read(stringsProvider).friendlyAiError(e, includeBootRunHint: true));
      }
    } finally {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  Future<void> _submit() async {
    if (_titleController.text.trim().isEmpty || _submitting) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await submitTaskDraft(
        ref: ref,
        draft: _draft,
        selectedDate: widget.selectedDate,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _error = ref.read(stringsProvider).friendlyAiError(e, includeBootRunHint: true));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        title: Text(s.taskDetails),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 32),
        children: [
          SpeechTextField(
            controller: _titleController,
            decoration: InputDecoration(hintText: s.taskNameHint),
            onChanged: (_) {
              if (_previewSteps != null) setState(() => _previewSteps = null);
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: medicationPresetsFor(ref.watch(appLanguageProvider).valueOrNull ?? 'tr').map((preset) {
              return ActionChip(
                avatar: const Icon(Icons.medication_rounded, size: 16),
                label: Text(preset.title),
                onPressed: () {
                  _titleController.text = preset.title;
                  setState(() {
                    _duration = preset.durationMinutes;
                    _selectedColor = preset.color;
                    _useAiDuration = false;
                  });
                },
              );
            }).toList(),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.addToInbox, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(s.inboxHint, style: const TextStyle(fontSize: 12)),
            value: _addToInbox,
            onChanged: (v) => setState(() => _addToInbox = v),
          ),
          if (!_splitIntoSubtasks) ...[
            const SizedBox(height: 12),
            Text(s.motivationWhy, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            TextField(
              controller: _motivationController,
              decoration: InputDecoration(hintText: s.motivationWhy),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Text(s.energyLevel, style: Theme.of(context).textTheme.labelLarge),
            Wrap(
              spacing: 8,
              children: EnergyLevel.values.map((e) {
                return ChoiceChip(
                  label: Text(s.energyLabel(e)),
                  selected: _energyLevel == e,
                  onSelected: (_) => setState(() => _energyLevel = _energyLevel == e ? null : e),
                );
              }).toList(),
            ),
          ],
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: context.palette.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: SwitchListTile(
              title: Text(s.splitIntoSteps, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                s.splitIntoStepsHint,
                style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
              ),
              secondary: const Icon(Icons.auto_awesome_rounded, color: FlorienColors.primary),
              value: _splitIntoSubtasks,
              onChanged: (v) => setState(() {
                _splitIntoSubtasks = v;
                if (!v) _previewSteps = null;
              }),
            ),
          ),
          if (_splitIntoSubtasks) ...[
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
            ],
          ],
          if (!_splitIntoSubtasks) ...[
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
          if (!_splitIntoSubtasks) ...[
            const SizedBox(height: 20),
            Text(s.duration, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: Text(s.aiDuration),
                  selected: _useAiDuration,
                  onSelected: (_) => setState(() => _useAiDuration = true),
                  selectedColor: FlorienColors.primary.withValues(alpha: 0.2),
                ),
                ...[15, 30, 45, 60, 90].map((min) {
                  final selected = !_useAiDuration && _duration == min;
                  return ChoiceChip(
                    label: Text(s.minutesShort(min)),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      _useAiDuration = false;
                      _duration = min;
                    }),
                    selectedColor: FlorienColors.primary.withValues(alpha: 0.2),
                  );
                }),
              ],
            ),
          ],
          if (!_splitIntoSubtasks) ...[
            const SizedBox(height: 16),
            Text(s.taskReminders, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.remind10Min, style: const TextStyle(fontWeight: FontWeight.w600)),
              value: _remind10Min,
              onChanged: (v) => setState(() => _remind10Min = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.remind5Min, style: const TextStyle(fontWeight: FontWeight.w600)),
              value: _remind5Min,
              onChanged: (v) => setState(() => _remind5Min = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.remind1Min, style: const TextStyle(fontWeight: FontWeight.w600)),
              value: _remind1Min,
              onChanged: (v) => setState(() => _remind1Min = v),
            ),
          ],
          if (!_addToInbox) ...[
            const SizedBox(height: 20),
            Text(s.time, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            InlineTimePicker(
              value: _time,
              onChanged: (time) => setState(() => _time = time),
            ),
            if (!_splitIntoSubtasks) ...[
              const SizedBox(height: 20),
              RecurrencePicker(
                value: _recurrence,
                onChanged: (value) => setState(() => _recurrence = value),
              ),
            ],
          ],
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
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(_splitIntoSubtasks ? s.addTaskAndSteps : s.addTaskButton),
            ),
          ),
        ],
      ),
    );
  }
}
