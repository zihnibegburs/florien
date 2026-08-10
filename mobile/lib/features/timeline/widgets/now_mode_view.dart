import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:florien/core/l10n/app_strings.dart';
import 'package:florien/core/models/models.dart';
import 'package:florien/core/theme/florien_theme.dart';
import 'package:florien/core/widgets/liquid_glass.dart';
import 'package:florien/core/utils/schedule_utils.dart';
import 'package:florien/features/providers.dart';

class NowModeView extends ConsumerWidget {
  const NowModeView({
    super.key,
    required this.tasks,
    required this.onTaskTap,
    required this.onStart,
    required this.onComplete,
  });

  final List<TaskModel> tasks;
  final void Function(TaskModel task) onTaskTap;
  final void Function(TaskModel task) onStart;
  final void Function(TaskModel task) onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final now = DateTime.now();
    final session = ref.watch(focusSessionProvider).valueOrNull;
    TaskModel? current;
    if (session != null) {
      current = findTaskInTimeline(TimelineModel(date: now, tasks: tasks), session.taskId);
    }
    current ??= currentTask(tasks, now);
    final next = nextTask(tasks, now, excludeId: current?.id);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NowCard(
            label: s.nowLabel,
            task: current,
            s: s,
            accent: FlorienColors.primary,
            onTap: current != null ? () => onTaskTap(current!) : null,
            onStart: current != null ? () => onStart(current!) : null,
            onComplete: current != null ? () => onComplete(current!) : null,
          ),
          const SizedBox(height: 16),
          _NowCard(
            label: s.upNext,
            task: next,
            s: s,
            accent: FlorienColors.primaryLight,
            onTap: next != null ? () => onTaskTap(next!) : null,
            onStart: next != null ? () => onStart(next!) : null,
            onComplete: next != null ? () => onComplete(next!) : null,
          ),
        ],
      ),
    );
  }
}

class _NowCard extends StatelessWidget {
  const _NowCard({
    required this.label,
    required this.task,
    required this.s,
    required this.accent,
    this.onTap,
    this.onStart,
    this.onComplete,
  });

  final String label;
  final TaskModel? task;
  final S s;
  final Color accent;
  final VoidCallback? onTap;
  final VoidCallback? onStart;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      blur: false,
      borderRadius: BorderRadius.circular(26),
      padding: const EdgeInsets.all(20),
      tintOpacity: 0.8,
      gradient: LinearGradient(
        colors: [
          accent.withValues(alpha: 0.12),
          accent.withValues(alpha: 0.04),
        ],
      ),
      child: task == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: accent, fontSize: 13)),
                const SizedBox(height: 8),
                Text(s.noPlanToday, style: TextStyle(color: context.palette.textSecondary)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: accent, fontSize: 13)),
                const SizedBox(height: 12),
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task!.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (task!.scheduledAt != null)
                        Text(
                          DateFormat('HH:mm').format(task!.scheduledAt!.toLocal()),
                          style: TextStyle(color: accent, fontWeight: FontWeight.w600),
                        ),
                      if (task!.hasMotivation) ...[
                        const SizedBox(height: 8),
                        Text(
                          task!.motivation!,
                          style: TextStyle(color: context.palette.textSecondary, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!task!.isCompleted) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onStart,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(s.start),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onComplete,
                          icon: const Icon(Icons.check_rounded),
                          label: Text(s.complete),
                          style: ElevatedButton.styleFrom(backgroundColor: FlorienColors.success),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}
