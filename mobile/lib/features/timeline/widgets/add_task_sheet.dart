import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/recurrence.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/liquid_glass.dart';
import 'package:florien/core/widgets/florien_soft_overlay.dart';
import 'package:florien/core/widgets/speech_text_field.dart';
import 'package:florien/features/timeline/widgets/add_task_detail_screen.dart';
import 'package:florien/features/timeline/widgets/task_draft.dart';

class AddTaskSheet extends ConsumerStatefulWidget {
  const AddTaskSheet({super.key, required this.selectedDate});

  final DateTime selectedDate;

  @override
  ConsumerState<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<AddTaskSheet> {
  final _titleController = TextEditingController();
  bool _isRecurring = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  TaskDraft get _draft => TaskDraft(
        title: _titleController.text,
        recurrence: _isRecurring
            ? const RecurrenceSelection(type: RecurrenceType.daily)
            : const RecurrenceSelection(),
      );

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
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _error = ref.read(stringsProvider).friendlyAiError(e, includeBootRunHint: true));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openDetails() async {
    final created = await pushFlorienOverlayRoute<bool>(
      context: context,
      builder: (_) => AddTaskDetailScreen(
        selectedDate: widget.selectedDate,
        initialDraft: _draft,
      ),
    );
    if (created == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: LiquidGlass(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        blur: true,
        blurSigma: LiquidGlassTokens.blurSigmaChrome,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            Text(
              s.newTask,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            SpeechTextField(
              controller: _titleController,
              decoration: InputDecoration(hintText: s.taskNameHint),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.recurringTask, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                _isRecurring ? s.repeatDaily : s.repeatNone,
                style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
              ),
              value: _isRecurring,
              onChanged: (v) => setState(() => _isRecurring = v),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _openDetails,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: Text(s.taskDetails),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _submitting || _titleController.text.trim().isEmpty ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(s.addTaskButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
