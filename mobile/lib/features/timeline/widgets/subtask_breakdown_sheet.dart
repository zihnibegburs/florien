import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/ai_models.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/repositories/ai_repository.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/copyable_error_banner.dart';
import 'package:florien/features/providers.dart';

class SubtaskBreakdownSheet extends ConsumerStatefulWidget {
  const SubtaskBreakdownSheet({
    super.key,
    required this.task,
    required this.selectedDate,
  });

  final TaskModel task;
  final DateTime selectedDate;

  @override
  ConsumerState<SubtaskBreakdownSheet> createState() => _SubtaskBreakdownSheetState();
}

class _SubtaskBreakdownSheetState extends ConsumerState<SubtaskBreakdownSheet> {
  bool _loadingPreview = false;
  bool _applying = false;
  List<AiStepModel>? _previewSteps;
  String? _error;

  Future<void> _loadPreview() async {
    setState(() {
      _loadingPreview = true;
      _error = null;
      _previewSteps = null;
    });

    try {
      final result = await ref.read(aiRepositoryProvider).breakdown(widget.task.title);
      if (mounted) setState(() => _previewSteps = result.steps);
    } catch (e) {
      if (mounted) setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loadingPreview = false);
    }
  }

  Future<void> _apply() async {
    setState(() {
      _applying = true;
      _error = null;
    });

    try {
      var steps = _previewSteps;
      if (steps == null || steps.isEmpty) {
        final result = await ref.read(aiRepositoryProvider).breakdown(widget.task.title);
        steps = result.steps;
      }

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
      if (mounted) setState(() => _applying = false);
    }
  }

  String _friendlyError(Object e) {
    return e.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final busy = _loadingPreview || _applying;

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
                const Icon(Icons.auto_awesome_rounded, color: FlorienColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.aiBreakdown,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              s.aiBreakdownHint,
              style: TextStyle(color: context.palette.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FlorienColors.fromHex(widget.task.color).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(widget.task.title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : _loadPreview,
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
            if (_error != null) ...[
              const SizedBox(height: 12),
              CopyableErrorBanner(message: _error!),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: busy ? null : _apply,
                icon: _applying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(_applying ? s.applyingSteps : s.applySteps),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
